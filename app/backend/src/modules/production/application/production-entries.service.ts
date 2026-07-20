import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { DomainEventPublisher, EventNames } from '../../../shared/events';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { ApproveEntryDto } from './dto/approve-entry.dto';
import { BulkApproveDto } from './dto/bulk-approve.dto';
import { CorrectApproveEntryDto } from './dto/correct-approve-entry.dto';
import { CreateOperationEntryDto } from './dto/create-operation-entry.dto';
import { ListMyEntriesQueryDto } from './dto/list-my-entries-query.dto';
import { RejectEntryDto } from './dto/reject-entry.dto';
import { BulkApprovePartialFailureError } from './errors/bulk-approve-partial-failure.error';
import { DateOutOfWindowError } from './errors/date-out-of-window.error';
import { DuplicateEntryError } from './errors/duplicate-entry.error';
import { EntryNotFoundError } from './errors/entry-not-found.error';
import { EntryNotPendingError } from './errors/entry-not-pending.error';
import { ForemanNotAssignedError } from './errors/foreman-not-assigned.error';
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
  worker_id?: string;
  operation_id?: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPICIOUS';
  worker?: {
    id: string;
    full_name: string;
    worker_code: string;
  };
  operation: {
    id: string;
    name: string;
    unit: 'PIECE' | 'METER' | 'PAIR';
  };
  operation_name_snapshot: string;
  operation_code_snapshot: string | null;
  quantity_submitted: number;
  quantity_approved?: number | null;
  unit_price_snapshot: number;
  currency_snapshot: 'UZS';
  record_date: string;
  worker_note: string | null;
  submitted_at: Date;
  foreman: { id: string; full_name: string } | null;
  approved_at?: Date | null;
  rejected_at?: Date | null;
  approved_by?: string | null;
  rejected_by?: string | null;
  rejection_reason?: string | null;
  foreman_note?: string | null;
  correction_comment?: string | null;
}

@Injectable()
export class ProductionEntriesService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

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

  async listMyEntries(
    tenantId: string,
    workerId: string,
    query: ListMyEntriesQueryDto,
  ): Promise<{ data: OperationEntryView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions: string[] = ['pe.tenant_id = $1', 'pe.worker_id = $2'];
      const params: unknown[] = [tenantId, workerId];
      let paramIndex = 3;

      if (query.status) {
        conditions.push(`pe.status = $${paramIndex++}`);
        params.push(query.status);
      }
      if (query.operation_id) {
        conditions.push(`pe.operation_id = $${paramIndex++}`);
        params.push(query.operation_id);
      }
      if (query.date_from) {
        conditions.push(`pe.record_date >= $${paramIndex++}`);
        params.push(query.date_from);
      }
      if (query.date_to) {
        conditions.push(`pe.record_date <= $${paramIndex++}`);
        params.push(query.date_to);
      }

      const whereClause = conditions.join(' AND ');

      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM production_entries pe
         WHERE ${whereClause}`,
        params,
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const entries = await manager.query<OperationEntryView[]>(
        `SELECT
           pe.id,
           pe.status,
           json_build_object(
             'id', pe.operation_id,
             'name', pe.operation_name_snapshot,
             'unit', o.unit
           ) AS operation,
           pe.operation_name_snapshot,
           pe.operation_code_snapshot,
           pe.quantity AS quantity_submitted,
           pe.unit_price_snapshot,
           pe.currency_snapshot,
           pe.record_date::text AS record_date,
           pe.worker_note,
           pe.created_at AS submitted_at,
           CASE WHEN fa.id IS NULL THEN NULL
             ELSE json_build_object('id', u.id, 'full_name', u.full_name)
           END AS foreman
         FROM production_entries pe
         LEFT JOIN operations o
           ON o.tenant_id = pe.tenant_id
          AND o.id = pe.operation_id
         LEFT JOIN foreman_assignments fa
           ON fa.tenant_id = pe.tenant_id
          AND fa.worker_id = pe.worker_id
          AND fa.assigned_at <= pe.record_date::timestamptz
          AND (fa.unassigned_at IS NULL OR fa.unassigned_at > pe.record_date::timestamptz)
         LEFT JOIN users u
           ON u.tenant_id = fa.tenant_id
          AND u.id = fa.foreman_id
         WHERE ${whereClause}
         ORDER BY pe.record_date DESC, pe.created_at DESC
         LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
        [...params, query.limit, query.offset],
      );

      return { data: entries, total };
    });
  }

  async listAllEntries(
    tenantId: string,
    query: ListMyEntriesQueryDto,
  ): Promise<{ data: OperationEntryView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions: string[] = ['pe.tenant_id = $1'];
      const params: unknown[] = [tenantId];
      let paramIndex = 2;

      if (query.worker_id) {
        conditions.push(`pe.worker_id = $${paramIndex++}`);
        params.push(query.worker_id);
      }
      if (query.status) {
        conditions.push(`pe.status = $${paramIndex++}`);
        params.push(query.status);
      }
      if (query.operation_id) {
        conditions.push(`pe.operation_id = $${paramIndex++}`);
        params.push(query.operation_id);
      }
      if (query.date_from) {
        conditions.push(`pe.record_date >= $${paramIndex++}`);
        params.push(query.date_from);
      }
      if (query.date_to) {
        conditions.push(`pe.record_date <= $${paramIndex++}`);
        params.push(query.date_to);
      }

      const whereClause = conditions.join(' AND ');

      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM production_entries pe
         WHERE ${whereClause}`,
        params,
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const entries = await manager.query<OperationEntryView[]>(
        `SELECT
           pe.id,
           pe.worker_id,
           pe.operation_id,
           pe.status,
           json_build_object(
             'id', u.id,
             'full_name', u.full_name,
             'worker_code', u.worker_code
           ) AS worker,
           json_build_object(
             'id', pe.operation_id,
             'name', pe.operation_name_snapshot,
             'unit', o.unit
           ) AS operation,
           pe.operation_name_snapshot,
           pe.operation_code_snapshot,
           pe.quantity AS quantity_submitted,
           pe.unit_price_snapshot,
           pe.currency_snapshot,
           pe.record_date::text AS record_date,
           pe.worker_note,
           pe.created_at AS submitted_at,
           pe.status,
           CASE WHEN fa.id IS NULL THEN NULL
             ELSE json_build_object('id', fm.id, 'full_name', fm.full_name)
           END AS foreman
         FROM production_entries pe
         JOIN users u
           ON u.tenant_id = pe.tenant_id AND u.id = pe.worker_id
         LEFT JOIN operations o
           ON o.tenant_id = pe.tenant_id
          AND o.id = pe.operation_id
         LEFT JOIN foreman_assignments fa
           ON fa.tenant_id = pe.tenant_id
          AND fa.worker_id = pe.worker_id
          AND fa.assigned_at <= pe.record_date::timestamptz
          AND (fa.unassigned_at IS NULL OR fa.unassigned_at > pe.record_date::timestamptz)
         LEFT JOIN users fm
           ON fm.tenant_id = fa.tenant_id AND fm.id = fa.foreman_id
         WHERE ${whereClause}
         ORDER BY pe.record_date DESC, pe.created_at DESC
         LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
        [...params, query.limit, query.offset],
      );

      return { data: entries, total };
    });
  }

  async listForemanHistory(
    tenantId: string,
    foremanId: string,
    query: ListMyEntriesQueryDto,
  ): Promise<{ data: OperationEntryView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions: string[] = [
        'pe.tenant_id = $1',
        `fa.foreman_id = $2`,
      ];
      const params: unknown[] = [tenantId, foremanId];
      let paramIndex = 3;

      if (query.status) {
        conditions.push(`pe.status = $${paramIndex++}`);
        params.push(query.status);
      }
      if (query.operation_id) {
        conditions.push(`pe.operation_id = $${paramIndex++}`);
        params.push(query.operation_id);
      }
      if (query.date_from) {
        conditions.push(`pe.record_date >= $${paramIndex++}`);
        params.push(query.date_from);
      }
      if (query.date_to) {
        conditions.push(`pe.record_date <= $${paramIndex++}`);
        params.push(query.date_to);
      }

      const whereClause = conditions.join(' AND ');

      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM production_entries pe
         JOIN foreman_assignments fa
           ON fa.tenant_id = pe.tenant_id
          AND fa.worker_id = pe.worker_id
          AND fa.unassigned_at IS NULL
         WHERE ${whereClause}`,
        params,
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const entries = await manager.query<OperationEntryView[]>(
        `SELECT
           pe.id,
           pe.worker_id,
           pe.operation_id,
           pe.status,
           json_build_object(
             'id', u.id,
             'full_name', u.full_name,
             'worker_code', u.worker_code
           ) AS worker,
           json_build_object(
             'id', o.id,
             'name', o.name,
             'unit', o.unit
           ) AS operation,
           pe.operation_name_snapshot,
           pe.operation_code_snapshot,
           pe.quantity AS quantity_submitted,
           pe.unit_price_snapshot,
           pe.currency_snapshot,
           pe.record_date::text AS record_date,
           pe.worker_note,
           pe.created_at AS submitted_at,
           pe.approved_at,
           pe.rejected_at,
           pe.rejection_reason,
           pe.correction_comment
         FROM production_entries pe
         JOIN foreman_assignments fa
           ON fa.tenant_id = pe.tenant_id
          AND fa.worker_id = pe.worker_id
          AND fa.unassigned_at IS NULL
         JOIN users u
           ON u.tenant_id = pe.tenant_id AND u.id = pe.worker_id
         LEFT JOIN operations o
           ON o.tenant_id = pe.tenant_id
          AND o.id = pe.operation_id
         WHERE ${whereClause}
         ORDER BY pe.updated_at DESC, pe.created_at DESC
         LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
        [...params, query.limit, query.offset],
      );

      return { data: entries, total };
    });
  }

  async listPendingForForeman(
    tenantId: string,
    foremanId: string,
  ): Promise<OperationEntryView[]> {
    return this.tenantDatabase.withTenant(tenantId, (manager) =>
      manager.query<OperationEntryView[]>(
        `SELECT
           pe.id,
           pe.worker_id,
           pe.operation_id,
           pe.quantity AS quantity_submitted,
           pe.record_date::text AS record_date,
           pe.status,
           pe.operation_name_snapshot,
           pe.operation_code_snapshot,
           pe.unit_price_snapshot,
           pe.currency_snapshot,
           pe.worker_note,
            pe.created_at AS submitted_at,
           json_build_object(
             'id', u.id,
             'full_name', u.full_name,
             'worker_code', u.worker_code
           ) AS worker,
           json_build_object(
             'id', o.id,
             'name', o.name,
             'unit', o.unit
           ) AS operation
         FROM production_entries pe
         JOIN foreman_assignments fa
           ON fa.tenant_id = pe.tenant_id
          AND fa.worker_id = pe.worker_id
          AND fa.foreman_id = $2
          AND fa.unassigned_at IS NULL
         JOIN users u
           ON u.tenant_id = pe.tenant_id
          AND u.id = pe.worker_id
         JOIN operations o
           ON o.tenant_id = pe.tenant_id
          AND o.id = pe.operation_id
         WHERE pe.tenant_id = $1
           AND pe.status = 'PENDING'
         ORDER BY pe.created_at DESC`,
        [tenantId, foremanId],
      ),
    );
  }

  async approveEntry(
    tenantId: string,
    foremanId: string,
    entryId: string,
    _dto: ApproveEntryDto,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<OperationEntryView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const entry = await this.lockPendingEntryOrFail(manager, tenantId, entryId);
      await this.assertForemanOwnsWorker(
        manager,
        tenantId,
        foremanId,
        entry.worker_id,
      );

      await this.insertEntryAudit(
        manager,
        tenantId,
        entryId,
        'ENTRY_APPROVED',
        actor,
        { status: 'PENDING' },
        { status: 'APPROVED' },
        metadata,
      );

      await manager.query(
        `UPDATE production_entries
         SET status = 'APPROVED',
             approved_at = now(),
             approved_by = $3,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, entryId, foremanId],
      );

      const foremanName = await this.getUserFullName(manager, tenantId, foremanId);
      this.eventPublisher.publish(
        EventNames.PRODUCTION_ENTRY_APPROVED,
        'ProductionEntry',
        entryId,
        tenantId,
        actor.sub,
        actor.role,
        {
          entry_id: entryId,
          worker_id: entry.worker_id,
          foreman_name: foremanName,
          operation_name: entry.operation_name_snapshot,
          quantity: entry.quantity,
        },
      );

      return this.requireEntryView(manager, tenantId, entryId);
    });
  }

  async rejectEntry(
    tenantId: string,
    foremanId: string,
    entryId: string,
    dto: RejectEntryDto,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<OperationEntryView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const entry = await this.lockPendingEntryOrFail(manager, tenantId, entryId);
      await this.assertForemanOwnsWorker(
        manager,
        tenantId,
        foremanId,
        entry.worker_id,
      );

      await this.insertEntryAudit(
        manager,
        tenantId,
        entryId,
        'ENTRY_REJECTED',
        actor,
        { status: 'PENDING' },
        { status: 'REJECTED', reason: dto.reason, foreman_note: dto.foreman_note ?? null },
        metadata,
      );

      await manager.query(
        `UPDATE production_entries
         SET status = 'REJECTED',
             rejection_reason = $3,
             foreman_note = $4,
             rejected_at = now(),
             rejected_by = $5,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, entryId, dto.reason, dto.foreman_note ?? null, foremanId],
      );

      const foremanName = await this.getUserFullName(manager, tenantId, foremanId);
      this.eventPublisher.publish(
        EventNames.PRODUCTION_ENTRY_REJECTED,
        'ProductionEntry',
        entryId,
        tenantId,
        actor.sub,
        actor.role,
        {
          entry_id: entryId,
          worker_id: entry.worker_id,
          foreman_name: foremanName,
          reason: dto.reason,
        },
      );

      return this.requireEntryView(manager, tenantId, entryId);
    });
  }

  async correctAndApproveEntry(
    tenantId: string,
    foremanId: string,
    entryId: string,
    dto: CorrectApproveEntryDto,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<OperationEntryView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const entry = await this.lockPendingEntryOrFail(manager, tenantId, entryId);
      await this.assertForemanOwnsWorker(
        manager,
        tenantId,
        foremanId,
        entry.worker_id,
      );

      await this.insertEntryAudit(
        manager,
        tenantId,
        entryId,
        'ENTRY_CORRECTED',
        actor,
        { quantity: entry.quantity },
        { quantity: dto.corrected_quantity, correction_comment: dto.correction_comment ?? null },
        metadata,
      );

      await manager.query(
        `UPDATE production_entries
         SET quantity = $3,
             status = 'APPROVED',
             correction_comment = $4,
             approved_at = now(),
             approved_by = $5,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [
          tenantId,
          entryId,
          dto.corrected_quantity,
          dto.correction_comment ?? null,
          foremanId,
        ],
      );

      const foremanName = await this.getUserFullName(manager, tenantId, foremanId);
      this.eventPublisher.publish(
        EventNames.PRODUCTION_ENTRY_APPROVED,
        'ProductionEntry',
        entryId,
        tenantId,
        actor.sub,
        actor.role,
        {
          entry_id: entryId,
          worker_id: entry.worker_id,
          foreman_name: foremanName,
          operation_name: entry.operation_name_snapshot,
          quantity: dto.corrected_quantity,
        },
      );

      return this.requireEntryView(manager, tenantId, entryId);
    });
  }

  async getSummary(
    tenantId: string,
  ): Promise<{
    todayEntriesCount: number;
    todayTotalQuantity: number;
    pendingEntriesCount: number;
    approvedEntriesCount: number;
    rejectedEntriesCount: number;
  }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const today = new Date().toISOString().slice(0, 10);

      const rows = await manager.query<
        {
          today_entries: string;
          today_quantity: string;
          pending: string;
          approved: string;
          rejected: string;
        }[]
      >(
        `SELECT
           COALESCE(SUM(CASE WHEN pe.record_date = $2::date THEN 1 ELSE 0 END), 0)::text AS today_entries,
           COALESCE(SUM(CASE WHEN pe.record_date = $2::date THEN pe.quantity ELSE 0 END), 0)::text AS today_quantity,
           COALESCE(SUM(CASE WHEN pe.status = 'PENDING' THEN 1 ELSE 0 END), 0)::text AS pending,
           COALESCE(SUM(CASE WHEN pe.status = 'APPROVED' THEN 1 ELSE 0 END), 0)::text AS approved,
           COALESCE(SUM(CASE WHEN pe.status = 'REJECTED' THEN 1 ELSE 0 END), 0)::text AS rejected
         FROM production_entries pe
         WHERE pe.tenant_id = $1`,
        [tenantId, today],
      );

      const row = rows[0];

      return {
        todayEntriesCount: Number.parseInt(row.today_entries, 10),
        todayTotalQuantity: Number.parseInt(row.today_quantity, 10),
        pendingEntriesCount: Number.parseInt(row.pending, 10),
        approvedEntriesCount: Number.parseInt(row.approved, 10),
        rejectedEntriesCount: Number.parseInt(row.rejected, 10),
      };
    });
  }

  async bulkApproveEntries(
    tenantId: string,
    foremanId: string,
    dto: BulkApproveDto,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<{ success: true; data: { approved_count: number } }> {
    const successfulIds: string[] = [];
    const failedIds: Array<{ entry_id: string; reason: string }> = [];

    for (const entryId of dto.entry_ids) {
      try {
        await this.approveEntry(
          tenantId,
          foremanId,
          entryId,
          {},
          actor,
          metadata,
        );
        successfulIds.push(entryId);
      } catch (error) {
        if (error instanceof EntryNotPendingError) {
          failedIds.push({ entry_id: entryId, reason: 'ENTRY_NOT_PENDING' });
        } else if (error instanceof ForemanNotAssignedError) {
          failedIds.push({ entry_id: entryId, reason: 'FOREMAN_NOT_ASSIGNED' });
        } else if (error instanceof EntryNotFoundError) {
          failedIds.push({ entry_id: entryId, reason: 'ENTRY_NOT_FOUND' });
        } else {
          throw error;
        }
      }
    }

    if (failedIds.length > 0) {
      throw new BulkApprovePartialFailureError(successfulIds, failedIds);
    }

    return { success: true, data: { approved_count: successfulIds.length } };
  }

  private async lockPendingEntryOrFail(
    manager: EntityManager,
    tenantId: string,
    entryId: string,
  ): Promise<{
    id: string;
    worker_id: string;
    status: string;
    quantity: number;
    operation_name_snapshot: string;
  }> {
    const rows = await manager.query<
      {
        id: string;
        worker_id: string;
        status: string;
        quantity: number;
        operation_name_snapshot: string;
      }[]
    >(
      `SELECT id, worker_id, status, quantity, operation_name_snapshot
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2 AND status = 'PENDING'
       FOR UPDATE`,
      [tenantId, entryId],
    );
    if (rows[0]) {
      return rows[0];
    }

    const existing = await manager.query<
      { id: string; status: string }[]
    >(
      `SELECT id, status
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, entryId],
    );
    if (existing[0]) {
      throw new EntryNotPendingError();
    }
    throw new EntryNotFoundError();
  }

  private async assertForemanOwnsWorker(
    manager: EntityManager,
    tenantId: string,
    foremanId: string,
    workerId: string,
  ): Promise<void> {
    const rows = await manager.query<{ id: string }[]>(
      `SELECT id
       FROM foreman_assignments
       WHERE tenant_id = $1
         AND foreman_id = $2
         AND worker_id = $3
         AND unassigned_at IS NULL
       LIMIT 1`,
      [tenantId, foremanId, workerId],
    );
    if (!rows[0]) {
      throw new ForemanNotAssignedError();
    }
  }

  private async insertEntryAudit(
    manager: EntityManager,
    tenantId: string,
    entryId: string,
    action: 'ENTRY_APPROVED' | 'ENTRY_REJECTED' | 'ENTRY_CORRECTED',
    actor: AccessTokenClaims,
    beforeState: Record<string, unknown>,
    afterState: Record<string, unknown>,
    metadata: RequestMetadata,
  ): Promise<void> {
    await manager.query(
      `INSERT INTO audit_events
        (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
         before_state, after_state, ip_address, user_agent)
       VALUES ($1, $2, 'PRODUCTION_ENTRY', $3, $4, $5, $6,
         $7::jsonb, $8::jsonb, $9, $10)`,
      [
        uuidv7(),
        tenantId,
        entryId,
        action,
        actor.sub,
        actor.role,
        JSON.stringify(beforeState),
        JSON.stringify(afterState),
        metadata.ipAddress ?? null,
        metadata.userAgent ?? null,
      ],
    );
  }

  private async requireEntryView(
    manager: EntityManager,
    tenantId: string,
    entryId: string,
  ): Promise<OperationEntryView> {
    const rows = await manager.query<OperationEntryView[]>(
      `SELECT
         pe.id,
         pe.worker_id,
         pe.operation_id,
         pe.status,
         json_build_object(
           'id', u.id,
           'full_name', u.full_name,
           'worker_code', u.worker_code
         ) AS worker,
         json_build_object(
           'id', o.id,
           'name', o.name,
           'unit', o.unit
         ) AS operation,
         pe.operation_name_snapshot,
         pe.operation_code_snapshot,
         pe.quantity AS quantity_submitted,
         CASE WHEN pe.status = 'APPROVED' THEN pe.quantity ELSE NULL END AS quantity_approved,
         pe.unit_price_snapshot,
         pe.currency_snapshot,
         pe.record_date::text AS record_date,
         pe.worker_note,
         pe.created_at AS submitted_at,
         CASE WHEN fa.id IS NULL THEN NULL
           ELSE json_build_object('id', fm.id, 'full_name', fm.full_name)
         END AS foreman,
         pe.approved_at,
         pe.rejected_at,
         pe.approved_by,
         pe.rejected_by,
         pe.rejection_reason,
         pe.foreman_note,
         pe.correction_comment
       FROM production_entries pe
       JOIN users u
         ON u.tenant_id = pe.tenant_id AND u.id = pe.worker_id
       JOIN operations o
         ON o.tenant_id = pe.tenant_id AND o.id = pe.operation_id
       LEFT JOIN foreman_assignments fa
         ON fa.tenant_id = pe.tenant_id
        AND fa.worker_id = pe.worker_id
        AND fa.unassigned_at IS NULL
       LEFT JOIN users fm
         ON fm.tenant_id = fa.tenant_id AND fm.id = fa.foreman_id
       WHERE pe.tenant_id = $1 AND pe.id = $2`,
      [tenantId, entryId],
    );
    const entry = rows[0];
    if (!entry) {
      throw new EntryNotFoundError();
    }
    return entry;
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

  private async readBackDateWindow(
    manager: EntityManager,
  ): Promise<number> {
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

  private async getUserFullName(
    manager: EntityManager,
    tenantId: string,
    userId: string,
  ): Promise<string> {
    const rows = await manager.query<{ full_name: string }[]>(
      `SELECT full_name FROM users WHERE tenant_id = $1 AND id = $2 LIMIT 1`,
      [tenantId, userId],
    );
    return rows[0]?.full_name ?? '';
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
