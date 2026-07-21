import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { SettingsService } from './application/settings.service';
import { TenantConfigService } from './application/tenant-config.service';
import { SettingsController } from './presentation/settings.controller';

@Module({
  imports: [IamModule],
  controllers: [SettingsController],
  providers: [SettingsService, TenantConfigService],
  exports: [TenantConfigService],
})
export class SettingsModule {}

