import {
  Body,
  Controller,
  HttpCode,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from '../application/auth.service';
import { LoginDto } from '../application/dto/login.dto';
import { RefreshDto } from '../application/dto/refresh.dto';
import { ChangePinDto } from '../application/dto/change-pin.dto';
import { VerifyPinDto } from '../application/dto/verify-pin.dto';
import { AuthenticatedRequest, JwtAuthGuard } from './jwt-auth.guard';

@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
  async login(
    @Body() dto: LoginDto,
    @Req() request: Request,
  ): Promise<{ success: true; data: Awaited<ReturnType<AuthService['login']>> }> {
    const data = await this.authService.login(dto, {
      ipAddress: request.ip,
      userAgent: request.get('user-agent'),
    });
    return { success: true, data };
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(
    @Body() dto: RefreshDto,
    @Req() request: Request,
  ): Promise<{ success: true; data: Awaited<ReturnType<AuthService['refresh']>> }> {
    const data = await this.authService.refresh(dto, {
      ipAddress: request.ip,
      userAgent: request.get('user-agent'),
    });
    return { success: true, data };
  }

  @Post('logout')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async logout(
    @Body() dto: RefreshDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { message: string } }> {
    await this.authService.logout(dto, request.user, {
      ipAddress: request.ip,
      userAgent: request.get('user-agent'),
    });
    return { success: true, data: { message: 'Tizimdan chiqildi' } };
  }

  @Post('change-pin')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async changePin(
    @Body() dto: ChangePinDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { message: string } }> {
    await this.authService.changePin(
      request.user.sub,
      request.user.tenant_id,
      dto,
      {
        ipAddress: request.ip,
        userAgent: request.get('user-agent'),
      },
    );
    return { success: true, data: { message: "PIN muvaffaqiyatli o'zgartirildi" } };
  }

  @Post('verify-pin')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async verifyPin(
    @Body() dto: VerifyPinDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { message: string } }> {
    await this.authService.verifyPin(
      request.user.sub,
      request.user.tenant_id,
      dto,
    );
    return { success: true, data: { message: 'PIN toʻgʻri' } };
  }
}
