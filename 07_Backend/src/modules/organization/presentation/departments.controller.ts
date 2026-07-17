import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  AuthenticatedRequest,
  JwtAuthGuard,
} from '../../iam/presentation/jwt-auth.guard';
import { Roles } from '../../iam/presentation/roles.decorator';
import { RolesGuard } from '../../iam/presentation/roles.guard';
import { CreateDepartmentDto } from '../application/dto/create-department.dto';
import { ListDepartmentsQueryDto } from '../application/dto/list-departments-query.dto';
import { UpdateDepartmentDto } from '../application/dto/update-department.dto';
import { DepartmentsService } from '../application/departments.service';
import { OrganizationExceptionFilter } from './organization-exception.filter';

@Controller({ path: 'departments', version: '1' })
@UseFilters(OrganizationExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class DepartmentsController {
  constructor(private readonly departmentsService: DepartmentsService) {}

  @Get()
  @Roles('DIRECTOR', 'ACCOUNTANT', 'FOREMAN', 'WORKER')
  async list(
    @Query() query: ListDepartmentsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<DepartmentsService['list']>>;
  }> {
    const data = await this.departmentsService.list(
      request.user.tenant_id,
      query,
    );
    return { success: true, data };
  }

  @Post()
  @HttpCode(201)
  @Roles('DIRECTOR')
  async create(
    @Body() dto: CreateDepartmentDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<DepartmentsService['create']>>;
  }> {
    const data = await this.departmentsService.create(
      request.user.tenant_id,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Patch(':id')
  @Roles('DIRECTOR')
  async update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateDepartmentDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<DepartmentsService['update']>>;
  }> {
    const data = await this.departmentsService.update(
      request.user.tenant_id,
      request.user,
      id,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }
}
