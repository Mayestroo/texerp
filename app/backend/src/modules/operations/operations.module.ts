import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { OperationsService } from './application/operations.service';
import { OperationsController } from './presentation/operations.controller';
import { OperationsExceptionFilter } from './presentation/operations-exception.filter';

@Module({
  imports: [IamModule],
  controllers: [OperationsController],
  providers: [OperationsService, OperationsExceptionFilter],
})
export class OperationsModule {}
