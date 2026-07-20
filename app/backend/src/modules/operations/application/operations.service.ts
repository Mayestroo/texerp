import { ForbiddenException, Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { CreateOperationDto } from './dto/create-operation.dto';
import { ListOperationsQueryDto } from './dto/list-operations-query.dto';
import { UpdateOperationDto } from './dto/update-operation.dto';
import { EmptyOperationUpdateError } from './errors/empty-operation-update.error';
import { OperationCodeAlreadyExistsError } from './errors/operation-code-already-exists.error';
import { OperationNameAlreadyExistsError } from './errors/operation-name-already-exists.error';
import { OperationNotFoundError } from './errors/operation-not-found.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

export interface OperationView {
  id: string;
  name: string;
  code: string | null;
  unit: 'PIECE' | 'METER' | 'PAIR';
  unit_price: number;
  currency: 'UZS';
  is_active: boolean;
  sort_order: number;
}

export interface OperationUpdateResult extends OperationView {
  price_changed: boolean;
  old_price?: number;
  new_price?: number;
  effective_from?: Date;
}

interface OperationState {
  name: string;
  code: string | null;
  unit_price: number;
  sort_order: number;
}

interface PostgresError {
  code?: string;
  constraint?: string;
}

@Injectable()
export class OperationsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async list(
    tenantId: string,
    actor: AccessTokenClaims,
    query: ListOperationsQueryDto,
  ): Promise<OperationView[]> {
    if (actor.role !== 'DIRECTOR' && query.status !== 'ACTIVE') {
      throw new ForbiddenException();
    }

    return this.tenantDatabase.withTenant(tenantId, (manager) =>
      manager.query<OperationView[]>(
        `SELECT id, name, code, unit, unit_price, currency, is_active, sort_order
         FROM operations
         WHERE tenant_id = $1
           AND ($2 = 'ALL' OR is_active = ($2 = 'ACTIVE'))
           AND ($3::text IS NULL OR name ILIKE '%' || $3 || '%' OR code ILIKE '%' || $3 || '%')
         ORDER BY sort_order ASC, name ASC, id ASC`,
        [tenantId, query.status, query.search ?? null],
      ),
    );
  }

  async create(
    tenantId: string,
    actor: AccessTokenClaims,
    dto: CreateOperationDto,
    metadata: RequestMetadata,
  ): Promise<OperationView> {
    const operationId = uuidv7();
    const historyId = uuidv7();

    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        const timestampResult = await manager.query<{ ts: Date }[]>(
          `SELECT clock_timestamp() AS ts`,
        );
        const timestamp = timestampResult[0].ts;

        const afterState = {
          id: operationId,
          name: dto.name,
          code: dto.code ?? null,
          unit: dto.unit,
          unit_price: dto.unit_price,
          currency: 'UZS',
          sort_order: dto.sort_order ?? 0,
          is_active: true,
        };

        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             after_state, ip_address, user_agent)
           VALUES ($1, $2, 'OPERATION', $3, 'OPERATION_CREATED', $4, $5,
             $6::jsonb, $7, $8)`,
          [
            uuidv7(),
            tenantId,
            operationId,
            actor.sub,
            actor.role,
            JSON.stringify(afterState),
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );

        await manager.query(
          `INSERT INTO operations
            (id, tenant_id, name, code, unit, unit_price, currency, sort_order,
             is_active, created_by, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11)`,
          [
            operationId,
            tenantId,
            dto.name,
            dto.code ?? null,
            dto.unit,
            dto.unit_price,
            'UZS',
            dto.sort_order ?? 0,
            true,
            actor.sub,
            timestamp,
          ],
        );

        await manager.query(
          `INSERT INTO operation_price_history
            (id, tenant_id, operation_id, unit_price, currency, effective_from, changed_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            historyId,
            tenantId,
            operationId,
            dto.unit_price,
            'UZS',
            timestamp,
            actor.sub,
          ],
        );

        const rows = await manager.query<OperationView[]>(
          `SELECT id, name, code, unit, unit_price, currency, is_active, sort_order
           FROM operations
           WHERE tenant_id = $1 AND id = $2`,
          [tenantId, operationId],
        );
        return rows[0];
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async update(
    tenantId: string,
    actor: AccessTokenClaims,
    operationId: string,
    dto: UpdateOperationDto,
    metadata: RequestMetadata,
  ): Promise<OperationUpdateResult> {
    if (
      dto.name === undefined &&
      dto.code === undefined &&
      dto.unit_price === undefined &&
      dto.sort_order === undefined
    ) {
      throw new EmptyOperationUpdateError();
    }

    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        const rows = await manager.query<OperationState[]>(
          `SELECT name, code, unit_price, sort_order
           FROM operations
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE`,
          [tenantId, operationId],
        );
        const current = rows[0];
        if (!current) throw new OperationNotFoundError();

        const priceChanged =
          dto.unit_price !== undefined && dto.unit_price !== current.unit_price;
        let effectiveFrom: Date | undefined;

        if (priceChanged) {
          const timestampResult = await manager.query<{ ts: Date }[]>(
            `SELECT clock_timestamp() AS ts`,
          );
          effectiveFrom = timestampResult[0].ts;

          // Build before/after states that include both price and metadata diffs
          const beforeState: Record<string, unknown> = {
            unit_price: current.unit_price,
          };
          const afterState: Record<string, unknown> = {
            unit_price: dto.unit_price,
            effective_from: effectiveFrom,
          };
          for (const field of ['name', 'code', 'sort_order'] as const) {
            if (dto[field] !== undefined && dto[field] !== current[field]) {
              beforeState[field] = current[field];
              afterState[field] = dto[field];
            }
          }

          await manager.query(
            `INSERT INTO audit_events
              (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
               before_state, after_state, ip_address, user_agent)
             VALUES ($1, $2, 'OPERATION', $3, 'OPERATION_PRICE_CHANGED', $4, $5,
               $6::jsonb, $7::jsonb, $8, $9)`,
            [
              uuidv7(),
              tenantId,
              operationId,
              actor.sub,
              actor.role,
              JSON.stringify(beforeState),
              JSON.stringify(afterState),
              metadata.ipAddress ?? null,
              metadata.userAgent ?? null,
            ],
          );

          await manager.query(
            `UPDATE operation_price_history
             SET effective_to = $3
             WHERE tenant_id = $1 AND operation_id = $2 AND effective_to IS NULL`,
            [tenantId, operationId, effectiveFrom],
          );

          await manager.query(
            `INSERT INTO operation_price_history
              (id, tenant_id, operation_id, unit_price, currency, effective_from, changed_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
              uuidv7(),
              tenantId,
              operationId,
              dto.unit_price,
              'UZS',
              effectiveFrom,
              actor.sub,
            ],
          );

          await manager.query(
            `UPDATE operations
             SET unit_price = $3,
                 name = CASE WHEN $4 THEN $5 ELSE name END,
                 code = CASE WHEN $6 THEN $7 ELSE code END,
                 sort_order = CASE WHEN $8 THEN $9 ELSE sort_order END,
                 updated_at = $10
             WHERE tenant_id = $1 AND id = $2`,
            [
              tenantId,
              operationId,
              dto.unit_price,
              dto.name !== undefined,
              dto.name ?? null,
              dto.code !== undefined,
              dto.code ?? null,
              dto.sort_order !== undefined,
              dto.sort_order ?? null,
              effectiveFrom,
            ],
          );
        } else {
          // Metadata-only change (no price change)
          const metadataChanged =
            (dto.name !== undefined && dto.name !== current.name) ||
            (dto.code !== undefined && dto.code !== current.code) ||
            (dto.sort_order !== undefined &&
              dto.sort_order !== current.sort_order);

          if (metadataChanged) {
            const beforeState: Record<string, unknown> = {};
            const afterState: Record<string, unknown> = {};
            for (const field of ['name', 'code', 'sort_order'] as const) {
              if (dto[field] !== undefined && dto[field] !== current[field]) {
                beforeState[field] = current[field];
                afterState[field] = dto[field];
              }
            }

            await manager.query(
              `INSERT INTO audit_events
                (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
                 before_state, after_state, ip_address, user_agent)
               VALUES ($1, $2, 'OPERATION', $3, 'OPERATION_UPDATED', $4, $5,
                 $6::jsonb, $7::jsonb, $8, $9)`,
              [
                uuidv7(),
                tenantId,
                operationId,
                actor.sub,
                actor.role,
                JSON.stringify(beforeState),
                JSON.stringify(afterState),
                metadata.ipAddress ?? null,
                metadata.userAgent ?? null,
              ],
            );

            await manager.query(
              `UPDATE operations
               SET name = CASE WHEN $3 THEN $4 ELSE name END,
                   code = CASE WHEN $5 THEN $6 ELSE code END,
                   sort_order = CASE WHEN $7 THEN $8 ELSE sort_order END,
                   updated_at = now()
               WHERE tenant_id = $1 AND id = $2`,
              [
                tenantId,
                operationId,
                dto.name !== undefined,
                dto.name ?? null,
                dto.code !== undefined,
                dto.code ?? null,
                dto.sort_order !== undefined,
                dto.sort_order ?? null,
              ],
            );
          }
        }

        const view = await this.requireOperationView(manager, tenantId, operationId);

        return {
          ...view,
          price_changed: priceChanged,
          ...(priceChanged && {
            old_price: current.unit_price,
            new_price: dto.unit_price,
            effective_from: effectiveFrom,
          }),
        };
      });
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async setActive(
    tenantId: string,
    actor: AccessTokenClaims,
    operationId: string,
    isActive: boolean,
    metadata: RequestMetadata,
  ): Promise<void> {
    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<{ is_active: boolean }[]>(
        `SELECT is_active
         FROM operations
         WHERE tenant_id = $1 AND id = $2
         FOR UPDATE`,
        [tenantId, operationId],
      );
      const current = rows[0];
      if (!current) throw new OperationNotFoundError();
      if (current.is_active === isActive) return;

      const action = isActive ? 'OPERATION_ACTIVATED' : 'OPERATION_DEACTIVATED';
      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           before_state, after_state, ip_address, user_agent)
         VALUES ($1, $2, 'OPERATION', $3, $4, $5, $6,
           $7::jsonb, $8::jsonb, $9, $10)`,
        [
          uuidv7(),
          tenantId,
          operationId,
          action,
          actor.sub,
          actor.role,
          JSON.stringify({ is_active: current.is_active }),
          JSON.stringify({ is_active: isActive }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      await manager.query(
        `UPDATE operations
         SET is_active = $3, updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, operationId, isActive],
      );
    });
  }

  private async requireOperationView(
    manager: EntityManager,
    tenantId: string,
    operationId: string,
  ): Promise<OperationView> {
    const rows = await manager.query<OperationView[]>(
      `SELECT id, name, code, unit, unit_price, currency, is_active, sort_order
       FROM operations
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, operationId],
    );
    if (!rows[0]) throw new OperationNotFoundError();
    return rows[0];
  }

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as PostgresError;
    if (driverError.code !== '23505') return;
    if (driverError.constraint === 'operations_tenant_name_key') {
      throw new OperationNameAlreadyExistsError();
    }
    if (driverError.constraint === 'operations_tenant_code_key') {
      throw new OperationCodeAlreadyExistsError();
    }
  }
}
