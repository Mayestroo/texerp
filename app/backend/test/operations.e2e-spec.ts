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

interface OperationUpdateView extends OperationView {
  price_changed: boolean;
  old_price?: number;
  new_price?: number;
  effective_from?: string;
}

interface OperationUpdateBody {
  data: OperationUpdateView;
}

interface AuditCountRow {
  count: string;
}

interface PriceHistoryRow {
  unit_price: number;
  effective_from: Date;
  effective_to: Date | null;
}

interface AuditEventRow {
  action: string;
  before_state?: Record<string, unknown>;
  after_state?: Record<string, unknown>;
}

interface OperationStateRow {
  is_active: boolean;
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

  it('changes a price, closes the previous rate interval, and writes an OPERATION_PRICE_CHANGED audit', async () => {
    const updated = await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ unit_price: 46_000 })
      .expect(200);

    const body = updated.body as OperationUpdateBody;
    expect(body.data).toMatchObject({
      id: mutableOperationId,
      unit_price: 46_000,
      price_changed: true,
      old_price: 45_000,
      new_price: 46_000,
    });
    expect(body.data.effective_from).toMatch(/\d{4}-/);

    const history = await admin.query<PriceHistoryRow>(
      `SELECT unit_price, effective_from, effective_to
       FROM operation_price_history
       WHERE operation_id = $1
       ORDER BY effective_from ASC`,
      [mutableOperationId],
    );
    expect(history.rows).toHaveLength(2);
    expect(history.rows[0].unit_price).toBe(45_000);
    expect(history.rows[0].effective_to).toBeInstanceOf(Date);
    expect(history.rows[0].effective_to).toEqual(history.rows[1].effective_from);
    expect(history.rows[1]).toMatchObject({
      unit_price: 46_000,
      effective_to: null,
    });

    const audits = await admin.query<AuditEventRow>(
      `SELECT action FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2`,
      [tenantId, mutableOperationId],
    );
    expect(audits.rows.map(({ action }) => action)).toContain(
      'OPERATION_PRICE_CHANGED',
    );
    expect(audits.rows.map(({ action }) => action)).not.toContain(
      'OPERATION_UPDATED',
    );
  });

  it('updates metadata only and writes an OPERATION_UPDATED audit', async () => {
    const updated = await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Mutable Updated', sort_order: 5 })
      .expect(200);

    const body = updated.body as OperationUpdateBody;
    expect(body.data).toMatchObject({
      id: mutableOperationId,
      name: 'Mutable Updated',
      sort_order: 5,
      unit_price: 46_000,
      price_changed: false,
    });
    expect(body.data.old_price).toBeUndefined();
    expect(body.data.new_price).toBeUndefined();
    expect(body.data.effective_from).toBeUndefined();

    const audits = await admin.query<AuditEventRow>(
      `SELECT action, before_state, after_state FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_UPDATED'`,
      [tenantId, mutableOperationId],
    );
    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].before_state).toMatchObject({ name: 'Mutable' });
    expect(audits.rows[0].after_state).toMatchObject({
      name: 'Mutable Updated',
      sort_order: 5,
    });

    const history = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM operation_price_history WHERE operation_id = $1`,
      [mutableOperationId],
    );
    expect(history.rows[0].count).toBe('2');
  });

  it('returns the current representation with no audit on a no-op update', async () => {
    const beforeAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2`,
      [tenantId, mutableOperationId],
    );

    const updated = await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Mutable Updated', sort_order: 5, unit_price: 46_000 })
      .expect(200);

    const body = updated.body as OperationUpdateBody;
    expect(body.data).toMatchObject({
      id: mutableOperationId,
      name: 'Mutable Updated',
      sort_order: 5,
      unit_price: 46_000,
      price_changed: false,
    });

    const afterAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2`,
      [tenantId, mutableOperationId],
    );
    expect(afterAudits.rows[0].count).toBe(beforeAudits.rows[0].count);
  });

  it('rejects an empty patch with EMPTY_UPDATE', async () => {
    const response = await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({})
      .expect(400);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'EMPTY_UPDATE' },
    });
  });

  it('rejects unit and is_active through whitelist validation', async () => {
    await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Rename', unit: 'METER' })
      .expect(400);
    await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Rename', is_active: false })
      .expect(400);
  });

  it('returns OPERATION_NOT_FOUND for missing or cross-tenant ids', async () => {
    for (const id of [randomUUID(), secondTenantOperationId]) {
      const response = await request(server)
        .patch(`/api/v1/operations/${id}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ name: 'Not Found' })
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'OPERATION_NOT_FOUND' },
      });
    }
  });

  it('returns OPERATION_NOT_FOUND for cross-tenant activate/deactivate', async () => {
    for (const route of ['activate', 'deactivate']) {
      const response = await request(server)
        .post(`/api/v1/operations/${secondTenantOperationId}/${route}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({})
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'OPERATION_NOT_FOUND' },
      });
    }

    // Verify no state change occurred
    const operation = await admin.query<{ is_active: boolean }>(
      `SELECT is_active FROM operations WHERE id = $1`,
      [secondTenantOperationId],
    );
    expect(operation.rows[0].is_active).toBe(true);
  });

  it('emits one OPERATION_PRICE_CHANGED audit with all fields for a combined name-and-price patch', async () => {
    const patchId = randomUUID();
    await admin.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, created_by)
       VALUES ($1, $2, 'Combined Patch Op', 'CPO', 'PIECE', 100, 0, $3)`,
      [patchId, tenantId, directorId],
    );
    await admin.query(
      `INSERT INTO operation_price_history (id, tenant_id, operation_id, unit_price, effective_from, changed_by)
       VALUES (gen_random_uuid(), $1, $2, 100, now(), $3)`,
      [tenantId, patchId, directorId],
    );

    const updated = await request(server)
      .patch(`/api/v1/operations/${patchId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Combined Renamed', unit_price: 200 })
      .expect(200);

    expect((updated.body as OperationUpdateBody).data.price_changed).toBe(true);

    const audits = await admin.query<{
      action: string;
      before_state: Record<string, unknown>;
      after_state: Record<string, unknown>;
    }>(
      `SELECT action, before_state, after_state FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2
       ORDER BY occurred_at ASC`,
      [tenantId, patchId],
    );

    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].action).toBe('OPERATION_PRICE_CHANGED');
    expect(audits.rows[0].before_state).toMatchObject({
      unit_price: 100,
      name: 'Combined Patch Op',
    });
    expect(audits.rows[0].after_state).toMatchObject({
      unit_price: 200,
      name: 'Combined Renamed',
    });
  });

  it('denies non-Directors update and lifecycle endpoints', async () => {
    for (const token of [workerToken, foremanToken, accountantToken]) {
      await request(server)
        .patch(`/api/v1/operations/${mutableOperationId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Denied' })
        .expect(403);
      await request(server)
        .post(`/api/v1/operations/${mutableOperationId}/deactivate`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(403);
      await request(server)
        .post(`/api/v1/operations/${mutableOperationId}/activate`)
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(403);
    }
  });

  it('deactivates an active operation and writes OPERATION_DEACTIVATED', async () => {
    await request(server)
      .post(`/api/v1/operations/${createdOperationId}/deactivate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({})
      .expect(200);

    const operation = await admin.query<OperationStateRow>(
      `SELECT is_active FROM operations WHERE id = $1`,
      [createdOperationId],
    );
    expect(operation.rows[0].is_active).toBe(false);

    const audits = await admin.query<AuditEventRow>(
      `SELECT action FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_DEACTIVATED'`,
      [tenantId, createdOperationId],
    );
    expect(audits.rows).toHaveLength(1);
  });

  it('deactivate is idempotent when the operation is already inactive', async () => {
    const beforeAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_DEACTIVATED'`,
      [tenantId, inactiveOperationId],
    );

    await request(server)
      .post(`/api/v1/operations/${inactiveOperationId}/deactivate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({})
      .expect(200);

    const afterAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_DEACTIVATED'`,
      [tenantId, inactiveOperationId],
    );
    expect(afterAudits.rows[0].count).toBe(beforeAudits.rows[0].count);
  });

  it('activates an inactive operation and writes OPERATION_ACTIVATED', async () => {
    await request(server)
      .post(`/api/v1/operations/${inactiveOperationId}/activate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({})
      .expect(200);

    const operation = await admin.query<OperationStateRow>(
      `SELECT is_active FROM operations WHERE id = $1`,
      [inactiveOperationId],
    );
    expect(operation.rows[0].is_active).toBe(true);

    const audits = await admin.query<AuditEventRow>(
      `SELECT action FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_ACTIVATED'`,
      [tenantId, inactiveOperationId],
    );
    expect(audits.rows).toHaveLength(1);
  });

  it('activate is idempotent when the operation is already active', async () => {
    const beforeAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_ACTIVATED'`,
      [tenantId, firstActiveOperationId],
    );

    await request(server)
      .post(`/api/v1/operations/${firstActiveOperationId}/activate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({})
      .expect(200);

    const afterAudits = await admin.query<AuditCountRow>(
      `SELECT count(*)::text AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'OPERATION' AND aggregate_id = $2 AND action = 'OPERATION_ACTIVATED'`,
      [tenantId, firstActiveOperationId],
    );
    expect(afterAudits.rows[0].count).toBe(beforeAudits.rows[0].count);
  });

  it('serializes concurrent price changes so only one rate interval is current', async () => {
    const lockClient = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    try {
      await lockClient.connect();
      await lockClient.query('BEGIN');
      await lockClient.query(
        `SELECT id FROM operations WHERE id = $1 FOR UPDATE`,
        [mutableOperationId],
      );

      const first = request(server)
        .patch(`/api/v1/operations/${mutableOperationId}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ unit_price: 47_000 });
      const second = request(server)
        .patch(`/api/v1/operations/${mutableOperationId}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ unit_price: 48_000 });

      // Wait for both requests to be blocked on the lock
      for (let i = 0; i < 50; i++) {
        const blocked = await admin.query<{ pid: number }>(
          `SELECT pid FROM pg_stat_activity
           WHERE state = 'active'
             AND wait_event_type = 'Lock'
             AND query ILIKE '%operations%'`,
        );
        if (blocked.rows.length >= 2) break;
        await new Promise((r) => setTimeout(r, 50));
      }

      // Release the lock so both requests can proceed
      await lockClient.query('COMMIT');

      const [firstRes, secondRes] = await Promise.all([first, second]);
      expect(firstRes.status).toBe(200);
      expect(secondRes.status).toBe(200);

      const history = await admin.query<PriceHistoryRow>(
        `SELECT unit_price, effective_to
         FROM operation_price_history
         WHERE operation_id = $1
         ORDER BY effective_from ASC`,
        [mutableOperationId],
      );
      const currentIntervals = history.rows.filter(
        ({ effective_to }) => effective_to === null,
      );
      expect(currentIntervals).toHaveLength(1);
      expect([47_000, 48_000]).toContain(currentIntervals[0].unit_price);
    } finally {
      await lockClient.query('ROLLBACK').catch(() => undefined);
      await lockClient.end().catch(() => undefined);
    }
  }, 15_000);
});
