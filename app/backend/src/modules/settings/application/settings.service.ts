import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { uuidv7 } from '../../../shared/common/uuid';
import { UpdateSettingsDto } from './dto/update-settings.dto';

export interface TenantSettingsView {
  tenant_id: string;
  name: string;
  timezone: string;
  language: string;
  currency: string;
  back_date_window_days: number;
  suspicious_quantity_multiplier: number;
  payroll_min_pay: number;
  duplicate_window_minutes: number;
  stock_negative_mode: 'HARD_BLOCK' | 'WARNING';
}

@Injectable()
export class SettingsService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  async get(tenantId: string): Promise<TenantSettingsView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      return this.getWithManager(manager, tenantId);
    });
  }

  private async getWithManager(
    manager: EntityManager,
    tenantId: string,
  ): Promise<TenantSettingsView> {
    const settingsRows = await manager.query<any[]>(
      `SELECT * FROM tenant_settings WHERE tenant_id = $1 LIMIT 1`,
      [tenantId],
    );

    if (!settingsRows[0]) {
      const id = uuidv7();
      await manager.query(
        `INSERT INTO tenant_settings (id, tenant_id) VALUES ($1, $2)`,
        [id, tenantId],
      );
      const created = await manager.query<any[]>(
        `SELECT * FROM tenant_settings WHERE tenant_id = $1 LIMIT 1`,
        [tenantId],
      );
      return this.mapSettings(created[0], null);
    }

    // Get tenant profile via SECURITY DEFINER function
    const profileRows = await manager.query<any[]>(
      `SELECT * FROM get_tenant_profile($1)`,
      [tenantId],
    );
    const profile = profileRows[0] || {};

    return this.mapSettings(settingsRows[0], profile);
  }

  async update(
    tenantId: string,
    actorId: string,
    dto: UpdateSettingsDto,
  ): Promise<TenantSettingsView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const sets: string[] = [];
      const values: unknown[] = [];
      let paramIndex = 1;

      if (dto.back_date_window_days !== undefined) {
        sets.push(`back_date_window_days = $${paramIndex++}`);
        values.push(dto.back_date_window_days);
      }
      if (dto.suspicious_quantity_multiplier !== undefined) {
        sets.push(`suspicious_quantity_multiplier = $${paramIndex++}`);
        values.push(dto.suspicious_quantity_multiplier);
      }
      if (dto.payroll_min_pay !== undefined) {
        sets.push(`payroll_min_pay = $${paramIndex++}`);
        values.push(dto.payroll_min_pay);
      }
      if (dto.duplicate_window_minutes !== undefined) {
        sets.push(`duplicate_window_minutes = $${paramIndex++}`);
        values.push(dto.duplicate_window_minutes);
      }

      if (sets.length === 0) {
        throw new HttpException(
          {
            success: false,
            error: {
              code: 'EMPTY_UPDATE',
              message: "Hech qanday o'zgartirish kiritilmadi",
            },
          },
          HttpStatus.BAD_REQUEST,
        );
      }

      sets.push('updated_at = now()');
      sets.push(`updated_by = $${paramIndex++}`);
      values.push(actorId);
      values.push(tenantId);

      await manager.query(
        `UPDATE tenant_settings SET ${sets.join(', ')} WHERE tenant_id = $${paramIndex}`,
        values,
      );

      // Read back using SAME manager (sees uncommitted changes)
      const result = await this.getWithManager(manager, tenantId);

      this.eventPublisher.publish(
        EventNames.TENANT_SETTINGS_UPDATED,
        'TenantSettings',
        tenantId,
        tenantId,
        actorId,
        'DIRECTOR',
        { ...dto },
      );

      return result;
    });
  }

  private mapSettings(row: any, profile: any): TenantSettingsView {
    return {
      tenant_id: row.tenant_id,
      name: profile?.name || null,
      timezone: profile?.timezone || 'Asia/Tashkent',
      language: profile?.language || 'uz',
      currency: profile?.currency || 'UZS',
      back_date_window_days: row.back_date_window_days,
      suspicious_quantity_multiplier: Number(row.suspicious_quantity_multiplier),
      payroll_min_pay: row.payroll_min_pay,
      duplicate_window_minutes: row.duplicate_window_minutes,
      stock_negative_mode: row.stock_negative_mode,
    };
  }
}
