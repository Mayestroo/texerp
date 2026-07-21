import {
  Body,
  Controller,
  HttpCode,
  Param,
  Post,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { PlatformJwtAuthGuard, AuthenticatedPlatformRequest } from './platform-jwt.guard';
import { PlatformExceptionFilter } from './platform-exception.filter';
import { ImpersonationService } from '../application/impersonation.service';
import { ImpersonateDto } from '../application/dto/impersonate.dto';
import { EndImpersonationDto } from '../application/dto/end-impersonation.dto';

@Controller({ path: 'platform/tenants', version: '1' })
@UseGuards(PlatformJwtAuthGuard)
@UseFilters(PlatformExceptionFilter)
export class PlatformImpersonationController {
  constructor(private readonly impersonationService: ImpersonationService) {}

  @Post(':id/impersonate')
  @HttpCode(200)
  async impersonate(
    @Param('id') id: string,
    @Body() dto: ImpersonateDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<ImpersonationService['startImpersonation']>> }> {
    const data = await this.impersonationService.startImpersonation(
      id,
      dto.user_id,
      request.user.sub,
    );
    return { success: true, data };
  }

  @Post(':id/impersonate/end')
  @HttpCode(200)
  async endImpersonation(
    @Param('id') id: string,
    @Body() dto: EndImpersonationDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true }> {
    await this.impersonationService.endImpersonation(
      dto.jti,
      request.user.sub,
    );
    return { success: true };
  }
}
