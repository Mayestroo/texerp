import {
  Body,
  Controller,
  HttpCode,
  Post,
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
import { CreateOperationEntryDto } from '../application/dto/create-operation-entry.dto';
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
}
