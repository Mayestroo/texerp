import { Injectable } from '@nestjs/common';
import { type EntityManager } from 'typeorm';
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { UpdateFeatureFlagsDto } from './dto/update-feature-flags.dto';

interface FeatureFlagRow {
  id: string;
  tenant_id: string;
  feature_key: string;
  is_enabled: boolean;
  enabled_at: Date | null;
  enabled_by: string | null;
}

@Injectable()
export class FeatureFlagsService {
  constructor(
    private readonly platformDatabase: PlatformDatabase,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  async getFlags(tenantId: string): Promise<FeatureFlagRow[]> {
    return this.platformDatabase.execute(async (manager) => {
      return manager.query<FeatureFlagRow[]>(
        `SELECT * FROM tenant_feature_flags WHERE tenant_id = $1 ORDER BY feature_key ASC`,
        [tenantId],
      );
    });
  }

  async updateFlags(
    tenantId: string,
    actorId: string,
    dto: UpdateFeatureFlagsDto,
  ): Promise<FeatureFlagRow[]> {
    return this.platformDatabase.execute(async (manager) => {
      const entries = Object.entries(dto.flags);
      await this.audit(
        manager,
        'FeatureFlagsUpdated',
        actorId,
        tenantId,
        'TenantFeatureFlags',
        tenantId,
        { flags: dto.flags },
      );

      for (const [featureKey, isEnabled] of entries) {
        await manager.query(
          `INSERT INTO tenant_feature_flags
           (id, tenant_id, feature_key, is_enabled, enabled_at, enabled_by)
           VALUES ($1, $2, $3, $4, now(), $5)
           ON CONFLICT (tenant_id, feature_key)
           DO UPDATE SET
             is_enabled = EXCLUDED.is_enabled,
             enabled_at = EXCLUDED.enabled_at,
             enabled_by = EXCLUDED.enabled_by`,
          [uuidv7(), tenantId, featureKey, isEnabled, actorId],
        );
      }

      const rows = await manager.query<FeatureFlagRow[]>(
        `SELECT * FROM tenant_feature_flags WHERE tenant_id = $1 ORDER BY feature_key ASC`,
        [tenantId],
      );

      this.eventPublisher.publish(
        EventNames.FEATURE_FLAG_CHANGED,
        'TenantFeatureFlags',
        tenantId,
        tenantId,
        actorId,
        'SUPER_ADMIN',
        { flags: dto.flags },
      );

      return rows;
    });
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
