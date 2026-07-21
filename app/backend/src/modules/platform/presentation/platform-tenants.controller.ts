import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { PlatformJwtAuthGuard, AuthenticatedPlatformRequest } from './platform-jwt.guard';
import { PlatformExceptionFilter } from './platform-exception.filter';
import { TenantsService } from '../application/tenants.service';
import { CreateTenantDto } from '../application/dto/create-tenant.dto';
import { UpdateTenantDto } from '../application/dto/update-tenant.dto';
import { ListTenantsQueryDto } from '../application/dto/list-tenants-query.dto';
import { SuspendTenantDto } from '../application/dto/suspend-tenant.dto';

@Controller({ path: 'platform/tenants', version: '1' })
@UseGuards(PlatformJwtAuthGuard)
@UseFilters(PlatformExceptionFilter)
export class PlatformTenantsController {
  constructor(private readonly tenantsService: TenantsService) {}

  @Get()
  async list(
    @Query() query: ListTenantsQueryDto,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['list']>> }> {
    const data = await this.tenantsService.list(query);
    return { success: true, data };
  }

  @Post()
  @HttpCode(201)
  async create(
    @Body() dto: CreateTenantDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['create']>> }> {
    const data = await this.tenantsService.create(request.user.sub, dto);
    return { success: true, data };
  }

  @Get(':id')
  async get(
    @Param('id') id: string,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['get']>> }> {
    const data = await this.tenantsService.get(id);
    return { success: true, data };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateTenantDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['update']>> }> {
    const data = await this.tenantsService.update(id, dto, request.user.sub);
    return { success: true, data };
  }

  @Post(':id/suspend')
  @HttpCode(200)
  async suspend(
    @Param('id') id: string,
    @Body() dto: SuspendTenantDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['suspend']>> }> {
    const data = await this.tenantsService.suspend(id, dto.reason, request.user.sub);
    return { success: true, data };
  }

  @Post(':id/reactivate')
  @HttpCode(200)
  async reactivate(
    @Param('id') id: string,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['reactivate']>> }> {
    const data = await this.tenantsService.reactivate(id, request.user.sub);
    return { success: true, data };
  }

  @Post(':id/terminate')
  @HttpCode(200)
  async terminate(
    @Param('id') id: string,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<TenantsService['terminate']>> }> {
    const data = await this.tenantsService.terminate(id, request.user.sub);
    return { success: true, data };
  }
}
