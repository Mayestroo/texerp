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

interface PendingEntryView {
  id: string;
  worker_id: string;
  operation_id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPICIOUS';
  worker: {
    id: string;
    full_name: string;
    worker_code: string;
  };
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
}

interface PendingBody {
  success: boolean;
  data: PendingEntryView[];
}

describe('Foreman Pending Approval Queue', () => {
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
  const foremanCId = randomUUID();
  const workerA1Id = randomUUID();
  const workerA2Id = randomUUID();
  const workerB1Id = randomUUID();
  const workerB2Id = randomUUID();

  const directorBId = randomUUID();
  const foremanB2Id = randomUUID();
  const workerTB1Id = randomUUID();
  const workerTB2Id = randomUUID();

  const departmentAId = randomUUID();
  const departmentA2Id = randomUUID();
  const departmentBId = randomUUID();

  const operationA1Id = randomUUID();
  const operationA2Id = randomUUID();
  const operationA3Id = randomUUID();
  const operationBId = randomUUID();

  const foremanAAssignmentA1Id = randomUUID();
  const foremanAAssignmentA2Id = randomUUID();
  const foremanBAssignmentB1Id = randomUUID();
  const foremanBAssignmentB2Id = randomUUID();
  const foremanBAssignmentTB1Id = randomUUID();
  const foremanBAssignmentTB2Id = randomUUID();

  const pendingA1Id = randomUUID();
  const pendingA2Id = randomUUID();
  const pendingA3Id = randomUUID();
  const pendingA4Id = randomUUID();
  const pendingA5Id = randomUUID();
  const approvedA6Id = randomUUID();
  const approvedA7Id = randomUUID();
  const pendingB1Id = randomUUID();
  const pendingB2Id = randomUUID();
  const pendingB3Id = randomUUID();
  const pendingTB1Id = randomUUID();
  const pendingTB2Id = randomUUID();
  const pendingTB3Id = randomUUID();

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
  let foremanCToken: string;

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
      [tenantAId, 'Pending Queue Tenant A', `pending-a-${tenantAId}`],
    );
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, $2, $3)`,
      [tenantBId, 'Pending Queue Tenant B', `pending-b-${tenantBId}`],
    );

    const users: [string, string, string, string, string, string][] = [
      [directorAId, tenantAId, phoneFor(suffixA, 1), 'Director A', 'DA-1', 'DIRECTOR'],
      [foremanAId, tenantAId, phoneFor(suffixA, 2), 'Foreman A', 'FA-1', 'FOREMAN'],
      [foremanBId, tenantAId, phoneFor(suffixA, 3), 'Foreman B', 'FB-1', 'FOREMAN'],
      [foremanCId, tenantAId, phoneFor(suffixA, 4), 'Foreman C', 'FC-1', 'FOREMAN'],
      [workerA1Id, tenantAId, phoneFor(suffixA, 5), 'Worker A1', 'WA1-1', 'WORKER'],
      [workerA2Id, tenantAId, phoneFor(suffixA, 6), 'Worker A2', 'WA2-1', 'WORKER'],
      [workerB1Id, tenantAId, phoneFor(suffixA, 7), 'Worker B1', 'WB1-1', 'WORKER'],
      [workerB2Id, tenantAId, phoneFor(suffixA, 8), 'Worker B2', 'WB2-1', 'WORKER'],
      [directorBId, tenantBId, phoneFor(suffixB, 1), 'Director B', 'DB-1', 'DIRECTOR'],
      [foremanB2Id, tenantBId, phoneFor(suffixB, 2), 'Foreman B2', 'FBT-1', 'FOREMAN'],
      [workerTB1Id, tenantBId, phoneFor(suffixB, 3), 'Worker TB1', 'WTB1-1', 'WORKER'],
      [workerTB2Id, tenantBId, phoneFor(suffixB, 4), 'Worker TB2', 'WTB2-1', 'WORKER'],
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
      `INSERT INTO departments
       (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Pending Line A', 'PL-A', $3, true)`,
      [departmentAId, tenantAId, foremanAId],
    );
    await admin.query(
      `INSERT INTO departments
       (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Pending Line B', 'PL-B', $3, true)`,
      [departmentA2Id, tenantAId, foremanBId],
    );
    await admin.query(
      `INSERT INTO departments
       (id, tenant_id, name, code, foreman_id, is_active)
       VALUES ($1, $2, 'Pending Line TB', 'PL-TB', $3, true)`,
      [departmentBId, tenantBId, foremanB2Id],
    );

    const assignments: [string, string, string, string, string, string][] = [
      [foremanAAssignmentA1Id, tenantAId, workerA1Id, foremanAId, departmentAId, directorAId],
      [foremanAAssignmentA2Id, tenantAId, workerA2Id, foremanAId, departmentAId, directorAId],
      [foremanBAssignmentB1Id, tenantAId, workerB1Id, foremanBId, departmentA2Id, directorAId],
      [foremanBAssignmentB2Id, tenantAId, workerB2Id, foremanBId, departmentA2Id, directorAId],
      [foremanBAssignmentTB1Id, tenantBId, workerTB1Id, foremanB2Id, departmentBId, directorBId],
      [foremanBAssignmentTB2Id, tenantBId, workerTB2Id, foremanB2Id, departmentBId, directorBId],
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
        pendingA1Id,
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
        pendingA2Id,
        tenantAId,
        workerA1Id,
        operationA2Id,
        15,
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
        pendingA3Id,
        tenantAId,
        workerA2Id,
        operationA1Id,
        20,
        '2026-07-12',
        'PENDING',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T08:00:00.000Z',
        '2026-07-10T08:00:00.000Z',
      ],
      [
        pendingA4Id,
        tenantAId,
        workerA2Id,
        operationA2Id,
        25,
        '2026-07-13',
        'PENDING',
        "Qo'l tikish",
        'OP-002',
        52000,
        'UZS',
        null,
        '2026-07-10T07:00:00.000Z',
        '2026-07-10T07:00:00.000Z',
      ],
      [
        pendingA5Id,
        tenantAId,
        workerA1Id,
        operationA3Id,
        30,
        '2026-07-14',
        'PENDING',
        'Dazmol tikish',
        'OP-003',
        30000,
        'UZS',
        null,
        '2026-07-10T06:00:00.000Z',
        '2026-07-10T06:00:00.000Z',
      ],
      [
        approvedA6Id,
        tenantAId,
        workerA1Id,
        operationA1Id,
        40,
        '2026-07-15',
        'APPROVED',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-09T10:00:00.000Z',
        '2026-07-09T10:00:00.000Z',
      ],
      [
        approvedA7Id,
        tenantAId,
        workerA2Id,
        operationA1Id,
        50,
        '2026-07-16',
        'APPROVED',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-09T09:00:00.000Z',
        '2026-07-09T09:00:00.000Z',
      ],
      [
        pendingB1Id,
        tenantAId,
        workerB1Id,
        operationA1Id,
        5,
        '2026-07-10',
        'PENDING',
        'Yoqa tikish',
        'OP-001',
        45000,
        'UZS',
        null,
        '2026-07-10T05:00:00.000Z',
        '2026-07-10T05:00:00.000Z',
      ],
      [
        pendingB2Id,
        tenantAId,
        workerB2Id,
        operationA1Id,
        6,
        '2026-07-10',
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
        pendingB3Id,
        tenantAId,
        workerB1Id,
        operationA2Id,
        7,
        '2026-07-11',
        'PENDING',
        "Qo'l tikish",
        'OP-002',
        52000,
        'UZS',
        null,
        '2026-07-10T03:00:00.000Z',
        '2026-07-10T03:00:00.000Z',
      ],
      [
        pendingTB1Id,
        tenantBId,
        workerTB1Id,
        operationBId,
        8,
        '2026-07-10',
        'PENDING',
        'Other Tenant Operation',
        'OP-OTHER',
        1,
        'UZS',
        null,
        '2026-07-10T02:00:00.000Z',
        '2026-07-10T02:00:00.000Z',
      ],
      [
        pendingTB2Id,
        tenantBId,
        workerTB2Id,
        operationBId,
        9,
        '2026-07-10',
        'PENDING',
        'Other Tenant Operation',
        'OP-OTHER',
        1,
        'UZS',
        null,
        '2026-07-10T01:00:00.000Z',
        '2026-07-10T01:00:00.000Z',
      ],
      [
        pendingTB3Id,
        tenantBId,
        workerTB1Id,
        operationBId,
        10,
        '2026-07-09',
        'PENDING',
        'Other Tenant Operation',
        'OP-OTHER',
        1,
        'UZS',
        null,
        '2026-07-10T00:00:00.000Z',
        '2026-07-10T00:00:00.000Z',
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
    foremanBToken = await login(phoneFor(suffixB, 2));
    foremanCToken = await login(phoneFor(suffixA, 4));
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

  it('foreman sees PENDING entries for their assigned workers only', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    expect(body.success).toBe(true);
    expect(body.data).toHaveLength(5);
    expect(body.data.map((entry) => entry.id).sort()).toEqual(
      [
        pendingA1Id,
        pendingA2Id,
        pendingA3Id,
        pendingA4Id,
        pendingA5Id,
      ].sort(),
    );

    const workerIds = body.data.map((entry) => entry.worker_id);
    expect(workerIds).toEqual(
      expect.arrayContaining([workerA1Id, workerA2Id]),
    );
    expect(workerIds).not.toEqual(
      expect.arrayContaining([workerB1Id, workerB2Id]),
    );

    for (const entry of body.data) {
      expect(entry.status).toBe('PENDING');
      expect(entry.worker).toEqual({
        id: entry.worker_id,
        full_name: expect.any(String) as string,
        worker_code: expect.any(String) as string,
      });
      expect(entry.operation).toEqual({
        id: entry.operation_id,
        name: entry.operation_name_snapshot,
        unit: expect.stringMatching(/^(PIECE|METER|PAIR)$/) as
          | 'PIECE'
          | 'METER'
          | 'PAIR',
      });
      expect(entry.submitted_at).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    }
  });

  it('orders pending entries by submitted_at descending', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    expect(body.data.map((entry) => entry.id)).toEqual([
      pendingA1Id,
      pendingA2Id,
      pendingA3Id,
      pendingA4Id,
      pendingA5Id,
    ]);
  });

  it('foreman does NOT see PENDING entries for workers assigned to other foremen', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    const ids = body.data.map((entry) => entry.id);
    expect(ids).not.toContain(pendingB1Id);
    expect(ids).not.toContain(pendingB2Id);
    expect(ids).not.toContain(pendingB3Id);
  });

  it('foreman does NOT see APPROVED or REJECTED entries', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanAToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    expect(body.data).toHaveLength(5);
    for (const entry of body.data) {
      expect(entry.status).toBe('PENDING');
    }
    const ids = body.data.map((entry) => entry.id);
    expect(ids).not.toContain(approvedA6Id);
    expect(ids).not.toContain(approvedA7Id);
  });

  it('returns empty data when foreman has no assigned workers or no pending entries', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanCToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    expect(body.success).toBe(true);
    expect(body.data).toEqual([]);
  });

  it('non-FOREMAN roles get 403', async () => {
    await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${directorAToken}`)
      .expect(403);
  });

  it('cross-tenant isolation is enforced by RLS', async () => {
    const response = await request(server)
      .get('/api/v1/production/entries/foreman/pending')
      .set('Authorization', `Bearer ${foremanBToken}`)
      .expect(200);

    const body = response.body as PendingBody;
    expect(body.success).toBe(true);
    expect(body.data).toHaveLength(3);
    expect(body.data.map((entry) => entry.id).sort()).toEqual(
      [pendingTB1Id, pendingTB2Id, pendingTB3Id].sort(),
    );
    for (const entry of body.data) {
      expect(entry.status).toBe('PENDING');
      expect([workerTB1Id, workerTB2Id]).toContain(entry.worker_id);
    }
  });
});
