import { Controller, Get, UseFilters, UseGuards } from '@nestjs/common';
import { PlatformJwtAuthGuard } from './platform-jwt.guard';
import { PlatformExceptionFilter } from './platform-exception.filter';
import { PlatformHealthService } from '../application/platform-health.service';

@Controller({ path: 'platform/health', version: '1' })
@UseGuards(PlatformJwtAuthGuard)
@UseFilters(PlatformExceptionFilter)
export class PlatformHealthController {
  constructor(private readonly platformHealthService: PlatformHealthService) {}

  @Get()
  async check(): Promise<{ success: true; data: Awaited<ReturnType<PlatformHealthService['check']>> }> {
    const data = await this.platformHealthService.check();
    return { success: true, data };
  }
}
