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

interface EntryView {
  id: string;
  status: 'PENDING';
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

interface EntryBody {
  data: EntryView;
}

interface ProductionEntryRow {
  id: string;
  status: string;
  quantity: number;
  record_date: string;
  operation_name_snapshot: string;
  operation_code_snapshot: string | null;
  unit_price_snapshot: number;
  currency_snapshot: string;
  worker_note: string | null;
}

interface AuditEventRow {
  action: string;
  after_state: Record<string, unknown>;
}

describe('Production Entries', () => {
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
  const secondTenantWorkerId = randomUUID();
  const departmentId = randomUUID();
  const activeOperationId = randomUUID();
  const activeOperationId2 = randomUUID();
  const inactiveOperationId = randomUUID();
  const secondTenantOperationId = randomUUID();
  const foremanAssignmentId = randomUUID();
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
  let createdEntryId: string;

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
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Production Tenant', $2), ($3, 'Other Production Tenant', $4)`,
      [
        tenantId,
        `production-${tenantId}`,
        secondTenantId,
        `production-${secondTenantId}`,
      ],
    );

    await admin.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $3, $4, 'Director', 'PD-1', 'DIRECTOR', 'ACTIVE'),
         ($5, $2, $6, $4, 'Worker', 'PW-1', 'WORKER', 'ACTIVE'),
         ($7, $2, $8, $4, 'Foreman', 'PF-1', 'FOREMAN', 'ACTIVE'),
         ($9, $2, $10, $4, 'Accountant', 'PA-1', 'ACCOUNTANT', 'ACTIVE'),
         ($11, $12, $13, $4, 'Other Director', 'PD-2', 'DIRECTOR', 'ACTIVE'),
         ($14, $12, $15, $4, 'Other Worker', 'PW-2', 'WORKER', 'ACTIVE')`,
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
        secondTenantWorkerId,
        phone(6),
      ],
    );

    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Production Line', 'PL-1', $3, true)`,
      [departmentId, tenantId, foremanId],
    );

    await admin.query(
      `INSERT INTO foreman_assignments (id, tenant_id, worker_id, foreman_id, department_id, assigned_by)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [foremanAssignmentId, tenantId, workerId, foremanId, departmentId, directorId],
    );

    await admin.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, is_active, created_by)
       VALUES
         ($1, $2, 'Yoqa tikish', 'OP-001', 'PIECE', 45000, 1, true, $3),
         ($4, $2, 'Qo''l tikish', 'OP-002', 'METER', 52000, 2, true, $3),
         ($5, $2, 'Nogiron operatsiya', 'OP-003', 'PAIR', 30000, 3, false, $3),
         ($6, $7, 'Other Tenant Operation', 'OP-OTHER', 'PIECE', 1, 0, true, $8)`,
      [
        activeOperationId,
        tenantId,
        directorId,
        activeOperationId2,
        inactiveOperationId,
        secondTenantOperationId,
        secondTenantId,
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
  }, 30_000);

  afterAll(async () => {
    await app.close();
    await admin.query(
      'DELETE FROM audit_events WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM production_entries WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM operation_price_history WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM operations WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM foreman_assignments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM user_sessions WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM departments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM users WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query('DELETE FROM tenants WHERE id = ANY($1::uuid[])', [
      [tenantId, secondTenantId],
    ]);
    await admin.end();
  });

  it('worker can create an entry with a valid operation, quantity, and date', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: activeOperationId,
        quantity: 85,
        record_date: today,
        worker_note: 'Eslatma',
      })
      .expect(201);

    const body = response.body as EntryBody;
    expect(body.data).toMatchObject({
      status: 'PENDING',
      operation: {
        id: activeOperationId,
        name: 'Yoqa tikish',
        unit: 'PIECE',
      },
      operation_name_snapshot: 'Yoqa tikish',
      operation_code_snapshot: 'OP-001',
      quantity_submitted: 85,
      unit_price_snapshot: 45000,
      currency_snapshot: 'UZS',
      record_date: today,
      worker_note: 'Eslatma',
      foreman: {
        id: foremanId,
        full_name: 'Foreman',
      },
    });
    expect(body.data.submitted_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    createdEntryId = body.data.id;
  });

  it('entry captures the price snapshot from the operation', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: activeOperationId2,
        quantity: 10,
        record_date: today,
      })
      .expect(201);

    const entryId = (response.body as EntryBody).data.id;
    const rows = await admin.query<ProductionEntryRow>(
      `SELECT id, status, quantity, record_date::text AS record_date,
              operation_name_snapshot, operation_code_snapshot,
              unit_price_snapshot, currency_snapshot, worker_note
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, entryId],
    );
    expect(rows.rows[0]).toMatchObject({
      status: 'PENDING',
      quantity: 10,
      record_date: today,
      operation_name_snapshot: "Qo'l tikish",
      operation_code_snapshot: 'OP-002',
      unit_price_snapshot: 52000,
      currency_snapshot: 'UZS',
      worker_note: null,
    });

    const audits = await admin.query<AuditEventRow>(
      `SELECT action, after_state
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'PRODUCTION_ENTRY' AND aggregate_id = $2`,
      [tenantId, entryId],
    );
    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].action).toBe('PRODUCTION_ENTRY_CREATED');
    expect(audits.rows[0].after_state).toMatchObject({
      id: entryId,
      operation_id: activeOperationId2,
      unit_price_snapshot: 52000,
      operation_name_snapshot: "Qo'l tikish",
      currency_snapshot: 'UZS',
      status: 'PENDING',
    });
  });

  it('duplicate entry returns 409 with existing_entry_id', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: activeOperationId,
        quantity: 100,
        record_date: today,
      })
      .expect(409);

    expect(response.body).toMatchObject({
      success: false,
      error: {
        code: 'DUPLICATE_ENTRY',
        existing_entry_id: createdEntryId,
      },
    });
  });

  it('inactive operation returns 400 OPERATION_INACTIVE', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: inactiveOperationId,
        quantity: 10,
        record_date: today,
      })
      .expect(400);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'OPERATION_INACTIVE' },
    });
  });

  it('invalid date format returns 400', async () => {
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: activeOperationId,
        quantity: 10,
        record_date: '2026/07/16',
      })
      .expect(400);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'VALIDATION_ERROR' },
    });
  });

  it('non-WORKER roles cannot submit production entries', async () => {
    const today = new Date().toISOString().slice(0, 10);
    for (const token of [directorToken, foremanToken, accountantToken]) {
      await request(server)
        .post('/api/v1/production/entries')
        .set('Authorization', `Bearer ${token}`)
        .send({
          operation_id: activeOperationId,
          quantity: 10,
          record_date: today,
        })
        .expect(403);
    }
  });

  it('cross-tenant operation id returns 404 OPERATION_NOT_FOUND', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: secondTenantOperationId,
        quantity: 10,
        record_date: today,
      })
      .expect(404);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'OPERATION_NOT_FOUND' },
    });
  });

  it('date outside back-date window returns 400', async () => {
    const tooOld = new Date();
    tooOld.setUTCDate(tooOld.getUTCDate() - 7);
    const response = await request(server)
      .post('/api/v1/production/entries')
      .set('Authorization', `Bearer ${workerToken}`)
      .send({
        operation_id: activeOperationId,
        quantity: 10,
        record_date: tooOld.toISOString().slice(0, 10),
      })
      .expect(400);

    expect(response.body).toMatchObject({
      success: false,
      error: {
        code: 'DATE_OUT_OF_WINDOW',
      },
    });
  });
});
