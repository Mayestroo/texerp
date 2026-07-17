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
import { CreateOperationDto } from '../application/dto/create-operation.dto';
import { EmptyBodyDto } from '../application/dto/empty-body.dto';
import { ListOperationsQueryDto } from '../application/dto/list-operations-query.dto';
import { UpdateOperationDto } from '../application/dto/update-operation.dto';
import { OperationsService } from '../application/operations.service';
import { OperationsExceptionFilter } from './operations-exception.filter';

@Controller({ path: 'operations', version: '1' })
@UseFilters(OperationsExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class OperationsController {
  constructor(private readonly operationsService: OperationsService) {}

  @Get()
  @Roles('DIRECTOR', 'ACCOUNTANT', 'FOREMAN', 'WORKER')
  async list(
    @Query() query: ListOperationsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<OperationsService['list']>>;
  }> {
    const data = await this.operationsService.list(
      request.user.tenant_id,
      request.user,
      query,
    );
    return { success: true, data };
  }

  @Post()
  @HttpCode(201)
  @Roles('DIRECTOR')
  async create(
    @Body() dto: CreateOperationDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<OperationsService['create']>>;
  }> {
    const data = await this.operationsService.create(
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
    @Body() dto: UpdateOperationDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<OperationsService['update']>>;
  }> {
    const data = await this.operationsService.update(
      request.user.tenant_id,
      request.user,
      id,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Post(':id/deactivate')
  @HttpCode(200)
  @Roles('DIRECTOR')
  async deactivate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true }> {
    await this.operationsService.setActive(
      request.user.tenant_id,
      request.user,
      id,
      false,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true };
  }

  @Post(':id/activate')
  @HttpCode(200)
  @Roles('DIRECTOR')
  async activate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true }> {
    await this.operationsService.setActive(
      request.user.tenant_id,
      request.user,
      id,
      true,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true };
  }
}
