import { Injectable } from '@nestjs/common';
import bcrypt from 'bcrypt';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { AccessTokenClaims } from './access-token-claims';
import { CreateUserDto } from './dto/create-user.dto';
import { ListUsersQueryDto } from './dto/list-users-query.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { CannotCreateDirectorError } from './errors/cannot-create-director.error';
import { CannotDeactivateSelfError } from './errors/cannot-deactivate-self.error';
import { EmptyUpdateError } from './errors/empty-update.error';
import { PhoneAlreadyExistsError } from './errors/phone-already-exists.error';
import { UserAlreadyActiveError } from './errors/user-already-active.error';
import { UserAlreadyDeactivatedError } from './errors/user-already-deactivated.error';
import { UserNotFoundError } from './errors/user-not-found.error';
import { WorkerCodeAlreadyExistsError } from './errors/worker-code-already-exists.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

interface CreatedUser {
  id: string;
  full_name: string;
  worker_code: string;
  role: Exclude<CreateUserDto['role'], 'DIRECTOR'>;
  status: 'ACTIVE';
}

interface UserSummary {
  id: string;
  full_name: string;
  worker_code: string;
  phone: string;
  role: AccessTokenClaims['role'];
  status: 'ACTIVE' | 'DEACTIVATED';
  avatar_url: string | null;
  department: { id: string; name: string } | null;
  foreman: { id: string; full_name: string } | null;
}

interface UserProfile extends Omit<UserSummary, 'department' | 'foreman'> {
  language: 'uz' | 'ru';
  department: { id: string; name: string; code: string } | null;
  foreman: { id: string; full_name: string; phone: string } | null;
  created_at: Date;
}

interface CountRow {
  total: string;
}

interface LifecycleUserRow {
  status: 'ACTIVE' | 'DEACTIVATED';
  deactivated_at: Date | null;
  deactivated_by: string | null;
}

interface SessionIdRow {
  id: string;
}

interface ListUsersResult {
  data: UserSummary[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
    has_next: boolean;
  };
}

interface PostgresError {
  code?: string;
  constraint?: string;
}

@Injectable()
export class UsersService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async list(
    tenantId: string,
    query: ListUsersQueryDto,
  ): Promise<ListUsersResult> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const parameters: unknown[] = [tenantId];
      const conditions = ['u.tenant_id = $1'];

      if (query.status !== 'ALL') {
        parameters.push(query.status);
        conditions.push(`u.status = $${parameters.length}`);
      }
      if (query.role) {
        parameters.push(query.role);
        conditions.push(`u.role = $${parameters.length}`);
      }
      if (query.search !== undefined) {
        parameters.push(query.search);
        const searchParameter = `$${parameters.length}`;
        conditions.push(
          `(u.full_name ILIKE '%' || ${searchParameter} || '%' OR u.worker_code ILIKE '%' || ${searchParameter} || '%')`,
        );
      }

      const where = conditions.join(' AND ');
      const countRows = await manager.query<CountRow[]>(
        `SELECT count(*)::text AS total FROM users u WHERE ${where}`,
        parameters,
      );
      const total = Number(countRows[0]?.total ?? 0);
      const pageParameters = [
        ...parameters,
        query.limit,
        (query.page - 1) * query.limit,
      ];
      const limitParameter = `$${pageParameters.length - 1}`;
      const offsetParameter = `$${pageParameters.length}`;
      const data = await manager.query<UserSummary[]>(
        `SELECT
           u.id,
           u.full_name,
           u.worker_code,
           u.phone,
           u.role,
           u.status,
           u.avatar_url,
           CASE WHEN d.id IS NULL THEN NULL
             ELSE json_build_object('id', d.id, 'name', d.name)
           END AS department,
           CASE WHEN f.id IS NULL THEN NULL
             ELSE json_build_object('id', f.id, 'full_name', f.full_name)
           END AS foreman
         FROM users u
         LEFT JOIN foreman_assignments fa
           ON fa.tenant_id = u.tenant_id
          AND fa.worker_id = u.id
          AND fa.unassigned_at IS NULL
         LEFT JOIN departments d
           ON d.tenant_id = fa.tenant_id AND d.id = fa.department_id
         LEFT JOIN users f
           ON f.tenant_id = fa.tenant_id AND f.id = fa.foreman_id
         WHERE ${where}
         ORDER BY u.full_name ASC, u.id ASC
         LIMIT ${limitParameter} OFFSET ${offsetParameter}`,
        pageParameters,
      );
      const totalPages = Math.ceil(total / query.limit);

      return {
        data,
        pagination: {
          page: query.page,
          limit: query.limit,
          total,
          total_pages: totalPages,
          has_next: query.page < totalPages,
        },
      };
    });
  }

  async getById(
    tenantId: string,
    actor: AccessTokenClaims,
    userId: string,
  ): Promise<UserProfile> {
    const user = await this.tenantDatabase.withTenant(tenantId, (manager) =>
      this.findProfile(manager, tenantId, userId, actor),
    );

    if (!user) {
      throw new UserNotFoundError();
    }
    return user;
  }

  async create(
    tenantId: string,
    actor: AccessTokenClaims,
    dto: CreateUserDto,
    metadata: RequestMetadata,
  ): Promise<CreatedUser> {
    if (dto.role === 'DIRECTOR') throw new CannotCreateDirectorError();

    const userId = uuidv7();
    const pinHash = await bcrypt.hash(dto.initial_pin, 12);
    const language = dto.language ?? 'uz';
    const user: CreatedUser = {
      id: userId,
      full_name: dto.full_name,
      worker_code: dto.worker_code,
      role: dto.role,
      status: 'ACTIVE',
    };

    try {
      await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             after_state, ip_address, user_agent)
           VALUES ($1, $2, 'USER', $3, 'USER_CREATED', $4, $5, $6::jsonb, $7, $8)`,
          [
            uuidv7(),
            tenantId,
            userId,
            actor.sub,
            actor.role,
            JSON.stringify({
              ...user,
              phone: dto.phone,
              language,
              avatar_url: null,
              created_by: actor.sub,
            }),
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );
        await manager.query(
          `INSERT INTO users
            (id, tenant_id, phone, pin_hash, full_name, worker_code, role,
             language, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            userId,
            tenantId,
            dto.phone,
            pinHash,
            dto.full_name,
            dto.worker_code,
            dto.role,
            language,
            actor.sub,
          ],
        );
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }

    return user;
  }

  async update(
    tenantId: string,
    actor: AccessTokenClaims,
    userId: string,
    dto: UpdateUserDto,
    metadata: RequestMetadata,
  ): Promise<UserProfile> {
    if (
      dto.full_name === undefined &&
      dto.language === undefined &&
      dto.avatar_url === undefined
    ) {
      throw new EmptyUpdateError();
    }

    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<
        Array<Pick<UserProfile, 'full_name' | 'language' | 'avatar_url'>>
      >(
        `SELECT full_name, language, avatar_url
         FROM users
         WHERE tenant_id = $1 AND id = $2
         FOR UPDATE`,
        [tenantId, userId],
      );
      const current = rows[0];
      if (!current) throw new UserNotFoundError();

      const beforeState: Record<string, unknown> = {};
      const afterState: Record<string, unknown> = {};
      for (const field of ['full_name', 'language', 'avatar_url'] as const) {
        if (dto[field] !== undefined && dto[field] !== current[field]) {
          beforeState[field] = current[field];
          afterState[field] = dto[field];
        }
      }

      if (Object.keys(afterState).length > 0) {
        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             before_state, after_state, ip_address, user_agent)
           VALUES ($1, $2, 'USER', $3, 'USER_UPDATED', $4, $5, $6::jsonb, $7::jsonb, $8, $9)`,
          [
            uuidv7(),
            tenantId,
            userId,
            actor.sub,
            actor.role,
            JSON.stringify(beforeState),
            JSON.stringify(afterState),
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );
        await manager.query(
          `UPDATE users
           SET full_name = COALESCE($3, full_name),
               language = COALESCE($4, language),
               avatar_url = CASE WHEN $5 THEN $6 ELSE avatar_url END,
               updated_at = now()
           WHERE tenant_id = $1 AND id = $2`,
          [
            tenantId,
            userId,
            dto.full_name ?? null,
            dto.language ?? null,
            dto.avatar_url !== undefined,
            dto.avatar_url ?? null,
          ],
        );
      }

      const profile = await this.findProfile(manager, tenantId, userId);
      if (!profile) throw new UserNotFoundError();
      return profile;
    });
  }

  async deactivate(
    tenantId: string,
    actor: AccessTokenClaims,
    userId: string,
    metadata: RequestMetadata,
  ): Promise<{ message: string; sessions_revoked: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<LifecycleUserRow[]>(
        `SELECT status, deactivated_at, deactivated_by
         FROM users
         WHERE tenant_id = $1 AND id = $2
         FOR UPDATE`,
        [tenantId, userId],
      );
      const user = rows[0];
      if (!user) throw new UserNotFoundError();
      if (userId === actor.sub) throw new CannotDeactivateSelfError();
      if (user.status === 'DEACTIVATED') {
        throw new UserAlreadyDeactivatedError();
      }

      const activeSessions = await manager.query<SessionIdRow[]>(
        `SELECT id
         FROM user_sessions
         WHERE tenant_id = $1
           AND user_id = $2
           AND revoked_at IS NULL
           AND expires_at > now()
         FOR UPDATE`,
        [tenantId, userId],
      );
      const sessionsRevoked = activeSessions.length;
      const deactivatedAt = new Date();
      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           before_state, after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER', $3, 'USER_DEACTIVATED', $4, $5,
           $6::jsonb, $7::jsonb, $8, $9)`,
        [
          uuidv7(),
          tenantId,
          userId,
          actor.sub,
          actor.role,
          JSON.stringify({
            status: user.status,
            deactivated_at: user.deactivated_at,
            deactivated_by: user.deactivated_by,
          }),
          JSON.stringify({
            status: 'DEACTIVATED',
            deactivated_at: deactivatedAt,
            deactivated_by: actor.sub,
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );
      await manager.query(
        `UPDATE users
         SET status = 'DEACTIVATED',
             deactivated_at = $3,
             deactivated_by = $4,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, userId, deactivatedAt, actor.sub],
      );

      return {
        message: 'Foydalanuvchi nofaol qilindi',
        sessions_revoked: sessionsRevoked,
      };
    });
  }

  async reactivate(
    tenantId: string,
    actor: AccessTokenClaims,
    userId: string,
    metadata: RequestMetadata,
  ): Promise<{ message: string }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<LifecycleUserRow[]>(
        `SELECT status, deactivated_at, deactivated_by
         FROM users
         WHERE tenant_id = $1 AND id = $2
         FOR UPDATE`,
        [tenantId, userId],
      );
      const user = rows[0];
      if (!user) throw new UserNotFoundError();
      if (user.status === 'ACTIVE') throw new UserAlreadyActiveError();

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           before_state, after_state, ip_address, user_agent)
         VALUES ($1, $2, 'USER', $3, 'USER_REACTIVATED', $4, $5,
           $6::jsonb, $7::jsonb, $8, $9)`,
        [
          uuidv7(),
          tenantId,
          userId,
          actor.sub,
          actor.role,
          JSON.stringify({
            status: user.status,
            deactivated_at: user.deactivated_at,
            deactivated_by: user.deactivated_by,
          }),
          JSON.stringify({
            status: 'ACTIVE',
            deactivated_at: null,
            deactivated_by: null,
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );
      await manager.query(
        `UPDATE users
         SET status = 'ACTIVE',
             deactivated_at = NULL,
             deactivated_by = NULL,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, userId],
      );

      return { message: 'Foydalanuvchi faollashtirildi' };
    });
  }

  async updateFcmToken(
    tenantId: string,
    userId: string,
    fcmToken: string,
    platform: 'ANDROID' | 'IOS' = 'ANDROID',
  ): Promise<void> {
    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `UPDATE device_tokens
         SET is_active = false, last_used_at = now()
         WHERE tenant_id = $1 AND user_id = $2 AND platform = $3 AND is_active = true`,
        [tenantId, userId, platform],
      );

      const existing = await manager.query<{ id: string }[]>(
        `SELECT id FROM device_tokens
         WHERE tenant_id = $1 AND user_id = $2 AND fcm_token = $3 AND platform = $4
         LIMIT 1`,
        [tenantId, userId, fcmToken, platform],
      );

      if (existing[0]) {
        await manager.query(
          `UPDATE device_tokens
           SET is_active = true, last_used_at = now()
           WHERE tenant_id = $1 AND id = $2`,
          [tenantId, existing[0].id],
        );
      } else {
        await manager.query(
          `INSERT INTO device_tokens (id, tenant_id, user_id, fcm_token, platform, is_active, registered_at, last_used_at)
           VALUES ($1, $2, $3, $4, $5, true, now(), now())`,
          [uuidv7(), tenantId, userId, fcmToken, platform],
        );
      }
    });
  }

  private async findProfile(
    manager: EntityManager,
    tenantId: string,
    userId: string,
    actor?: AccessTokenClaims,
  ): Promise<UserProfile | undefined> {
    const visibility =
      actor?.role === 'FOREMAN'
        ? `AND (
            u.id = $3
            OR (
              u.role = 'WORKER'
              AND EXISTS (
                SELECT 1
                FROM foreman_assignments visible_assignment
                WHERE visible_assignment.tenant_id = u.tenant_id
                  AND visible_assignment.worker_id = u.id
                  AND visible_assignment.foreman_id = $3
                  AND visible_assignment.unassigned_at IS NULL
              )
            )
          )`
        : '';
    const parameters =
      actor?.role === 'FOREMAN'
        ? [tenantId, userId, actor.sub]
        : [tenantId, userId];
    const rows = await manager.query<UserProfile[]>(
      `SELECT
         u.id,
         u.full_name,
         u.phone,
         u.worker_code,
         u.role,
         u.status,
         u.language,
         u.avatar_url,
         CASE WHEN d.id IS NULL THEN NULL
           ELSE json_build_object('id', d.id, 'name', d.name, 'code', d.code)
         END AS department,
         CASE WHEN f.id IS NULL THEN NULL
           ELSE json_build_object(
             'id', f.id,
             'full_name', f.full_name,
             'phone', f.phone
           )
         END AS foreman,
         u.created_at
       FROM users u
       LEFT JOIN foreman_assignments fa
         ON fa.tenant_id = u.tenant_id
        AND fa.worker_id = u.id
        AND fa.unassigned_at IS NULL
       LEFT JOIN departments d
         ON d.tenant_id = fa.tenant_id AND d.id = fa.department_id
       LEFT JOIN users f
         ON f.tenant_id = fa.tenant_id AND f.id = fa.foreman_id
       WHERE u.tenant_id = $1 AND u.id = $2
       ${visibility}`,
      parameters,
    );
    return rows[0];
  }

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as PostgresError;
    if (driverError.code !== '23505') return;

    if (driverError.constraint === 'users_phone_key') {
      throw new PhoneAlreadyExistsError();
    }
    if (driverError.constraint === 'users_tenant_id_worker_code_key') {
      throw new WorkerCodeAlreadyExistsError();
    }
  }
}
