import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { uuidv7 } from '../../../shared/common/uuid';
import { ProductionReportQueryDto } from './dto/production-report-query.dto';
import { InvalidReportDateRangeError } from './errors/invalid-report-date-range.error';

interface ReportExportStatus {
  status: string;
  download_url: string | null;
  file_size_bytes: number | null;
  expires_at: Date | null;
}

interface ReportExportRow {
  status: string;
  file_url: string | null;
  file_size_bytes: string | null;
  error_message: string | null;
  generated_at: Date | null;
  expires_at: Date | null;
}

@Injectable()
export class ReportExportsService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    @InjectQueue('report-export') private readonly reportExportQueue: Queue,
  ) {}

  async queueExport(
    tenantId: string,
    requestedBy: string,
    filters: ProductionReportQueryDto,
  ): Promise<{ export_id: string }> {
    const exportId = uuidv7();

    const dateFrom = new Date(filters.date_from);
    const dateTo = new Date(filters.date_to);
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

    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `INSERT INTO report_exports
          (id, tenant_id, report_type, format, status, filters, requested_by)
         VALUES ($1, $2, 'PRODUCTION', 'EXCEL', 'QUEUED', $3::jsonb, $4)`,
        [exportId, tenantId, JSON.stringify(filters), requestedBy],
      );
    });

    await this.reportExportQueue.add(
      'generate-production-excel',
      { tenantId, exportId, filters },
      { attempts: 3, backoff: { type: 'exponential', delay: 1000 } },
    );

    return { export_id: exportId };
  }

  async getExportStatus(
    tenantId: string,
    exportId: string,
  ): Promise<ReportExportStatus | null> {
    return this.tenantDatabase.withTenant(
      tenantId,
      async (manager): Promise<ReportExportStatus | null> => {
        const rows = await manager.query<ReportExportRow[]>(
          `SELECT status, file_url, file_size_bytes, error_message, generated_at, expires_at
           FROM report_exports WHERE tenant_id = $1 AND id = $2`,
          [tenantId, exportId],
        );
        if (!rows[0]) return null;
        const row = rows[0];
        return {
          status: row.status,
          download_url: row.file_url,
          file_size_bytes: row.file_size_bytes
            ? Number.parseInt(row.file_size_bytes, 10)
            : null,
          expires_at: row.expires_at,
        };
      },
    );
  }

  async processExportJob(
    tenantId: string,
    exportId: string,
    // Reserved for actual Excel generation; placeholder implementation for MVP.
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    _filters: ProductionReportQueryDto,
  ): Promise<void> {
    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `UPDATE report_exports
         SET status = 'GENERATING'
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, exportId],
      );
    });

    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `UPDATE report_exports
         SET status = 'FAILED', error_message = $3
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, exportId, 'Not yet implemented'],
      );
    });
  }
}
