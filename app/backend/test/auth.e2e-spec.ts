import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import bcrypt from 'bcrypt';
import { createHash, randomUUID } from 'node:crypto';
import { Server } from 'node:http';
import Redis from 'ioredis';
import { Client } from 'pg';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/shared/bootstrap/configure-app';

interface LoginBody {
  success: boolean;
  data: {
    access_token: string;
    refresh_token: string;
    expires_in: number;
    user: {
      id: string;
      full_name: string;
      worker_code: string;
      role: string;
      language: string;
      avatar_url: string | null;
      department: { id: string; name: string } | null;
      foreman: { id: string; full_name: string } | null;
    };
  };
}

interface RefreshBody {
  success: boolean;
  data: {
    access_token: string;
    refresh_token: string;
    expires_in: number;
  };
}

describe('Authentication', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });
  const tenantId = randomUUID();
  const userId = randomUUID();
  const phone = '+998905551122';
  const lockoutUserId = randomUUID();
  const lockoutPhone = '+998905551133';
  const deactivatedUserId = randomUUID();
  const deactivatedPhone = '+998905551144';
  const concurrentUserId = randomUUID();
  const concurrentPhone = '+998905551155';
  let app: INestApplication;
  let server: Server;
  let refreshToken: string;
  let rotatedRefreshToken: string;
  let accessToken: string;

  async function flushRedis(): Promise<void> {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.flushdb();
    await redis.quit();
  }

  beforeAll(async () => {
    await flushRedis();
    await admin.connect();
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Auth Tenant', $2)`,
      [tenantId, `auth-${tenantId}`],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
        ($1, $2, $3, $4, 'Aziz Karimov', 'W-0042', 'WORKER', 'ACTIVE'),
        ($5, $2, $6, $4, 'Lockout User', 'W-0043', 'WORKER', 'ACTIVE'),
        ($7, $2, $8, $4, 'Former User', 'W-0044', 'WORKER', 'DEACTIVATED'),
        ($9, $2, $10, $4, 'Concurrent User', 'W-0045', 'WORKER', 'ACTIVE')`,
      [
        userId,
        tenantId,
        phone,
        await bcrypt.hash('4826', 4),
        lockoutUserId,
        lockoutPhone,
        deactivatedUserId,
        deactivatedPhone,
        concurrentUserId,
        concurrentPhone,
      ],
    );

    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication();
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });

  beforeEach(flushRedis);

  afterAll(async () => {
    await admin.query('DELETE FROM audit_events WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM used_refresh_tokens WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM user_sessions WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM users WHERE tenant_id = $1', [tenantId]);
    await admin.query('DELETE FROM tenants WHERE id = $1', [tenantId]);
    await app.close();
    await admin.end();
  });

  it('logs in an active user with a valid phone and PIN', async () => {
    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '4826' })
      .expect(200);
    const body = response.body as LoginBody;

    expect(body.success).toBe(true);
    expect(body.data.access_token).toEqual(expect.any(String));
    expect(body.data.refresh_token).toEqual(expect.any(String));
    expect(body.data.expires_in).toBe(900);
    expect(body.data.user).toEqual({
      id: userId,
      full_name: 'Aziz Karimov',
      worker_code: 'W-0042',
      role: 'WORKER',
      language: 'uz',
      avatar_url: null,
      department: null,
      foreman: null,
    });
    refreshToken = body.data.refresh_token;
    accessToken = body.data.access_token;
  });

  it('rotates the refresh token when issuing a new access token', async () => {
    rotatedRefreshToken = refreshToken;
    const response = await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: refreshToken })
      .expect(200);
    const body = response.body as RefreshBody;

    expect(body.success).toBe(true);
    expect(body.data.access_token).toEqual(expect.any(String));
    expect(body.data.refresh_token).toEqual(expect.any(String));
    expect(body.data.refresh_token).not.toBe(refreshToken);
    expect(body.data.expires_in).toBe(900);
    refreshToken = body.data.refresh_token;
    accessToken = body.data.access_token;
  });

  it('rejects a refresh token after it has been rotated', async () => {
    const response = await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: rotatedRefreshToken })
      .expect(401);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'INVALID_REFRESH_TOKEN' },
    });

    await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: refreshToken })
      .expect(401);
  });

  it('logs out by revoking the current refresh token', async () => {
    const login = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '4826' })
      .expect(200);
    const loginBody = login.body as LoginBody;
    accessToken = loginBody.data.access_token;
    refreshToken = loginBody.data.refresh_token;

    await request(server)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ refresh_token: refreshToken })
      .expect(200, {
        success: true,
        data: { message: 'Tizimdan chiqildi' },
      });

    await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: refreshToken })
      .expect(401);

    await flushRedis();

    const secondLogout = await request(server)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ refresh_token: refreshToken })
      .expect(401);
    expect(secondLogout.body).not.toMatchObject({
      error: { code: 'INVALID_REFRESH_TOKEN' },
    });
  });

  it('distinguishes an expired refresh token', async () => {
    const expiredToken = 'expired-refresh-token-that-is-long-enough-123';
    const expiredHash = createHash('sha256').update(expiredToken).digest('hex');
    await admin.query(
      `INSERT INTO user_sessions
        (id, tenant_id, user_id, refresh_token_hash, expires_at)
       VALUES ($1, $2, $3, $4, now() - interval '1 day')`,
      [randomUUID(), tenantId, userId, expiredHash],
    );

    const response = await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: expiredToken })
      .expect(401);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'REFRESH_TOKEN_EXPIRED' },
    });
  });

  it('does not reveal whether a phone exists without the correct PIN', async () => {
    const wrongPin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '0000' })
      .expect(401);
    const unknownPhone = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: '+998905559999', pin: '0000' })
      .expect(401);
    const deactivated = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: deactivatedPhone, pin: '0000' })
      .expect(401);

    expect(unknownPhone.body).toEqual(wrongPin.body);
    expect(deactivated.body).toEqual(wrongPin.body);
  });

  it('rate limits repeated login attempts for one phone', async () => {
    const target = '+998905558888';
    for (let attempt = 1; attempt <= 10; attempt += 1) {
      await request(server)
        .post('/api/v1/auth/login')
        .send({ phone: target, pin: '0000' })
        .expect(401);
    }

    await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: target, pin: '0000' })
      .expect(429);
  });

  it('rate limits login attempts across phones from one IP', async () => {
    for (let attempt = 1; attempt <= 10; attempt += 1) {
      await request(server)
        .post('/api/v1/auth/login')
        .send({
          phone: `+9989100000${attempt.toString().padStart(2, '0')}`,
          pin: '0000',
        })
        .expect(401);
    }

    await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: '+998910000011', pin: '0000' })
      .expect(429);
  });

  it('serializes concurrent failed attempts with accurate audit numbers', async () => {
    const responses = await Promise.all(
      Array.from({ length: 5 }, () =>
        request(server)
          .post('/api/v1/auth/login')
          .send({ phone: concurrentPhone, pin: '0000' }),
      ),
    );

    expect(responses.map((response) => response.status)).toEqual([
      401, 401, 401, 401, 401,
    ]);
    const user = await admin.query<{
      failed_login_attempts: number;
      locked_until: Date | null;
    }>('SELECT failed_login_attempts, locked_until FROM users WHERE id = $1', [
      concurrentUserId,
    ]);
    expect(user.rows[0]?.failed_login_attempts).toBe(5);
    expect(user.rows[0]?.locked_until).not.toBeNull();

    const audit = await admin.query<{ attempt: number }>(
      `SELECT (after_state->>'attempt')::integer AS attempt
       FROM audit_events
       WHERE actor_id = $1 AND action = 'LOGIN_FAILED'
       ORDER BY attempt`,
      [concurrentUserId],
    );
    expect(audit.rows.map((row) => row.attempt)).toEqual([1, 2, 3, 4, 5]);
  });

  it('locks a user for 15 minutes after five invalid PIN attempts', async () => {
    for (let attempt = 1; attempt < 5; attempt += 1) {
      await request(server)
        .post('/api/v1/auth/login')
        .send({ phone: lockoutPhone, pin: '0000' })
        .expect(401);
    }

    const attempts = await admin.query<{ failed_login_attempts: number }>(
      'SELECT failed_login_attempts FROM users WHERE id = $1',
      [lockoutUserId],
    );
    expect(attempts.rows[0]?.failed_login_attempts).toBe(4);

    await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: lockoutPhone, pin: '0000' })
      .expect(401);

    const locked = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: lockoutPhone, pin: '4826' })
      .expect(429);

    expect(locked.body).toMatchObject({
      success: false,
      error: { code: 'ACCOUNT_LOCKED' },
    });
  });

  it('rejects access immediately after user deactivation', async () => {
    const login = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '4826' })
      .expect(200);
    const body = login.body as LoginBody;

    await admin.query(
      `UPDATE users
       SET status = 'DEACTIVATED', deactivated_at = now()
       WHERE id = $1`,
      [userId],
    );

    await request(server)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${body.data.access_token}`)
      .send({ refresh_token: body.data.refresh_token })
      .expect(401);
  });
});
