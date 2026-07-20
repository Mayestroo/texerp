import { Module } from '@nestjs/common';
import { SettingsService } from './application/settings.service';
import { TenantConfigService } from './application/tenant-config.service';
import { SettingsController } from './presentation/settings.controller';

@Module({
  controllers: [SettingsController],
  providers: [SettingsService, TenantConfigService],
  exports: [TenantConfigService],
})
export class SettingsModule {}
