import {
  Body,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
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
import { RolesGuard } from '../../iam/presentation/roles.guard';
import { Roles } from '../../iam/presentation/roles.decorator';
import { ProductionReportsService } from '../application/production-reports.service';
import { ReportExportsService } from '../application/report-exports.service';
import { ProductionReportQueryDto } from '../application/dto/production-report-query.dto';
import { ReportsExceptionFilter } from './reports-exception.filter';

@Controller({ path: 'reports', version: '1' })
@UseFilters(ReportsExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportsController {
  constructor(
    private readonly productionReportsService: ProductionReportsService,
    private readonly reportExportsService: ReportExportsService,
  ) {}

  @Get('production')
  @Roles('DIRECTOR', 'ACCOUNTANT', 'FOREMAN')
  async getProductionReport(
    @Query() query: ProductionReportQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: {
      period: { from: string; to: string };
      total_pieces: number;
      total_earnings: number;
      rows: unknown[];
    };
    pagination: {
      page: number;
      limit: number;
      total: number;
      totalPages: number;
      hasNext: boolean;
      hasPrev: boolean;
    };
  }> {
    const result = await this.productionReportsService.generateReport(
      request.user.tenant_id,
      request.user,
      query,
    );
    return {
      success: true,
      data: {
        period: result.period,
        total_pieces: result.total_pieces,
        total_earnings: result.total_earnings,
        rows: result.rows,
      },
      pagination: {
        page: result.pagination.page,
        limit: result.pagination.limit,
        total: result.pagination.total,
        totalPages: result.pagination.total_pages,
        hasNext: result.pagination.page < result.pagination.total_pages,
        hasPrev: result.pagination.page > 1,
      },
    };
  }

  @Post('production/export')
  @HttpCode(202)
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async exportProductionReport(
    @Body() filters: ProductionReportQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: { export_id: string; message: string; estimated_seconds: number };
  }> {
    const result = await this.reportExportsService.queueExport(
      request.user.tenant_id,
      request.user.sub,
      filters,
    );
    return {
      success: true,
      data: {
        export_id: result.export_id,
        message: 'Excel tayyorlanmoqda',
        estimated_seconds: 30,
      },
    };
  }

  @Get('exports/:exportId')
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async getExportStatus(
    @Param('exportId', new ParseUUIDPipe()) exportId: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: unknown }> {
    const data = await this.reportExportsService.getExportStatus(
      request.user.tenant_id,
      exportId,
    );
    if (!data) {
      throw new NotFoundException({
        success: false,
        error: { code: 'EXPORT_NOT_FOUND', message: 'Eksport topilmadi' },
      });
    }
    return { success: true, data };
  }
}
