import { Module } from '@nestjs/common';
import { IamModule } from '../iam/iam.module';
import { FcmModule } from '../../infrastructure/fcm/fcm.module';
import { NotificationsService } from './application/notifications.service';
import { NotificationTemplatesService } from './application/notification-templates.service';
import { NotificationPreferencesService } from './application/notification-preferences.service';
import { NotificationEventListener } from './application/notification-event.listener';
import { NotificationsController } from './presentation/notifications.controller';

@Module({
  imports: [IamModule, FcmModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationTemplatesService,
    NotificationPreferencesService,
    NotificationEventListener,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
