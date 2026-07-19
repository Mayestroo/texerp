import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { PayrollPeriodsService } from './application/payroll-periods.service';
import { PayrollController } from './presentation/payroll.controller';
import { PayrollExceptionFilter } from './presentation/payroll-exception.filter';

@Module({
  imports: [IamModule],
  controllers: [PayrollController],
  providers: [PayrollPeriodsService, PayrollExceptionFilter],
})
export class PayrollModule {}
