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

interface DepartmentBody {
  data: {
    id: string;
    name: string;
    code: string;
    is_active: boolean;
    foreman: { id: string; full_name: string } | null;
    worker_count: number;
  };
}

interface DepartmentListBody {
  data: DepartmentBody['data'][];
}

interface WorkerListBody {
  data: {
    id: string;
    full_name: string;
    worker_code: string;
    phone: string;
    role: 'WORKER';
    status: 'ACTIVE';
    avatar_url: string | null;
    department: { id: string; name: string } | null;
    foreman: { id: string; full_name: string } | null;
  }[];
}

describe('Organization Departments', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });
  const tenantId = randomUUID();
  const secondTenantId = randomUUID();
  const directorId = randomUUID();
  const foremanId = randomUUID();
  const replacementForemanId = randomUUID();
  const inactiveForemanId = randomUUID();
  const secondTenantForemanId = randomUUID();
  const workerId = randomUUID();
  const assignmentWorkerId = randomUUID();
  const visibleWorkerId = randomUUID();
  const sameNameWorkerFirstId = '00000000-0000-4000-8000-000000000001';
  const sameNameWorkerSecondId = '00000000-0000-4000-8000-000000000002';
  const endedAssignmentWorkerId = randomUUID();
  const otherForemanWorkerId = randomUUID();
  const inactiveWorkerId = randomUUID();
  const secondTenantWorkerId = randomUUID();
  const accountantId = randomUUID();
  const activeDepartmentId = randomUUID();
  const inactiveDepartmentId = randomUUID();
  const mutableDepartmentId = randomUUID();
  const secondTenantDepartmentId = randomUUID();
  const replacementDepartmentId = randomUUID();
  const noForemanDepartmentId = randomUUID();
  const inactiveForemanDepartmentId = randomUUID();
  const foremanAssignmentId = randomUUID();
  const runPhoneSuffix = (
    Number.parseInt(tenantId.replaceAll('-', '').slice(0, 10), 16) % 10_000_000
  )
    .toString()
    .padStart(7, '0');
  const testPhone = (sequence: number): string =>
    `+998${runPhoneSuffix}${sequence.toString().padStart(2, '0')}`;
  const directorPhone = testPhone(1);
  const foremanPhone = testPhone(2);
  const workerPhone = testPhone(3);
  const accountantPhone = testPhone(4);
  const replacementForemanPhone = testPhone(5);
  const inactiveForemanPhone = testPhone(6);
  const assignmentWorkerPhone = testPhone(7);
  const inactiveWorkerPhone = testPhone(8);
  const secondTenantWorkerPhone = testPhone(9);
  const visibleWorkerPhone = testPhone(10);
  const endedAssignmentWorkerPhone = testPhone(11);
  const otherForemanWorkerPhone = testPhone(12);
  const secondTenantForemanPhone = testPhone(13);
  const sameNameWorkerFirstPhone = testPhone(14);
  const sameNameWorkerSecondPhone = testPhone(15);
  let app: INestApplication;
  let server: Server;
  let directorToken: string;
  let foremanToken: string;
  let workerToken: string;
  let accountantToken: string;

  async function flushRedis(): Promise<void> {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.flushdb();
    await redis.quit();
  }

  async function login(phone: string): Promise<string> {
    const response = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone, pin: '4826' })
      .expect(200);
    return (response.body as LoginBody).data.access_token;
  }

  async function waitForBlockedWorkerLocks(
    blockerPid: number,
    observedPids: Set<number>,
  ): Promise<number[]> {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const result = await admin.query<{ pid: number }>(
        `SELECT pid
         FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND state = 'active'
           AND wait_event_type = 'Lock'
           AND pg_blocking_pids(pid) && $1::integer[]
           AND query ILIKE '%FROM users%'
         ORDER BY pid`,
        [[blockerPid, ...observedPids]],
      );
      for (const { pid } of result.rows) observedPids.add(pid);
      if (result.rows.length === 2) return result.rows.map(({ pid }) => pid);
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(
      'Timed out waiting for both Foreman Assignment requests to block',
    );
  }

  async function waitForAdvisoryLockWaiter(lockKey: number): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const result = await admin.query<{ pid: number }>(
        `SELECT pid
         FROM pg_locks
         WHERE locktype = 'advisory'
           AND classid = 0
           AND objid = $1
           AND objsubid = 1
           AND NOT granted
         LIMIT 1`,
        [lockKey],
      );
      if (result.rows[0]?.pid) return result.rows[0].pid;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(`Timed out waiting for advisory lock ${lockKey}`);
  }

  async function waitForBlockedQuery(
    blockerPid: number,
    queryFragment: string,
  ): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const result = await admin.query<{ pid: number }>(
        `SELECT pid
         FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND state = 'active'
           AND wait_event_type = 'Lock'
           AND $1::integer = ANY(pg_blocking_pids(pid))
           AND query ILIKE '%' || $2 || '%'
         LIMIT 1`,
        [blockerPid, queryFragment],
      );
      if (result.rows[0]?.pid) return result.rows[0].pid;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(
      `Timed out waiting for query blocked by PID ${blockerPid}: ${queryFragment}`,
    );
  }

  async function withTimeout<T>(
    promise: Promise<T>,
    message: string,
    timeoutMs = 5_000,
  ): Promise<T> {
    let timeout: NodeJS.Timeout | undefined;
    try {
      return await Promise.race([
        promise,
        new Promise<never>((_resolve, reject) => {
          timeout = setTimeout(() => reject(new Error(message)), timeoutMs);
        }),
      ]);
    } finally {
      if (timeout) clearTimeout(timeout);
    }
  }

  async function settleRequests(
    promises: Array<Promise<request.Response> | undefined>,
    timeoutMs = 2_000,
  ): Promise<void> {
    await withTimeout(
      Promise.allSettled(
        promises.filter(
          (promise): promise is Promise<request.Response> =>
            promise !== undefined,
        ),
      ),
      'Timed out settling concurrent Foreman Assignment requests',
      timeoutMs,
    );
  }

  async function terminateTestBackends(pids: Set<number>): Promise<void> {
    if (pids.size === 0) return;
    await admin.query(
      `SELECT pg_terminate_backend(pid)
       FROM unnest($1::integer[]) AS blocked(pid)`,
      [[...pids]],
    );
  }

  beforeAll(async () => {
    await flushRedis();
    await admin.connect();
    const pinHash = await bcrypt.hash('4826', 4);
    await admin.query(
      `INSERT INTO tenants (id, name, slug)
       VALUES ($1, 'Organization Tenant', $2),
              ($3, 'Second Organization Tenant', $4)`,
      [
        tenantId,
        `organization-${tenantId}`,
        secondTenantId,
        `organization-${secondTenantId}`,
      ],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $11, $3, 'Assignment Worker', 'OW-2', 'WORKER', 'ACTIVE'),
         ($4, $2, $12, $3, 'Inactive Worker', 'OW-3', 'WORKER', 'DEACTIVATED'),
         ($5, $6, $13, $3, 'Other Tenant Worker', 'OW-4', 'WORKER', 'ACTIVE'),
         ($7, $2, $14, $3, 'Alpha Assigned Worker', 'OW-5', 'WORKER', 'ACTIVE'),
         ($8, $2, $15, $3, 'Beta Ended Worker', 'OW-6', 'WORKER', 'ACTIVE'),
         ($9, $2, $16, $3, 'Gamma Other Foreman Worker', 'OW-7', 'WORKER', 'ACTIVE'),
         ($10, $6, $17, $3, 'Other Tenant Foreman', 'OF-4', 'FOREMAN', 'ACTIVE')`,
      [
        assignmentWorkerId,
        tenantId,
        pinHash,
        inactiveWorkerId,
        secondTenantWorkerId,
        secondTenantId,
        visibleWorkerId,
        endedAssignmentWorkerId,
        otherForemanWorkerId,
        secondTenantForemanId,
        assignmentWorkerPhone,
        inactiveWorkerPhone,
        secondTenantWorkerPhone,
        visibleWorkerPhone,
        endedAssignmentWorkerPhone,
        otherForemanWorkerPhone,
        secondTenantForemanPhone,
      ],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
        ($1, $2, $3, $4, 'Organization Director', 'OD-1', 'DIRECTOR', 'ACTIVE'),
        ($5, $2, $6, $4, 'Primary Foreman', 'OF-1', 'FOREMAN', 'ACTIVE'),
         ($7, $2, $13, $4, 'Replacement Foreman', 'OF-2', 'FOREMAN', 'ACTIVE'),
         ($8, $2, $14, $4, 'Inactive Foreman', 'OF-3', 'FOREMAN', 'DEACTIVATED'),
        ($9, $2, $10, $4, 'Organization Worker', 'OW-1', 'WORKER', 'ACTIVE'),
        ($11, $2, $12, $4, 'Organization Accountant', 'OA-1', 'ACCOUNTANT', 'ACTIVE')`,
      [
        directorId,
        tenantId,
        directorPhone,
        pinHash,
        foremanId,
        foremanPhone,
        replacementForemanId,
        inactiveForemanId,
        workerId,
        workerPhone,
        accountantId,
        accountantPhone,
        replacementForemanPhone,
        inactiveForemanPhone,
      ],
    );
    await admin.query(
      `INSERT INTO departments
        (id, tenant_id, name, code, foreman_id, is_active)
       VALUES
        ($1, $2, 'Active Department', 'ACTIVE', $3, true),
        ($4, $2, 'Inactive Department', 'INACTIVE', $3, false),
        ($5, $2, 'Mutable Department', 'MUTABLE', $3, true),
        ($6, $7, 'Other Tenant Department', 'OTHER', NULL, true),
        ($8, $2, 'Replacement Department', 'REPLACE', $9, true),
        ($10, $2, 'No Foreman Department', 'NO-FOREMAN', NULL, true),
        ($11, $2, 'Inactive Foreman Department', 'INACTIVE-F', $12, true)`,
      [
        activeDepartmentId,
        tenantId,
        foremanId,
        inactiveDepartmentId,
        mutableDepartmentId,
        secondTenantDepartmentId,
        secondTenantId,
        replacementDepartmentId,
        replacementForemanId,
        noForemanDepartmentId,
        inactiveForemanDepartmentId,
        inactiveForemanId,
      ],
    );
    await admin.query(
      `INSERT INTO foreman_assignments
        (id, tenant_id, worker_id, foreman_id, department_id, assigned_by, unassigned_at)
       VALUES
        ($1, $2, $3, $4, $5, $6, NULL),
        ($7, $2, $8, $4, $9, $6, NULL),
        ($10, $2, $11, $4, $9, $6, NOW()),
        ($12, $2, $13, $4, $9, $6, NULL),
        ($14, $2, $15, $16, $17, $6, NULL),
        ($18, $19, $20, $21, $22, $21, NULL)`,
      [
        foremanAssignmentId,
        tenantId,
        workerId,
        foremanId,
        mutableDepartmentId,
        directorId,
        randomUUID(),
        visibleWorkerId,
        activeDepartmentId,
        randomUUID(),
        endedAssignmentWorkerId,
        randomUUID(),
        inactiveWorkerId,
        randomUUID(),
        otherForemanWorkerId,
        replacementForemanId,
        replacementDepartmentId,
        randomUUID(),
        secondTenantId,
        secondTenantWorkerId,
        secondTenantForemanId,
        secondTenantDepartmentId,
      ],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $5, $3, 'Same Name Worker', 'OW-9', 'WORKER', 'ACTIVE'),
         ($4, $2, $6, $3, 'Same Name Worker', 'OW-8', 'WORKER', 'ACTIVE')`,
      [
        sameNameWorkerSecondId,
        tenantId,
        pinHash,
        sameNameWorkerFirstId,
        sameNameWorkerSecondPhone,
        sameNameWorkerFirstPhone,
      ],
    );
    await admin.query(
      `INSERT INTO foreman_assignments
        (id, tenant_id, worker_id, foreman_id, department_id, assigned_by)
       VALUES
        ($1, $2, $3, $4, $5, $6),
        ($7, $2, $8, $4, $5, $6)`,
      [
        randomUUID(),
        tenantId,
        sameNameWorkerSecondId,
        foremanId,
        activeDepartmentId,
        directorId,
        randomUUID(),
        sameNameWorkerFirstId,
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
    [directorToken, foremanToken, workerToken, accountantToken] =
      await Promise.all([
        login(directorPhone),
        login(foremanPhone),
        login(workerPhone),
        login(accountantPhone),
      ]);
  });

  afterAll(async () => {
    await admin.query(
      'DELETE FROM audit_events WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM user_sessions WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM foreman_assignments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query(
      'DELETE FROM departments WHERE tenant_id = ANY($1::uuid[])',
      [[tenantId, secondTenantId]],
    );
    await admin.query('DELETE FROM users WHERE tenant_id = ANY($1::uuid[])', [
      [tenantId, secondTenantId],
    ]);
    await admin.query('DELETE FROM tenants WHERE id = ANY($1::uuid[])', [
      [tenantId, secondTenantId],
    ]);
    await app.close();
    await admin.end();
  });

  it('lists active Departments for every authenticated role', async () => {
    for (const token of [
      directorToken,
      foremanToken,
      workerToken,
      accountantToken,
    ]) {
      const response = await request(server)
        .get('/api/v1/departments')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      const body = response.body as DepartmentListBody;
      expect(body.data.map((department) => department.id)).toEqual([
        activeDepartmentId,
        inactiveForemanDepartmentId,
        mutableDepartmentId,
        noForemanDepartmentId,
        replacementDepartmentId,
      ]);
      expect(body.data[0]).toMatchObject({
        id: activeDepartmentId,
        foreman: { id: foremanId, full_name: 'Primary Foreman' },
        worker_count: 4,
      });
      expect(
        body.data.find(({ id }) => id === mutableDepartmentId),
      ).toMatchObject({
        id: mutableDepartmentId,
        worker_count: 1,
      });
    }
  });

  it('lists only the authenticated Foreman active assigned Workers in stable order', async () => {
    const response = await request(server)
      .get('/api/v1/users/me/workers')
      .set('Authorization', `Bearer ${foremanToken}`)
      .expect(200);

    expect(response.body).toEqual({
      success: true,
      data: [
        {
          id: visibleWorkerId,
          full_name: 'Alpha Assigned Worker',
          worker_code: 'OW-5',
          phone: visibleWorkerPhone,
          role: 'WORKER',
          status: 'ACTIVE',
          avatar_url: null,
          department: { id: activeDepartmentId, name: 'Active Department' },
          foreman: { id: foremanId, full_name: 'Primary Foreman' },
        },
        {
          id: workerId,
          full_name: 'Organization Worker',
          worker_code: 'OW-1',
          phone: workerPhone,
          role: 'WORKER',
          status: 'ACTIVE',
          avatar_url: null,
          department: { id: mutableDepartmentId, name: 'Mutable Department' },
          foreman: { id: foremanId, full_name: 'Primary Foreman' },
        },
        {
          id: sameNameWorkerFirstId,
          full_name: 'Same Name Worker',
          worker_code: 'OW-8',
          phone: sameNameWorkerFirstPhone,
          role: 'WORKER',
          status: 'ACTIVE',
          avatar_url: null,
          department: { id: activeDepartmentId, name: 'Active Department' },
          foreman: { id: foremanId, full_name: 'Primary Foreman' },
        },
        {
          id: sameNameWorkerSecondId,
          full_name: 'Same Name Worker',
          worker_code: 'OW-9',
          phone: sameNameWorkerSecondPhone,
          role: 'WORKER',
          status: 'ACTIVE',
          avatar_url: null,
          department: { id: activeDepartmentId, name: 'Active Department' },
          foreman: { id: foremanId, full_name: 'Primary Foreman' },
        },
      ],
    } satisfies { success: true } & WorkerListBody);

    await request(server)
      .delete(`/api/v1/users/${visibleWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);

    const afterUnassignment = await request(server)
      .get('/api/v1/users/me/workers')
      .set('Authorization', `Bearer ${foremanToken}`)
      .expect(200);
    expect(
      (afterUnassignment.body as WorkerListBody).data.map(({ id }) => id),
    ).toEqual([workerId, sameNameWorkerFirstId, sameNameWorkerSecondId]);
  });

  it('forbids non-Foremen from listing a Foreman worker list', async () => {
    for (const token of [directorToken, accountantToken, workerToken]) {
      await request(server)
        .get('/api/v1/users/me/workers')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    }
  });

  it('includes inactive Departments only for literal true', async () => {
    const response = await request(server)
      .get('/api/v1/departments?include_inactive=true')
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    expect(
      (response.body as DepartmentListBody).data.map(({ id }) => id),
    ).toContain(inactiveDepartmentId);

    await request(server)
      .get('/api/v1/departments?include_inactive=false')
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    for (const value of ['1', 'yes', '']) {
      await request(server)
        .get(`/api/v1/departments?include_inactive=${value}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .expect(400);
    }
  });

  it('creates a Department with an active Foreman and audit metadata', async () => {
    const response = await request(server)
      .post('/api/v1/departments')
      .set('Authorization', `Bearer ${directorToken}`)
      .set('User-Agent', 'TexERP Organization E2E')
      .send({ name: 'Sewing Line 1', code: 'SL-1', foreman_id: foremanId })
      .expect(201);
    expect(response.body).toMatchObject({
      success: true,
      data: {
        name: 'Sewing Line 1',
        code: 'SL-1',
        is_active: true,
        foreman: { id: foremanId, full_name: 'Primary Foreman' },
        worker_count: 0,
      },
    });
    const department = (response.body as DepartmentBody).data;
    const audit = await admin.query<{
      actor_id: string;
      action: string;
      after_state: Record<string, unknown>;
      user_agent: string;
    }>(
      `SELECT actor_id, action, after_state, user_agent
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_id = $2`,
      [tenantId, department.id],
    );
    expect(audit.rows).toEqual([
      {
        actor_id: directorId,
        action: 'DEPARTMENT_CREATED',
        after_state: {
          id: department.id,
          name: 'Sewing Line 1',
          code: 'SL-1',
          foreman_id: foremanId,
          is_active: true,
        },
        user_agent: 'TexERP Organization E2E',
      },
    ]);
  });

  it('patches every mutable Department field', async () => {
    const assignmentBefore = await admin.query<{
      foreman_id: string;
      department_id: string;
      assigned_at: string;
      unassigned_at: string | null;
      is_active: boolean;
    }>(
      `SELECT foreman_id, department_id, assigned_at::text,
              unassigned_at::text, unassigned_at IS NULL AS is_active
       FROM foreman_assignments
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, foremanAssignmentId],
    );
    expect(assignmentBefore.rows).toHaveLength(1);
    expect(typeof assignmentBefore.rows[0]?.assigned_at).toBe('string');
    expect(assignmentBefore.rows[0]).toMatchObject({
      foreman_id: foremanId,
      department_id: mutableDepartmentId,
      unassigned_at: null,
      is_active: true,
    });

    const response = await request(server)
      .patch(`/api/v1/departments/${mutableDepartmentId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .set('User-Agent', 'TexERP Organization Department Update E2E')
      .send({
        name: 'Updated Department',
        code: 'UPDATED',
        foreman_id: replacementForemanId,
        is_active: false,
      })
      .expect(200);
    expect(response.body).toMatchObject({
      success: true,
      data: {
        id: mutableDepartmentId,
        name: 'Updated Department',
        code: 'UPDATED',
        is_active: false,
        foreman: {
          id: replacementForemanId,
          full_name: 'Replacement Foreman',
        },
        worker_count: 1,
      },
    });

    const audit = await admin.query<{
      tenant_id: string;
      aggregate_type: string;
      aggregate_id: string;
      action: string;
      actor_id: string;
      actor_role: string;
      before_state: Record<string, unknown>;
      after_state: Record<string, unknown>;
      ip_address: string;
      user_agent: string;
    }>(
      `SELECT tenant_id, aggregate_type, aggregate_id, action, actor_id,
              actor_role, before_state, after_state, ip_address::text, user_agent
       FROM audit_events
       WHERE tenant_id = $1 AND aggregate_id = $2`,
      [tenantId, mutableDepartmentId],
    );
    expect(audit.rows).toEqual([
      {
        tenant_id: tenantId,
        aggregate_type: 'DEPARTMENT',
        aggregate_id: mutableDepartmentId,
        action: 'DEPARTMENT_UPDATED',
        actor_id: directorId,
        actor_role: 'DIRECTOR',
        before_state: {
          name: 'Mutable Department',
          code: 'MUTABLE',
          foreman_id: foremanId,
          is_active: true,
        },
        after_state: {
          name: 'Updated Department',
          code: 'UPDATED',
          foreman_id: replacementForemanId,
          is_active: false,
        },
        ip_address: '::ffff:127.0.0.1/128',
        user_agent: 'TexERP Organization Department Update E2E',
      },
    ]);

    const assignmentAfter = await admin.query<{
      foreman_id: string;
      department_id: string;
      assigned_at: string;
      unassigned_at: string | null;
      is_active: boolean;
    }>(
      `SELECT foreman_id, department_id, assigned_at::text,
              unassigned_at::text, unassigned_at IS NULL AS is_active
       FROM foreman_assignments
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, foremanAssignmentId],
    );
    expect(assignmentAfter.rows).toEqual(assignmentBefore.rows);
  });

  it('does not update or audit an unchanged Department PATCH', async () => {
    const before = await admin.query<{
      name: string;
      code: string;
      foreman_id: string;
      is_active: boolean;
      updated_at: Date;
      audit_count: number;
    }>(
      `SELECT d.name, d.code, d.foreman_id, d.is_active, d.updated_at,
              count(a.id)::integer AS audit_count
       FROM departments d
       LEFT JOIN audit_events a
         ON a.tenant_id = d.tenant_id
        AND a.aggregate_id = d.id
        AND a.action = 'DEPARTMENT_UPDATED'
       WHERE d.tenant_id = $1 AND d.id = $2
       GROUP BY d.id`,
      [tenantId, activeDepartmentId],
    );

    const response = await request(server)
      .patch(`/api/v1/departments/${activeDepartmentId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({
        name: 'Active Department',
        code: 'ACTIVE',
        foreman_id: foremanId,
        is_active: true,
      })
      .expect(200);
    expect(response.body).toMatchObject({
      success: true,
      data: {
        id: activeDepartmentId,
        name: 'Active Department',
        code: 'ACTIVE',
        foreman: { id: foremanId },
        is_active: true,
      },
    });

    const after = await admin.query<{
      name: string;
      code: string;
      foreman_id: string;
      is_active: boolean;
      updated_at: Date;
      audit_count: number;
    }>(
      `SELECT d.name, d.code, d.foreman_id, d.is_active, d.updated_at,
              count(a.id)::integer AS audit_count
       FROM departments d
       LEFT JOIN audit_events a
         ON a.tenant_id = d.tenant_id
        AND a.aggregate_id = d.id
        AND a.action = 'DEPARTMENT_UPDATED'
       WHERE d.tenant_id = $1 AND d.id = $2
       GROUP BY d.id`,
      [tenantId, activeDepartmentId],
    );
    expect(after.rows).toEqual(before.rows);
  });

  it('rejects empty, unknown, and invalid Department inputs', async () => {
    const bodies: Record<string, unknown>[] = [
      {},
      { unknown: true },
      { name: '' },
      { code: '' },
      { foreman_id: 'not-a-uuid' },
      { is_active: 'true' },
    ];
    for (const body of bodies) {
      const response = await request(server)
        .patch(`/api/v1/departments/${activeDepartmentId}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send(body)
        .expect(400);
      expect(response.body).toMatchObject({ success: false, error: {} });
    }

    const nullForemanResponse = await request(server)
      .patch(`/api/v1/departments/${activeDepartmentId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ foreman_id: null })
      .expect(400);
    expect(nullForemanResponse.body).toMatchObject({
      success: false,
      error: { code: 'VALIDATION_ERROR' },
    });

    await request(server)
      .patch('/api/v1/departments/not-a-uuid')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Invalid Path' })
      .expect(400);
    await request(server)
      .post('/api/v1/departments')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({
        name: 'Unknown Field',
        code: 'UNKNOWN',
        foreman_id: foremanId,
        x: 1,
      })
      .expect(400);
  });

  it('conceals absent, cross-Tenant, inactive, and wrong-role selections', async () => {
    for (const foreman_id of [
      inactiveForemanId,
      workerId,
      secondTenantForemanId,
      randomUUID(),
    ]) {
      const response = await request(server)
        .post('/api/v1/departments')
        .set('Authorization', `Bearer ${directorToken}`)
        .send({
          name: `Rejected ${foreman_id}`,
          code: foreman_id.slice(0, 8),
          foreman_id,
        })
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'FOREMAN_NOT_FOUND' },
      });
    }

    const crossTenantForeman = await request(server)
      .patch(`/api/v1/departments/${activeDepartmentId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ foreman_id: secondTenantForemanId })
      .expect(404);
    expect(crossTenantForeman.body).toEqual({
      success: false,
      error: { code: 'FOREMAN_NOT_FOUND', message: 'Brigadir topilmadi' },
    });

    const response = await request(server)
      .patch(`/api/v1/departments/${secondTenantDepartmentId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Concealed Update' })
      .expect(404);
    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'DEPARTMENT_NOT_FOUND' },
    });
  });

  it('returns stable Tenant-local duplicate name and code conflicts', async () => {
    for (const [body, code] of [
      [
        { name: 'Active Department', code: 'UNIQUE-1', foreman_id: foremanId },
        'DEPARTMENT_NAME_ALREADY_EXISTS',
      ],
      [
        { name: 'Unique Department', code: 'ACTIVE', foreman_id: foremanId },
        'DEPARTMENT_CODE_ALREADY_EXISTS',
      ],
    ] as const) {
      const response = await request(server)
        .post('/api/v1/departments')
        .set('Authorization', `Bearer ${directorToken}`)
        .send(body)
        .expect(409);
      expect(response.body).toMatchObject({ success: false, error: { code } });
    }

    for (const [body, code] of [
      [{ name: 'Replacement Department' }, 'DEPARTMENT_NAME_ALREADY_EXISTS'],
      [{ code: 'REPLACE' }, 'DEPARTMENT_CODE_ALREADY_EXISTS'],
    ] as const) {
      const response = await request(server)
        .patch(`/api/v1/departments/${activeDepartmentId}`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send(body)
        .expect(409);
      expect(response.body).toMatchObject({ success: false, error: { code } });
    }
  });

  it('forbids non-Directors from mutating Departments', async () => {
    for (const token of [foremanToken, workerToken, accountantToken]) {
      await request(server)
        .post('/api/v1/departments')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Forbidden', code: 'FORBIDDEN', foreman_id: foremanId })
        .expect(403);
      await request(server)
        .patch(`/api/v1/departments/${activeDepartmentId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Forbidden' })
        .expect(403);
    }
  });

  it('assigns, idempotently reassigns, and unassigns a Worker with history and audits', async () => {
    const response = await request(server)
      .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .set('User-Agent', 'TexERP Foreman Assignment E2E')
      .send({ department_id: activeDepartmentId })
      .expect(200);

    expect(response.body).toMatchObject({
      success: true,
      data: {
        worker: { id: assignmentWorkerId, full_name: 'Assignment Worker' },
        department: {
          id: activeDepartmentId,
          name: 'Active Department',
          code: 'ACTIVE',
        },
        foreman: { id: foremanId, full_name: 'Primary Foreman' },
      },
    });
    const assignment = (response.body as { data: { id: string } }).data;
    const persisted = await admin.query<{
      id: string;
      worker_id: string;
      department_id: string;
      foreman_id: string;
      assigned_by: string;
      unassigned_at: Date | null;
    }>(
      `SELECT id, worker_id, department_id, foreman_id, assigned_by, unassigned_at
       FROM foreman_assignments
       WHERE tenant_id = $1 AND worker_id = $2`,
      [tenantId, assignmentWorkerId],
    );
    expect(persisted.rows).toEqual([
      {
        id: assignment.id,
        worker_id: assignmentWorkerId,
        department_id: activeDepartmentId,
        foreman_id: foremanId,
        assigned_by: directorId,
        unassigned_at: null,
      },
    ]);
    const audit = await admin.query<{
      action: string;
      before_state: Record<string, unknown> | null;
      after_state: Record<string, unknown>;
      user_agent: string;
    }>(
      `SELECT action, before_state, after_state, user_agent
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_type = 'FOREMAN_ASSIGNMENT'
         AND aggregate_id = $2`,
      [tenantId, assignmentWorkerId],
    );
    expect(audit.rows).toEqual([
      {
        action: 'FOREMAN_ASSIGNED',
        before_state: null,
        after_state: {
          assignment_id: assignment.id,
          worker_id: assignmentWorkerId,
          department_id: activeDepartmentId,
          foreman_id: foremanId,
        },
        user_agent: 'TexERP Foreman Assignment E2E',
      },
    ]);

    const idempotentResponse = await request(server)
      .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ department_id: activeDepartmentId })
      .expect(200);
    expect((idempotentResponse.body as { data: { id: string } }).data.id).toBe(
      assignment.id,
    );
    const afterNoOp = await admin.query<{
      assignments: number;
      audits: number;
    }>(
      `SELECT
         (SELECT count(*)::integer FROM foreman_assignments
          WHERE tenant_id = $1 AND worker_id = $2) AS assignments,
         (SELECT count(*)::integer FROM audit_events
          WHERE tenant_id = $1 AND aggregate_type = 'FOREMAN_ASSIGNMENT'
            AND aggregate_id = $2) AS audits`,
      [tenantId, assignmentWorkerId],
    );
    expect(afterNoOp.rows).toEqual([{ assignments: 1, audits: 1 }]);

    const reassignmentResponse = await request(server)
      .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ department_id: replacementDepartmentId })
      .expect(200);
    expect(reassignmentResponse.body).toMatchObject({
      success: true,
      data: {
        worker: { id: assignmentWorkerId },
        department: { id: replacementDepartmentId },
        foreman: { id: replacementForemanId },
      },
    });
    const reassignment = (reassignmentResponse.body as { data: { id: string } })
      .data;
    expect(reassignment.id).not.toBe(assignment.id);

    const history = await admin.query<{
      id: string;
      department_id: string;
      foreman_id: string;
      assigned_at: Date;
      unassigned_at: Date | null;
    }>(
      `SELECT id, department_id, foreman_id, assigned_at, unassigned_at
       FROM foreman_assignments
       WHERE tenant_id = $1 AND worker_id = $2
       ORDER BY assigned_at, id`,
      [tenantId, assignmentWorkerId],
    );
    expect(history.rows).toHaveLength(2);
    expect(history.rows[0]).toMatchObject({
      id: assignment.id,
      department_id: activeDepartmentId,
      foreman_id: foremanId,
    });
    expect(history.rows[0]?.unassigned_at).toEqual(
      history.rows[1]?.assigned_at,
    );
    expect(history.rows[1]).toMatchObject({
      id: reassignment.id,
      department_id: replacementDepartmentId,
      foreman_id: replacementForemanId,
      unassigned_at: null,
    });
    const reassignmentAudit = await admin.query<{
      before_state: Record<string, unknown>;
      after_state: Record<string, unknown>;
    }>(
      `SELECT before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_type = 'FOREMAN_ASSIGNMENT'
         AND aggregate_id = $2
         AND action = 'FOREMAN_REASSIGNED'`,
      [tenantId, assignmentWorkerId],
    );
    expect(reassignmentAudit.rows).toEqual([
      {
        before_state: {
          assignment_id: assignment.id,
          worker_id: assignmentWorkerId,
          department_id: activeDepartmentId,
          foreman_id: foremanId,
        },
        after_state: {
          assignment_id: reassignment.id,
          worker_id: assignmentWorkerId,
          department_id: replacementDepartmentId,
          foreman_id: replacementForemanId,
        },
      },
    ]);

    const unassignmentResponse = await request(server)
      .delete(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    expect(unassignmentResponse.body).toEqual({
      success: true,
      data: { message: 'Ishchi brigadirdan ajratildi' },
    });
    const ended = await admin.query<{
      id: string;
      department_id: string;
      foreman_id: string;
      unassigned_at: Date;
    }>(
      `SELECT id, department_id, foreman_id, unassigned_at
       FROM foreman_assignments
       WHERE tenant_id = $1 AND worker_id = $2
       ORDER BY assigned_at DESC, id DESC
       LIMIT 1`,
      [tenantId, assignmentWorkerId],
    );
    expect(ended.rows[0]).toMatchObject({
      id: reassignment.id,
      department_id: replacementDepartmentId,
      foreman_id: replacementForemanId,
    });
    expect(ended.rows[0]?.unassigned_at).toBeInstanceOf(Date);
    const unassignmentAudit = await admin.query<{
      before_state: Record<string, unknown>;
      after_state: Record<string, unknown>;
    }>(
      `SELECT before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_type = 'FOREMAN_ASSIGNMENT'
         AND aggregate_id = $2
         AND action = 'FOREMAN_UNASSIGNED'`,
      [tenantId, assignmentWorkerId],
    );
    expect(unassignmentAudit.rows).toHaveLength(1);
    expect(unassignmentAudit.rows[0]?.before_state).toMatchObject({
      assignment_id: reassignment.id,
      department_id: replacementDepartmentId,
      foreman_id: replacementForemanId,
      unassigned_at: null,
    });
    expect(unassignmentAudit.rows[0]?.after_state).toMatchObject({
      assignment_id: reassignment.id,
      department_id: replacementDepartmentId,
      foreman_id: replacementForemanId,
      unassigned_at: ended.rows[0]?.unassigned_at.toISOString(),
    });

    await request(server)
      .delete(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    const afterIdempotentDelete = await admin.query<{ audits: number }>(
      `SELECT count(*)::integer AS audits
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_type = 'FOREMAN_ASSIGNMENT'
         AND aggregate_id = $2`,
      [tenantId, assignmentWorkerId],
    );
    expect(afterIdempotentDelete.rows).toEqual([{ audits: 3 }]);
  });

  it('serializes concurrent reassignment to one active Foreman Assignment', async () => {
    const raceWorkerId = randomUUID();
    const lockClient = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    const observedPids = new Set<number>();
    let firstRequest: Promise<request.Response> | undefined;
    let secondRequest: Promise<request.Response> | undefined;
    let blockerPid: number | undefined;
    let lockHeld = false;

    await lockClient.connect();
    try {
      await admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES ($1, $2, $3, 'hash', 'Assignment Race Worker', $4, 'WORKER', 'ACTIVE')`,
        [
          raceWorkerId,
          tenantId,
          testPhone(16),
          `RACE-${raceWorkerId.slice(0, 8)}`,
        ],
      );
      await lockClient.query('BEGIN');
      lockHeld = true;
      const blocker = await lockClient.query<{ pid: number }>(
        `SELECT pg_backend_pid() AS pid
         FROM users
         WHERE tenant_id = $1 AND id = $2
         FOR UPDATE`,
        [tenantId, raceWorkerId],
      );
      blockerPid = blocker.rows[0]?.pid;
      if (!blockerPid)
        throw new Error('Failed to acquire the Worker race lock');

      firstRequest = request(server)
        .put(`/api/v1/users/${raceWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: activeDepartmentId })
        .then((response) => response);
      secondRequest = request(server)
        .put(`/api/v1/users/${raceWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: replacementDepartmentId })
        .then((response) => response);

      await waitForBlockedWorkerLocks(blockerPid, observedPids);
      await lockClient.query('COMMIT');
      lockHeld = false;

      const [firstResponse, secondResponse] = await withTimeout(
        Promise.all([firstRequest, secondRequest]),
        'Timed out waiting for concurrent Foreman Assignment responses',
      );
      expect(firstResponse.status).toBe(200);
      expect(firstResponse.body).toMatchObject({
        success: true,
        data: {
          department: { id: activeDepartmentId },
          foreman: { id: foremanId },
        },
      });
      expect(secondResponse.status).toBe(200);
      expect(secondResponse.body).toMatchObject({
        success: true,
        data: {
          department: { id: replacementDepartmentId },
          foreman: { id: replacementForemanId },
        },
      });

      const active = await admin.query<{
        id: string;
        department_id: string;
        foreman_id: string;
      }>(
        `SELECT id, department_id, foreman_id
         FROM foreman_assignments
         WHERE tenant_id = $1 AND worker_id = $2 AND unassigned_at IS NULL`,
        [tenantId, raceWorkerId],
      );
      expect(active.rows).toHaveLength(1);
      expect([
        [activeDepartmentId, foremanId],
        [replacementDepartmentId, replacementForemanId],
      ]).toContainEqual([
        active.rows[0]?.department_id,
        active.rows[0]?.foreman_id,
      ]);

      const history = await admin.query<{
        id: string;
        department_id: string;
        foreman_id: string;
        assigned_at: Date;
        unassigned_at: Date | null;
      }>(
        `SELECT id, department_id, foreman_id, assigned_at, unassigned_at
         FROM foreman_assignments
         WHERE tenant_id = $1 AND worker_id = $2
         ORDER BY unassigned_at NULLS LAST, assigned_at, id`,
        [tenantId, raceWorkerId],
      );
      expect(history.rows).toHaveLength(2);
      expect(history.rows).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            department_id: activeDepartmentId,
            foreman_id: foremanId,
          }),
          expect.objectContaining({
            department_id: replacementDepartmentId,
            foreman_id: replacementForemanId,
          }),
        ]),
      );
      const [firstAssignment, secondAssignment] = history.rows;
      if (!firstAssignment?.unassigned_at || !secondAssignment) {
        throw new Error('Expected one ended and one active assignment');
      }
      expect(firstAssignment.assigned_at).toBeInstanceOf(Date);
      expect(firstAssignment.unassigned_at).toBeInstanceOf(Date);
      expect(secondAssignment.assigned_at).toBeInstanceOf(Date);
      expect(Number.isNaN(firstAssignment.assigned_at.getTime())).toBe(false);
      expect(Number.isNaN(firstAssignment.unassigned_at.getTime())).toBe(false);
      expect(Number.isNaN(secondAssignment.assigned_at.getTime())).toBe(false);
      expect(firstAssignment.assigned_at.getTime()).toBeLessThanOrEqual(
        firstAssignment.unassigned_at.getTime(),
      );
      expect(firstAssignment.unassigned_at.getTime()).toBeLessThanOrEqual(
        secondAssignment.assigned_at.getTime(),
      );
      expect(secondAssignment.unassigned_at).toBeNull();

      const audits = await admin.query<{
        action: string;
        before_state: {
          assignment_id: string;
          worker_id: string;
          department_id: string;
          foreman_id: string;
        } | null;
        after_state: {
          assignment_id: string;
          worker_id: string;
          department_id: string;
          foreman_id: string;
        };
      }>(
        `SELECT action, before_state, after_state
         FROM audit_events
         WHERE tenant_id = $1
           AND aggregate_type = 'FOREMAN_ASSIGNMENT'
           AND aggregate_id = $2`,
        [tenantId, raceWorkerId],
      );
      expect(audits.rows).toHaveLength(2);
      expect(audits.rows.map(({ action }) => action)).toEqual(
        expect.arrayContaining(['FOREMAN_ASSIGNED', 'FOREMAN_REASSIGNED']),
      );
      const assignedAudit = audits.rows.find(
        ({ action }) => action === 'FOREMAN_ASSIGNED',
      );
      const reassignedAudit = audits.rows.find(
        ({ action }) => action === 'FOREMAN_REASSIGNED',
      );
      expect(assignedAudit).toEqual({
        action: 'FOREMAN_ASSIGNED',
        before_state: null,
        after_state: {
          assignment_id: firstAssignment.id,
          worker_id: raceWorkerId,
          department_id: firstAssignment.department_id,
          foreman_id: firstAssignment.foreman_id,
        },
      });
      expect(reassignedAudit).toEqual({
        action: 'FOREMAN_REASSIGNED',
        before_state: {
          assignment_id: firstAssignment.id,
          worker_id: raceWorkerId,
          department_id: firstAssignment.department_id,
          foreman_id: firstAssignment.foreman_id,
        },
        after_state: {
          assignment_id: secondAssignment.id,
          worker_id: raceWorkerId,
          department_id: secondAssignment.department_id,
          foreman_id: secondAssignment.foreman_id,
        },
      });
      expect(secondAssignment.id).toBe(active.rows[0]?.id);
    } finally {
      try {
        if (lockHeld) {
          await withTimeout(
            lockClient.query('ROLLBACK'),
            'Timed out rolling back the Worker race lock',
            1_000,
          );
          lockHeld = false;
        }
      } finally {
        try {
          if (lockHeld && blockerPid) {
            await withTimeout(
              terminateTestBackends(new Set([blockerPid])),
              'Timed out terminating the Worker race lock backend',
              1_000,
            );
          }
        } finally {
          try {
            try {
              await settleRequests([firstRequest, secondRequest]);
            } catch {
              try {
                await withTimeout(
                  terminateTestBackends(observedPids),
                  'Timed out terminating blocked Foreman Assignment backends',
                  1_000,
                );
              } finally {
                await settleRequests([firstRequest, secondRequest]);
              }
            }
          } finally {
            try {
              await withTimeout(
                admin.query(
                  'DELETE FROM audit_events WHERE tenant_id = $1 AND aggregate_id = $2',
                  [tenantId, raceWorkerId],
                ),
                'Timed out deleting Worker race audit fixtures',
                1_000,
              );
            } finally {
              try {
                await withTimeout(
                  admin.query(
                    'DELETE FROM foreman_assignments WHERE tenant_id = $1 AND worker_id = $2',
                    [tenantId, raceWorkerId],
                  ),
                  'Timed out deleting Worker race Foreman Assignment fixtures',
                  1_000,
                );
              } finally {
                try {
                  await withTimeout(
                    admin.query(
                      'DELETE FROM users WHERE tenant_id = $1 AND id = $2',
                      [tenantId, raceWorkerId],
                    ),
                    'Timed out deleting the Worker race fixture',
                    1_000,
                  );
                } finally {
                  await withTimeout(
                    lockClient.end(),
                    'Timed out closing the Worker race lock client',
                    1_000,
                  );
                }
              }
            }
          }
        }
      }
    }
  }, 15_000);

  it('rejects assignment after concurrent Foreman deactivation wins the User lock', async () => {
    const raceForemanId = randomUUID();
    const raceWorkerId = randomUUID();
    const raceDepartmentId = randomUUID();
    const suffix = raceForemanId.replaceAll('-', '');
    const functionName = `organization_foreman_barrier_${suffix}`;
    const triggerName = `organization_foreman_barrier_${suffix}`;
    const lockKey = Number.parseInt(suffix.slice(0, 7), 16);
    const lockClient = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    let deactivationRequest: Promise<request.Response> | undefined;
    let assignmentRequest: Promise<request.Response> | undefined;
    let deactivationPid: number | undefined;
    let assignmentPid: number | undefined;

    await lockClient.connect();
    try {
      await admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES
          ($1, $2, $3, 'hash', 'Deactivation Race Foreman', $4, 'FOREMAN', 'ACTIVE'),
          ($5, $2, $6, 'hash', 'Deactivation Race Worker', $7, 'WORKER', 'ACTIVE')`,
        [
          raceForemanId,
          tenantId,
          testPhone(17),
          `RF-${raceForemanId.slice(0, 8)}`,
          raceWorkerId,
          testPhone(18),
          `RW-${raceWorkerId.slice(0, 8)}`,
        ],
      );
      await admin.query(
        `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          raceDepartmentId,
          tenantId,
          `Deactivation Race ${raceDepartmentId}`,
          `DR-${raceDepartmentId.slice(0, 8)}`,
          raceForemanId,
        ],
      );
      await lockClient.query('SELECT pg_advisory_lock($1)', [lockKey]);
      await admin.query(`
        CREATE FUNCTION ${functionName}()
        RETURNS trigger AS $$
        BEGIN
          IF NEW.id = '${raceForemanId}'::uuid
             AND NEW.status = 'DEACTIVATED' THEN
            PERFORM pg_advisory_xact_lock(${lockKey});
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);
      await admin.query(`
        CREATE TRIGGER ${triggerName}
        BEFORE UPDATE OF status ON users
        FOR EACH ROW EXECUTE FUNCTION ${functionName}()
      `);

      deactivationRequest = request(server)
        .post(`/api/v1/users/${raceForemanId}/deactivate`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({})
        .then((response) => response);
      deactivationPid = await waitForAdvisoryLockWaiter(lockKey);

      assignmentRequest = request(server)
        .put(`/api/v1/users/${raceWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: raceDepartmentId })
        .then((response) => response);
      assignmentPid = await waitForBlockedQuery(
        deactivationPid,
        'SELECT full_name',
      );
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);

      const [deactivation, assignment] = await withTimeout(
        Promise.all([deactivationRequest, assignmentRequest]),
        'Timed out waiting for Foreman deactivation and assignment',
      );
      expect(deactivation.status).toBe(200);
      expect(assignment.status).toBe(400);
      expect(assignment.body).toEqual({
        success: false,
        error: {
          code: 'DEPARTMENT_HAS_NO_FOREMAN',
          message: "Bo'limga faol brigadir biriktirilmagan",
        },
      });

      const effects = await admin.query<{
        status: string;
        assignments: number;
        assignment_audits: number;
      }>(
        `SELECT u.status,
                (SELECT count(*)::integer FROM foreman_assignments
                 WHERE tenant_id = $1 AND worker_id = $3) AS assignments,
                (SELECT count(*)::integer FROM audit_events
                 WHERE tenant_id = $1
                   AND aggregate_type = 'FOREMAN_ASSIGNMENT'
                   AND aggregate_id = $3) AS assignment_audits
         FROM users u
         WHERE u.tenant_id = $1 AND u.id = $2`,
        [tenantId, raceForemanId, raceWorkerId],
      );
      expect(effects.rows).toEqual([
        { status: 'DEACTIVATED', assignments: 0, assignment_audits: 0 },
      ]);
    } finally {
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);
      let settleError: unknown;
      try {
        await settleRequests([deactivationRequest, assignmentRequest]);
      } catch (error) {
        settleError = error;
        await terminateTestBackends(
          new Set(
            [deactivationPid, assignmentPid].filter(
              (pid): pid is number => pid !== undefined,
            ),
          ),
        );
        await settleRequests([deactivationRequest, assignmentRequest]);
      }
      await admin.query(`DROP TRIGGER IF EXISTS ${triggerName} ON users`);
      await admin.query(`DROP FUNCTION IF EXISTS ${functionName}()`);
      await admin.query(
        'DELETE FROM audit_events WHERE aggregate_id = ANY($1::uuid[])',
        [[raceForemanId, raceWorkerId]],
      );
      await admin.query(
        'DELETE FROM foreman_assignments WHERE tenant_id = $1 AND worker_id = $2',
        [tenantId, raceWorkerId],
      );
      await admin.query('DELETE FROM departments WHERE id = $1', [
        raceDepartmentId,
      ]);
      await admin.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [
        [raceForemanId, raceWorkerId],
      ]);
      await lockClient.end();
      expect(settleError).toBeUndefined();
    }
  }, 15_000);

  it('rolls back an assignment audit when the state insert fails', async () => {
    const rollbackWorkerId = randomUUID();
    const suffix = rollbackWorkerId.replaceAll('-', '');
    const functionName = `organization_assignment_failure_${suffix}`;
    const triggerName = `organization_assignment_failure_${suffix}`;

    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES ($1, $2, $3, 'hash', 'Rollback Assignment Worker', $4, 'WORKER', 'ACTIVE')`,
      [
        rollbackWorkerId,
        tenantId,
        testPhone(19),
        `RB-${rollbackWorkerId.slice(0, 8)}`,
      ],
    );
    try {
      await admin.query(`
        CREATE FUNCTION ${functionName}()
        RETURNS trigger AS $$
        BEGIN
          IF NEW.worker_id = '${rollbackWorkerId}'::uuid
             AND EXISTS (
               SELECT 1
               FROM audit_events
               WHERE tenant_id = NEW.tenant_id
                 AND aggregate_type = 'FOREMAN_ASSIGNMENT'
                 AND aggregate_id = NEW.worker_id
                 AND action = 'FOREMAN_ASSIGNED'
             ) THEN
            RAISE EXCEPTION 'forced Organization assignment insert failure';
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);
      await admin.query(`
        CREATE TRIGGER ${triggerName}
        BEFORE INSERT ON foreman_assignments
        FOR EACH ROW EXECUTE FUNCTION ${functionName}()
      `);

      await request(server)
        .put(`/api/v1/users/${rollbackWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: activeDepartmentId })
        .expect(500);
    } finally {
      await admin.query(
        `DROP TRIGGER IF EXISTS ${triggerName} ON foreman_assignments`,
      );
      await admin.query(`DROP FUNCTION IF EXISTS ${functionName}()`);
    }

    const effects = await admin.query<{ kind: string }>(
      `SELECT 'assignment' AS kind
       FROM foreman_assignments
       WHERE tenant_id = $1 AND worker_id = $2
       UNION ALL
       SELECT 'audit' AS kind
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_type = 'FOREMAN_ASSIGNMENT'
         AND aggregate_id = $2`,
      [tenantId, rollbackWorkerId],
    );
    expect(effects.rows).toEqual([]);
    await admin.query('DELETE FROM users WHERE id = $1', [rollbackWorkerId]);
  });

  it('rejects invalid assignment request fields and path parameters', async () => {
    for (const body of [
      {},
      { department_id: 'not-a-uuid' },
      { department_id: activeDepartmentId, unknown: true },
    ]) {
      await request(server)
        .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send(body)
        .expect(400);
    }
    await request(server)
      .put('/api/v1/users/not-a-uuid/foreman-assignment')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ department_id: activeDepartmentId })
      .expect(400);
    await request(server)
      .delete('/api/v1/users/not-a-uuid/foreman-assignment')
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(400);
  });

  it('conceals invalid Workers and unavailable Departments during assignment', async () => {
    for (const invalidWorkerId of [
      inactiveWorkerId,
      directorId,
      secondTenantWorkerId,
      randomUUID(),
    ]) {
      const response = await request(server)
        .put(`/api/v1/users/${invalidWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: activeDepartmentId })
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'WORKER_NOT_FOUND' },
      });
    }

    for (const unavailableDepartmentId of [
      inactiveDepartmentId,
      secondTenantDepartmentId,
      randomUUID(),
    ]) {
      const response = await request(server)
        .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: unavailableDepartmentId })
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'DEPARTMENT_NOT_FOUND' },
      });
    }

    for (const departmentId of [
      noForemanDepartmentId,
      inactiveForemanDepartmentId,
    ]) {
      const response = await request(server)
        .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${directorToken}`)
        .send({ department_id: departmentId })
        .expect(400);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'DEPARTMENT_HAS_NO_FOREMAN' },
      });
    }

    const concealedDelete = await request(server)
      .delete(`/api/v1/users/${secondTenantWorkerId}/foreman-assignment`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(404);
    expect(concealedDelete.body).toMatchObject({
      success: false,
      error: { code: 'WORKER_NOT_FOUND' },
    });
  });

  it('forbids non-Directors from changing Foreman Assignments', async () => {
    for (const token of [foremanToken, workerToken, accountantToken]) {
      await request(server)
        .put(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${token}`)
        .send({ department_id: activeDepartmentId })
        .expect(403);
      await request(server)
        .delete(`/api/v1/users/${assignmentWorkerId}/foreman-assignment`)
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    }
  });
});
