import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { ProductionEntriesService } from './application/production-entries.service';
import { ProductionEntriesController } from './presentation/production-entries.controller';
import { ProductionExceptionFilter } from './presentation/production-exception.filter';

@Module({
  imports: [IamModule],
  controllers: [ProductionEntriesController],
  providers: [ProductionEntriesService, ProductionExceptionFilter],
})
export class ProductionModule {}
