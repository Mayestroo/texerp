import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { SettingsModule } from '../settings/settings.module';
import { MaterialsService } from './application/materials.service';
import { StockMovementsService } from './application/stock-movements.service';
import { MaterialsController } from './presentation/materials.controller';
import { WarehouseExceptionFilter } from './presentation/warehouse-exception.filter';

@Module({
  imports: [IamModule, SettingsModule],
  controllers: [MaterialsController],
  providers: [MaterialsService, StockMovementsService, WarehouseExceptionFilter],
})
export class WarehouseModule {}
