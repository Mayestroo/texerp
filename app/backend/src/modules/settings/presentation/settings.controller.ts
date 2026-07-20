import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import {
  AuthenticatedRequest,
  JwtAuthGuard,
} from '../../iam/presentation/jwt-auth.guard';
import { RolesGuard } from '../../iam/presentation/roles.guard';
import { Roles } from '../../iam/presentation/roles.decorator';
import { SettingsService, TenantSettingsView } from '../application/settings.service';
import { TenantConfigService } from '../application/tenant-config.service';
import { UpdateSettingsDto } from '../application/dto/update-settings.dto';

@Controller({ path: 'settings', version: '1' })
@UseGuards(JwtAuthGuard, RolesGuard)
export class SettingsController {
  constructor(
    private readonly settingsService: SettingsService,
    private readonly tenantConfigService: TenantConfigService,
  ) {}

  @Get()
  @Roles('DIRECTOR')
  async get(
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: TenantSettingsView }> {
    const data = await this.settingsService.get(request.user.tenant_id);
    return { success: true, data };
  }

  @Patch()
  @Roles('DIRECTOR')
  async update(
    @Body() dto: UpdateSettingsDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: TenantSettingsView }> {
    const data = await this.settingsService.update(
      request.user.tenant_id,
      request.user.sub,
      dto,
    );
    await this.tenantConfigService.invalidate(request.user.tenant_id);
    return { success: true, data };
  }
}
