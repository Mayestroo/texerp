import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Put,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { PlatformJwtAuthGuard, AuthenticatedPlatformRequest } from './platform-jwt.guard';
import { PlatformExceptionFilter } from './platform-exception.filter';
import { FeatureFlagsService } from '../application/feature-flags.service';
import { UpdateFeatureFlagsDto } from '../application/dto/update-feature-flags.dto';

@Controller({ path: 'platform/tenants', version: '1' })
@UseGuards(PlatformJwtAuthGuard)
@UseFilters(PlatformExceptionFilter)
export class PlatformFeaturesController {
  constructor(private readonly featureFlagsService: FeatureFlagsService) {}

  @Get(':id/features')
  async getFlags(
    @Param('id') id: string,
  ): Promise<{ success: true; data: Awaited<ReturnType<FeatureFlagsService['getFlags']>> }> {
    const data = await this.featureFlagsService.getFlags(id);
    return { success: true, data };
  }

  @Put(':id/features')
  @HttpCode(200)
  async updateFlags(
    @Param('id') id: string,
    @Body() dto: UpdateFeatureFlagsDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<FeatureFlagsService['updateFlags']>> }> {
    const data = await this.featureFlagsService.updateFlags(id, request.user.sub, dto);
    return { success: true, data };
  }
}
