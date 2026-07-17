import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import bcrypt from 'bcrypt';
import { randomUUID } from 'node:crypto';
import { Server } from 'node:http';
import Redis from 'ioredis';
import { Client } from 'pg';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/shared/bootstrap/configure-app';

interface LoginBody {
  data: { access_token: string };
}

interface OperationView {
  id: string;
  name: string;
  code: string | null;
  unit: 'PIECE' | 'METER' | 'PAIR';
  unit_price: number;
  currency: 'UZS';
  is_active: boolean;
  sort_order: number;
}

interface OperationListBody {
  data: OperationView[];
}

describe('Operations Catalog', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });
  const tenantId = randomUUID();
  const secondTenantId = randomUUID();
  const directorId = randomUUID();
  const workerId = randomUUID();
  const foremanId = randomUUID();
  const accountantId = randomUUID();
  const secondTenantDirectorId = randomUUID();
  const firstActiveOperationId = randomUUID();
  const secondActiveOperationId = randomUUID();
  const inactiveOperationId = randomUUID();
  const mutableOperationId = randomUUID();
  const secondTenantOperationId = randomUUID();
  const initialPriceHistoryIds = Array.from({ length: 5 }, () => randomUUID());
  const suffix = (
    Number.parseInt(tenantId.replaceAll('-', '').slice(0, 10), 16) % 10_000_000
  )
    .toString()
    .padStart(7, '0');
  const phone = (sequence: number): string =>
    `+998${suffix}${sequence.toString().padStart(2, '0')}`;
  let app: INestApplication;
  let server: Server;
  let directorToken: string;
  let workerToken: string;
  let foremanToken: string;
  let accountantToken: string;
  let createdOperationId: string;

  async function login(value: string): Promise<string> {
    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: value, pin: '4826' })
      .expect(200);
    return (response.body as LoginBody).data.access_token;
  }

  beforeAll(async () => {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.flushdb();
    await redis.quit();
    await admin.connect();
    const pinHash = await bcrypt.hash('4826', 4);
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Operations Tenant', $2), ($3, 'Other Operations Tenant', $4)`,
      [
        tenantId,
        `operations-${tenantId}`,
        secondTenantId,
        `operations-${secondTenantId}`,
      ],
    );
    await admin.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $3, $4, 'Director', 'OD-1', 'DIRECTOR', 'ACTIVE'),
         ($5, $2, $6, $4, 'Worker', 'OW-1', 'WORKER', 'ACTIVE'),
         ($7, $2, $8, $4, 'Foreman', 'OF-1', 'FOREMAN', 'ACTIVE'),
         ($9, $2, $10, $4, 'Accountant', 'OA-1', 'ACCOUNTANT', 'ACTIVE'),
         ($11, $12, $13, $4, 'Other Director', 'OD-2', 'DIRECTOR', 'ACTIVE')`,
      [
        directorId,
        tenantId,
        phone(1),
        pinHash,
        workerId,
        phone(2),
        foremanId,
        phone(3),
        accountantId,
        phone(4),
        secondTenantDirectorId,
        secondTenantId,
        phone(5),
      ],
    );
    await admin.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, is_active, created_by)
       VALUES
         ($1, $2, 'Alpha', 'ALPHA', 'PIECE', 100, 1, true, $3),
         ($4, $2, 'Beta', 'BETA', 'METER', 200, 1, true, $3),
         ($5, $2, 'Inactive', 'INACTIVE', 'PAIR', 300, 2, false, $3),
         ($6, $2, 'Mutable', 'MUTABLE', 'PIECE', 45000, 3, true, $3),
         ($7, $8, 'Other Tenant', 'OTHER', 'PIECE', 1, 0, true, $9)`,
      [
        firstActiveOperationId,
        tenantId,
        directorId,
        secondActiveOperationId,
        inactiveOperationId,
        mutableOperationId,
        secondTenantOperationId,
        secondTenantId,
        secondTenantDirectorId,
      ],
    );
    await admin.query(
      `INSERT INTO operation_price_history
        (id, tenant_id, operation_id, unit_price, effective_from, changed_by)
       VALUES
        ($1, $2, $3, 100, now(), $4),
        ($5, $2, $6, 200, now(), $4),
        ($7, $2, $8, 300, now(), $4),
        ($9, $2, $10, 45000, now(), $4),
        ($11, $12, $13, 1, now(), $14)`,
      [
        initialPriceHistoryIds[0],
        tenantId,
        firstActiveOperationId,
        directorId,
        initialPriceHistoryIds[1],
        secondActiveOperationId,
        initialPriceHistoryIds[2],
        inactiveOperationId,
        initialPriceHistoryIds[3],
        mutableOperationId,
        initialPriceHistoryIds[4],
        secondTenantId,
        secondTenantOperationId,
        secondTenantDirectorId,
      ],
    );
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication();
    app.useLogger(false);
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
    directorToken = await login(phone(1));
    workerToken = await login(phone(2));
    foremanToken = await login(phone(3));
    accountantToken = await login(phone(4));
  });

  afterAll(async () => {
    await app.close();
    await admin.query('DELETE FROM audit_events WHERE tenant_id IN ($1, $2)', [
      tenantId,
      secondTenantId,
    ]);
    await admin.query(
      'DELETE FROM operation_price_history WHERE tenant_id IN ($1, $2)',
      [tenantId, secondTenantId],
    );
    await admin.query('DELETE FROM operations WHERE tenant_id IN ($1, $2)', [
      tenantId,
      secondTenantId,
    ]);
    await admin.query('DELETE FROM user_sessions WHERE tenant_id IN ($1, $2)', [
      tenantId,
      secondTenantId,
    ]);
    await admin.query('DELETE FROM users WHERE tenant_id IN ($1, $2)', [
      tenantId,
      secondTenantId,
    ]);
    await admin.query('DELETE FROM tenants WHERE id IN ($1, $2)', [
      tenantId,
      secondTenantId,
    ]);
    await admin.end();
  });

  it('lists only active Operations for every authenticated role in deterministic order', async () => {
    const response = await request(server)
      .get('/api/v1/operations')
      .set('Authorization', `Bearer ${workerToken}`)
      .expect(200);

    expect(response.body).toEqual({
      success: true,
      data: [
        expect.objectContaining({
          id: firstActiveOperationId,
          name: 'Alpha',
          sort_order: 1,
        }),
        expect.objectContaining({
          id: secondActiveOperationId,
          name: 'Beta',
          sort_order: 1,
        }),
        expect.objectContaining({
          id: mutableOperationId,
          name: 'Mutable',
          sort_order: 3,
        }),
      ],
    });
  });

  it('lets only a Director create an Operation and starts its first rate interval', async () => {
    const created = await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({
        name: 'Collar sewing',
        code: 'COL-SEW',
        unit: 'PIECE',
        unit_price: 45000,
        sort_order: 2,
      })
      .expect(201);

    const createdBody = created.body as { data: OperationView };
    expect(createdBody.data).toMatchObject({
      name: 'Collar sewing',
      code: 'COL-SEW',
      unit: 'PIECE',
      unit_price: 45000,
      currency: 'UZS',
      is_active: true,
      sort_order: 2,
    });
    createdOperationId = createdBody.data.id;
    const history = await admin.query(
      `SELECT unit_price, effective_to FROM operation_price_history WHERE operation_id = $1`,
      [createdBody.data.id],
    );
    expect(history.rows).toEqual([{ unit_price: 45000, effective_to: null }]);
  });

  it('denies non-Directors catalog creation', async () => {
    for (const token of [workerToken, foremanToken, accountantToken]) {
      await request(server)
        .post('/api/v1/operations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Denied', unit: 'PIECE', unit_price: 1 })
        .expect(403);
    }
  });

  it('lets a Director list INACTIVE and ALL Operations', async () => {
    const inactive = await request(server)
      .get('/api/v1/operations?status=INACTIVE')
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    expect(
      (inactive.body as OperationListBody).data.map(({ id }) => id),
    ).toEqual([inactiveOperationId]);

    const all = await request(server)
      .get('/api/v1/operations?status=ALL')
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    expect((all.body as OperationListBody).data.map(({ id }) => id)).toEqual([
      firstActiveOperationId,
      secondActiveOperationId,
      createdOperationId,
      inactiveOperationId,
      mutableOperationId,
    ]);
  });

  it('denies non-Directors status visibility', async () => {
    for (const token of [workerToken, foremanToken, accountantToken]) {
      await request(server)
        .get('/api/v1/operations?status=INACTIVE')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
      await request(server)
        .get('/api/v1/operations?status=ALL')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    }
  });

  it('searches Operations by name and code case-insensitively', async () => {
    const byName = await request(server)
      .get('/api/v1/operations?search=Alpha')
      .set('Authorization', `Bearer ${workerToken}`)
      .expect(200);
    expect(
      (byName.body as OperationListBody).data.map(({ id }) => id),
    ).toEqual([firstActiveOperationId]);

    const byCode = await request(server)
      .get('/api/v1/operations?search=beta')
      .set('Authorization', `Bearer ${workerToken}`)
      .expect(200);
    expect(
      (byCode.body as OperationListBody).data.map(({ id }) => id),
    ).toEqual([secondActiveOperationId]);

    const byPartial = await request(server)
      .get('/api/v1/operations?search=able')
      .set('Authorization', `Bearer ${workerToken}`)
      .expect(200);
    expect(
      (byPartial.body as OperationListBody).data.map(({ id }) => id),
    ).toEqual([mutableOperationId]);
  });

  it('returns stable tenant-local duplicate name and code conflicts', async () => {
    for (const [body, code] of [
      [
        { name: 'Alpha', code: 'UNIQUE-1', unit: 'PIECE', unit_price: 1 },
        'OPERATION_NAME_ALREADY_EXISTS',
      ],
      [
        { name: 'Unique Operation', code: 'ALPHA', unit: 'PIECE', unit_price: 1 },
        'OPERATION_CODE_ALREADY_EXISTS',
      ],
    ] as const) {
      const response = await request(server)
        .post('/api/v1/operations')
        .set('Authorization', `Bearer ${directorToken}`)
        .send(body)
        .expect(409);
      expect(response.body).toMatchObject({
        success: false,
        error: { code },
      });
    }
  });

  it('rejects invalid unit_price and unknown fields', async () => {
    await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Zero price', unit: 'PIECE', unit_price: 0 })
      .expect(400);
    await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Negative price', unit: 'PIECE', unit_price: -1 })
      .expect(400);
    await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({
        name: 'Unknown field',
        unit: 'PIECE',
        unit_price: 1,
        category_id: randomUUID(),
      })
      .expect(400);
  });
});
