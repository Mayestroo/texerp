import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
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
import { CreateAdjustmentDto } from '../application/dto/create-adjustment.dto';
import { CreateAdvanceDto } from '../application/dto/create-advance.dto';
import { CreatePayrollPeriodDto } from '../application/dto/create-payroll-period.dto';
import { EmptyBodyDto } from '../application/dto/empty-body.dto';
import { FinalizePeriodDto } from '../application/dto/finalize-period.dto';
import { ListPayrollPeriodsQueryDto } from '../application/dto/list-payroll-periods-query.dto';
import {
  PayrollPeriodsService,
  PayrollPeriodView,
  PeriodDetailView,
  WorkerCalculationDetailView,
} from '../application/payroll-periods.service';
import { PayrollExceptionFilter } from './payroll-exception.filter';

@Controller({ path: 'payroll', version: '1' })
@UseFilters(PayrollExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class PayrollController {
  constructor(
    private readonly payrollPeriodsService: PayrollPeriodsService,
  ) {}

  @Get('periods')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async listPeriods(
    @Query() query: ListPayrollPeriodsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: PayrollPeriodView[]; total: number }> {
    const result = await this.payrollPeriodsService.list(
      request.user.tenant_id,
      query,
    );
    return { success: true, ...result };
  }

  @Post('periods')
  @HttpCode(201)
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async createPeriod(
    @Body() dto: CreatePayrollPeriodDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: PayrollPeriodView & { pending_entries_count: number } }> {
    const data = await this.payrollPeriodsService.create(
      request.user.tenant_id,
      request.user.sub,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Get('periods/:id')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async getPeriod(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: PeriodDetailView }> {
    const data = await this.payrollPeriodsService.getById(
      request.user.tenant_id,
      id,
    );
    return { success: true, data };
  }

  @Post('periods/:id/calculate')
  @HttpCode(200)
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async calculatePeriod(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { job_id: string; message: string; poll_url: string } }> {
    const data = await this.payrollPeriodsService.enqueueCalculation(
      request.user.tenant_id,
      id,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Get('periods/:id/status')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async getCalculationStatus(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: {
      status: string;
      progress?: { processed: number; total: number; current_worker: string };
    };
  }> {
    const data = await this.payrollPeriodsService.getCalculationStatus(
      request.user.tenant_id,
      id,
    );
    return { success: true, data };
  }

  @Post('periods/:id/export')
  @HttpCode(200)
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async exportPeriod(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { export_id: string; message: string; estimated_seconds: number } }> {
    const data = await this.payrollPeriodsService.enqueueExport(
      request.user.tenant_id,
      id,
      request.user,
    );
    return { success: true, data };
  }

  @Get('periods/:id/export/:exportId')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async getExportStatus(
    @Param('id', new ParseUUIDPipe()) _id: string,
    @Param('exportId', new ParseUUIDPipe()) exportId: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: {
      status: string;
      download_url?: string;
      expires_at?: Date;
      file_size_bytes?: number;
    };
  }> {
    const data = await this.payrollPeriodsService.getExportStatus(
      request.user.tenant_id,
      exportId,
    );
    return { success: true, data };
  }

  @Get('periods/:id/calculations/:workerId')
  @Roles('ACCOUNTANT', 'DIRECTOR', 'WORKER')
  async getWorkerCalculation(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Param('workerId', new ParseUUIDPipe()) workerId: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: WorkerCalculationDetailView }> {
    const data = await this.payrollPeriodsService.getWorkerCalculation(
      request.user.tenant_id,
      id,
      workerId,
      request.user,
    );
    return { success: true, data };
  }

  @Post('periods/:id/adjustments')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async addAdjustment(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CreateAdjustmentDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { id: string } }> {
    const data = await this.payrollPeriodsService.addAdjustment(
      request.user.tenant_id,
      id,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Delete('periods/:id/adjustments/:adjustmentId')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async removeAdjustment(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Param('adjustmentId', new ParseUUIDPipe()) adjustmentId: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: null }> {
    await this.payrollPeriodsService.removeAdjustment(
      request.user.tenant_id,
      id,
      adjustmentId,
      request.user,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data: null };
  }

  @Post('periods/:id/advances')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async addAdvance(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: CreateAdvanceDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { id: string } }> {
    const data = await this.payrollPeriodsService.addAdvance(
      request.user.tenant_id,
      id,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Post('periods/:id/finalize')
  @Roles('ACCOUNTANT', 'DIRECTOR')
  async finalizePeriod(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: FinalizePeriodDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: { period_id: string; workers_notified: number; total_final_pay: number };
  }> {
    const data = await this.payrollPeriodsService.finalize(
      request.user.tenant_id,
      id,
      request.user,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Get('me')
  @Roles('WORKER')
  async getMyPayroll(
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: PayrollPeriodView[] }> {
    const data = await this.payrollPeriodsService.getMyPayroll(
      request.user.tenant_id,
      request.user.sub,
    );
    return { success: true, data };
  }
}
