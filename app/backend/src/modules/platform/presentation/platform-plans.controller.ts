import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { PlatformJwtAuthGuard, AuthenticatedPlatformRequest } from './platform-jwt.guard';
import { PlatformExceptionFilter } from './platform-exception.filter';
import { PlansService } from '../application/plans.service';
import { CreatePlanDto } from '../application/dto/create-plan.dto';
import { UpdatePlanDto } from '../application/dto/update-plan.dto';

@Controller({ path: 'platform/plans', version: '1' })
@UseGuards(PlatformJwtAuthGuard)
@UseFilters(PlatformExceptionFilter)
export class PlatformPlansController {
  constructor(private readonly plansService: PlansService) {}

  @Get()
  async list(): Promise<{ success: true; data: Awaited<ReturnType<PlansService['list']>> }> {
    const data = await this.plansService.list();
    return { success: true, data };
  }

  @Post()
  @HttpCode(201)
  async create(
    @Body() dto: CreatePlanDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<PlansService['create']>> }> {
    const data = await this.plansService.create(dto, request.user.sub);
    return { success: true, data };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: UpdatePlanDto,
    @Req() request: AuthenticatedPlatformRequest,
  ): Promise<{ success: true; data: Awaited<ReturnType<PlansService['update']>> }> {
    const data = await this.plansService.update(id, dto, request.user.sub);
    return { success: true, data };
  }
}
