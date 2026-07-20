import { Injectable } from '@nestjs/common';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { AccessTokenClaims } from '../../iam/application/access-token-claims';
import { ProductionReportQueryDto } from './dto/production-report-query.dto';
import { InvalidReportDateRangeError } from './errors/invalid-report-date-range.error';
import { InvalidReportGroupByError } from './errors/invalid-report-group-by.error';

interface ReportPagination {
  page: number;
  limit: number;
  total: number;
  total_pages: number;
}

interface ProductionReportResult {
  period: { from: string; to: string };
  total_pieces: number;
  total_earnings: number;
  rows: unknown[];
  pagination: ReportPagination;
}

interface BaseReportRow {
  id: string | null;
  full_name: string | null;
  worker_code: string | null;
  name: string | null;
  code: string | null;
  date: string | null;
  total_pieces: string | null;
  operations_count: string | null;
  workers_count: string | null;
  gross_earnings: string | null;
  records_count: string | null;
}

@Injectable()
export class ProductionReportsService {
  constructor(private readonly tenantDatabase: TenantDatabase) {}

  async generateReport(
    tenantId: string,
    actor: AccessTokenClaims,
    query: ProductionReportQueryDto,
  ): Promise<ProductionReportResult> {
    const dateFrom = new Date(query.date_from);
    const dateTo = new Date(query.date_to);
    const diffDays = Math.ceil(
      (dateTo.getTime() - dateFrom.getTime()) / (1000 * 60 * 60 * 24),
    );

    if (diffDays > 30) {
      throw new InvalidReportDateRangeError(
        "Sana oralig'i 31 kundan oshmasligi kerak",
      );
    }
    if (diffDays < 0) {
      throw new InvalidReportDateRangeError(
        "date_to date_from dan kichik bo'lmasligi kerak",
      );
    }

    return this.tenantDatabase.withTenant(
      tenantId,
      async (manager): Promise<ProductionReportResult> => {
        const conditions = [
          'pe.tenant_id = $1',
          'pe.record_date >= $2',
          'pe.record_date <= $3',
          "pe.status = 'APPROVED'",
        ];
        const params: unknown[] = [tenantId, query.date_from, query.date_to];

        if (query.worker_id) {
          params.push(query.worker_id);
          conditions.push(`pe.worker_id = $${params.length}`);
        }

        if (query.operation_id) {
          params.push(query.operation_id);
          conditions.push(`pe.operation_id = $${params.length}`);
        }

        if (query.foreman_id) {
          params.push(query.foreman_id);
          conditions.push(`fa.foreman_id = $${params.length}`);
        }

        if (query.department_id) {
          params.push(query.department_id);
          conditions.push(`fa.department_id = $${params.length}`);
        }

        if (actor.role === 'FOREMAN') {
          params.push(actor.sub);
          conditions.push(`fa.foreman_id = $${params.length}`);
        }

        const where = conditions.join(' AND ');

        const needsForemanJoin =
          query.foreman_id !== undefined ||
          query.department_id !== undefined ||
          actor.role === 'FOREMAN' ||
          query.group_by === 'foreman';

        const joins = `
          LEFT JOIN users u
            ON u.tenant_id = pe.tenant_id AND u.id = pe.worker_id
          LEFT JOIN operations o
            ON o.tenant_id = pe.tenant_id AND o.id = pe.operation_id
          ${
            needsForemanJoin
              ? `LEFT JOIN foreman_assignments fa
                   ON fa.tenant_id = pe.tenant_id
                   AND fa.worker_id = pe.worker_id
                   AND fa.assigned_at <= pe.record_date::timestamptz
                   AND (fa.unassigned_at IS NULL OR fa.unassigned_at > pe.record_date::timestamptz)
                 LEFT JOIN users f
                   ON f.tenant_id = fa.tenant_id AND f.id = fa.foreman_id`
              : ''
          }
        `;

        let groupBySql: string;
        let selectSql: string;

        switch (query.group_by) {
          case 'worker':
            selectSql = `
              pe.worker_id AS id,
              u.full_name,
              u.worker_code,
              SUM(pe.quantity) AS total_pieces,
              COUNT(DISTINCT pe.operation_id) AS operations_count,
              SUM(pe.quantity * pe.unit_price_snapshot) AS gross_earnings,
              COUNT(*) AS records_count
            `;
            groupBySql = 'pe.worker_id, u.full_name, u.worker_code';
            break;
          case 'operation':
            selectSql = `
              pe.operation_id AS id,
              o.name,
              o.code,
              SUM(pe.quantity) AS total_pieces,
              COUNT(DISTINCT pe.worker_id) AS workers_count,
              SUM(pe.quantity * pe.unit_price_snapshot) AS gross_earnings,
              COUNT(*) AS records_count
            `;
            groupBySql = 'pe.operation_id, o.name, o.code';
            break;
          case 'date':
            selectSql = `
              pe.record_date AS date,
              SUM(pe.quantity) AS total_pieces,
              SUM(pe.quantity * pe.unit_price_snapshot) AS gross_earnings,
              COUNT(*) AS records_count
            `;
            groupBySql = 'pe.record_date';
            break;
          case 'foreman':
            selectSql = `
              fa.foreman_id AS id,
              f.full_name,
              COUNT(DISTINCT pe.worker_id) AS workers_count,
              SUM(pe.quantity) AS total_pieces,
              SUM(pe.quantity * pe.unit_price_snapshot) AS gross_earnings,
              COUNT(*) AS records_count
            `;
            groupBySql = 'fa.foreman_id, f.full_name';
            break;
          default:
            throw new InvalidReportGroupByError();
        }

        const totalRows = await manager.query<
          Array<{
            total_pieces: string | null;
            total_earnings: string | null;
          }>
        >(
          `SELECT
            SUM(pe.quantity) AS total_pieces,
            SUM(pe.quantity * pe.unit_price_snapshot) AS total_earnings
          FROM production_entries pe
          ${joins}
          WHERE ${where}`,
          params,
        );

        const limit = query.limit || 25;
        const page = query.page || 1;
        const offset = (page - 1) * limit;

        const rows = await manager.query<BaseReportRow[]>(
          `SELECT ${selectSql}
          FROM production_entries pe
          ${joins}
          WHERE ${where}
          GROUP BY ${groupBySql}
          ORDER BY gross_earnings DESC
          LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
          [...params, limit, offset],
        );

        const countRows = await manager.query<Array<{ total: string }>>(
          `SELECT COUNT(*)::text AS total FROM (
            SELECT 1 FROM production_entries pe
            ${joins}
            WHERE ${where}
            GROUP BY ${groupBySql}
          ) sub`,
          params,
        );
        const total = Number.parseInt(countRows[0]?.total || '0', 10);

        return {
          period: { from: query.date_from, to: query.date_to },
          total_pieces: Number.parseInt(
            totalRows[0]?.total_pieces || '0',
            10,
          ),
          total_earnings: Number.parseInt(
            totalRows[0]?.total_earnings || '0',
            10,
          ),
          rows: rows.map((r) => this.mapRow(query.group_by, r)),
          pagination: {
            page,
            limit,
            total,
            total_pages: Math.ceil(total / limit),
          },
        };
      },
    );
  }

  private mapRow(groupBy: string, row: BaseReportRow): unknown {
    switch (groupBy) {
      case 'worker':
        return {
          worker: {
            id: row.id,
            full_name: row.full_name,
            worker_code: row.worker_code,
          },
          total_pieces: Number.parseInt(row.total_pieces ?? '0', 10),
          operations_count: Number.parseInt(
            row.operations_count ?? '0',
            10,
          ),
          gross_earnings: Number.parseInt(row.gross_earnings ?? '0', 10),
          records_count: Number.parseInt(row.records_count ?? '0', 10),
        };
      case 'operation':
        return {
          operation: {
            id: row.id,
            name: row.name,
            code: row.code,
          },
          total_pieces: Number.parseInt(row.total_pieces ?? '0', 10),
          workers_count: Number.parseInt(row.workers_count ?? '0', 10),
          gross_earnings: Number.parseInt(row.gross_earnings ?? '0', 10),
          records_count: Number.parseInt(row.records_count ?? '0', 10),
        };
      case 'date':
        return {
          date: row.date,
          total_pieces: Number.parseInt(row.total_pieces ?? '0', 10),
          gross_earnings: Number.parseInt(row.gross_earnings ?? '0', 10),
          records_count: Number.parseInt(row.records_count ?? '0', 10),
        };
      case 'foreman':
        return {
          foreman: {
            id: row.id,
            full_name: row.full_name,
          },
          total_pieces: Number.parseInt(row.total_pieces ?? '0', 10),
          workers_count: Number.parseInt(row.workers_count ?? '0', 10),
          gross_earnings: Number.parseInt(row.gross_earnings ?? '0', 10),
          records_count: Number.parseInt(row.records_count ?? '0', 10),
        };
      default:
        return row;
    }
  }
}
