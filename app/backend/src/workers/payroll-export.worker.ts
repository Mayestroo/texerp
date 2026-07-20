import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { PayrollPeriodsService } from '../modules/payroll/application/payroll-periods.service';

@Processor('payroll-export')
export class PayrollExportWorker extends WorkerHost {
  constructor(private readonly payrollPeriodsService: PayrollPeriodsService) {
    super();
  }

  async process(job: Job<any>): Promise<any> {
    const { exportId, tenantId, periodId, format, actor } = job.data;
    try {
      await this.payrollPeriodsService.processExportJob(exportId, tenantId, periodId, format, actor);
    } catch (error) {
      console.error(`Export failed for job ${job.id}:`, error);
      throw error;
    }
  }
}
