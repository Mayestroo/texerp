import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { DataSource } from 'typeorm';
import bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

describe('Security & Multi-Tenant RLS Penetration Tests (e2e)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  let tenantAToken: string;
  let tenantBToken: string;
  let tenantAUserId: string;
  let tenantBUserId: string;
  let tenantAId: string;
  let tenantBId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();

    dataSource = app.get<DataSource>(DataSource);

    // Provision Tenant A
    tenantAId = randomUUID();
    await dataSource.query(
      `INSERT INTO tenants (id, name, slug, status, timezone, language, currency)
       VALUES ($1, 'Tenant A Factory', 'tenant-a-sec', 'ACTIVE', 'Asia/Tashkent', 'uz', 'UZS')`,
      [tenantAId],
    );

    const pinHash = await bcrypt.hash('1234', 4);

    tenantAUserId = randomUUID();
    await dataSource.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
       VALUES ($1, $2, '+998991111111', $3, 'Tenant A Director', 'DIR-A-01', 'DIRECTOR', 'ACTIVE', 'uz')`,
      [tenantAUserId, tenantAId, pinHash],
    );

    // Provision Tenant B
    tenantBId = randomUUID();
    await dataSource.query(
      `INSERT INTO tenants (id, name, slug, status, timezone, language, currency)
       VALUES ($1, 'Tenant B Factory', 'tenant-b-sec', 'ACTIVE', 'Asia/Tashkent', 'uz', 'UZS')`,
      [tenantBId],
    );

    tenantBUserId = randomUUID();
    await dataSource.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
       VALUES ($1, $2, '+998992222222', $3, 'Tenant B Director', 'DIR-B-01', 'DIRECTOR', 'ACTIVE', 'uz')`,
      [tenantBUserId, tenantBId, pinHash],
    );

    // Authenticate Tenant A
    const loginA = await request(app.getHttpServer())
      .post('/v1/iam/auth/login')
      .send({ phone: '+998991111111', pin: '1234' });
    tenantAToken = loginA.body.accessToken;

    // Authenticate Tenant B
    const loginB = await request(app.getHttpServer())
      .post('/v1/iam/auth/login')
      .send({ phone: '+998992222222', pin: '1234' });
    tenantBToken = loginB.body.accessToken;
  });

  afterAll(async () => {
    // Cleanup security test data
    if (dataSource && dataSource.isInitialized) {
      await dataSource.query("DELETE FROM user_sessions WHERE user_id IN ($1, $2)", [tenantAUserId, tenantBUserId]);
      await dataSource.query("DELETE FROM users WHERE id IN ($1, $2)", [tenantAUserId, tenantBUserId]);
      await dataSource.query("DELETE FROM tenants WHERE id IN ($1, $2)", [tenantAId, tenantBId]);
    }
    await app.close();
  });

  describe('Cross-Tenant Data Access Prevention', () => {
    it('Tenant A SHOULD NOT be able to fetch Tenant B user profile', async () => {
      const res = await request(app.getHttpServer())
        .get(`/v1/iam/users/${tenantBUserId}`)
        .set('Authorization', `Bearer ${tenantAToken}`);

      expect(res.status).toBeGreaterThanOrEqual(400);
      expect(res.status).not.toBe(200);
    });

    it('Tenant A SHOULD NOT be able to list Tenant B workers/users', async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/iam/users')
        .set('Authorization', `Bearer ${tenantAToken}`);

      if (res.status === 200) {
        const returnedUserIds = res.body.data ? res.body.data.map((u: any) => u.id) : [];
        expect(returnedUserIds).not.toContain(tenantBUserId);
      }
    });

    it('Tenant A token with forged x-tenant-id header MUST NOT leak Tenant B data', async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/iam/users')
        .set('Authorization', `Bearer ${tenantAToken}`)
        .set('x-tenant-id', tenantBId);

      if (res.status === 200) {
        const returnedUserIds = res.body.data ? res.body.data.map((u: any) => u.id) : [];
        expect(returnedUserIds).not.toContain(tenantBUserId);
      }
    });

    it('Unauthenticated requests to protected endpoints MUST return 401 Unauthorized', async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/iam/users');

      expect(res.status).toBe(401);
    });

    it('Tampered / Malformed JWT tokens MUST return 401 Unauthorized', async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/iam/users')
        .set('Authorization', `Bearer ${tenantAToken}tampered123`);

      expect(res.status).toBe(401);
    });
  });
});
