import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { CreatePlanDto } from './dto/create-plan.dto';
import { UpdatePlanDto } from './dto/update-plan.dto';
import { PlanNotFoundError } from './errors/plan-not-found.error';
import { PlanNameAlreadyExistsError } from './errors/plan-name-already-exists.error';

interface PlanRow {
  id: string;
  name: string;
  description: string | null;
  price_monthly_tiyin: number;
  price_annual_tiyin: number;
  currency: string;
  user_limit: number | null;
  storage_quota_gb: number | null;
  features: string[];
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

@Injectable()
export class PlansService {
  constructor(private readonly platformDatabase: PlatformDatabase) {}

  async list(): Promise<PlanRow[]> {
    return this.platformDatabase.execute(async (manager) => {
      return manager.query<PlanRow[]>(
        `SELECT * FROM subscription_plans ORDER BY created_at DESC`,
      );
    });
  }

  async get(id: string): Promise<PlanRow> {
    const plan = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<PlanRow[]>(
        `SELECT * FROM subscription_plans WHERE id = $1`,
        [id],
      );
      return rows[0];
    });

    if (!plan) {
      throw new PlanNotFoundError();
    }
    return plan;
  }

  async create(dto: CreatePlanDto, actorId: string): Promise<PlanRow> {
    const id = uuidv7();
    try {
      return await this.platformDatabase.execute(async (manager) => {
        await this.audit(manager, 'PlanCreated', actorId, null, 'SubscriptionPlan', id, {
          name: dto.name,
          price_monthly_tiyin: dto.price_monthly_tiyin,
          price_annual_tiyin: dto.price_annual_tiyin,
        });

        await manager.query(
          `INSERT INTO subscription_plans
           (id, name, description, price_monthly_tiyin, price_annual_tiyin,
            currency, user_limit, storage_quota_gb, features, is_active)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            id,
            dto.name,
            dto.description ?? null,
            dto.price_monthly_tiyin,
            dto.price_annual_tiyin,
            dto.currency ?? 'UZS',
            dto.user_limit ?? null,
            dto.storage_quota_gb ?? null,
            JSON.stringify(dto.features ?? []),
            dto.is_active ?? true,
          ],
        );

        const rows = await manager.query<PlanRow[]>(
          `SELECT * FROM subscription_plans WHERE id = $1`,
          [id],
        );
        return rows[0];
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async update(id: string, dto: UpdatePlanDto, actorId: string): Promise<PlanRow> {
    return this.platformDatabase.execute(async (manager) => {
      const existingRows = await manager.query<PlanRow[]>(
        `SELECT * FROM subscription_plans WHERE id = $1 FOR UPDATE`,
        [id],
      );
      if (!existingRows[0]) {
        throw new PlanNotFoundError();
      }

      const sets: string[] = [];
      const values: unknown[] = [];
      let paramIndex = 1;

      const fields: Array<{ key: keyof UpdatePlanDto; column: string }> = [
        { key: 'name', column: 'name' },
        { key: 'description', column: 'description' },
        { key: 'price_monthly_tiyin', column: 'price_monthly_tiyin' },
        { key: 'price_annual_tiyin', column: 'price_annual_tiyin' },
        { key: 'currency', column: 'currency' },
        { key: 'user_limit', column: 'user_limit' },
        { key: 'storage_quota_gb', column: 'storage_quota_gb' },
        { key: 'is_active', column: 'is_active' },
      ];

      const changed: Record<string, unknown> = {};
      for (const { key, column } of fields) {
        if (dto[key] !== undefined) {
          sets.push(`${column} = $${paramIndex++}`);
          values.push(dto[key]);
          changed[column] = dto[key];
        }
      }

      if (dto.features !== undefined) {
        sets.push(`features = $${paramIndex++}`);
        values.push(JSON.stringify(dto.features));
        changed.features = dto.features;
      }

      if (sets.length === 0) {
        return existingRows[0];
      }

      await this.audit(manager, 'PlanUpdated', actorId, null, 'SubscriptionPlan', id, changed);

      sets.push('updated_at = now()');
      values.push(id);

      await manager.query(
        `UPDATE subscription_plans SET ${sets.join(', ')} WHERE id = $${paramIndex}`,
        values,
      );

      const rows = await manager.query<PlanRow[]>(
        `SELECT * FROM subscription_plans WHERE id = $1`,
        [id],
      );
      return rows[0];
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

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as { code?: string; constraint?: string };
    if (driverError.code !== '23505') return;

    if (driverError.constraint === 'subscription_plans_name_key') {
      throw new PlanNameAlreadyExistsError();
    }
  }
}
