import { Injectable } from '@nestjs/common';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';

export interface ResolvedTemplate {
  id: string;
  title_uz: string;
  title_ru: string;
  body_uz: string;
  body_ru: string;
  channel: string;
  is_critical: boolean;
}

@Injectable()
export class NotificationTemplatesService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async resolveTemplate(tenantId: string, type: string): Promise<ResolvedTemplate | null> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<ResolvedTemplate[]>(
        `SELECT * FROM resolve_notification_template($1)`,
        [type],
      );
      return rows[0] || null;
    });
  }

  interpolate(text: string, vars: Record<string, string>): string {
    return text.replace(/\{\{(\w+)\}\}/g, (_: string, key: string) => vars[key] ?? '');
  }
}
