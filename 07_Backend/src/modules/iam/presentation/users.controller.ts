import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { CreateUserDto } from '../application/dto/create-user.dto';
import { EmptyBodyDto } from '../application/dto/empty-body.dto';
import { ListUsersQueryDto } from '../application/dto/list-users-query.dto';
import { UpdateUserDto } from '../application/dto/update-user.dto';
import { UsersService } from '../application/users.service';
import { AuthenticatedRequest, JwtAuthGuard } from './jwt-auth.guard';
import { Roles } from './roles.decorator';
import { RolesGuard } from './roles.guard';
import { UserExceptionFilter } from './user-exception.filter';

@Controller({ path: 'users', version: '1' })
@UseFilters(UserExceptionFilter)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR', 'ACCOUNTANT')
  async list(
    @Query() query: ListUsersQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<Awaited<ReturnType<UsersService['list']>> & { success: true }> {
    const result = await this.usersService.list(request.user.tenant_id, query);
    return { success: true, ...result };
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR', 'ACCOUNTANT', 'FOREMAN')
  async getById(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<UsersService['getById']>>;
  }> {
    const data = await this.usersService.getById(
      request.user.tenant_id,
      request.user,
      id,
    );
    return { success: true, data };
  }

  @Post()
  @HttpCode(201)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR')
  async create(
    @Body() dto: CreateUserDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<UsersService['create']>>;
  }> {
    const data = await this.usersService.create(
      request.user.tenant_id,
      request.user,
      dto,
      {
        ipAddress: request.ip,
        userAgent: request.get('user-agent'),
      },
    );
    return { success: true, data };
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR')
  async update(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateUserDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<UsersService['update']>>;
  }> {
    const data = await this.usersService.update(
      request.user.tenant_id,
      request.user,
      id,
      dto,
      {
        ipAddress: request.ip,
        userAgent: request.get('user-agent'),
      },
    );
    return { success: true, data };
  }

  @Post(':id/deactivate')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR')
  async deactivate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<UsersService['deactivate']>>;
  }> {
    const data = await this.usersService.deactivate(
      request.user.tenant_id,
      request.user,
      id,
      {
        ipAddress: request.ip,
        userAgent: request.get('user-agent'),
      },
    );
    return { success: true, data };
  }

  @Post(':id/reactivate')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DIRECTOR')
  async reactivate(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() _dto: EmptyBodyDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{
    success: true;
    data: Awaited<ReturnType<UsersService['reactivate']>>;
  }> {
    const data = await this.usersService.reactivate(
      request.user.tenant_id,
      request.user,
      id,
      {
        ipAddress: request.ip,
        userAgent: request.get('user-agent'),
      },
    );
    return { success: true, data };
  }
}
