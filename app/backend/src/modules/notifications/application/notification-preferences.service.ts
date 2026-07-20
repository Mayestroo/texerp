import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';

export interface NotificationPreferenceView {
  notification_type: string;
  is_enabled: boolean;
  is_critical: boolean;
  can_disable: boolean;
}

@Injectable()
export class NotificationPreferencesService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async getPreferences(tenantId: string, userId: string): Promise<NotificationPreferenceView[]> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      return this.getPreferencesWithManager(manager, tenantId, userId);
    });
  }

  private async getPreferencesWithManager(
    manager: EntityManager,
    tenantId: string,
    userId: string,
  ): Promise<NotificationPreferenceView[]> {
    const templateRows = await manager.query<{ type: string; is_critical: boolean }[]>(
      `SELECT DISTINCT ON (type) type, is_critical
       FROM notification_templates
       WHERE (tenant_id IS NULL OR tenant_id = $1) AND is_active = true
         AND channel IN ('BOTH', 'PUSH', 'IN_APP')
       ORDER BY type, tenant_id NULLS LAST`,
      [tenantId],
    );

    const prefRows = await manager.query<{ notification_type: string; is_enabled: boolean }[]>(
      `SELECT notification_type, is_enabled FROM notification_preferences
       WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, userId],
    );
    const prefsMap = new Map(prefRows.map((r) => [r.notification_type, r.is_enabled]));

    return templateRows.map((t) => {
      const isEnabled = t.is_critical ? true : (prefsMap.get(t.type) ?? true);
      return {
        notification_type: t.type,
        is_enabled: isEnabled,
        is_critical: t.is_critical,
        can_disable: !t.is_critical,
      };
    });
  }

  async updatePreferences(
    tenantId: string,
    userId: string,
    preferences: Array<{ notification_type: string; is_enabled: boolean }>,
  ): Promise<NotificationPreferenceView[]> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const templateRows = await manager.query<{ type: string; is_critical: boolean }[]>(
        `SELECT DISTINCT ON (type) type, is_critical
         FROM notification_templates
         WHERE (tenant_id IS NULL OR tenant_id = $1) AND is_active = true
           AND channel IN ('BOTH', 'PUSH', 'IN_APP')
         ORDER BY type, tenant_id NULLS LAST`,
        [tenantId],
      );
      const templateMap = new Map(templateRows.map((r) => [r.type, r.is_critical]));

      for (const pref of preferences) {
        if (!templateMap.has(pref.notification_type)) {
          throw new HttpException(
            {
              success: false,
              error: {
                code: 'UNKNOWN_NOTIFICATION_TYPE',
                message: `Noma'lum bildirishnoma turi: ${pref.notification_type}`,
              },
            },
            HttpStatus.BAD_REQUEST,
          );
        }
        if (templateMap.get(pref.notification_type) && !pref.is_enabled) {
          throw new HttpException(
            {
              success: false,
              error: {
                code: 'CANNOT_DISABLE_CRITICAL',
                message: "Majburiy bildirishnomalarni o'chirib bo'lmaydi",
              },
            },
            HttpStatus.BAD_REQUEST,
          );
        }
      }

      for (const pref of preferences) {
        await manager.query(
          `INSERT INTO notification_preferences (id, tenant_id, user_id, notification_type, is_enabled)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (tenant_id, user_id, notification_type)
           DO UPDATE SET is_enabled = $5`,
          [uuidv7(), tenantId, userId, pref.notification_type, pref.is_enabled],
        );
      }

      return this.getPreferencesWithManager(manager, tenantId, userId);
    });
  }

  async isEnabled(tenantId: string, userId: string, type: string): Promise<boolean> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const templateRows = await manager.query<{ is_critical: boolean }[]>(
        `SELECT DISTINCT ON (type) is_critical
         FROM notification_templates
         WHERE (tenant_id IS NULL OR tenant_id = $1) AND type = $2 AND is_active = true
           AND channel IN ('BOTH', 'PUSH', 'IN_APP')
         ORDER BY type, tenant_id NULLS LAST
         LIMIT 1`,
        [tenantId, type],
      );
      if (templateRows[0]?.is_critical) return true;

      const prefRows = await manager.query<{ is_enabled: boolean }[]>(
        `SELECT is_enabled FROM notification_preferences
         WHERE tenant_id = $1 AND user_id = $2 AND notification_type = $3`,
        [tenantId, userId, type],
      );
      return prefRows[0]?.is_enabled ?? true;
    });
  }
}
