import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { TenantDatabase } from '../../../infrastructure/database/tenant-database';
import { FcmService } from '../../../infrastructure/fcm/fcm.service';
import { uuidv7 } from '../../../shared/common/uuid';
import { ListNotificationsQueryDto } from './dto/list-notifications-query.dto';
import { FcmPermanentError } from '../../../infrastructure/fcm/fcm-permanent.error';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly tenantDatabase: TenantDatabase,
    private readonly fcmService: FcmService,
    @InjectQueue('notification-dispatch') private readonly notificationQueue: Queue,
  ) {}

  async createNotification(
    tenantId: string,
    recipientId: string,
    type: string,
    titleUz: string,
    titleRu: string,
    bodyUz: string,
    bodyRu: string,
    data: any = null,
    channel: 'PUSH' | 'IN_APP' | 'BOTH' = 'BOTH',
  ): Promise<string> {
    const notificationId = uuidv7();

    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      await manager.query(
        `INSERT INTO notifications
          (id, tenant_id, recipient_id, type, title_uz, title_ru, body_uz, body_ru, data, channel, push_status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10, $11)`,
        [
          notificationId,
          tenantId,
          recipientId,
          type,
          titleUz,
          titleRu,
          bodyUz,
          bodyRu,
          data ? JSON.stringify(data) : null,
          channel,
          channel === 'IN_APP' ? 'SENT' : 'PENDING',
        ],
      );
    });

    if (channel === 'BOTH' || channel === 'PUSH') {
      await this.notificationQueue.add(
        'dispatch-push',
        { tenantId, notificationId, recipientId },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 1000 },
        },
      );
    }

    return notificationId;
  }

  async list(
    tenantId: string,
    recipientId: string,
    query: ListNotificationsQueryDto,
  ) {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const conditions = ['tenant_id = $1', 'recipient_id = $2'];
      const parameters: any[] = [tenantId, recipientId];

      if (query.status === 'UNREAD') {
        conditions.push('is_read = false');
      }

      const where = conditions.join(' AND ');

      // Total count
      const countResult = await manager.query<{ total: string }[]>(
        `SELECT COUNT(*)::text AS total FROM notifications WHERE ${where}`,
        parameters,
      );
      const total = parseInt(countResult[0]?.total ?? '0', 10);

      // Unread count (always needed)
      const unreadResult = await manager.query<{ total: string }[]>(
        `SELECT COUNT(*)::text AS total FROM notifications WHERE tenant_id = $1 AND recipient_id = $2 AND is_read = false`,
        [tenantId, recipientId],
      );
      const unread_count = parseInt(unreadResult[0]?.total ?? '0', 10);

      // Data list
      const offset = (query.page - 1) * query.limit;
      const listParams = [...parameters, query.limit, offset];
      const limitParamIndex = listParams.length - 1;
      const offsetParamIndex = listParams.length;

      const rows = await manager.query<any[]>(
        `SELECT
           id,
           type,
           title_uz,
           title_ru,
           body_uz,
           body_ru,
           data,
           is_read,
           created_at,
           read_at
         FROM notifications
         WHERE ${where}
         ORDER BY created_at DESC
         LIMIT $${limitParamIndex} OFFSET $${offsetParamIndex}`,
        listParams,
      );

      // Map rows to clean contract format
      const mappedRows = rows.map((row) => ({
        id: row.id,
        type: row.type,
        title: row.title_uz, // Default to Uz title for API list
        title_uz: row.title_uz,
        title_ru: row.title_ru,
        body: row.body_uz,   // Default to Uz body
        body_uz: row.body_uz,
        body_ru: row.body_ru,
        data: row.data,
        is_read: row.is_read,
        created_at: row.created_at,
        read_at: row.read_at,
      }));

      const totalPages = Math.ceil(total / query.limit);

      return {
        data: mappedRows,
        unread_count,
        pagination: {
          page: query.page,
          limit: query.limit,
          total,
          total_pages: totalPages,
        },
      };
    });
  }

  async markRead(
    tenantId: string,
    recipientId: string,
    notificationIds?: string[],
    markAll?: boolean,
  ): Promise<{ marked_count: number }> {
    return this.tenantDatabase.withTenant(tenantId, async (manager) => {
      let result;
      if (markAll) {
        result = await manager.query(
          `UPDATE notifications
           SET is_read = true, read_at = now()
           WHERE tenant_id = $1 AND recipient_id = $2 AND is_read = false`,
          [tenantId, recipientId],
        );
      } else if (notificationIds && notificationIds.length > 0) {
        // Enforce UUID array syntax safely
        result = await manager.query(
          `UPDATE notifications
           SET is_read = true, read_at = now()
           WHERE tenant_id = $1 AND recipient_id = $2 AND id = ANY($3::uuid[]) AND is_read = false`,
          [tenantId, recipientId, notificationIds],
        );
      } else {
        return { marked_count: 0 };
      }

      const marked_count = result[1] || 0;
      return { marked_count };
    });
  }

  async processNotificationJob(
    tenantId: string,
    notificationId: string,
    recipientId: string,
  ): Promise<void> {
    await this.tenantDatabase.withTenant(tenantId, async (manager) => {
      const notifications = await manager.query<any[]>(
        `SELECT id, type, title_uz, title_ru, body_uz, body_ru, data, channel, push_attempts, recipient_id
         FROM notifications
         WHERE tenant_id = $1 AND id = $2
         LIMIT 1`,
        [tenantId, notificationId],
      );

      const notification = notifications[0];
      if (!notification) return;

      const userRows = await manager.query<{ language: string }[]>(
        `SELECT language FROM users WHERE tenant_id = $1 AND id = $2 LIMIT 1`,
        [tenantId, recipientId],
      );
      const recipientLang = userRows[0]?.language === 'ru' ? 'ru' : 'uz';

      const title = recipientLang === 'ru' ? notification.title_ru : notification.title_uz;
      const body = recipientLang === 'ru' ? notification.body_ru : notification.body_uz;

      const activeTokens = await manager.query<{ id: string; fcm_token: string; platform: string }[]>(
        `SELECT id, fcm_token, platform FROM device_tokens
         WHERE tenant_id = $1 AND user_id = $2 AND is_active = true`,
        [tenantId, recipientId],
      );

      await manager.query(
        `UPDATE notifications
         SET push_attempts = push_attempts + 1
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, notificationId],
      );

      if (activeTokens.length === 0) {
        await manager.query(
          `UPDATE notifications
           SET push_status = 'SENT', push_sent_at = now()
           WHERE tenant_id = $1 AND id = $2`,
          [tenantId, notificationId],
        );
        return;
      }

      let sentCount = 0;
      for (const tokenRow of activeTokens) {
        try {
          const payloadData: Record<string, string> = {
            type: notification.type,
            ...(notification.data || {}),
          };
          
          // Stringify any non-string values for FCM compatibility
          for (const key of Object.keys(payloadData)) {
            if (typeof payloadData[key] !== 'string') {
              payloadData[key] = JSON.stringify(payloadData[key]);
            }
          }

          await this.fcmService.sendPush(tokenRow.fcm_token, {
            title,
            body,
            data: payloadData,
          });
          sentCount++;
        } catch (error) {
          if (error instanceof FcmPermanentError) {
            // Deactivate invalid device token immediately in DB
            await manager.query(
              `UPDATE device_tokens
               SET is_active = false, last_used_at = now()
               WHERE tenant_id = $1 AND id = $2`,
              [tenantId, tokenRow.id],
            );
          } else {
            // Re-throw transient issues so BullMQ job retries
            throw error;
          }
        }
      }

      // If at least one active token was targeted, set status to SENT
      await manager.query(
        `UPDATE notifications
         SET push_status = $3, push_sent_at = now()
         WHERE tenant_id = $1 AND id = $2`,
        [tenantId, notificationId, sentCount > 0 ? 'SENT' : 'FAILED'],
      );
    });
  }
}
