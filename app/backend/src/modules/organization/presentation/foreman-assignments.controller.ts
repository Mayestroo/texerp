import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Put,
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
import { SetForemanAssignmentDto } from '../application/dto/set-foreman-assignment.dto';
import { ForemanAssignmentsService } from '../application/foreman-assignments.service';
import { OrganizationExceptionFilter } from './organization-exception.filter';

@Controller({ path: 'users', version: '1' })
@UseFilters(OrganizationExceptionFilter)
@UseGuards(JwtAuthGuard, RolesGuard)
export class ForemanAssignmentsController {
  constructor(private readonly assignmentsService: ForemanAssignmentsService) {}

  @Get('me/workers')
  @Roles('FOREMAN')
  async listMyWorkers(@Req() request: AuthenticatedRequest): Promise<{
    success: true;
    data: Awaited<ReturnType<ForemanAssignmentsService['listMyWorkers']>>;
  }> {
    const data = await this.assignmentsService.listMyWorkers(
      request.user.tenant_id,
      request.user.sub,
    );
    return { success: true, data };
  }

  @Put(':workerId/foreman-assignment')
  @Roles('DIRECTOR')
  async setAssignment(
    @Param('workerId', new ParseUUIDPipe()) workerId: string,
    @Body() dto: SetForemanAssignmentDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<ForemanAssignmentsService['setAssignment']>>;
  }> {
    const data = await this.assignmentsService.setAssignment(
      request.user.tenant_id,
      request.user,
      workerId,
      dto,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }

  @Delete(':workerId/foreman-assignment')
  @Roles('DIRECTOR')
  async unassign(
    @Param('workerId', new ParseUUIDPipe()) workerId: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<ForemanAssignmentsService['unassign']>>;
  }> {
    const data = await this.assignmentsService.unassign(
      request.user.tenant_id,
      request.user,
      workerId,
      { ipAddress: request.ip, userAgent: request.get('user-agent') },
    );
    return { success: true, data };
  }
}
