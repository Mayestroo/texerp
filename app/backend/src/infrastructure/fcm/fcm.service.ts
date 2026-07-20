import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { FcmPermanentError } from './fcm-permanent.error';

@Injectable()
export class FcmService implements OnModuleInit {
  private fcmApp: App | null = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const projectId = this.config.get<string>('FCM_PROJECT_ID');
    const clientEmail = this.config.get<string>('FCM_CLIENT_EMAIL');
    const privateKeyBase64 = this.config.get<string>('FCM_PRIVATE_KEY_BASE64');

    if (!projectId || !clientEmail || !privateKeyBase64) {
      console.warn('FCM credentials missing. Push notifications will be stubbed.');
      return;
    }

    try {
      const privateKey = Buffer.from(privateKeyBase64, 'base64').toString('utf8');
      
      const existingApps = getApps();
      const existingApp = existingApps.find(app => app?.name === 'fcm');
      
      if (existingApp) {
        this.fcmApp = existingApp;
      } else {
        this.fcmApp = initializeApp({
          credential: cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        }, 'fcm');
      }
    } catch (error) {
      console.error('Failed to initialize FCM client. Push notifications will be stubbed:', error);
    }
  }

  async sendPush(
    token: string,
    payload: { title: string; body: string; data?: Record<string, string> },
  ): Promise<boolean> {
    if (!this.fcmApp) {
      console.log(`[FCM Mock] Sending push to ${token}:`, payload);
      return true;
    }

    try {
      await getMessaging(this.fcmApp).send({
        token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
      });
      return true;
    } catch (error: any) {
      const code = error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-argument' ||
        error.message?.includes('registration') ||
        error.message?.includes('not registered')
      ) {
        console.warn(`Permanent FCM failure for token ${token}:`, error.message);
        throw new FcmPermanentError(error.message || 'Token not registered');
      }
      throw error;
    }
  }
}
