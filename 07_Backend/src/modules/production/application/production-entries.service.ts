import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/utils/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { CreateOperationEntryDto } from './dto/create-operation-entry.dto';
import { DateOutOfWindowError } from './errors/date-out-of-window.error';
import { DuplicateEntryError } from './errors/duplicate-entry.error';
import { OperationInactiveError } from './errors/operation-inactive.error';
import { OperationNotFoundError } from './errors/operation-not-found.error';
import { WorkerNotActiveError } from './errors/worker-not-active.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

interface OperationSnapshot {
  id: string;
  name: string;
  code: string | null;
  unit: 'PIECE' | 'METER' | 'PAIR';
  unit_price: number;
  is_active: boolean;
}

interface DuplicateEntryRow {
  id: string;
}

export interface OperationEntryView {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPICIOUS';
  operation: {
    id: string;
    name: string;
    unit: 'PIECE' | 'METER' | 'PAIR';
  };
  operation_name_snapshot: string;
  operation_code_snapshot: string | null;
  quantity_submitted: number;
  unit_price_snapshot: number;
  currency_snapshot: 'UZS';
  record_date: string;
  worker_note: string | null;
  submitted_at: Date;
  foreman: { id: string; full_name: string } | null;
}

@Injectable()
export class ProductionEntriesService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async create(
    tenantId: string,
    workerId: string,
    actor: AccessTokenClaims,
    dto: CreateOperationEntryDto,
    metadata: RequestMetadata,
  ): Promise<OperationEntryView> {
    try {
      return await this.tenantDatabase.withTenant(tenantId, async (manager) => {
        await this.validateWorker(manager, tenantId, workerId);
        const operation = await this.lockActiveOperation(
          manager,
          tenantId,
          dto.operation_id,
        );
        const backDateWindowDays = await this.readBackDateWindow(manager);
        this.validateRecordDate(dto.record_date, backDateWindowDays);

        const duplicate = await this.findPendingDuplicate(
          manager,
          tenantId,
          workerId,
          dto.operation_id,
          dto.record_date,
        );
        if (duplicate) {
          throw new DuplicateEntryError(duplicate.id);
        }

        const entryId = uuidv7();
        const timestampResult = await manager.query<{ ts: Date }[]>(
          `SELECT clock_timestamp() AS ts`,
        );
        const timestamp = timestampResult[0].ts;

        const afterState = {
          id: entryId,
          tenant_id: tenantId,
          worker_id: workerId,
          operation_id: dto.operation_id,
          quantity: dto.quantity,
          record_date: dto.record_date,
          status: 'PENDING',
          operation_name_snapshot: operation.name,
          operation_code_snapshot: operation.code,
          unit_price_snapshot: operation.unit_price,
          currency_snapshot: 'UZS',
          worker_note: dto.worker_note ?? null,
          created_at: timestamp,
          updated_at: timestamp,
        };

        await manager.query(
          `INSERT INTO audit_events
            (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
             after_state, ip_address, user_agent)
           VALUES ($1, $2, 'PRODUCTION_ENTRY', $3, 'PRODUCTION_ENTRY_CREATED', $4, $5,
             $6::jsonb, $7, $8)`,
          [
            uuidv7(),
            tenantId,
            entryId,
            actor.sub,
            actor.role,
            JSON.stringify(afterState),
            metadata.ipAddress ?? null,
            metadata.userAgent ?? null,
          ],
        );

        await manager.query(
          `INSERT INTO production_entries
            (id, tenant_id, worker_id, operation_id, quantity, record_date, status,
             operation_name_snapshot, operation_code_snapshot, unit_price_snapshot,
             currency_snapshot, worker_note, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, 'PENDING', $7, $8, $9, $10, $11, $12, $12)`,
          [
            entryId,
            tenantId,
            workerId,
            dto.operation_id,
            dto.quantity,
            dto.record_date,
            operation.name,
            operation.code,
            operation.unit_price,
            'UZS',
            dto.worker_note ?? null,
            timestamp,
          ],
        );

        const foreman = await this.findActiveForeman(
          manager,
          tenantId,
          workerId,
        );

        return {
          id: entryId,
          status: 'PENDING',
          operation: {
            id: operation.id,
            name: operation.name,
            unit: operation.unit,
          },
          operation_name_snapshot: operation.name,
          operation_code_snapshot: operation.code,
          quantity_submitted: dto.quantity,
          unit_price_snapshot: operation.unit_price,
          currency_snapshot: 'UZS',
          record_date: dto.record_date,
          worker_note: dto.worker_note ?? null,
          submitted_at: timestamp,
          foreman,
        };
      });
    } catch (error) {
      if (this.isDuplicateEntryViolation(error)) {
        const existingId = await this.findExistingPendingEntryId(
          tenantId,
          workerId,
          dto.operation_id,
          dto.record_date,
        );
        throw new DuplicateEntryError(existingId ?? 'unknown');
      }
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  private async validateWorker(
    manager: EntityManager,
    tenantId: string,
    workerId: string,
  ): Promise<void> {
    const rows = await manager.query<{ status: string }[]>(
      `SELECT status
       FROM users
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, workerId],
    );
    const worker = rows[0];
    if (!worker || worker.status !== 'ACTIVE') {
      throw new WorkerNotActiveError();
    }
  }

  private async lockActiveOperation(
    manager: EntityManager,
    tenantId: string,
    operationId: string,
  ): Promise<OperationSnapshot> {
    const rows = await manager.query<OperationSnapshot[]>(
      `SELECT id, name, code, unit, unit_price, is_active
       FROM operations
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, operationId],
    );
    const operation = rows[0];
    if (!operation) {
      throw new OperationNotFoundError();
    }
    if (!operation.is_active) {
      throw new OperationInactiveError();
    }
    return operation;
  }

  private async readBackDateWindow(manager: EntityManager): Promise<number> {
    const rows = await manager.query<{ back_date_window_days: number }[]>(
      `SELECT production_back_date_window() AS back_date_window_days`,
    );
    const days = rows[0]?.back_date_window_days;
    return days ?? 3;
  }

  private validateRecordDate(
    recordDate: string,
    backDateWindowDays: number,
  ): void {
    const currentDate = new Date().toISOString().slice(0, 10);
    const current = new Date(`${currentDate}T00:00:00.000Z`);
    const record = new Date(`${recordDate}T00:00:00.000Z`);
    const allowedFrom = new Date(current);
    allowedFrom.setUTCDate(current.getUTCDate() - backDateWindowDays);
    const allowedFromString = allowedFrom.toISOString().slice(0, 10);

    if (record < allowedFrom || record > current) {
      throw new DateOutOfWindowError(allowedFromString);
    }
  }

  private async findPendingDuplicate(
    manager: EntityManager,
    tenantId: string,
    workerId: string,
    operationId: string,
    recordDate: string,
  ): Promise<DuplicateEntryRow | undefined> {
    const rows = await manager.query<DuplicateEntryRow[]>(
      `SELECT id
       FROM production_entries
       WHERE tenant_id = $1
         AND worker_id = $2
         AND operation_id = $3
         AND record_date = $4
         AND status = 'PENDING'
       LIMIT 1`,
      [tenantId, workerId, operationId, recordDate],
    );
    return rows[0];
  }

  private async findActiveForeman(
    manager: EntityManager,
    tenantId: string,
    workerId: string,
  ): Promise<{ id: string; full_name: string } | null> {
    const rows = await manager.query<{ id: string; full_name: string }[]>(
      `SELECT u.id, u.full_name
       FROM foreman_assignments fa
       JOIN users u ON u.tenant_id = fa.tenant_id AND u.id = fa.foreman_id
       WHERE fa.tenant_id = $1 AND fa.worker_id = $2 AND fa.unassigned_at IS NULL
       LIMIT 1`,
      [tenantId, workerId],
    );
    return rows[0] ?? null;
  }

  private isDuplicateEntryViolation(error: unknown): boolean {
    if (!(error instanceof QueryFailedError)) return false;
    const driverError = error.driverError as {
      code?: string;
      constraint?: string;
    };
    return (
      driverError?.code === '23505' &&
      driverError?.constraint === 'production_entries_duplicate_check'
    );
  }

  private async findExistingPendingEntryId(
    tenantId: string,
    workerId: string,
    operationId: string,
    recordDate: string,
  ): Promise<string | undefined> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<{ id: string }[]>(
        `SELECT id
         FROM production_entries
         WHERE tenant_id = $1
           AND worker_id = $2
           AND operation_id = $3
           AND record_date = $4
           AND status = 'PENDING'
         LIMIT 1`,
        [tenantId, workerId, operationId, recordDate],
      );
      return rows[0]?.id;
    });
  }

  private mapUniqueViolation(error: unknown): void {
    if (!(error instanceof QueryFailedError)) return;
    const driverError = error.driverError as {
      code?: string;
      constraint?: string;
    };
    if (driverError?.code !== '23505') return;
  }
}
