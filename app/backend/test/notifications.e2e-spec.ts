import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';
import { Client } from 'pg';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/shared/bootstrap/configure-app';

interface LoginBody {
  data: {
    access_token: string;
  };
}

describe('Notifications & Background Jobs API (E2E)', () => {
  let app: INestApplication;
  let server: Server;
  let admin: Client;

  const tenantId = randomUUID();
  const accountantId = randomUUID();
  const workerId = randomUUID();
  const periodId = randomUUID();

  const accountantPhone = '+998901239991';
  const workerPhone = '+998901239992';

  let accountantToken: string;
  let workerToken: string;

  async function cleanDb() {
    await admin.query("DELETE FROM device_tokens WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM notifications WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM payroll_exports WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM payroll_periods WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM user_sessions WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM audit_events WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM users WHERE tenant_id IN (SELECT id FROM tenants WHERE slug LIKE 'notif-%')");
    await admin.query("DELETE FROM tenants WHERE slug LIKE 'notif-%'");
  }

  beforeAll(async () => {
    admin = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    await admin.connect();

    // Stale clean
    await cleanDb();

    // Seed test tenant, users, and a payroll period
    const pinHash = await bcrypt.hash('4826', 4);
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Notification Test Tenant', $2)`,
      [tenantId, `notif-${tenantId}`],
    );

    await admin.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $3, $4, 'Test Accountant', 'A-NOTIF-1', 'ACCOUNTANT', 'ACTIVE'),
         ($5, $2, $6, $4, 'Test Worker', 'W-NOTIF-1', 'WORKER', 'ACTIVE')`,
      [accountantId, tenantId, accountantPhone, pinHash, workerId, workerPhone],
    );

    await admin.query(
      `INSERT INTO payroll_periods (id, tenant_id, name, start_date, end_date, status, created_by)
       VALUES ($1, $2, 'August 2026', '2026-08-01', '2026-08-15', 'DRAFT', $3)`,
      [periodId, tenantId, accountantId],
    );

    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    app.useLogger(false);
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;

    // Login users to get JWT tokens
    const accLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: accountantPhone, pin: '4826' })
      .expect(200);
    accountantToken = (accLogin.body as LoginBody).data.access_token;

    const wrkLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: workerPhone, pin: '4826' })
      .expect(200);
    workerToken = (wrkLogin.body as LoginBody).data.access_token;
  });

  afterAll(async () => {
    if (app) await app.close();
    await cleanDb();
    await admin.end();
  });

  describe('FCM Token Registration', () => {
    it('allows a user to register and update their FCM token', async () => {
      await request(server)
        .put('/api/v1/users/me/fcm-token')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ fcm_token: 'test-fcm-token-123', platform: 'ANDROID' })
        .expect(200);

      // Verify DB entry
      const rows = await admin.query(
        `SELECT fcm_token, platform, is_active FROM device_tokens WHERE tenant_id = $1 AND user_id = $2`,
        [tenantId, workerId],
      );
      expect(rows.rows[0]).toMatchObject({
        fcm_token: 'test-fcm-token-123',
        platform: 'ANDROID',
        is_active: true,
      });
    });
  });

  describe('Notifications Feed', () => {
    it('returns an empty list when there are no notifications', async () => {
      const response = await request(server)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${workerToken}`)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        data: [],
        unread_count: 0,
        pagination: {
          page: 1,
          limit: 30,
          total: 0,
          total_pages: 0,
        },
      });
    });

    it('can mark notifications as read', async () => {
      const notifId = randomUUID();
      // Directly seed a notification
      await admin.query(
        `INSERT INTO notifications (id, tenant_id, recipient_id, type, title_uz, title_ru, body_uz, body_ru, channel)
         VALUES ($1, $2, $3, 'TEST_TYPE', 'Sarlavha', 'Заголовок', 'Tana', 'Тело', 'IN_APP')`,
        [notifId, tenantId, workerId],
      );

      // List feed
      const list = await request(server)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${workerToken}`)
        .expect(200);

      expect(list.body.unread_count).toBe(1);
      expect(list.body.data[0]).toMatchObject({
        id: notifId,
        is_read: false,
      });

      // Mark read
      const mark = await request(server)
        .post('/api/v1/notifications/mark-read')
        .set('Authorization', `Bearer ${workerToken}`)
        .send({ notification_ids: [notifId] })
        .expect(200);

      expect(mark.body.data).toMatchObject({ marked_count: 1 });

      // Verify feed status
      const updatedList = await request(server)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${workerToken}`)
        .expect(200);

      expect(updatedList.body.unread_count).toBe(0);
      expect(updatedList.body.data[0].is_read).toBe(true);
    });
  });

  describe('Background Payroll Calculations & Exports', () => {
    it('allows enqueuing calculation and polling status', async () => {
      const res = await request(server)
        .post(`/api/v1/payroll/periods/${periodId}/calculate`)
        .set('Authorization', `Bearer ${accountantToken}`)
        .send({})
        .expect(200);

      expect(res.body.data).toHaveProperty('job_id');
      expect(res.body.data.poll_url).toBe(`/v1/payroll/periods/${periodId}/status`);

      // Poll status
      const statusRes = await request(server)
        .get(`/api/v1/payroll/periods/${periodId}/status`)
        .set('Authorization', `Bearer ${accountantToken}`)
        .expect(200);

      expect(statusRes.body.data).toHaveProperty('status');
    });

    it('allows enqueuing exports and polling status', async () => {
      // Set status to CALCULATED so export is allowed
      await admin.query(
        `UPDATE payroll_periods SET status = 'CALCULATED' WHERE tenant_id = $1 AND id = $2`,
        [tenantId, periodId],
      );

      const res = await request(server)
        .post(`/api/v1/payroll/periods/${periodId}/export`)
        .set('Authorization', `Bearer ${accountantToken}`)
        .send({})
        .expect(200);

      expect(res.body.data).toHaveProperty('export_id');
      expect(res.body.data.estimated_seconds).toBe(30);

      const exportId = res.body.data.export_id;

      // Poll status
      const statusRes = await request(server)
        .get(`/api/v1/payroll/periods/${periodId}/export/${exportId}`)
        .set('Authorization', `Bearer ${accountantToken}`)
        .expect(200);

      expect(statusRes.body.data).toHaveProperty('status');
      expect(['PROCESSING', 'READY', 'FAILED']).toContain(statusRes.body.data.status);
    });
  });
});
