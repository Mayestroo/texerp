import { Injectable } from '@nestjs/common';
import { type EntityManager } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { RedisService } from '../../../infrastructure/redis/redis.service';
import { uuidv7 } from '../../../shared/common/uuid';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { PlatformImpersonationPayload } from './platform-access-token-claims';
import { TenantNotFoundError } from './errors/tenant-not-found.error';

interface ImpersonatedUserRow {
  id: string;
  tenant_id: string;
  phone: string;
  role: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT' | 'DIRECTOR';
  tenant_status: 'ACTIVE' | 'SUSPENDED' | 'TERMINATED';
}

interface ImpersonationResult {
  access_token: string;
  expires_in: 3600;
  tenant_id: string;
  user_id: string;
}

interface ImpersonationSessionRow {
  id: string;
  tenant_id: string;
  user_id: string;
  expires_at: Date;
}

@Injectable()
export class ImpersonationService {
  constructor(
    private readonly platformDatabase: PlatformDatabase,
    private readonly jwtService: JwtService,
    private readonly redisService: RedisService,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  async startImpersonation(
    tenantId: string,
    userId: string,
    actorId: string,
  ): Promise<ImpersonationResult> {
    const sessionId = uuidv7();
    const refreshTokenHash = `impersonation:${sessionId}`;
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    const user = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<ImpersonatedUserRow[]>(
        `SELECT u.id, u.tenant_id, u.phone, u.role, t.status as tenant_status
         FROM users u
         JOIN tenants t ON t.id = u.tenant_id
         WHERE u.id = $1 AND u.tenant_id = $2 AND u.status = 'ACTIVE' AND t.status = 'ACTIVE'`,
        [userId, tenantId],
      );
      return rows[0];
    });

    if (!user) {
      throw new TenantNotFoundError();
    }

    await this.platformDatabase.execute(async (manager) => {
      await this.audit(manager, 'ImpersonationStarted', actorId, user.tenant_id, 'User', user.id, {
        impersonated_user_id: user.id,
        tenant_id: user.tenant_id,
        session_id: sessionId,
      });

      await manager.query(
        `INSERT INTO user_sessions
         (id, tenant_id, user_id, refresh_token_hash, expires_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [sessionId, user.tenant_id, user.id, refreshTokenHash, expiresAt],
      );
    });

    const accessToken = await this.jwtService.signAsync<PlatformImpersonationPayload>(
      {
        sub: user.id,
        tenant_id: user.tenant_id,
        role: user.role,
        phone: user.phone,
        token_use: 'impersonation',
        impersonation: true,
        jti: sessionId,
        sid: sessionId,
      },
      { expiresIn: '1h' },
    );

    this.eventPublisher.publish(
      EventNames.IMPERSONATION_SESSION_STARTED,
      'User',
      user.id,
      user.tenant_id,
      actorId,
      'SUPER_ADMIN',
      { impersonated_user_id: user.id, tenant_id: user.tenant_id, session_id: sessionId },
    );

    return {
      access_token: accessToken,
      expires_in: 3600,
      tenant_id: user.tenant_id,
      user_id: user.id,
    };
  }

  async endImpersonation(jti: string, actorId: string): Promise<void> {
    const session = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<ImpersonationSessionRow[]>(
        `SELECT id, tenant_id, user_id, expires_at FROM user_sessions WHERE id = $1 FOR UPDATE`,
        [jti],
      );
      return rows[0];
    });

    if (!session) {
      return;
    }

    const ttlRemaining = Math.max(
      Math.ceil((session.expires_at.getTime() - Date.now()) / 1000),
      1,
    );

    await this.platformDatabase.execute(async (manager) => {
      await this.audit(
        manager,
        'ImpersonationEnded',
        actorId,
        session.tenant_id,
        'UserSession',
        session.id,
        {
          impersonated_user_id: session.user_id,
          tenant_id: session.tenant_id,
          jti: session.id,
        },
      );

      await manager.query(
        `UPDATE user_sessions
         SET revoked_at = now(), revoked_reason = 'IMPERSONATION_ENDED'
         WHERE id = $1`,
        [session.id],
      );
    });

    const redis = this.redisService.getRedis();
    await redis.set(
      `auth:session-revoked:${session.id}`,
      '1',
      'EX',
      ttlRemaining,
    );

    this.eventPublisher.publish(
      EventNames.IMPERSONATION_SESSION_ENDED,
      'UserSession',
      session.id,
      session.tenant_id,
      actorId,
      'SUPER_ADMIN',
      {
        impersonated_user_id: session.user_id,
        tenant_id: session.tenant_id,
        jti: session.id,
      },
    );
  }

  private async audit(
    manager: EntityManager,
    eventType: string,
    actorId: string,
    tenantId: string | null,
    targetType: string,
    targetId: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    await manager.query(
      `INSERT INTO platform_audit_events
       (id, event_type, actor_id, tenant_id, target_type, target_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, now())`,
      [uuidv7(), eventType, actorId, tenantId, targetType, targetId, JSON.stringify(payload)],
    );
  }
}
