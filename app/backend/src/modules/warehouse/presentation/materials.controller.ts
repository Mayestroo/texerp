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
import { CreateMaterialDto } from '../application/dto/create-material.dto';
import { ListMaterialsQueryDto } from '../application/dto/list-materials-query.dto';
import { ListMovementsQueryDto } from '../application/dto/list-movements-query.dto';
import { RecordCorrectionDto } from '../application/dto/record-correction.dto';
import { RecordIssuanceDto } from '../application/dto/record-issuance.dto';
import { RecordReceiptDto } from '../application/dto/record-receipt.dto';
import { UpdateMaterialDto } from '../application/dto/update-material.dto';
import {
  MaterialView,
  MaterialsService,
} from '../application/materials.service';
import {
  StockMovementView,
  StockMovementsService,
} from '../application/stock-movements.service';
import { WarehouseExceptionFilter } from './warehouse-exception.filter';

@Controller({ path: 'warehouse/materials', version: '1' })
@UseFilters(WarehouseExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class MaterialsController {
  constructor(
    private readonly materialsService: MaterialsService,
    private readonly stockMovementsService: StockMovementsService,
  ) {}

  @Get()
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async list(
    @Query() query: ListMaterialsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView[]; total: number }> {
    const result = await this.materialsService.list(
      request.user.tenant_id,
      query,
    );
    return { success: true, ...result };
  }

  @Post()
  @HttpCode(201)
  @Roles('DIRECTOR')
  async create(
    @Body() dto: CreateMaterialDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView }> {
    const data = await this.materialsService.create(
      request.user.tenant_id,
      request.user.sub,
      dto,
    );
    return { success: true, data };
  }

  @Get(':id')
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async get(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView }> {
    const data = await this.materialsService.get(request.user.tenant_id, id);
    return { success: true, data };
  }

  @Patch(':id')
  @Roles('DIRECTOR')
  async update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateMaterialDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView }> {
    const data = await this.materialsService.update(
      request.user.tenant_id,
      id,
      dto,
    );
    return { success: true, data };
  }

  @Post(':id/deactivate')
  @HttpCode(200)
  @Roles('DIRECTOR')
  async deactivate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView }> {
    const data = await this.materialsService.deactivate(
      request.user.tenant_id,
      id,
    );
    return { success: true, data };
  }

  @Post(':id/activate')
  @HttpCode(200)
  @Roles('DIRECTOR')
  async activate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: MaterialView }> {
    const data = await this.materialsService.activate(
      request.user.tenant_id,
      id,
    );
    return { success: true, data };
  }

  @Post(':id/receipts')
  @HttpCode(201)
  @Roles('DIRECTOR')
  async recordReceipt(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: RecordReceiptDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: StockMovementView }> {
    const data = await this.stockMovementsService.recordReceipt(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
    );
    return { success: true, data };
  }

  @Post(':id/issuances')
  @HttpCode(201)
  @Roles('DIRECTOR')
  async recordIssuance(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: RecordIssuanceDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: StockMovementView }> {
    const data = await this.stockMovementsService.recordIssuance(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
    );
    return { success: true, data };
  }

  @Post(':id/corrections')
  @HttpCode(201)
  @Roles('DIRECTOR')
  async recordCorrection(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: RecordCorrectionDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: StockMovementView }> {
    const data = await this.stockMovementsService.recordCorrection(
      request.user.tenant_id,
      request.user.sub,
      id,
      dto,
    );
    return { success: true, data };
  }

  @Get(':id/movements')
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async listMovements(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: ListMovementsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: StockMovementView[]; total: number }> {
    const result = await this.stockMovementsService.listMovements(
      request.user.tenant_id,
      id,
      query,
    );
    return { success: true, ...result };
  }

  @Get(':id/balance')
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async getBalance(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { material_id: string; balance: number } }> {
    const data = await this.materialsService.getBalance(
      request.user.tenant_id,
      id,
    );
    return { success: true, data };
  }
}
