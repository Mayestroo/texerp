import { ForbiddenException, Injectable } from '@nestjs/common';
import { QueryFailedError } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/utils/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { CreateOperationDto } from './dto/create-operation.dto';
import { ListOperationsQueryDto } from './dto/list-operations-query.dto';
import { OperationCodeAlreadyExistsError } from './errors/operation-code-already-exists.error';
import { OperationNameAlreadyExistsError } from './errors/operation-name-already-exists.error';

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
