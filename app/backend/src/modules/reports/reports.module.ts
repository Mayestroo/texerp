import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { ProductionReportsService } from './application/production-reports.service';
import { ReportExportsService } from './application/report-exports.service';
import { ReportsController } from './presentation/reports.controller';
import { ReportsExceptionFilter } from './presentation/reports-exception.filter';

@Module({
  imports: [IamModule],
  controllers: [ReportsController],
  providers: [
    ProductionReportsService,
    ReportExportsService,
    ReportsExceptionFilter,
  ],
  exports: [ProductionReportsService, ReportExportsService],
})
export class ReportsModule {}

