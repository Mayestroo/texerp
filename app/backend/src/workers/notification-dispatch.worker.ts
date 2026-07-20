import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { NotificationsService } from '../modules/notifications/application/notifications.service';

@Processor('notification-dispatch')
export class NotificationDispatchWorker extends WorkerHost {
  constructor(private readonly notificationsService: NotificationsService) {
    super();
  }

  async process(job: Job<any>): Promise<any> {
    const { tenantId, notificationId, recipientId } = job.data;
    try {
      await this.notificationsService.processNotificationJob(tenantId, notificationId, recipientId);
    } catch (error) {
      console.error(`Notification dispatch failed for job ${job.id}:`, error);
      throw error;
    }
  }
}
