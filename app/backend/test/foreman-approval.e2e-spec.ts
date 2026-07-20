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

interface EntryBody {
  success: boolean;
  data: {
    id: string;
    status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPICIOUS';
    worker_id?: string;
    operation_id?: string;
    operation: {
      id: string;
      name: string;
      unit: 'PIECE' | 'METER' | 'PAIR';
    };
    quantity_submitted: number;
    quantity_approved?: number | null;
    record_date: string;
    approved_at?: string | null;
    rejected_at?: string | null;
    rejection_reason?: string | null;
    foreman_note?: string | null;
    correction_comment?: string | null;
  };
}

interface AuditEventRow {
  action: string;
  before_state: Record<string, unknown> | null;
  after_state: Record<string, unknown>;
}

interface ProductionEntryRow {
  id: string;
  status: string;
  quantity: number;
  approved_by: string | null;
  rejected_by: string | null;
  approved_at: Date | null;
  rejected_at: Date | null;
  rejection_reason: string | null;
  foreman_note: string | null;
  correction_comment: string | null;
}

describe('Foreman Approval', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });

  const tenantAId = randomUUID();
  const tenantBId = randomUUID();

  const directorAId = randomUUID();
  const foremanAId = randomUUID();
  const foremanBId = randomUUID();
  const workerA1Id = randomUUID();
  const workerA2Id = randomUUID();
  const workerB1Id = randomUUID();

  const directorBId = randomUUID();
  const foremanB2Id = randomUUID();
  const workerBTId = randomUUID();

  const departmentAId = randomUUID();
  const departmentBId = randomUUID();
  const departmentB2Id = randomUUID();

  const operationA1Id = randomUUID();
  const operationA2Id = randomUUID();
  const operationA3Id = randomUUID();
  const operationBId = randomUUID();

  const assignmentA1Id = randomUUID();
  const assignmentA2Id = randomUUID();
  const assignmentB1Id = randomUUID();
  const assignmentB2Id = randomUUID();
  const assignmentTBId = randomUUID();

  const w1Pending1Id = randomUUID();
  const w1Pending2Id = randomUUID();
  const w1ApprovedId = randomUUID();
  const w2PendingId = randomUUID();
  const foremanBPendingId = randomUUID();
  const w1BulkPendingId = randomUUID();
  const w2BulkPendingId = randomUUID();
  const tenantBPendingId = randomUUID();

  const suffixA = (
    Number.parseInt(tenantAId.replaceAll('-', '').slice(0, 10), 16) % 10_000_000
  )
    .toString()
    .padStart(7, '0');
  const suffixB = (
    Number.parseInt(tenantBId.replaceAll('-', '').slice(0, 10), 16) % 10_000_000
  )
    .toString()
    .padStart(7, '0');
  const phoneFor = (tenantSuffix: string, sequence: number): string =>
    `+998${tenantSuffix}${sequence.toString().padStart(2, '0')}`;

  let app: INestApplication;
  let server: Server;
  let directorAToken: string;
  let foremanAToken: string;
  let foremanBToken: string;

  async function login(phone: string): Promise<string> {
    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '4826' })
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
      `INSERT INTO tenants (id, name, slug) VALUES ($1, $2, $3)`,
      [tenantAId, 'Approval Tenant A', `approval-a-${tenantAId}`],
    );
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, $2, $3)`,
      [tenantBId, 'Approval Tenant B', `approval-b-${tenantBId}`],
    );

    const users: [string, string, string, string, string, string][] = [
      [directorAId, tenantAId, phoneFor(suffixA, 1), 'Director A', 'DA-1', 'DIRECTOR'],
      [foremanAId, tenantAId, phoneFor(suffixA, 2), 'Foreman A', 'FA-1', 'FOREMAN'],
      [foremanBId, tenantAId, phoneFor(suffixA, 3), 'Foreman B', 'FB-1', 'FOREMAN'],
      [workerA1Id, tenantAId, phoneFor(suffixA, 4), 'Worker A1', 'WA1-1', 'WORKER'],
      [workerA2Id, tenantAId, phoneFor(suffixA, 5), 'Worker A2', 'WA2-1', 'WORKER'],
      [workerB1Id, tenantAId, phoneFor(suffixA, 6), 'Worker B1', 'WB1-1', 'WORKER'],
      [directorBId, tenantBId, phoneFor(suffixB, 1), 'Director B', 'DB-1', 'DIRECTOR'],
      [foremanB2Id, tenantBId, phoneFor(suffixB, 2), 'Foreman B2', 'FBT-1', 'FOREMAN'],
      [workerBTId, tenantBId, phoneFor(suffixB, 3), 'Worker BT', 'WBT-1', 'WORKER'],
    ];
    for (const [id, tenantId, phone, fullName, workerCode, role] of users) {
      await admin.query(
        `INSERT INTO users
         (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE')`,
        [id, tenantId, phone, pinHash, fullName, workerCode, role],
      );
    }

    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Approval Line A', 'AL-A', $3, true)`,
      [departmentAId, tenantAId, foremanAId],
    );
    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Approval Line B', 'AL-B', $3, true)`,
      [departmentBId, tenantAId, foremanBId],
    );
    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Approval Line TB', 'AL-TB', $3, true)`,
      [departmentB2Id, tenantBId, foremanB2Id],
    );

    const assignments: [string, string, string, string, string, string][] = [
      [assignmentA1Id, tenantAId, workerA1Id, foremanAId, departmentAId, directorAId],
      [assignmentA2Id, tenantAId, workerA2Id, foremanAId, departmentAId, directorAId],
      [assignmentB1Id, tenantAId, workerB1Id, foremanBId, departmentBId, directorAId],
      [assignmentTBId, tenantBId, workerBTId, foremanB2Id, departmentB2Id, directorBId],
    ];
    for (const [id, tenantId, workerId, foremanId, departmentId, assignedBy] of assignments) {
      await admin.query(
        `INSERT INTO foreman_assignments
         (id, tenant_id, worker_id, foreman_id, department_id, assigned_by)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [id, tenantId, workerId, foremanId, departmentId, assignedBy],
      );
    }

    const operations: [string, string, string, string, string, number, number, string][] = [
      [operationA1Id, tenantAId, 'Yoqa tikish', 'OP-001', 'PIECE', 45000, 1, directorAId],
      [operationA2Id, tenantAId, "Qo'l tikish", 'OP-002', 'METER', 52000, 2, directorAId],
      [operationA3Id, tenantAId, 'Dazmol tikish', 'OP-003', 'PAIR', 30000, 3, directorAId],
      [operationBId, tenantBId, 'Other Tenant Operation', 'OP-OTHER', 'PIECE', 1, 0, directorBId],
    ];
    for (const [id, tenantId, name, code, unit, unitPrice, sortOrder, createdBy] of operations) {
      await admin.query(
        `INSERT INTO operations
         (id, tenant_id, name, code, unit, unit_price, sort_order, is_active, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, true, $8)`,
        [id, tenantId, name, code, unit, unitPrice, sortOrder, createdBy],
      );
    }

    const entries: [
      string,
      string,
      string,
      string,
      number,
      string,
      string,
      string,
      string,
      number,
      string,
      null,
      string,
      string,
    ][] = [
      [
        w1Pending1Id,
        tenantAId,
        workerA1Id,
        operationA1Id,
        10,
        '2026-07-10',
        'PENDING',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T10:00:00.000Z',
        '2026-07-10T10:00:00.000Z',
      ],
      [
        w1Pending2Id,
        tenantAId,
        workerA1Id,
        operationA2Id,
        20,
        '2026-07-11',
        'PENDING',
        "Qo'l tikish",
        'OP-002',
        52000,
        'UZS',
        null,
        '2026-07-10T09:00:00.000Z',
        '2026-07-10T09:00:00.000Z',
      ],
      [
        w1ApprovedId,
        tenantAId,
        workerA1Id,
        operationA1Id,
        30,
        '2026-07-12',
        'APPROVED',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T08:00:00.000Z',
        '2026-07-10T08:00:00.000Z',
      ],
      [
        w2PendingId,
        tenantAId,
        workerA2Id,
        operationA3Id,
        15,
        '2026-07-13',
        'PENDING',
        'Dazmol tikish',
        'OP-003',
        30000,
        'UZS',
        null,
        '2026-07-10T07:00:00.000Z',
        '2026-07-10T07:00:00.000Z',
      ],
      [
        foremanBPendingId,
        tenantAId,
        workerB1Id,
        operationA1Id,
        12,
        '2026-07-10',
        'PENDING',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T06:00:00.000Z',
        '2026-07-10T06:00:00.000Z',
      ],
      [
        w1BulkPendingId,
        tenantAId,
        workerA1Id,
        operationA2Id,
        40,
        '2026-07-14',
        'PENDING',
        "Qo'l tikish",
        'OP-002',
        52000,
        'UZS',
        null,
        '2026-07-10T05:00:00.000Z',
        '2026-07-10T05:00:00.000Z',
      ],
      [
        w2BulkPendingId,
        tenantAId,
        workerA2Id,
        operationA1Id,
        22,
        '2026-07-15',
        'PENDING',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T04:00:00.000Z',
        '2026-07-10T04:00:00.000Z',
      ],
      [
        tenantBPendingId,
        tenantBId,
        workerBTId,
        operationBId,
        5,
        '2026-07-10',
        'PENDING',
        'Other Tenant Operation',
        'OP-OTHER',
        1,
        'UZS',
        null,
        '2026-07-10T05:00:00.000Z',
        '2026-07-10T05:00:00.000Z',
      ],
    ];
    for (const [
      id,
      tenantId,
      workerId,
      operationId,
      quantity,
      recordDate,
      status,
      operationNameSnapshot,
      operationCodeSnapshot,
      unitPriceSnapshot,
      currencySnapshot,
      workerNote,
      createdAt,
      updatedAt,
    ] of entries) {
      await admin.query(
        `INSERT INTO production_entries
         (id, tenant_id, worker_id, operation_id, quantity, record_date, status,
          operation_name_snapshot, operation_code_snapshot, unit_price_snapshot,
          currency_snapshot, worker_note, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
        [
          id,
          tenantId,
          workerId,
          operationId,
          quantity,
          recordDate,
          status,
          operationNameSnapshot,
          operationCodeSnapshot,
          unitPriceSnapshot,
          currencySnapshot,
          workerNote,
          createdAt,
          updatedAt,
        ],
      );
    }

    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication();
    app.useLogger(false);
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;

    directorAToken = await login(phoneFor(suffixA, 1));
    foremanAToken = await login(phoneFor(suffixA, 2));
    foremanBToken = await login(phoneFor(suffixA, 3));
  }, 30_000);

  afterAll(async () => {
    await admin.query(
      'DELETE FROM production_entries WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM audit_events WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM foreman_assignments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM operation_price_history WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM operations WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM departments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM user_sessions WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM users WHERE tenant_id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    await admin.query(
      'DELETE FROM tenants WHERE id = ANY($1::uuid[])',
      [[tenantAId, tenantBId]],
    );
    if (app) {
      await app.close();
    }
    await admin.end();
  });

  it('foreman can approve a PENDING entry for their worker', async () => {
    const response = await request(server)
      .post(`/api/v1/production/entries/${w1Pending1Id}/approve`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({})
      .expect(200);

    const body = response.body as EntryBody;
    expect(body.success).toBe(true);
    expect(body.data).toMatchObject({
      id: w1Pending1Id,
      status: 'APPROVED',
      quantity_submitted: 10,
      quantity_approved: 10,
    });
    expect(body.data.approved_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);

    const rows = await admin.query<ProductionEntryRow>(
      `SELECT id, status, quantity, approved_by, approved_at
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2`,
      [tenantAId, w1Pending1Id],
    );
    expect(rows.rows[0]).toMatchObject({
      status: 'APPROVED',
      quantity: 10,
      approved_by: foremanAId,
    });
    expect(rows.rows[0].approved_at).toBeInstanceOf(Date);

    const audits = await admin.query<AuditEventRow>(
      `SELECT action, before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'PRODUCTION_ENTRY' AND aggregate_id = $2`,
      [tenantAId, w1Pending1Id],
    );
    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].action).toBe('ENTRY_APPROVED');
    expect(audits.rows[0].before_state).toMatchObject({ status: 'PENDING' });
    expect(audits.rows[0].after_state).toMatchObject({ status: 'APPROVED' });
  });

  it('foreman gets 403 when trying to approve another foreman worker', async () => {
    const response = await request(server)
      .post(`/api/v1/production/entries/${foremanBPendingId}/approve`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({})
      .expect(403);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'FOREMAN_NOT_ASSIGNED' },
    });
  });

  it('foreman gets 400 when approving an already APPROVED entry', async () => {
    const response = await request(server)
      .post(`/api/v1/production/entries/${w1ApprovedId}/approve`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({})
      .expect(400);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'ENTRY_NOT_PENDING' },
    });
  });

  it('foreman can reject with reason', async () => {
    const response = await request(server)
      .post(`/api/v1/production/entries/${w2PendingId}/reject`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({ reason: 'Wrong quantity', foreman_note: 'Check the bundle' })
      .expect(200);

    const body = response.body as EntryBody;
    expect(body.success).toBe(true);
    expect(body.data).toMatchObject({
      id: w2PendingId,
      status: 'REJECTED',
      rejection_reason: 'Wrong quantity',
      foreman_note: 'Check the bundle',
    });
    expect(body.data.rejected_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);

    const rows = await admin.query<ProductionEntryRow>(
      `SELECT id, status, rejected_by, rejected_at, rejection_reason, foreman_note
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2`,
      [tenantAId, w2PendingId],
    );
    expect(rows.rows[0]).toMatchObject({
      status: 'REJECTED',
      rejected_by: foremanAId,
      rejection_reason: 'Wrong quantity',
      foreman_note: 'Check the bundle',
    });
    expect(rows.rows[0].rejected_at).toBeInstanceOf(Date);

    const audits = await admin.query<AuditEventRow>(
      `SELECT action, before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'PRODUCTION_ENTRY' AND aggregate_id = $2`,
      [tenantAId, w2PendingId],
    );
    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].action).toBe('ENTRY_REJECTED');
    expect(audits.rows[0].before_state).toMatchObject({ status: 'PENDING' });
    expect(audits.rows[0].after_state).toMatchObject({
      status: 'REJECTED',
      reason: 'Wrong quantity',
      foreman_note: 'Check the bundle',
    });
  });

  it('foreman can correct quantity and approve', async () => {
    const response = await request(server)
      .patch(`/api/v1/production/entries/${w1Pending2Id}/correct-approve`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({ corrected_quantity: 18, correction_comment: 'Counted twice' })
      .expect(200);

    const body = response.body as EntryBody;
    expect(body.success).toBe(true);
    expect(body.data).toMatchObject({
      id: w1Pending2Id,
      status: 'APPROVED',
      quantity_submitted: 18,
      quantity_approved: 18,
      correction_comment: 'Counted twice',
    });
    expect(body.data.approved_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);

    const rows = await admin.query<ProductionEntryRow>(
      `SELECT id, status, quantity, correction_comment, approved_by
       FROM production_entries
       WHERE tenant_id = $1 AND id = $2`,
      [tenantAId, w1Pending2Id],
    );
    expect(rows.rows[0]).toMatchObject({
      status: 'APPROVED',
      quantity: 18,
      correction_comment: 'Counted twice',
      approved_by: foremanAId,
    });

    const audits = await admin.query<AuditEventRow>(
      `SELECT action, before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_type = 'PRODUCTION_ENTRY' AND aggregate_id = $2`,
      [tenantAId, w1Pending2Id],
    );
    expect(audits.rows).toHaveLength(1);
    expect(audits.rows[0].action).toBe('ENTRY_CORRECTED');
    expect(audits.rows[0].before_state).toMatchObject({ quantity: 20 });
    expect(audits.rows[0].after_state).toMatchObject({
      quantity: 18,
      correction_comment: 'Counted twice',
    });
  });

  it('bulk approve: all succeed returns 200 with approved_count', async () => {
    const response = await request(server)
      .post('/api/v1/production/entries/bulk-approve')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({ entry_ids: [w1BulkPendingId, w2BulkPendingId] })
      .expect(200);

    expect(response.body).toEqual({
      success: true,
      data: { approved_count: 2 },
    });

    const rows = await admin.query<{ status: string }>(
      `SELECT status FROM production_entries
       WHERE tenant_id = $1 AND id = ANY($2::uuid[])`,
      [tenantAId, [w1BulkPendingId, w2BulkPendingId]],
    );
    expect(rows.rows.every((r) => r.status === 'APPROVED')).toBe(true);
  });

  it('bulk approve: some fail returns 207 with skipped_entries', async () => {
    const response = await request(server)
      .post('/api/v1/production/entries/bulk-approve')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({ entry_ids: [w1ApprovedId, foremanBPendingId] })
      .expect(207);

    expect(response.body).toMatchObject({
      success: true,
      data: {
        approved_count: 0,
        skipped_entries: [
          { entry_id: w1ApprovedId, reason: 'ENTRY_NOT_PENDING' },
          { entry_id: foremanBPendingId, reason: 'FOREMAN_NOT_ASSIGNED' },
        ],
      },
    });
  });

  it('non-FOREMAN role gets 403', async () => {
    await request(server)
      .post(`/api/v1/production/entries/${foremanBPendingId}/approve`)
      .set('Authorization', `Bearer ${directorAToken}`)
      .send({})
      .expect(403);
  });

  it('cross-tenant entry ID returns 404', async () => {
    const response = await request(server)
      .post(`/api/v1/production/entries/${tenantBPendingId}/approve`)
      .set('Authorization', `Bearer ${foremanAToken}`)
      .send({})
      .expect(404);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'ENTRY_NOT_FOUND' },
    });
  });
});
