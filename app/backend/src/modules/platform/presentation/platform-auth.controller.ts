import {
  Body,
  Controller,
  HttpCode,
  Post,
  UseFilters,
} from '@nestjs/common';
import { PlatformAuthService } from '../application/platform-auth.service';
import { PlatformLoginDto } from '../application/dto/platform-login.dto';
import { PlatformExceptionFilter } from './platform-exception.filter';

@Controller({ path: 'platform/auth', version: '1' })
@UseFilters(PlatformExceptionFilter)
export class PlatformAuthController {
  constructor(private readonly platformAuthService: PlatformAuthService) {}

  @Post('login')
  @HttpCode(200)
  async login(
    @Body() dto: PlatformLoginDto,
  ): Promise<{ success: true; data: Awaited<ReturnType<PlatformAuthService['login']>> }> {
    const data = await this.platformAuthService.login(dto);
    return { success: true, data };
  }
}
