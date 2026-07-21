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
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { PlatformLoginDto } from './dto/platform-login.dto';
import { PlatformAccessTokenClaims, PlatformAccessTokenPayload } from './platform-access-token-claims';

const DUMMY_PASSWORD_HASH =
  '$2b$12$CaqxpTgb3ihTYsUymUcr/u.Ku6gr7vpSiNx16QQkiyPoNj6MZhHL.';

interface PlatformUserRow {
  id: string;
  email: string;
  password_hash: string;
  full_name: string;
  status: 'ACTIVE' | 'DEACTIVATED';
  failed_login_attempts: number;
  locked_until: Date | null;
}

interface PlatformLoginResult {
  access_token: string;
  refresh_token: string;
  expires_in: 900;
  user: {
    id: string;
    email: string;
    full_name: string;
    role: 'SUPER_ADMIN';
  };
}

@Injectable()
export class PlatformAuthService {
  constructor(
    private readonly platformDatabase: PlatformDatabase,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: PlatformLoginDto): Promise<PlatformLoginResult> {
    return this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<PlatformUserRow[]>(
        `SELECT id, email, password_hash, full_name, status, failed_login_attempts, locked_until
         FROM platform_users
         WHERE email = $1
         FOR UPDATE`,
        [dto.email],
      );
      const user = rows[0];
      const passwordMatches = await bcrypt.compare(
        dto.password,
        user?.password_hash ?? DUMMY_PASSWORD_HASH,
      );

      if (!user || !passwordMatches) {
        if (user) {
          await this.recordFailedLogin(manager, user);
        }
        throw new UnauthorizedException({
          success: false,
          error: {
            code: 'INVALID_CREDENTIALS',
            message: 'Noto‘g‘ri email yoki parol',
          },
        });
      }

      if (user.status !== 'ACTIVE') {
        throw new ForbiddenException({
          success: false,
          error: {
            code: 'ACCOUNT_DEACTIVATED',
            message: 'Platform administrator hisobi nofaol',
          },
        });
      }

      if (user.locked_until && user.locked_until > new Date()) {
        throw this.accountLockedException(user.locked_until);
      }

      const sessionId = uuidv7();
      const refreshToken = randomBytes(32).toString('base64url');
      const refreshTokenHash = createHash('sha256')
        .update(refreshToken)
        .digest('hex');
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

      await manager.query(
        `INSERT INTO platform_sessions
         (id, platform_user_id, refresh_token_hash, expires_at)
         VALUES ($1, $2, $3, $4)`,
        [sessionId, user.id, refreshTokenHash, expiresAt],
      );

      await manager.query(
        `UPDATE platform_users
         SET failed_login_attempts = 0,
             locked_until = NULL,
             updated_at = now()
         WHERE id = $1`,
        [user.id],
      );

      const accessToken = await this.jwtService.signAsync<PlatformAccessTokenPayload>({
        sub: user.id,
        tenant_id: null,
        role: 'SUPER_ADMIN',
        email: user.email,
        token_use: 'platform',
        jti: uuidv7(),
        sid: sessionId,
      });

      return {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: 900,
        user: {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: 'SUPER_ADMIN',
        },
      };
    });
  }

  async validateAccessSession(claims: PlatformAccessTokenClaims): Promise<boolean> {
    const rows = await this.platformDatabase.execute(async (manager) => {
      return manager.query<Array<{ is_valid: boolean }>>(
        `SELECT EXISTS (
          SELECT 1
          FROM platform_sessions
          WHERE id = $1
            AND platform_user_id = $2
            AND expires_at > now()
        ) AS is_valid`,
        [claims.sid, claims.sub],
      );
    });
    return rows[0]?.is_valid === true;
  }

  private async recordFailedLogin(
    manager: import('typeorm').EntityManager,
    user: PlatformUserRow,
  ): Promise<void> {
    const nextAttempt = user.failed_login_attempts + 1;
    const lockedUntil =
      nextAttempt >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : user.locked_until;

    await manager.query(
      `UPDATE platform_users
       SET failed_login_attempts = $2,
           locked_until = $3,
           updated_at = now()
       WHERE id = $1`,
      [user.id, nextAttempt, lockedUntil],
    );
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
}
