import {
  Body,
  Controller,
  Get,
  HttpCode,
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
import { ListOperationsQueryDto } from '../application/dto/list-operations-query.dto';
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
}
