import { Injectable } from '@nestjs/common';
import { QueryFailedError, type EntityManager } from 'typeorm';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/utils/uuid';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { CreateAdjustmentDto } from './dto/create-adjustment.dto';
import { CreateAdvanceDto } from './dto/create-advance.dto';
import { CreatePayrollPeriodDto } from './dto/create-payroll-period.dto';
import { FinalizePeriodDto } from './dto/finalize-period.dto';
import { ListPayrollPeriodsQueryDto } from './dto/list-payroll-periods-query.dto';
import { AdjustmentNotFoundError } from './errors/adjustment-not-found.error';
import { CalculationAlreadyRunningError } from './errors/calculation-already-running.error';
import { ConfirmationRequiredError } from './errors/confirmation-required.error';
import { InvalidDateRangeError } from './errors/invalid-date-range.error';
import { PeriodAlreadyFinalizedError } from './errors/period-already-finalized.error';
import { PeriodFinalizedError } from './errors/period-finalized.error';
import { PeriodNotCalculatedError } from './errors/period-not-calculated.error';
import { PeriodNotDraftOrCalculatedError } from './errors/period-not-draft-or-calculated.error';
import { PeriodNotFoundError } from './errors/period-not-found.error';
import { PeriodOverlapError } from './errors/period-overlap.error';
import { WorkerNotInPeriodError } from './errors/worker-not-in-period.error';

interface RequestMetadata {
  ipAddress?: string;
  userAgent?: string;
}

export interface PayrollPeriodView {
  id: string;
  name: string;
  start_date: string;
  end_date: string;
  status: string;
  worker_count: number;
  total_gross: number;
  total_final: number;
  calculated_at: Date | null;
  finalized_at: Date | null;
  created_at: Date;
}

export interface PayrollCalculationView {
  id: string;
  worker_id: string;
  worker_full_name: string;
  worker_code: string;
  total_pieces: number;
  gross_earnings: number;
  total_bonuses: number;
  total_deductions: number;
  total_advances: number;
  advance_carryforward: number;
  final_pay: number;
  has_adjustments: boolean;
  calculation_version: number;
  entries_count: number;
}

export interface PeriodDetailView extends PayrollPeriodView {
  calculations: PayrollCalculationView[];
  pending_entries_count: number;
}

export interface WorkerCalculationDetailView {
  worker_id: string;
  worker_full_name: string;
  worker_code: string;
  department_name: string | null;
  operations_breakdown: Array<{
    operation_name: string;
    quantity: number;
    unit_price: number;
    earnings: number;
  }>;
  total_pieces: number;
  gross_earnings: number;
  adjustments: Array<{
    id: string;
    type: 'BONUS' | 'DEDUCTION';
    amount: number;
    reason: string;
  }>;
  advances: Array<{
    id: string;
    amount: number;
    given_date: string;
    reason: string | null;
  }>;
  total_bonuses: number;
  total_deductions: number;
  total_advances: number;
  advance_carryforward: number;
  final_pay: number;
  calculation_version: number;
  entries_count: number;
}

@Injectable()
export class PayrollPeriodsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async create(
    tenantId: string,
    actorId: string,
    actor: AccessTokenClaims,
    dto: CreatePayrollPeriodDto,
    metadata: RequestMetadata,
  ): Promise<PayrollPeriodView & { pending_entries_count: number }> {
    this.validateDateRange(dto.start_date, dto.end_date);

    try {
      return await this.tenantDatabase.withTenant(
        tenantId,
        async (manager) => {
          const overlap = await this.findOverlap(
            manager,
            tenantId,
            dto.start_date,
            dto.end_date,
          );
          if (overlap) {
            throw new PeriodOverlapError(overlap.id);
          }

          const periodId = uuidv7();

          const pendingResult = await manager.query<{ count: string }[]>(
            `SELECT COUNT(*)::text AS count
             FROM production_entries
             WHERE tenant_id = $1
               AND status = 'APPROVED'
               AND record_date >= $2
               AND record_date <= $3`,
            [tenantId, dto.start_date, dto.end_date],
          );
          const pending_entries_count = Number.parseInt(
            pendingResult[0].count,
            10,
          );

          const afterState = {
            id: periodId,
            name: dto.name,
            start_date: dto.start_date,
            end_date: dto.end_date,
            status: 'DRAFT',
          };

          await manager.query(
            `INSERT INTO audit_events
              (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
               after_state, ip_address, user_agent)
             VALUES ($1, $2, 'PAYROLL_PERIOD', $3, 'PAYROLL_PERIOD_CREATED', $4, $5,
               $6::jsonb, $7, $8)`,
            [
              uuidv7(),
              tenantId,
              periodId,
              actor.sub,
              actor.role,
              JSON.stringify(afterState),
              metadata.ipAddress ?? null,
              metadata.userAgent ?? null,
            ],
          );

          await manager.query(
            `INSERT INTO payroll_periods
              (id, tenant_id, name, start_date, end_date, status, created_by, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, 'DRAFT', $6, now(), now())`,
            [periodId, tenantId, dto.name, dto.start_date, dto.end_date, actorId],
          );

          return this.requirePeriodView(manager, tenantId, periodId).then(
            (p) => ({ ...p, pending_entries_count }),
          );
        },
      );
    } catch (error) {
      this.mapUniqueViolation(error);
      throw error;
    }
  }

  async list(
    tenantId: string,
    query: ListPayrollPeriodsQueryDto,
  ): Promise<{ data: PayrollPeriodView[]; total: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions: string[] = ['pp.tenant_id = $1'];
      const params: unknown[] = [tenantId];
      let paramIndex = 2;

      if (query.status && query.status !== 'ALL') {
        conditions.push(`pp.status = $${paramIndex++}`);
        params.push(query.status);
      }

      const whereClause = conditions.join(' AND ');

      const countResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM payroll_periods pp
         WHERE ${whereClause}`,
        params,
      );
      const total = Number.parseInt(countResult[0].count, 10);

      const rows = await manager.query<PayrollPeriodView[]>(
        `SELECT
           pp.id,
           pp.name,
           pp.start_date::text AS start_date,
           pp.end_date::text AS end_date,
           pp.status,
           pp.worker_count,
           pp.total_gross,
           pp.total_final,
           pp.calculated_at,
           pp.finalized_at,
           pp.created_at
         FROM payroll_periods pp
         WHERE ${whereClause}
         ORDER BY pp.created_at DESC
         LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
        [...params, query.limit, (query.page - 1) * query.limit],
      );

      return { data: rows, total };
    });
  }

  async getById(
    tenantId: string,
    periodId: string,
  ): Promise<PeriodDetailView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.requirePeriod(manager, tenantId, periodId);

      const pendingResult = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM production_entries
         WHERE tenant_id = $1
           AND status = 'PENDING'
           AND record_date >= $2
           AND record_date <= $3`,
        [tenantId, period.start_date, period.end_date],
      );
      const pending_entries_count = Number.parseInt(pendingResult[0].count, 10);

      const calculations = await manager.query<PayrollCalculationView[]>(
        `SELECT
           pc.id,
           pc.worker_id,
           u.full_name AS worker_full_name,
           u.worker_code AS worker_code,
           pc.total_pieces,
           pc.gross_earnings,
           pc.total_bonuses,
           pc.total_deductions,
           pc.total_advances,
           pc.advance_carryforward,
           pc.final_pay,
           pc.has_adjustments,
           pc.calculation_version,
           pc.entries_count
         FROM payroll_calculations pc
         JOIN users u ON u.tenant_id = pc.tenant_id AND u.id = pc.worker_id
         WHERE pc.tenant_id = $1 AND pc.period_id = $2
         ORDER BY u.full_name`,
        [tenantId, periodId],
      );

      return {
        ...period,
        calculations,
        pending_entries_count,
      };
    });
  }

  async calculate(
    tenantId: string,
    periodId: string,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<{ status: string; worker_count: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.lockPeriodOrFail(manager, tenantId, periodId);

      if (!['DRAFT', 'CALCULATED'].includes(period.status)) {
        throw new PeriodNotDraftOrCalculatedError(period.status);
      }

      await manager.query(
        `UPDATE payroll_periods
         SET status = 'CALCULATING', updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, periodId],
      );

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_PERIOD', $3, 'PAYROLL_CALCULATION_STARTED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          periodId,
          actor.sub,
          actor.role,
          JSON.stringify({ status: 'CALCULATING' }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      const approvedEntries = await manager.query<
        Array<{
          worker_id: string;
          quantity: number;
          unit_price_snapshot: number;
        }>
      >(
        `SELECT worker_id, quantity, unit_price_snapshot
         FROM production_entries
         WHERE tenant_id = $1
           AND status = 'APPROVED'
           AND record_date >= $2
           AND record_date <= $3
         ORDER BY worker_id`,
        [tenantId, period.start_date, period.end_date],
      );

      const workerMap = new Map<
        string,
        {
          total_pieces: number;
          gross_earnings: number;
          entries_count: number;
        }
      >();

      for (const entry of approvedEntries) {
        const existing = workerMap.get(entry.worker_id) ?? {
          total_pieces: 0,
          gross_earnings: 0,
          entries_count: 0,
        };
        existing.total_pieces += entry.quantity;
        existing.gross_earnings += entry.quantity * entry.unit_price_snapshot;
        existing.entries_count += 1;
        workerMap.set(entry.worker_id, existing);
      }

      const workerIds = [...workerMap.keys()];

      await manager.query(
        `DELETE FROM payroll_calculations
         WHERE tenant_id = $1 AND period_id = $2`,
        [tenantId, periodId],
      );

      for (const workerId of workerIds) {
        const calc = workerMap.get(workerId)!;

        const adjustments = await manager.query<
          Array<{ type: string; amount: number }>
        >(
          `SELECT type, amount
           FROM payroll_adjustments
           WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3`,
          [tenantId, periodId, workerId],
        );

        const advances = await manager.query<{ amount: number }[]>(
          `SELECT COALESCE(SUM(amount), 0) AS amount
           FROM payroll_advances
           WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3`,
          [tenantId, periodId, workerId],
        );

        let totalBonuses = 0;
        let totalDeductions = 0;
        for (const adj of adjustments) {
          if (adj.type === 'BONUS') totalBonuses += adj.amount;
          else totalDeductions += adj.amount;
        }
        const totalAdvances = Number(advances[0]?.amount ?? 0);

        const advanceCarryforward = 0;

        const finalPay = Math.max(
          calc.gross_earnings + totalBonuses - totalDeductions - totalAdvances - advanceCarryforward,
          0,
        );

        const calcId = uuidv7();
        await manager.query(
          `INSERT INTO payroll_calculations
            (id, tenant_id, period_id, worker_id, total_pieces, gross_earnings,
             total_bonuses, total_deductions, total_advances, advance_carryforward,
             final_pay, has_adjustments, calculation_version, entries_count, calculated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, now())`,
          [
            calcId,
            tenantId,
            periodId,
            workerId,
            calc.total_pieces,
            calc.gross_earnings,
            totalBonuses,
            totalDeductions,
            totalAdvances,
            advanceCarryforward,
            finalPay,
            adjustments.length > 0,
            1,
            calc.entries_count,
          ],
        );
      }

      const now = new Date();
      const totals = workerIds.reduce(
        (acc, wid) => {
          const c = workerMap.get(wid)!;
          return {
            total_gross: acc.total_gross + c.gross_earnings,
          };
        },
        { total_gross: 0 },
      );

      const finalTotalsResult = await manager.query<
        Array<{ total_final: bigint }>
      >(
        `SELECT COALESCE(SUM(final_pay), 0) AS total_final
         FROM payroll_calculations
         WHERE tenant_id = $1 AND period_id = $2`,
        [tenantId, periodId],
      );

      await manager.query(
        `UPDATE payroll_periods
         SET status = 'CALCULATED',
             worker_count = $3,
             total_gross = $4,
             total_final = $5,
             calculated_at = $6,
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [
          tenantId,
          periodId,
          workerIds.length,
          totals.total_gross,
          Number(finalTotalsResult[0]?.total_final ?? 0),
          now,
        ],
      );

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_PERIOD', $3, 'PAYROLL_CALCULATION_COMPLETED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          periodId,
          actor.sub,
          actor.role,
          JSON.stringify({
            status: 'CALCULATED',
            worker_count: workerIds.length,
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      return { status: 'CALCULATED', worker_count: workerIds.length };
    });
  }

  async getWorkerCalculation(
    tenantId: string,
    periodId: string,
    workerId: string,
    actor: AccessTokenClaims,
  ): Promise<WorkerCalculationDetailView> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.requirePeriod(manager, tenantId, periodId);

      if (actor.role === 'WORKER' && actor.sub !== workerId) {
        throw new PeriodNotFoundError();
      }
      if (
        actor.role === 'WORKER' &&
        period.status !== 'FINALIZED'
      ) {
        throw new PeriodNotFoundError();
      }

      const calc = await manager.query<
        Array<{
          id: string;
          worker_id: string;
          full_name: string;
          worker_code: string;
          department_name: string | null;
          total_pieces: number;
          gross_earnings: number;
          total_bonuses: number;
          total_deductions: number;
          total_advances: number;
          advance_carryforward: number;
          final_pay: number;
          calculation_version: number;
          entries_count: number;
        }>
      >(
        `SELECT
           pc.id,
           pc.worker_id,
           u.full_name,
           u.worker_code,
           d.name AS department_name,
           pc.total_pieces,
           pc.gross_earnings,
           pc.total_bonuses,
           pc.total_deductions,
           pc.total_advances,
           pc.advance_carryforward,
           pc.final_pay,
           pc.calculation_version,
           pc.entries_count
         FROM payroll_calculations pc
         JOIN users u ON u.tenant_id = pc.tenant_id AND u.id = pc.worker_id
         LEFT JOIN departments d ON d.tenant_id = u.tenant_id AND d.id = (
           SELECT department_id FROM foreman_assignments fa
           WHERE fa.tenant_id = u.tenant_id AND fa.worker_id = u.id AND fa.unassigned_at IS NULL
           LIMIT 1
         )
         WHERE pc.tenant_id = $1 AND pc.period_id = $2 AND pc.worker_id = $3`,
        [tenantId, periodId, workerId],
      );

      if (!calc[0]) {
        throw new PeriodNotFoundError();
      }

      const operationsBreakdown = await manager.query<
        Array<{
          operation_name: string;
          quantity: number;
          unit_price: number;
        }>
      >(
        `SELECT
           pe.operation_name_snapshot AS operation_name,
           SUM(pe.quantity) AS quantity,
           pe.unit_price_snapshot AS unit_price
         FROM production_entries pe
         WHERE pe.tenant_id = $1
           AND pe.worker_id = $2
           AND pe.status = 'APPROVED'
           AND pe.record_date >= (SELECT start_date FROM payroll_periods WHERE tenant_id = $1 AND id = $3)
           AND pe.record_date <= (SELECT end_date FROM payroll_periods WHERE tenant_id = $1 AND id = $3)
         GROUP BY pe.operation_name_snapshot, pe.unit_price_snapshot
         ORDER BY pe.operation_name_snapshot`,
        [tenantId, workerId, periodId],
      );

      const adjustments = await manager.query<
        Array<{
          id: string;
          type: 'BONUS' | 'DEDUCTION';
          amount: number;
          reason: string;
        }>
      >(
        `SELECT id, type, amount, reason
         FROM payroll_adjustments
         WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3
         ORDER BY created_at`,
        [tenantId, periodId, workerId],
      );

      const advances = await manager.query<
        Array<{
          id: string;
          amount: number;
          given_date: string;
          reason: string | null;
        }>
      >(
        `SELECT id, amount, given_date::text AS given_date, reason
         FROM payroll_advances
         WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3
         ORDER BY given_date`,
        [tenantId, periodId, workerId],
      );

      const c = calc[0];
      return {
        worker_id: c.worker_id,
        worker_full_name: c.full_name,
        worker_code: c.worker_code,
        department_name: c.department_name,
        operations_breakdown: operationsBreakdown.map((o) => ({
          ...o,
          earnings: o.quantity * o.unit_price,
        })),
        total_pieces: c.total_pieces,
        gross_earnings: c.gross_earnings,
        adjustments,
        advances,
        total_bonuses: c.total_bonuses,
        total_deductions: c.total_deductions,
        total_advances: c.total_advances,
        advance_carryforward: c.advance_carryforward,
        final_pay: c.final_pay,
        calculation_version: c.calculation_version,
        entries_count: c.entries_count,
      };
    });
  }

  async addAdjustment(
    tenantId: string,
    periodId: string,
    actor: AccessTokenClaims,
    dto: CreateAdjustmentDto,
    metadata: RequestMetadata,
  ): Promise<{ id: string }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.lockPeriodOrFail(manager, tenantId, periodId);
      if (period.status === 'FINALIZED') {
        throw new PeriodFinalizedError();
      }

      const calc = await manager.query<{ id: string }[]>(
        `SELECT id FROM payroll_calculations
         WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3
         LIMIT 1`,
        [tenantId, periodId, dto.worker_id],
      );
      if (!calc[0]) {
        throw new WorkerNotInPeriodError();
      }

      const adjustmentId = uuidv7();
      await manager.query(
        `INSERT INTO payroll_adjustments
          (id, tenant_id, period_id, worker_id, type, amount, reason, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          adjustmentId,
          tenantId,
          periodId,
          dto.worker_id,
          dto.type,
          dto.amount,
          dto.reason,
          actor.sub,
        ],
      );

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_ADJUSTMENT', $3, 'PAYROLL_ADJUSTMENT_CREATED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          adjustmentId,
          actor.sub,
          actor.role,
          JSON.stringify({
            period_id: periodId,
            worker_id: dto.worker_id,
            type: dto.type,
            amount: dto.amount,
            reason: dto.reason,
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      return { id: adjustmentId };
    });
  }

  async removeAdjustment(
    tenantId: string,
    periodId: string,
    adjustmentId: string,
    actor: AccessTokenClaims,
    metadata: RequestMetadata,
  ): Promise<void> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.lockPeriodOrFail(manager, tenantId, periodId);
      if (period.status === 'FINALIZED') {
        throw new PeriodFinalizedError();
      }

      const result = await manager.query(
        `DELETE FROM payroll_adjustments
         WHERE tenant_id = $1 AND id = $2 AND period_id = $3`,
        [tenantId, adjustmentId, periodId],
      );

      if (result[1] === 0) {
        throw new AdjustmentNotFoundError();
      }

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_ADJUSTMENT', $3, 'PAYROLL_ADJUSTMENT_DELETED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          adjustmentId,
          actor.sub,
          actor.role,
          JSON.stringify({ deleted: true }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );
    });
  }

  async addAdvance(
    tenantId: string,
    periodId: string,
    actor: AccessTokenClaims,
    dto: CreateAdvanceDto,
    metadata: RequestMetadata,
  ): Promise<{ id: string }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.lockPeriodOrFail(manager, tenantId, periodId);
      if (period.status === 'FINALIZED') {
        throw new PeriodFinalizedError();
      }

      const calc = await manager.query<{ id: string }[]>(
        `SELECT id FROM payroll_calculations
         WHERE tenant_id = $1 AND period_id = $2 AND worker_id = $3
         LIMIT 1`,
        [tenantId, periodId, dto.worker_id],
      );
      if (!calc[0]) {
        throw new WorkerNotInPeriodError();
      }

      const advanceId = uuidv7();
      await manager.query(
        `INSERT INTO payroll_advances
          (id, tenant_id, period_id, worker_id, amount, given_date, reason, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          advanceId,
          tenantId,
          periodId,
          dto.worker_id,
          dto.amount,
          dto.given_date,
          dto.reason ?? null,
          actor.sub,
        ],
      );

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_ADVANCE', $3, 'PAYROLL_ADVANCE_CREATED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          advanceId,
          actor.sub,
          actor.role,
          JSON.stringify({
            period_id: periodId,
            worker_id: dto.worker_id,
            amount: dto.amount,
            given_date: dto.given_date,
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      return { id: advanceId };
    });
  }

  async finalize(
    tenantId: string,
    periodId: string,
    actor: AccessTokenClaims,
    dto: FinalizePeriodDto,
    metadata: RequestMetadata,
  ): Promise<{
    period_id: string;
    workers_notified: number;
    total_final_pay: number;
  }> {
    if (!dto.confirmed) {
      throw new ConfirmationRequiredError();
    }

    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const period = await this.lockPeriodOrFail(manager, tenantId, periodId);

      if (period.status === 'FINALIZED') {
        throw new PeriodAlreadyFinalizedError();
      }
      if (period.status !== 'CALCULATED') {
        throw new PeriodNotCalculatedError(period.status);
      }

      const pendingCount = await manager.query<{ count: string }[]>(
        `SELECT COUNT(*)::text AS count
         FROM production_entries
         WHERE tenant_id = $1
           AND status = 'PENDING'
           AND record_date >= $2
           AND record_date <= $3`,
        [tenantId, period.start_date, period.end_date],
      );

      const totalsResult = await manager.query<
        Array<{ total_final: bigint; worker_count: bigint }>
      >(
        `SELECT
           COALESCE(SUM(final_pay), 0) AS total_final,
           COUNT(*) AS worker_count
         FROM payroll_calculations
         WHERE tenant_id = $1 AND period_id = $2`,
        [tenantId, periodId],
      );

      await manager.query(
        `UPDATE payroll_periods
         SET status = 'FINALIZED',
             total_final = $3,
             worker_count = $4,
             finalized_at = now(),
             updated_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [
          tenantId,
          periodId,
          Number(totalsResult[0]?.total_final ?? 0),
          Number(totalsResult[0]?.worker_count ?? 0),
        ],
      );

      await manager.query(
        `INSERT INTO audit_events
          (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role,
           after_state, ip_address, user_agent)
         VALUES ($1, $2, 'PAYROLL_PERIOD', $3, 'PAYROLL_PERIOD_FINALIZED', $4, $5,
           $6::jsonb, $7, $8)`,
        [
          uuidv7(),
          tenantId,
          periodId,
          actor.sub,
          actor.role,
          JSON.stringify({
            status: 'FINALIZED',
            total_final: Number(totalsResult[0]?.total_final ?? 0),
            worker_count: Number(totalsResult[0]?.worker_count ?? 0),
          }),
          metadata.ipAddress ?? null,
          metadata.userAgent ?? null,
        ],
      );

      return {
        period_id: periodId,
        workers_notified: Number(totalsResult[0]?.worker_count ?? 0),
        total_final_pay: Number(totalsResult[0]?.total_final ?? 0),
      };
    });
  }

  async getMyPayroll(
    tenantId: string,
    workerId: string,
  ): Promise<PayrollPeriodView[]> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const rows = await manager.query<PayrollPeriodView[]>(
        `SELECT
           pp.id,
           pp.name,
           pp.start_date::text AS start_date,
           pp.end_date::text AS end_date,
           pp.status,
           pp.worker_count,
           pp.total_gross,
           pp.total_final,
           pp.calculated_at,
           pp.finalized_at,
           pp.created_at
         FROM payroll_periods pp
         WHERE pp.tenant_id = $1
           AND pp.status = 'FINALIZED'
           AND EXISTS (
             SELECT 1 FROM payroll_calculations pc
             WHERE pc.tenant_id = pp.tenant_id
               AND pc.period_id = pp.id
               AND pc.worker_id = $2
           )
         ORDER BY pp.end_date DESC`,
        [tenantId, workerId],
      );
      return rows;
    });
  }

  // --- Private helpers ---

  private validateDateRange(startDate: string, endDate: string): void {
    if (startDate >= endDate) {
      throw new InvalidDateRangeError();
    }
  }

  private async findOverlap(
    manager: EntityManager,
    tenantId: string,
    startDate: string,
    endDate: string,
  ): Promise<{ id: string } | undefined> {
    const rows = await manager.query<{ id: string }[]>(
      `SELECT id FROM payroll_periods
       WHERE tenant_id = $1
         AND status IN ('DRAFT', 'CALCULATING', 'CALCULATED')
         AND (start_date, end_date) OVERLAPS ($2::date, $3::date)
       LIMIT 1`,
      [tenantId, startDate, endDate],
    );
    return rows[0];
  }

  private async lockPeriodOrFail(
    manager: EntityManager,
    tenantId: string,
    periodId: string,
  ): Promise<{
    id: string;
    status: string;
    start_date: string;
    end_date: string;
  }> {
    const rows = await manager.query<
      { id: string; status: string; start_date: string; end_date: string }[]
    >(
      `SELECT id, status, start_date::text AS start_date, end_date::text AS end_date
       FROM payroll_periods
       WHERE tenant_id = $1 AND id = $2
       FOR UPDATE`,
      [tenantId, periodId],
    );
    if (!rows[0]) {
      throw new PeriodNotFoundError();
    }
    return rows[0];
  }

  private async requirePeriod(
    manager: EntityManager,
    tenantId: string,
    periodId: string,
  ): Promise<PayrollPeriodView> {
    const rows = await this.loadPeriodViews(manager, tenantId, periodId);
    if (!rows[0]) {
      throw new PeriodNotFoundError();
    }
    return rows[0];
  }

  private async requirePeriodView(
    manager: EntityManager,
    tenantId: string,
    periodId: string,
  ): Promise<PayrollPeriodView> {
    const rows = await this.loadPeriodViews(manager, tenantId, periodId);
    if (!rows[0]) {
      throw new PeriodNotFoundError();
    }
    return rows[0];
  }

  private async loadPeriodViews(
    manager: EntityManager,
    tenantId: string,
    periodId: string,
  ): Promise<PayrollPeriodView[]> {
    return manager.query<PayrollPeriodView[]>(
      `SELECT
         id,
         name,
         start_date::text AS start_date,
         end_date::text AS end_date,
         status,
         worker_count,
         total_gross,
         total_final,
         calculated_at,
         finalized_at,
         created_at
       FROM payroll_periods
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, periodId],
    );
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
