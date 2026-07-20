import { Module } from '@nestjs/common';
import { PayrollCalculationWorker } from './payroll-calculation.worker';
import { PayrollExportWorker } from './payroll-export.worker';
import { ReportExportWorker } from './report-export.worker';
import { NotificationDispatchWorker } from './notification-dispatch.worker';
import { PayrollModule } from '../modules/payroll/payroll.module';
import { ReportsModule } from '../modules/reports/reports.module';
import { NotificationsModule } from '../modules/notifications/notifications.module';

@Module({
  imports: [PayrollModule, ReportsModule, NotificationsModule],
  providers: [
    PayrollCalculationWorker,
    PayrollExportWorker,
    ReportExportWorker,
    NotificationDispatchWorker,
  ],
})
export class WorkersModule {}
