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

interface HistoryEntryView {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPICIOUS';
  operation: {
    id: string;
    name: string;
    unit: 'PIECE' | 'METER' | 'PAIR';
  };
  operation_name_snapshot: string;
  operation_code_snapshot: string | null;
  quantity_submitted: number;
  unit_price_snapshot: number;
  currency_snapshot: 'UZS';
  record_date: string;
  worker_note: string | null;
  submitted_at: string;
  foreman: { id: string; full_name: string } | null;
}

interface HistoryBody {
  success: boolean;
  data: HistoryEntryView[];
  total: number;
}

describe('Production History', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });
  const tenantId = randomUUID();
  const directorId = randomUUID();
  const foremanId = randomUUID();
  const workerAId = randomUUID();
  const workerBId = randomUUID();
  const accountantId = randomUUID();
  const departmentId = randomUUID();
  const foremanAssignmentAId = randomUUID();
  const foremanAssignmentBId = randomUUID();
  const operation1Id = randomUUID();
  const operation2Id = randomUUID();
  const operation3Id = randomUUID();
  const entryA1 = randomUUID();
  const entryA2 = randomUUID();
  const entryA3 = randomUUID();
  const entryA4 = randomUUID();
  const entryA5 = randomUUID();
  const entryB1 = randomUUID();
  const entryB2 = randomUUID();
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
  let foremanToken: string;
  let workerAToken: string;
  let workerBToken: string;
  let accountantToken: string;

  async function login(value: string): Promise<string> {
    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: value, pin: '4826' })
      .expect(200);
    return (response.body as { data: { access_token: string } }).data
      .access_token;
  }

  beforeAll(async () => {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.flushdb();
    await redis.quit();
    await admin.connect();
    const pinHash = await bcrypt.hash('4826', 4);

    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'History Tenant', $2)`,
      [tenantId, `history-${tenantId}`],
    );

    await admin.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $3, $4, 'Director', 'HD-1', 'DIRECTOR', 'ACTIVE'),
         ($5, $2, $6, $4, 'Foreman', 'HF-1', 'FOREMAN', 'ACTIVE'),
         ($7, $2, $8, $4, 'Worker A', 'HW-A', 'WORKER', 'ACTIVE'),
         ($9, $2, $10, $4, 'Worker B', 'HW-B', 'WORKER', 'ACTIVE'),
         ($11, $2, $12, $4, 'Accountant', 'HA-1', 'ACCOUNTANT', 'ACTIVE')`,
      [
        directorId,
        tenantId,
        phone(1),
        pinHash,
        foremanId,
        phone(2),
        workerAId,
        phone(3),
        workerBId,
        phone(4),
        accountantId,
        phone(5),
      ],
    );

    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'History Line', 'HL-1', $3, true)`,
      [departmentId, tenantId, foremanId],
    );

    await admin.query(
      `INSERT INTO foreman_assignments (id, tenant_id, worker_id, foreman_id, department_id, assigned_at, assigned_by)
       VALUES
         ($1, $2, $3, $4, $5, $6, $7),
         ($8, $2, $9, $4, $5, $6, $7)`,
      [
        foremanAssignmentAId,
        tenantId,
        workerAId,
        foremanId,
        departmentId,
        '2026-07-01T00:00:00.000Z',
        directorId,
        foremanAssignmentBId,
        workerBId,
      ],
    );

    await admin.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, is_active, created_by)
       VALUES
         ($1, $2, 'Yoqa tikish', 'OP-001', 'PIECE', 45000, 1, true, $3),
         ($4, $2, 'Qo''l tikish', 'OP-002', 'METER', 52000, 2, true, $3),
         ($5, $2, 'Dazmol tikish', 'OP-003', 'PAIR', 30000, 3, true, $3)`,
      [operation1Id, tenantId, directorId, operation2Id, operation3Id],
    );

    await admin.query(
      `INSERT INTO production_entries
        (id, tenant_id, worker_id, operation_id, quantity, record_date, status,
         operation_name_snapshot, operation_code_snapshot, unit_price_snapshot,
         currency_snapshot, worker_note, created_at, updated_at)
       VALUES
         ($1, $2, $3, $4, 10, '2026-07-10', 'PENDING',
          'Yoqa tikish', 'OP-001', 45000, 'UZS', NULL, NOW(), NOW()),
         ($5, $2, $3, $4, 20, '2026-07-11', 'APPROVED',
          'Yoqa tikish', 'OP-001', 45000, 'UZS', NULL, NOW(), NOW()),
         ($6, $2, $3, $7, 30, '2026-07-12', 'REJECTED',
          'Qo''l tikish', 'OP-002', 52000, 'UZS', 'Noto''g''ri', NOW(), NOW()),
         ($8, $2, $3, $7, 40, '2026-07-13', 'PENDING',
          'Qo''l tikish', 'OP-002', 52000, 'UZS', NULL, NOW(), NOW()),
         ($9, $2, $3, $10, 50, '2026-07-14', 'SUSPICIOUS',
          'Dazmol tikish', 'OP-003', 30000, 'UZS', NULL, NOW(), NOW()),
         ($11, $2, $12, $4, 5, '2026-07-10', 'PENDING',
          'Yoqa tikish', 'OP-001', 45000, 'UZS', NULL, NOW(), NOW()),
         ($13, $2, $12, $7, 15, '2026-07-11', 'APPROVED',
          'Qo''l tikish', 'OP-002', 52000, 'UZS', NULL, NOW(), NOW())`,
      [
        entryA1,
        tenantId,
        workerAId,
        operation1Id,
        entryA2,
        entryA3,
        operation2Id,
        entryA4,
        entryA5,
        operation3Id,
        entryB1,
        workerBId,
        entryB2,
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
    foremanToken = await login(phone(2));
    workerAToken = await login(phone(3));
    workerBToken = await login(phone(4));
    accountantToken = await login(phone(5));
  }, 30_000);

  afterAll(async () => {
    await app.close();
    await admin.query('DELETE FROM audit_events WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM production_entries WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM operation_price_history WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM operations WHERE tenant_id = $1', [tenantId]);
    await admin.query('DELETE FROM foreman_assignments WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM user_sessions WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM departments WHERE tenant_id = $1', [tenantId]);
    await admin.query('DELETE FROM users WHERE tenant_id = $1', [tenantId]);
    await admin.query('DELETE FROM tenants WHERE id = $1', [tenantId]);
    await admin.end();
  });

  it('worker can list their own entries', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/me')
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.success).toBe(true);
    expect(body.total).toBe(5);
    expect(body.data).toHaveLength(5);
    expect(body.data[0].id).toBe(entryA5);
    expect(body.data[1].id).toBe(entryA4);
    expect(body.data[2].id).toBe(entryA3);
    expect(body.data[3].id).toBe(entryA2);
    expect(body.data[4].id).toBe(entryA1);
    for (const entry of body.data) {
      expect(entry.operation).toBeDefined();
      expect(typeof entry.operation.id).toBe('string');
      expect(entry.operation.name).toBe(entry.operation_name_snapshot);
      expect(entry.operation.unit).toMatch(/^(PIECE|METER|PAIR)$/);
      expect(entry.foreman).toEqual({ id: foremanId, full_name: 'Foreman' });
    }
  });

  it('filters by status', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/me?status=APPROVED')
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.total).toBe(1);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].status).toBe('APPROVED');
    expect(body.data[0].id).toBe(entryA2);
  });

  it('filters by operation_id', async () => {
    const response = await request(server)
      .get(`/api/v1/production/entries/me?operation_id=${operation1Id}`)
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.total).toBe(2);
    expect(body.data).toHaveLength(2);
    expect(body.data.map((entry) => entry.id).sort()).toEqual(
      [entryA1, entryA2].sort(),
    );
  });

  it('filters by date range', async () => {
    const response = await request(server)
      .get(
        '/api/v1/production/entries/me?date_from=2026-07-11&date_to=2026-07-13',
      )
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.total).toBe(3);
    expect(body.data).toHaveLength(3);
    expect(body.data.map((entry) => entry.id).sort()).toEqual(
      [entryA2, entryA3, entryA4].sort(),
    );
  });

  it('paginates with limit and offset', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/me?limit=2&offset=0')
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.total).toBe(5);
    expect(body.data).toHaveLength(2);
    expect(body.data[0].id).toBe(entryA5);
    expect(body.data[1].id).toBe(entryA4);

    const page2 = await request(server)
      .get('/api/v1/production/entries/me?limit=2&offset=2')
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const page2Body = page2.body as HistoryBody;
    expect(page2Body.total).toBe(5);
    expect(page2Body.data).toHaveLength(2);
    expect(page2Body.data[0].id).toBe(entryA3);
    expect(page2Body.data[1].id).toBe(entryA2);
  });

  it('non-WORKER roles cannot access own history endpoint', async () => {
    for (const token of [directorToken, foremanToken, accountantToken]) {
      await request(server)
        .get('/api/v1/production/entries/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    }
  });

  it('worker cannot see other workers entries', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/me')
      .set('Authorization', `Bearer ${workerBToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.total).toBe(2);
    expect(body.data).toHaveLength(2);
    expect(body.data.map((entry) => entry.id).sort()).toEqual(
      [entryB1, entryB2].sort(),
    );
  });

  it('returns empty data and zero total when no entries match', async () => {
    const response = await request(server)
      .get(
        '/api/v1/production/entries/me?date_from=2020-01-01&date_to=2020-01-31',
      )
      .set('Authorization', `Bearer ${workerAToken}`)
      .expect(200);

    const body = response.body as HistoryBody;
    expect(body.success).toBe(true);
    expect(body.data).toEqual([]);
    expect(body.total).toBe(0);
  });
});
