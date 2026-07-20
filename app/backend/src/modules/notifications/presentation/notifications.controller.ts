import {
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedRequest, JwtAuthGuard } from '../../iam/presentation/jwt-auth.guard';
import { ListNotificationsQueryDto } from '../application/dto/list-notifications-query.dto';
import { MarkReadDto } from '../application/dto/mark-read.dto';
import { UpdatePreferencesDto } from '../application/dto/update-preferences.dto';
import { NotificationPreferenceView, NotificationPreferencesService } from '../application/notification-preferences.service';
import { NotificationsService } from '../application/notifications.service';

@Controller({ path: 'notifications', version: '1' })
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly preferencesService: NotificationPreferencesService,
  ) {}

  @Get()
  async list(
    @Query() query: ListNotificationsQueryDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: any[]; unread_count: number; pagination: any }> {
    const result = await this.notificationsService.list(
      request.user.tenant_id,
      request.user.sub,
      query,
    );
    return { success: true, ...result };
  }

  @Post('mark-read')
  @HttpCode(200)
  async markRead(
    @Body() dto: MarkReadDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: { marked_count: number } }> {
    const data = await this.notificationsService.markRead(
      request.user.tenant_id,
      request.user.sub,
      dto.notification_ids,
      dto.mark_all,
    );
    return { success: true, data };
  }

  @Get('preferences')
  async getPreferences(
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: NotificationPreferenceView[] }> {
    const data = await this.preferencesService.getPreferences(
      request.user.tenant_id,
      request.user.sub,
    );
    return { success: true, data };
  }

  @Patch('preferences')
  async updatePreferences(
    @Body() dto: UpdatePreferencesDto,
    @Req() request: AuthenticatedRequest,
  ): Promise<{ success: true; data: NotificationPreferenceView[] }> {
    const data = await this.preferencesService.updatePreferences(
      request.user.tenant_id,
      request.user.sub,
      dto.preferences,
    );
    return { success: true, data };
  }
}
