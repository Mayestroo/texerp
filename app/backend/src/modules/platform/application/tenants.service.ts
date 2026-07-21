import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import bcrypt from 'bcrypt';
import { PlatformDatabase } from '../../../infrastructure/database/platform-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { CreateTenantDto } from './dto/create-tenant.dto';
import { UpdateTenantDto } from './dto/update-tenant.dto';
import { ListTenantsQueryDto } from './dto/list-tenants-query.dto';
import { TenantNotFoundError } from './errors/tenant-not-found.error';
import { PlanNotFoundError } from './errors/plan-not-found.error';
import { TenantSlugAlreadyExistsError } from './errors/tenant-slug-already-exists.error';
import { DirectorPhoneAlreadyExistsError } from './errors/director-phone-already-exists.error';

interface PlanRow {
  id: string;
  name: string;
  features: string[];
}

interface TenantRow {
  id: string;
  name: string;
  slug: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'TERMINATED';
  legal_name: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  country: string | null;
  terminated_at: Date | null;
  deletion_scheduled_at: Date | null;
  suspend_reason: string | null;
  timezone: string;
  language: 'uz' | 'ru' | 'uz_ru';
  currency: string;
  created_at: Date;
  updated_at: Date;
}

interface TenantWithSubscription extends TenantRow {
  subscription_id: string | null;
  plan_id: string | null;
  plan_name: string | null;
  billing_cycle: 'MONTHLY' | 'ANNUAL' | null;
  subscription_status: 'ACTIVE' | 'SUSPENDED' | 'CANCELLED' | null;
  started_at: Date | null;
  ends_at: Date | null;
}

interface CreatedTenant {
  id: string;
  name: string;
  slug: string;
  status: 'ACTIVE';
  director_id: string;
  subscription_id: string;
}

interface CountRow {
  total: string;
}

interface ListTenantsResult {
  data: TenantWithSubscription[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
    has_next: boolean;
  };
}

@Injectable()
export class TenantsService {
  constructor(
    private readonly platformDatabase: PlatformDatabase,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  async create(
    actorId: string,
    dto: CreateTenantDto,
  ): Promise<CreatedTenant> {
    const tenantId = uuidv7();
    const directorId = uuidv7();
    const subscriptionId = uuidv7();
    const settingsId = uuidv7();
    const pinHash = await bcrypt.hash(dto.director_initial_pin, 12);
    const language = dto.language ?? 'uz';
    const userLanguage: 'uz' | 'ru' = language === 'ru' ? 'ru' : 'uz';
    const country = dto.country ?? 'UZ';
    const timezone = dto.timezone ?? 'Asia/Tashkent';
    const currency = dto.currency ?? 'UZS';

    try {
      const result = await this.platformDatabase.execute(async (manager) => {
        const plan = await this.resolvePlan(manager, dto.plan_id);

        await this.audit(manager, 'TenantCreated', actorId, tenantId, 'Tenant', tenantId, {
          name: dto.name,
          slug: dto.slug,
          plan_id: plan.id,
        });

        await manager.query(
          `INSERT INTO tenants
           (id, name, slug, legal_name, contact_email, contact_phone, country,
            timezone, language, currency, status, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'ACTIVE', now(), now())`,
          [
            tenantId,
            dto.name,
            dto.slug,
            dto.legal_name ?? null,
            dto.contact_email ?? null,
            dto.contact_phone ?? null,
            country,
            timezone,
            language,
            currency,
          ],
        );

        await manager.query(
          `INSERT INTO users
           (id, tenant_id, phone, pin_hash, full_name, worker_code, role,
            status, language, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, 'DIRECTOR', 'DIRECTOR', 'ACTIVE', $6, now(), now())`,
          [directorId, tenantId, dto.director_phone, pinHash, dto.director_full_name, userLanguage],
        );

        await manager.query(
          `INSERT INTO tenant_settings (id, tenant_id)
           VALUES ($1, $2)`,
          [settingsId, tenantId],
        );

        for (const feature of plan.features) {
          await manager.query(
            `INSERT INTO tenant_feature_flags
             (id, tenant_id, feature_key, is_enabled, enabled_at, enabled_by)
             VALUES ($1, $2, $3, true, now(), $4)`,
            [uuidv7(), tenantId, feature, actorId],
          );
        }

        await manager.query(
          `INSERT INTO tenant_subscriptions
           (id, tenant_id, plan_id, billing_cycle, status, started_at, created_by)
           VALUES ($1, $2, $3, 'MONTHLY', 'ACTIVE', now(), $4)`,
          [subscriptionId, tenantId, plan.id, actorId],
        );

        return {
          id: tenantId,
          name: dto.name,
          slug: dto.slug,
          status: 'ACTIVE' as const,
          director_id: directorId,
          subscription_id: subscriptionId,
        };
      });

      this.eventPublisher.publish(
        EventNames.TENANT_CREATED,
        'Tenant',
        tenantId,
        tenantId,
        actorId,
        'SUPER_ADMIN',
        { name: dto.name, slug: dto.slug, subscription_id: subscriptionId },
      );

      return result;
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async list(query: ListTenantsQueryDto): Promise<ListTenantsResult> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    return this.platformDatabase.execute(async (manager) => {
      const parameters: unknown[] = [];
      const conditions: string[] = [];

      if (query.status) {
        parameters.push(query.status);
        conditions.push(`t.status = $${parameters.length}`);
      }
      if (query.search) {
        parameters.push(`%${query.search}%`);
        conditions.push(
          `(t.name ILIKE $${parameters.length} OR t.slug ILIKE $${parameters.length})`,
        );
      }

      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const countRows = await manager.query<CountRow[]>(
        `SELECT count(*)::text AS total FROM tenants t ${where}`,
        parameters,
      );
      const total = Number(countRows[0]?.total ?? 0);

      const pageParameters = [...parameters, limit, (page - 1) * limit];
      const limitParameter = `$${pageParameters.length - 1}`;
      const offsetParameter = `$${pageParameters.length}`;

      const data = await manager.query<TenantWithSubscription[]>(
        `SELECT
           t.*,
           ts.id AS subscription_id,
           ts.plan_id,
           ts.billing_cycle,
           ts.status AS subscription_status,
           ts.started_at,
           ts.ends_at,
           sp.name AS plan_name
         FROM tenants t
         LEFT JOIN LATERAL (
           SELECT * FROM tenant_subscriptions
           WHERE tenant_id = t.id AND status = 'ACTIVE'
           ORDER BY started_at DESC
           LIMIT 1
         ) ts ON true
         LEFT JOIN subscription_plans sp ON sp.id = ts.plan_id
         ${where}
         ORDER BY t.created_at DESC, t.id DESC
         LIMIT ${limitParameter} OFFSET ${offsetParameter}`,
        pageParameters,
      );

      const totalPages = Math.ceil(total / limit);
      return {
        data,
        pagination: {
          page,
          limit,
          total,
          total_pages: totalPages,
          has_next: page < totalPages,
        },
      };
    });
  }

  async get(id: string): Promise<TenantWithSubscription> {
    const tenant = await this.platformDatabase.execute(async (manager) => {
      return this.findWithSubscription(manager, id);
    });

    if (!tenant) {
      throw new TenantNotFoundError();
    }
    return tenant;
  }

  async update(
    id: string,
    dto: UpdateTenantDto,
    actorId: string,
  ): Promise<TenantWithSubscription> {
    let changedFields: string[] = [];

    const tenant = await this.platformDatabase.execute(async (manager) => {
      const existingRows = await manager.query<TenantRow[]>(
        `SELECT * FROM tenants WHERE id = $1 FOR UPDATE`,
        [id],
      );
      if (!existingRows[0]) {
        throw new TenantNotFoundError();
      }

      const sets: string[] = [];
      const values: unknown[] = [];
      let paramIndex = 1;

      const fields: Array<{ key: keyof UpdateTenantDto; column: string }> = [
        { key: 'name', column: 'name' },
        { key: 'legal_name', column: 'legal_name' },
        { key: 'contact_email', column: 'contact_email' },
        { key: 'contact_phone', column: 'contact_phone' },
        { key: 'country', column: 'country' },
        { key: 'timezone', column: 'timezone' },
        { key: 'language', column: 'language' },
        { key: 'currency', column: 'currency' },
      ];

      const changed: Record<string, unknown> = {};
      for (const { key, column } of fields) {
        if (dto[key] !== undefined) {
          sets.push(`${column} = $${paramIndex++}`);
          values.push(dto[key]);
          changed[column] = dto[key];
        }
      }

      if (sets.length > 0) {
        await this.audit(manager, 'TenantUpdated', actorId, id, 'Tenant', id, changed);

        sets.push('updated_at = now()');
        values.push(id);

        await manager.query(
          `UPDATE tenants SET ${sets.join(', ')} WHERE id = $${paramIndex}`,
          values,
        );
        changedFields = Object.keys(changed);
      }

      const updated = await this.findWithSubscription(manager, id);
      if (!updated) {
        throw new TenantNotFoundError();
      }
      return updated;
    });

    if (changedFields.length > 0) {
      this.eventPublisher.publish(
        EventNames.TENANT_UPDATED,
        'Tenant',
        id,
        id,
        actorId,
        'SUPER_ADMIN',
        { changed_fields: changedFields },
      );
    }

    return tenant;
  }

  async suspend(
    id: string,
    reason: string,
    actorId: string,
  ): Promise<TenantWithSubscription> {
    const tenant = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<TenantRow[]>(
        `SELECT * FROM tenants WHERE id = $1 FOR UPDATE`,
        [id],
      );
      const tenant = rows[0];
      if (!tenant || tenant.status === 'TERMINATED') {
        throw new TenantNotFoundError();
      }

      await this.audit(manager, 'TenantSuspended', actorId, id, 'Tenant', id, {
        reason,
        previous_status: tenant.status,
      });

      await manager.query(
        `UPDATE tenants
         SET status = 'SUSPENDED',
             suspend_reason = $2,
             updated_at = now()
         WHERE id = $1`,
        [id, reason],
      );

      return this.findWithSubscription(manager, id);
    });

    if (!tenant) {
      throw new TenantNotFoundError();
    }

    this.eventPublisher.publish(
      EventNames.TENANT_SUSPENDED,
      'Tenant',
      id,
      id,
      actorId,
      'SUPER_ADMIN',
      { reason },
    );
    return tenant;
  }

  async reactivate(id: string, actorId: string): Promise<TenantWithSubscription> {
    const tenant = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<TenantRow[]>(
        `SELECT * FROM tenants WHERE id = $1 FOR UPDATE`,
        [id],
      );
      const tenant = rows[0];
      if (!tenant || tenant.status === 'TERMINATED') {
        throw new TenantNotFoundError();
      }

      await this.audit(manager, 'TenantReactivated', actorId, id, 'Tenant', id, {
        previous_status: tenant.status,
      });

      await manager.query(
        `UPDATE tenants
         SET status = 'ACTIVE',
             suspend_reason = NULL,
             terminated_at = NULL,
             deletion_scheduled_at = NULL,
             updated_at = now()
         WHERE id = $1`,
        [id],
      );

      return this.findWithSubscription(manager, id);
    });

    if (!tenant) {
      throw new TenantNotFoundError();
    }

    this.eventPublisher.publish(
      EventNames.TENANT_REACTIVATED,
      'Tenant',
      id,
      id,
      actorId,
      'SUPER_ADMIN',
      {},
    );
    return tenant;
  }

  async terminate(id: string, actorId: string): Promise<TenantWithSubscription> {
    const terminatedAt = new Date();
    const deletionScheduledAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    const tenant = await this.platformDatabase.execute(async (manager) => {
      const rows = await manager.query<TenantRow[]>(
        `SELECT * FROM tenants WHERE id = $1 FOR UPDATE`,
        [id],
      );
      const tenant = rows[0];
      if (!tenant || tenant.status === 'TERMINATED') {
        throw new TenantNotFoundError();
      }

      await this.audit(manager, 'TenantTerminated', actorId, id, 'Tenant', id, {
        previous_status: tenant.status,
        terminated_at: terminatedAt.toISOString(),
        deletion_scheduled_at: deletionScheduledAt.toISOString(),
      });

      await manager.query(
        `UPDATE tenants
         SET status = 'TERMINATED',
             terminated_at = $2,
             deletion_scheduled_at = $3,
             updated_at = now()
         WHERE id = $1`,
        [id, terminatedAt, deletionScheduledAt],
      );

      return this.findWithSubscription(manager, id);
    });

    if (!tenant) {
      throw new TenantNotFoundError();
    }

    this.eventPublisher.publish(
      EventNames.TENANT_TERMINATED,
      'Tenant',
      id,
      id,
      actorId,
      'SUPER_ADMIN',
      {
        terminated_at: terminatedAt.toISOString(),
        deletion_scheduled_at: deletionScheduledAt.toISOString(),
      },
    );
    return tenant;
  }

  private async resolvePlan(
    manager: EntityManager,
    planId?: string,
  ): Promise<PlanRow> {
    let rows: PlanRow[];
    if (planId) {
      rows = await manager.query<PlanRow[]>(
        `SELECT id, name, features FROM subscription_plans WHERE id = $1`,
        [planId],
      );
    } else {
      rows = await manager.query<PlanRow[]>(
        `SELECT id, name, features FROM subscription_plans WHERE name = 'Standard' LIMIT 1`,
      );
    }
    const plan = rows[0];
    if (!plan) {
      throw new PlanNotFoundError();
    }
    return plan;
  }

  private async findWithSubscription(
    manager: EntityManager,
    id: string,
  ): Promise<TenantWithSubscription | undefined> {
    const rows = await manager.query<TenantWithSubscription[]>(
      `SELECT
         t.*,
         ts.id AS subscription_id,
         ts.plan_id,
         ts.billing_cycle,
         ts.status AS subscription_status,
         ts.started_at,
         ts.ends_at,
         sp.name AS plan_name
       FROM tenants t
       LEFT JOIN LATERAL (
         SELECT * FROM tenant_subscriptions
         WHERE tenant_id = t.id AND status = 'ACTIVE'
         ORDER BY started_at DESC
         LIMIT 1
       ) ts ON true
       LEFT JOIN subscription_plans sp ON sp.id = ts.plan_id
       WHERE t.id = $1`,
      [id],
    );
    return rows[0];
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

    if (driverError.constraint === 'tenants_slug_key') {
      throw new TenantSlugAlreadyExistsError();
    }
    if (driverError.constraint === 'users_phone_key') {
      throw new DirectorPhoneAlreadyExistsError();
    }
  }
}
