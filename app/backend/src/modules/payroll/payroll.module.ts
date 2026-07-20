import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StorageModule } from '../../infrastructure/storage/storage.module';
import { PayrollPeriodsService } from './application/payroll-periods.service';
import { PayrollController } from './presentation/payroll.controller';
import { PayrollExceptionFilter } from './presentation/payroll-exception.filter';

@Module({
  imports: [IamModule, NotificationsModule, StorageModule],
  controllers: [PayrollController],
  providers: [PayrollPeriodsService, PayrollExceptionFilter],
  exports: [PayrollPeriodsService],
})
export class PayrollModule {}
