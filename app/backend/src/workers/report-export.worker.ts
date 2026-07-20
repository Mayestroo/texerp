import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { ReportExportsService } from '../modules/reports/application/report-exports.service';
import { ProductionReportQueryDto } from '../modules/reports/application/dto/production-report-query.dto';

interface ReportExportJobData {
  tenantId: string;
  exportId: string;
  filters: ProductionReportQueryDto;
}

@Processor('report-export')
export class ReportExportWorker extends WorkerHost {
  constructor(private readonly reportExportsService: ReportExportsService) {
    super();
  }

  async process(job: Job<ReportExportJobData>): Promise<void> {
    const { tenantId, exportId, filters } = job.data;
    try {
      await this.reportExportsService.processExportJob(
        tenantId,
        exportId,
        filters,
      );
    } catch (error) {
      console.error(`Report export failed for job ${job.id}:`, error);
      throw error;
    }
  }
}
