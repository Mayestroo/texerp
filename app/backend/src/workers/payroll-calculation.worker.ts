import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { PayrollPeriodsService } from '../modules/payroll/application/payroll-periods.service';

@Processor('payroll-calculation')
export class PayrollCalculationWorker extends WorkerHost {
  constructor(private readonly payrollPeriodsService: PayrollPeriodsService) {
    super();
  }

  async process(job: Job<any>): Promise<any> {
    const { tenantId, periodId, actor, metadata } = job.data;
    try {
      await this.payrollPeriodsService.processCalculationJob(tenantId, periodId, actor, metadata);
    } catch (error) {
      console.error(`Calculation failed for job ${job.id}:`, error);
      throw error;
    }
  }
}
