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
import { Throttle } from '../../../infrastructure/rate-limit/rate-limit.decorator';
import { ApproveEntryDto } from '../application/dto/approve-entry.dto';
import { BulkApproveDto } from '../application/dto/bulk-approve.dto';
import { CorrectApproveEntryDto } from '../application/dto/correct-approve-entry.dto';
import { CreateOperationEntryDto } from '../application/dto/create-operation-entry.dto';
import { ListMyEntriesQueryDto } from '../application/dto/list-my-entries-query.dto';
import { RejectEntryDto } from '../application/dto/reject-entry.dto';
import {
  OperationEntryView,
  ProductionEntriesService,
} from '../application/production-entries.service';
import { ProductionExceptionFilter } from './production-exception.filter';

@Controller({ path: 'production/entries', version: '1' })
@UseFilters(ProductionExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class ProductionEntriesController {
  constructor(
    private readonly productionEntriesService: ProductionEntriesService,
  ) {}

  @Post()
  @HttpCode(201)
  @Throttle({ limit: 100, windowSec: 60, key: 'user' })
  @Roles('WORKER')
  async create(
    @Body() dto: CreateOperationEntryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView }> {
    const data = await this.productionEntriesService.create(
      request.user.tenant_id,
      request.user.sub,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Get('me')
  @Roles('WORKER')
  async listMyEntries(
    @Query() query: ListMyEntriesQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView[]; total: number }> {
    const result = await this.productionEntriesService.listMyEntries(
      request.user.tenant_id,
      request.user.sub,
      query,
    );
    return { success: true, ...result };
  }

  @Get()
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async listAllEntries(
    @Query() query: ListMyEntriesQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView[]; total: number }> {
    const result = await this.productionEntriesService.listAllEntries(
      request.user.tenant_id,
      query,
    );
    return { success: true, ...result };
  }

  @Get('summary')
  @Roles('DIRECTOR')
  async getSummary(
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: {
      todayEntriesCount: number;
      todayTotalQuantity: number;
      pendingEntriesCount: number;
      approvedEntriesCount: number;
      rejectedEntriesCount: number;
    };
  }> {
    const data =
      await this.productionEntriesService.getSummary(request.user.tenant_id);
    return { success: true, data };
  }

  @Get('foreman/history')
  @Roles('FOREMAN')
  async listForemanHistory(
    @Query() query: ListMyEntriesQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView[]; total: number }> {
    const result = await this.productionEntriesService.listForemanHistory(
      request.user.tenant_id,
      request.user.sub,
      query,
    );
    return { success: true, ...result };
  }

  @Get('foreman/pending')
  @Roles('FOREMAN')
  async listPendingForForeman(
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView[] }> {
    const data = await this.productionEntriesService.listPendingForForeman(
      request.user.tenant_id,
      request.user.sub,
    );
    return { success: true, data };
  }

  @Post(':id/approve')
  @HttpCode(200)
  @Roles('FOREMAN')
  async approveEntry(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ApproveEntryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView }> {
    const data = await this.productionEntriesService.approveEntry(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Post(':id/reject')
  @HttpCode(200)
  @Roles('FOREMAN')
  async rejectEntry(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: RejectEntryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView }> {
    const data = await this.productionEntriesService.rejectEntry(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Patch(':id/correct-approve')
  @Roles('FOREMAN')
  async correctAndApproveEntry(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CorrectApproveEntryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: OperationEntryView }> {
    const data = await this.productionEntriesService.correctAndApproveEntry(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Post('bulk-approve')
  @HttpCode(200)
  @Roles('FOREMAN')
  async bulkApproveEntries(
    @Body() dto: BulkApproveDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { approved_count: number } }> {
    return this.productionEntriesService.bulkApproveEntries(
      request.user.tenant_id,
      request.user.sub,
      dto,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
  }
}
