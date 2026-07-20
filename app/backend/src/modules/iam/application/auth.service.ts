import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'node:crypto';
import { DataSource } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ChangePinDto } from './dto/change-pin.dto';
import { VerifyPinDto } from './dto/verify-pin.dto';
import { AccessTokenClaims } from './access-token-claims';
import { RedisService } from '../../../infrastructure/redis/redis.service';

const DUMMY_PIN_HASH =
  '$2b$12$CaqxpTgb3ihTYsUymUcr/u.Ku6gr7vpSiNx16QQkiyPoNj6MZhHL.';

interface LoginUserRow {
  id: string;
  tenant_id: string;
  phone: string;
  pin_hash: string;
  full_name: string;
  worker_code: string;
  role: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';
  user_status: 'ACTIVE' | 'DEACTIVATED';
  language: 'uz' | 'ru';
  avatar_url: string | null;
  department_id: string | null;
  department_name: string | null;
  foreman_id: string | null;
  foreman_name: string | null;
  failed_login_attempts: number;
  locked_until: Date | null;
  tenant_status: 'ACTIVE' | 'SUSPENDED' | 'TERMINATED';
}

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

interface LoginResult {
  access_token: string;
  refresh_token: string;
  expires_in: 900;
  user: {
    id: string;
    full_name: string;
    worker_code: string;
    role: LoginUserRow['role'];
    language: LoginUserRow['language'];
    avatar_url: string | null;
    department: { id: string; name: string } | null;
    foreman: { id: string; full_name: string } | null;
  };
}

interface SessionLookupRow {
  session_id: string;
  tenant_id: string;
  user_id: string;
  refresh_token_hash: string;
  expires_at: Date;
  revoked_at: Date | null;
  phone: string;
  role: LoginUserRow['role'];
  user_status: LoginUserRow['user_status'];
  tenant_status: LoginUserRow['tenant_status'];
  token_state: 'CURRENT' | 'USED';
}

interface RefreshResult {
  access_token: string;
  refresh_token: string;
  expires_in: 900;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly tenantDatabase: TenantDatabase,
    private readonly jwtService: JwtService,
    private readonly redis: RedisService,
  ) {}

  async login(dto: LoginDto, metadata: RequestMetadata): Promise<LoginResult> {
    await this.enforceLoginRateLimit(dto.phone, metadata.ipAddress);
    const rows = await this.dataSource.query<LoginUserRow[]>(
      'SELECT * FROM auth_lookup_user($1)',
      [dto.phone],
    );
    const user = rows[0];
    const pinMatches = await bcrypt.compare(
      dto.pin,
      user?.pin_hash ?? DUMMY_PIN_HASH,
    );

    if (!user || !pinMatches) {
      if (user && (!user.locked_until || user.locked_until <= new Date())) {
        await this.recordFailedLogin(user, metadata);
      }
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'INVALID_CREDENTIALS',
          message: "Noto'g'ri telefon yoki PIN kod",
        },
      });
    }
    if (user.user_status !== 'ACTIVE') {
      throw new ForbiddenException({
        success: false,
        error: { code: 'ACCOUNT_DEACTIVATED', message: 'Foydalanuvchi nofaol' },
      });
    }
    if (user.tenant_status !== 'ACTIVE') {
      throw new ForbiddenException({
        success: false,
        error: { code: 'TENANT_SUSPENDED', message: 'Tenant faol emas' },
      });
    }
    if (user.locked_until && user.locked_until > new Date()) {
      const retryAfterSeconds = Math.max(
        Math.ceil((user.locked_until.getTime() - Date.now()) / 1000),
        1,
      );
      throw new HttpException(
        {
          success: false,
          error: {
            code: 'ACCOUNT_LOCKED',
            message: 'Hisob vaqtincha bloklangan',
            retry_after_seconds: retryAfterSeconds,
          },
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const sessionId = uuidv7();
    const refreshToken = randomBytes(32).toString('base64url');
    const refreshTokenHash = createHash('sha256')
      .update(refreshToken)
      .digest('hex');
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    const loginState = await this.tenantDatabase.withTenant(
      user.tenant_id,
      async (manager) => {
        const currentRows = await manager.query<
          Array<{
            status: LoginUserRow['user_status'];
            locked_until: Date | null;
          }>
        >(`SELECT status, locked_until FROM users WHERE id = $1 FOR UPDATE`, [
          user.id,
        ]);
        const current = currentRows[0];
        if (!current || current.status !== 'ACTIVE') {
          return { outcome: 'DEACTIVATED' as const, lockedUntil: null };
        }
        if (current.locked_until && current.locked_until > new Date()) {
          return {
            outcome: 'LOCKED' as const,
            lockedUntil: current.locked_until,
          };
        }
        await manager.query(
          `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER_SESSION', $3, 'SESSION_CREATED', $4, $5,
           jsonb_build_object('session_id', to_jsonb($3::uuid)), $6, $7)`,
          [
            uuidv7(),
            user.tenant_id,
            sessionId,
            user.id,
            user.role,
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );
        await manager.query(
          `UPDATE users
         SET failed_login_attempts = 0, locked_until = NULL, updated_at = now()
         WHERE id = $1`,
          [user.id],
        );
        await manager.query(
          `INSERT INTO user_sessions
          (id, tenant_id, user_id, refresh_token_hash, ip_address, user_agent, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            sessionId,
            user.tenant_id,
            user.id,
            refreshTokenHash,
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
            expiresAt,
          ],
        );
        return { outcome: 'CREATED' as const, lockedUntil: null };
      },
    );
    if (loginState.outcome === 'DEACTIVATED') {
      throw new ForbiddenException({
        success: false,
        error: { code: 'ACCOUNT_DEACTIVATED', message: 'Foydalanuvchi nofaol' },
      });
    }
    if (loginState.outcome === 'LOCKED' && loginState.lockedUntil) {
      throw this.accountLockedException(loginState.lockedUntil);
    }

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      tenant_id: user.tenant_id,
      role: user.role,
      phone: user.phone,
      jti: uuidv7(),
      sid: sessionId,
    });

    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: 900,
      user: {
        id: user.id,
        full_name: user.full_name,
        worker_code: user.worker_code,
        role: user.role,
        language: user.language,
        avatar_url: user.avatar_url,
        department:
          user.department_id && user.department_name
            ? { id: user.department_id, name: user.department_name }
            : null,
        foreman:
          user.foreman_id && user.foreman_name
            ? { id: user.foreman_id, full_name: user.foreman_name }
            : null,
      },
    };
  }

  async refresh(
    dto: RefreshDto,
    metadata: RequestMetadata,
  ): Promise<RefreshResult> {
    const oldHash = createHash('sha256')
      .update(dto.refresh_token)
      .digest('hex');
    const rows = await this.dataSource.query<SessionLookupRow[]>(
      'SELECT * FROM auth_lookup_session($1)',
      [oldHash],
    );
    const session = rows[0];

    if (!session) {
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh token yaroqsiz',
        },
      });
    }
    if (session.expires_at <= new Date()) {
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'REFRESH_TOKEN_EXPIRED',
          message: 'Refresh token muddati tugagan',
        },
      });
    }
    if (session.revoked_at || session.token_state === 'USED') {
      if (!session.revoked_at) {
        await this.revokeSession(session, 'REFRESH_REPLAY', metadata);
      }
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh token yaroqsiz',
        },
      });
    }
    if (session.user_status !== 'ACTIVE') {
      throw new ForbiddenException({
        success: false,
        error: { code: 'ACCOUNT_DEACTIVATED', message: 'Foydalanuvchi nofaol' },
      });
    }
    if (session.tenant_status !== 'ACTIVE') {
      throw new ForbiddenException({
        success: false,
        error: { code: 'TENANT_SUSPENDED', message: 'Tenant faol emas' },
      });
    }

    const newRefreshToken = randomBytes(32).toString('base64url');
    const newHash = createHash('sha256').update(newRefreshToken).digest('hex');

    const rotated = await this.tenantDatabase.withTenant(
      session.tenant_id,
      async (manager) => {
        const current = await manager.query<Array<{ id: string }>>(
          `SELECT id FROM user_sessions
           WHERE id = $1 AND refresh_token_hash = $2 AND revoked_at IS NULL
           FOR UPDATE`,
          [session.session_id, oldHash],
        );
        if (!current[0]) return false;
        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             after_state, ip_address, user_agent)
           VALUES ($1, $2, 'USER_SESSION', $3, 'SESSION_REFRESHED', $4, $5,
             jsonb_build_object('session_id', to_jsonb($3::uuid)), $6, $7)`,
          [
            uuidv7(),
            session.tenant_id,
            session.session_id,
            session.user_id,
            session.role,
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );
        await manager.query(
          `INSERT INTO used_refresh_tokens
            (refresh_token_hash, tenant_id, session_id, user_id)
           VALUES ($1, $2, $3, $4)`,
          [oldHash, session.tenant_id, session.session_id, session.user_id],
        );
        await manager.query(
          `UPDATE user_sessions
           SET refresh_token_hash = $1,
               ip_address = $2,
               user_agent = $3
           WHERE id = $4 AND refresh_token_hash = $5 AND revoked_at IS NULL`,
          [
            newHash,
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
            session.session_id,
            oldHash,
          ],
        );
        return true;
      },
    );
    if (!rotated) {
      await this.revokeSession(session, 'REFRESH_REPLAY', metadata);
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh token yaroqsiz',
        },
      });
    }

    const accessToken = await this.jwtService.signAsync({
      sub: session.user_id,
      tenant_id: session.tenant_id,
      role: session.role,
      phone: session.phone,
      jti: uuidv7(),
      sid: session.session_id,
    });

    return {
      access_token: accessToken,
      refresh_token: newRefreshToken,
      expires_in: 900,
    };
  }

  async logout(
    dto: RefreshDto,
    claims: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<void> {
    const refreshTokenHash = createHash('sha256')
      .update(dto.refresh_token)
      .digest('hex');
    const rows = await this.dataSource.query<SessionLookupRow[]>(
      'SELECT * FROM auth_lookup_session($1)',
      [refreshTokenHash],
    );
    const session = rows[0];

    if (
      !session ||
      session.revoked_at ||
      session.user_id !== claims.sub ||
      session.tenant_id !== claims.tenant_id ||
      session.session_id !== claims.sid
    ) {
      throw new UnauthorizedException({
        success: false,
        error: {
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh token yaroqsiz',
        },
      });
    }

    await this.revokeSession(session, 'LOGOUT', metadata);
  }

  private async revokeSession(
    session: SessionLookupRow,
    reason: 'LOGOUT' | 'REFRESH_REPLAY',
    metadata: RequestMetadata,
  ): Promise<void> {
    await this.tenantDatabase.withTenant(session.tenant_id, async (manager) => {
      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER_SESSION', $3, 'SESSION_REVOKED', $4, $5,
           jsonb_build_object('reason', $6::text), $7, $8)`,
        [
          uuidv7(),
          session.tenant_id,
          session.session_id,
          session.user_id,
          session.role,
          reason,
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );
      await manager.query(
        `UPDATE user_sessions
         SET revoked_at = now(), revoked_reason = $2
         WHERE id = $1 AND revoked_at IS NULL`,
        [session.session_id, reason],
      );
    });
    const ttlSeconds = Math.max(
      Math.ceil((session.expires_at.getTime() - Date.now()) / 1000),
      1,
    );
    await this.redis.revokeSession(session.session_id, ttlSeconds);
  }

  async validateAccessSession(claims: AccessTokenClaims): Promise<boolean> {
    if (await this.redis.isSessionRevoked(claims.sid)) return false;

    const rows = await this.dataSource.query<Array<{ is_valid: boolean }>>(
      `SELECT auth_validate_session($1, $2, $3) AS is_valid`,
      [claims.sid, claims.sub, claims.tenant_id],
    );
    const isValid = rows[0]?.is_valid === true;
    if (!isValid) {
      await this.redis.revokeSession(
        claims.sid,
        Math.max(claims.exp - Math.floor(Date.now() / 1000), 1),
      );
    }
    return isValid;
  }

  private async recordFailedLogin(
    user: LoginUserRow,
    metadata: RequestMetadata,
  ): Promise<number> {
    return this.tenantDatabase.withTenant(user.tenant_id, async (manager) => {
      const currentRows = await manager.query<
        Array<{ failed_login_attempts: number; locked_until: Date | null }>
      >(
        `SELECT failed_login_attempts, locked_until
         FROM users WHERE id = $1 FOR UPDATE`,
        [user.id],
      );
      const current = currentRows[0];
      if (!current) return 0;
      if (current.locked_until && current.locked_until > new Date()) {
        return current.failed_login_attempts;
      }
      const nextAttempt = current.failed_login_attempts + 1;
      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER', $3, 'LOGIN_FAILED', $3, $4,
           jsonb_build_object('attempt', $5::integer), $6, $7)`,
        [
          uuidv7(),
          user.tenant_id,
          user.id,
          user.role,
          nextAttempt,
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );
      await manager.query(
        `UPDATE users
         SET failed_login_attempts = $2::smallint,
             locked_until = CASE
               WHEN $2::smallint >= 5 THEN now() + interval '15 minutes'
               ELSE locked_until
             END,
             updated_at = now()
         WHERE id = $1`,
        [user.id, nextAttempt],
      );
      return nextAttempt;
    });
  }

  private async enforceLoginRateLimit(
    phone: string,
    ipAddress?: string,
  ): Promise<void> {
    const phoneHash = createHash('sha256').update(phone).digest('hex');
    const [phoneAllowed, ipAllowed] = await Promise.all([
      this.redis.consumeRateLimit(`ratelimit:login:phone:${phoneHash}`, 10, 60),
      this.redis.consumeRateLimit(
        `ratelimit:login:ip:${ipAddress ?? 'unknown'}`,
        10,
        15 * 60,
      ),
    ]);
    if (!phoneAllowed || !ipAllowed) {
      throw new HttpException(
        {
          success: false,
          error: {
            code: 'RATE_LIMITED',
            message: "Ko'p urinish. Keyinroq qayta urinib ko'ring",
            retry_after_seconds: 60,
          },
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private accountLockedException(lockedUntil: Date): HttpException {
    const retryAfterSeconds = Math.max(
      Math.ceil((lockedUntil.getTime() - Date.now()) / 1000),
      1,
    );
    return new HttpException(
      {
        success: false,
        error: {
          code: 'ACCOUNT_LOCKED',
          message: 'Hisob vaqtincha bloklangan',
          retry_after_seconds: retryAfterSeconds,
        },
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  async verifyPin(
    userId: string,
    tenantId: string,
    dto: VerifyPinDto,
  ): Promise<void> {
    const user = await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<LoginUserRow[]>(
        `SELECT * FROM users WHERE id = $1 AND tenant_id = $2`,
        [userId, tenantId]
      );
      return rows[0];
    });

    if (!user) {
      throw new UnauthorizedException({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'Foydalanuvchi topilmadi' },
      });
    }

    const pinMatches = await bcrypt.compare(dto.pin, user.pin_hash);
    if (!pinMatches) {
      throw new ForbiddenException({
        success: false,
        error: { code: 'INVALID_CURRENT_PIN', message: "Joriy PIN noto'g'ri" },
      });
    }
  }

  async changePin(
    userId: string,
    tenantId: string,
    dto: ChangePinDto,
    metadata: RequestMetadata,
  ): Promise<void> {
    const user = await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<LoginUserRow[]>(
        `SELECT * FROM users WHERE id = $1 AND tenant_id = $2`,
        [userId, tenantId]
      );
      return rows[0];
    });

    if (!user) {
      throw new UnauthorizedException({
        success: false,
        error: { code: 'USER_NOT_FOUND', message: 'Foydalanuvchi topilmadi' },
      });
    }

    const pinMatches = await bcrypt.compare(dto.current_pin, user.pin_hash);
    if (!pinMatches) {
      throw new ForbiddenException({
        success: false,
        error: { code: 'INVALID_CURRENT_PIN', message: "Joriy PIN noto'g'ri" },
      });
    }

    const newPinHash = await bcrypt.hash(dto.new_pin, 12);

    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER', $3, 'PIN_CHANGED', $3, $4,
           '{}'::jsonb, $5, $6)`,
        [
          uuidv7(),
          tenantId,
          userId,
          user.role,
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      await manager.query(
        `UPDATE users
         SET pin_hash = $1, updated_at = now()
         WHERE id = $2 AND tenant_id = $3`,
        [newPinHash, userId, tenantId]
      );
    });
  }
}
