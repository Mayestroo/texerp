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
  data: { access_token: string; refresh_token: string };
}

interface RefreshBody {
  data: { access_token: string; refresh_token: string };
}

interface ReadUserBody {
  data: {
    created_at: string;
    department: { id: string; name: string; code: string } | null;
    foreman: { id: string; full_name: string; phone: string } | null;
  };
}

interface ListUsersBody {
  data: Array<{
    id: string;
    full_name: string;
    status: 'ACTIVE' | 'DEACTIVATED';
    department: { id: string; name: string } | null;
    foreman: { id: string; full_name: string } | null;
  }>;
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
    has_next: boolean;
  };
}

interface ErrorEnvelopeBody {
  success: false;
  error: {
    code: string;
    message: string | string[];
  };
}

interface PersistedUserRow {
  id: string;
  pin_hash: string;
  created_by: string;
  language: string;
}

interface UserCreatedAuditRow {
  actor_id: string;
  actor_role: string;
  after_state: Record<string, unknown>;
  ip_address: string;
  user_agent: string;
}

interface UserUpdatedAuditRow {
  actor_id: string;
  actor_role: string;
  before_state: Record<string, unknown>;
  after_state: Record<string, unknown>;
  ip_address: string;
  user_agent: string;
}

interface UserLifecycleAuditRow {
  action: 'USER_DEACTIVATED' | 'USER_REACTIVATED';
  actor_id: string;
  actor_role: string;
  before_state: Record<string, unknown>;
  after_state: Record<string, unknown>;
  ip_address: string;
  user_agent: string;
}

describe('Director User Management', () => {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });
  const tenantId = randomUUID();
  const secondTenantId = randomUUID();
  const directorId = randomUUID();
  const workerId = randomUUID();
  const unassignedWorkerId = randomUUID();
  const deactivatedWorkerId = randomUUID();
  const accountantId = randomUUID();
  const foremanId = randomUUID();
  const mutableUserId = randomUUID();
  const departmentId = randomUUID();
  const lowerTieBreakerId = '00000000-0000-4000-8000-000000000010';
  const higherTieBreakerId = '00000000-0000-4000-8000-000000000020';
  const secondTenantUserId = randomUUID();
  const directorPhone = '+998901230010';
  const workerPhone = '+998901230011';
  const secondTenantPhone = '+998901230012';
  const accountantPhone = '+998901230013';
  const foremanPhone = '+998901230014';
  const sharedWorkerCode = 'SHARED-0001';
  let app: INestApplication;
  let server: Server;
  let directorAccessToken: string;
  let workerAccessToken: string;
  let workerRefreshToken: string;
  let accountantAccessToken: string;
  let foremanAccessToken: string;

  async function waitForAdvisoryLockWaiter(
    lockClient: Client,
    lockKey: number,
  ): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const result = await lockClient.query<{ pid: number }>(
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

  async function settleRequests(
    promises: Array<Promise<request.Response> | undefined>,
  ): Promise<void> {
    await withTimeout(
      Promise.allSettled(
        promises.filter(
          (promise): promise is Promise<request.Response> =>
            promise !== undefined,
        ),
      ),
      'Timed out settling concurrent requests',
    );
  }

  async function withTimeout<T>(
    promise: Promise<T>,
    message: string,
  ): Promise<T> {
    let timeout: NodeJS.Timeout | undefined;
    try {
      return await Promise.race([
        promise,
        new Promise<never>((_resolve, reject) => {
          timeout = setTimeout(() => reject(new Error(message)), 5_000);
        }),
      ]);
    } finally {
      if (timeout) clearTimeout(timeout);
    }
  }

  async function terminateTestBackends(
    pids: Array<number | undefined>,
  ): Promise<void> {
    const activePids = pids.filter((pid): pid is number => pid !== undefined);
    if (activePids.length === 0) return;
    await admin.query(
      `SELECT pg_terminate_backend(pid)
       FROM unnest($1::integer[]) AS blocked(pid)`,
      [activePids],
    );
  }

  async function cleanupRaceRedis(
    phone: string,
    accessTokens: string[],
  ): Promise<void> {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    const phoneHash = createHash('sha256').update(phone).digest('hex');
    const sessionKeys = accessTokens.map((token) => {
      const claims = JSON.parse(
        Buffer.from(token.split('.')[1] ?? '', 'base64url').toString('utf8'),
      ) as { sid: string };
      return `auth:session-revoked:${claims.sid}`;
    });
    await redis.del(`ratelimit:login:phone:${phoneHash}`, ...sessionKeys);
    await redis.quit();
  }

  async function expectAccessAndRefreshRejected(
    userId: string,
    accessToken: string,
    refreshToken: string,
  ): Promise<void> {
    await request(server)
      .get(`/api/v1/users/${userId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(401);
    const refresh = await request(server)
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: refreshToken })
      .expect(401);
    expect(refresh.body).toMatchObject({
      success: false,
      error: { code: 'INVALID_REFRESH_TOKEN' },
    });
  }

  async function flushRedis(): Promise<void> {
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.flushdb();
    await redis.quit();
  }

  beforeAll(async () => {
    await flushRedis();
    await admin.connect();
    await admin.query(
      `INSERT INTO tenants (id, name, slug)
       VALUES
         ($1, 'User Management Tenant', $2),
         ($3, 'Second User Management Tenant', $4)`,
      [
        tenantId,
        `users-${tenantId}`,
        secondTenantId,
        `users-${secondTenantId}`,
      ],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
         ($1, $2, $3, $4, 'Dilshod Rahimov', 'D-0001', 'DIRECTOR', 'ACTIVE'),
         ($5, $2, $6, $4, 'Aziz Karimov', 'W-0042', 'WORKER', 'ACTIVE'),
         ($7, $2, '+998901230015', $4, 'Nodira Aliyeva', 'W-0044', 'WORKER', 'ACTIVE'),
          ($8, $2, '+998901230016', $4, 'Zarina Yusupova', 'W-0045', 'WORKER', 'DEACTIVATED'),
          ($9, $2, $10, $4, 'Kamola Sobirova', 'A-0001', 'ACCOUNTANT', 'ACTIVE'),
          ($11, $2, $12, $4, 'Akbar Toshmatov', 'F-0001', 'FOREMAN', 'ACTIVE'),
          ($13, $2, '+998901230019', $4, 'Mutable User', 'W-UPDATE', 'WORKER', 'ACTIVE')`,
      [
        directorId,
        tenantId,
        directorPhone,
        await bcrypt.hash('4826', 4),
        workerId,
        workerPhone,
        unassignedWorkerId,
        deactivatedWorkerId,
        accountantId,
        accountantPhone,
        foremanId,
        foremanPhone,
        mutableUserId,
      ],
    );
    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
       VALUES ($1, $2, 'Tikarish Line 1', 'L1', $3)`,
      [departmentId, tenantId, foremanId],
    );
    await admin.query(
      `INSERT INTO foreman_assignments
        (id, tenant_id, worker_id, foreman_id, department_id, assigned_by)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [randomUUID(), tenantId, workerId, foremanId, departmentId, directorId],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
       VALUES
        ($1, $2, $3, $4, 'Second Tenant Worker', $5, 'WORKER', 'ACTIVE')`,
      [
        secondTenantUserId,
        secondTenantId,
        secondTenantPhone,
        await bcrypt.hash('4826', 4),
        sharedWorkerCode,
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

    const login = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: directorPhone, pin: '4826' })
      .expect(200);
    directorAccessToken = (login.body as LoginBody).data.access_token;

    const workerLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: workerPhone, pin: '4826' })
      .expect(200);
    workerAccessToken = (workerLogin.body as LoginBody).data.access_token;
    workerRefreshToken = (workerLogin.body as LoginBody).data.refresh_token;

    const accountantLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: accountantPhone, pin: '4826' })
      .expect(200);
    accountantAccessToken = (accountantLogin.body as LoginBody).data
      .access_token;

    const foremanLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: foremanPhone, pin: '4826' })
      .expect(200);
    foremanAccessToken = (foremanLogin.body as LoginBody).data.access_token;
  });

  afterAll(async () => {
    await admin.query('DROP TRIGGER IF EXISTS task_1_reject_user ON users');
    await admin.query('DROP FUNCTION IF EXISTS task_1_reject_user_insert()');
    await admin.query(
      'DROP TRIGGER IF EXISTS task_4_check_user_update ON users',
    );
    await admin.query('DROP FUNCTION IF EXISTS task_4_check_user_update()');
    await admin.query(
      'DROP TRIGGER IF EXISTS task_5_check_user_lifecycle ON users',
    );
    await admin.query('DROP FUNCTION IF EXISTS task_5_check_user_lifecycle()');
    await admin.query('DELETE FROM audit_events WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM used_refresh_tokens WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM user_sessions WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM foreman_assignments WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM departments WHERE tenant_id = $1', [
      tenantId,
    ]);
    await admin.query('DELETE FROM users WHERE tenant_id = $1', [tenantId]);
    await admin.query('DELETE FROM users WHERE tenant_id = $1', [
      secondTenantId,
    ]);
    await admin.query('DELETE FROM tenants WHERE id = ANY($1::uuid[])', [
      [tenantId, secondTenantId],
    ]);
    await app.close();
    await admin.end();
  });

  it('creates a Worker', async () => {
    const response = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .set('User-Agent', 'TexERP Task 1 E2E')
      .send({
        full_name: 'Malika Yusupova',
        phone: '+998901230001',
        worker_code: 'W-0043',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(201);

    const persisted = await admin.query<PersistedUserRow>(
      `SELECT id, pin_hash, created_by, language
       FROM users
       WHERE tenant_id = $1 AND phone = $2`,
      [tenantId, '+998901230001'],
    );
    expect(persisted.rows).toHaveLength(1);
    const createdUser = persisted.rows[0];
    expect(createdUser).toBeDefined();
    expect(response.body).toEqual({
      success: true,
      data: {
        id: createdUser.id,
        full_name: 'Malika Yusupova',
        worker_code: 'W-0043',
        role: 'WORKER',
        status: 'ACTIVE',
      },
    });
    expect(createdUser.pin_hash).not.toBe('4321');
    await expect(bcrypt.compare('4321', createdUser.pin_hash)).resolves.toBe(
      true,
    );
    expect(bcrypt.getRounds(createdUser.pin_hash)).toBe(12);
    expect(createdUser.created_by).toBe(directorId);
    expect(createdUser.language).toBe('uz');

    const audit = await admin.query<UserCreatedAuditRow>(
      `SELECT actor_id, actor_role, after_state, ip_address::text, user_agent
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_id = $2
         AND action = 'USER_CREATED'`,
      [tenantId, createdUser.id],
    );
    expect(audit.rows).toHaveLength(1);
    expect(audit.rows[0]).toEqual({
      actor_id: directorId,
      actor_role: 'DIRECTOR',
      after_state: {
        id: createdUser.id,
        full_name: 'Malika Yusupova',
        worker_code: 'W-0043',
        role: 'WORKER',
        status: 'ACTIVE',
        phone: '+998901230001',
        language: 'uz',
        avatar_url: null,
        created_by: directorId,
      },
      ip_address: '::ffff:127.0.0.1/128',
      user_agent: 'TexERP Task 1 E2E',
    });
    const serializedAudit = JSON.stringify(audit.rows[0].after_state);
    expect(serializedAudit).not.toContain('4321');
    expect(serializedAudit).not.toContain('initial_pin');
    expect(serializedAudit).not.toContain('pin_hash');
  });

  it('forbids a Worker from creating a User', async () => {
    const response = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${workerAccessToken}`)
      .send({
        full_name: 'Nodira Aliyeva',
        phone: '+998901230002',
        worker_code: 'W-0044',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(403);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'FORBIDDEN' },
    });
    const deniedEffects = await admin.query<{ kind: string }>(
      `SELECT 'user' AS kind
       FROM users
       WHERE tenant_id = $1 AND phone = $2
       UNION ALL
       SELECT 'audit' AS kind
       FROM audit_events
       WHERE tenant_id = $1
         AND action = 'USER_CREATED'
         AND after_state->>'phone' = $2`,
      [tenantId, '+998901230002'],
    );
    expect(deniedEffects.rows).toEqual([]);
  });

  it('returns stable conflicts for duplicate phone and worker code', async () => {
    await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Duplicate Baseline User',
        phone: '+998901230004',
        worker_code: 'DUPLICATE-0001',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(201);

    const duplicatePhone = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Duplicate Phone User',
        phone: '+998901230004',
        worker_code: 'DUPLICATE-0002',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(409);

    expect(duplicatePhone.body).toMatchObject({
      success: false,
      error: { code: 'PHONE_ALREADY_EXISTS' },
    });

    const duplicateCode = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Duplicate Worker Code User',
        phone: '+998901230005',
        worker_code: 'DUPLICATE-0001',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(409);

    expect(duplicateCode.body).toMatchObject({
      success: false,
      error: { code: 'WORKER_CODE_ALREADY_EXISTS' },
    });
  });

  it('treats phone as globally duplicate and worker code as Tenant-local', async () => {
    await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Shared Worker Code User',
        phone: '+998901230006',
        worker_code: sharedWorkerCode,
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(201);

    const duplicatePhone = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Cross Tenant Duplicate Phone User',
        phone: secondTenantPhone,
        worker_code: 'CROSS-0001',
        role: 'WORKER',
        initial_pin: '4321',
      })
      .expect(409);

    expect(duplicatePhone.body).toMatchObject({
      success: false,
      error: { code: 'PHONE_ALREADY_EXISTS' },
    });
  });

  it('lists active Users for Directors and Accountants with deterministic pagination', async () => {
    const directorResponse = await request(server)
      .get('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .expect(200);
    const directorList = directorResponse.body as ListUsersBody;
    expect(directorList.pagination).toEqual({
      page: 1,
      limit: 50,
      total: directorList.data.length,
      total_pages: 1,
      has_next: false,
    });
    expect(directorList.data.map((user) => user.id)).not.toContain(
      deactivatedWorkerId,
    );
    expect(directorList.data[0]).toMatchObject({
      id: foremanId,
      full_name: 'Akbar Toshmatov',
      department: null,
      foreman: null,
    });
    expect(directorList.data[1]).toMatchObject({
      id: workerId,
      full_name: 'Aziz Karimov',
      department: { id: departmentId, name: 'Tikarish Line 1' },
      foreman: { id: foremanId, full_name: 'Akbar Toshmatov' },
    });

    const accountantResponse = await request(server)
      .get('/api/v1/users?role=WORKER&status=ALL&search=zArInA&page=1&limit=50')
      .set('Authorization', `Bearer ${accountantAccessToken}`)
      .expect(200);

    expect(accountantResponse.body).toMatchObject({
      success: true,
      data: [
        {
          id: deactivatedWorkerId,
          full_name: 'Zarina Yusupova',
          role: 'WORKER',
          status: 'DEACTIVATED',
        },
      ],
      pagination: {
        page: 1,
        limit: 50,
        total: 1,
        total_pages: 1,
        has_next: false,
      },
    });
  });

  it('lists Users by partial worker code and validates supported filters', async () => {
    const response = await request(server)
      .get('/api/v1/users?search=0044&status=ALL&role=WORKER')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .expect(200);

    expect(response.body).toMatchObject({
      success: true,
      data: [{ id: unassignedWorkerId, worker_code: 'W-0044' }],
      pagination: {
        page: 1,
        limit: 50,
        total: 1,
        total_pages: 1,
        has_next: false,
      },
    });

    for (const query of [
      'page=0',
      'page=1e2',
      'limit=201',
      'limit=0',
      'limit=0x10',
      'role=OWNER',
      'status=SUSPENDED',
      `department_id=${departmentId}`,
      `foreman_id=${foremanId}`,
    ]) {
      const response = await request(server)
        .get(`/api/v1/users?${query}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .expect(400);

      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'VALIDATION_ERROR' },
      });
    }
  });

  it('lists equal full names by the secondary ID ordering tie-breaker', async () => {
    try {
      await admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role)
         VALUES
          ($1, $2, '+998901230017', $3, 'Task Three Tie', 'TIE-2', 'WORKER'),
          ($4, $2, '+998901230018', $3, 'Task Three Tie', 'TIE-1', 'WORKER')`,
        [
          higherTieBreakerId,
          tenantId,
          await bcrypt.hash('4826', 4),
          lowerTieBreakerId,
        ],
      );

      const response = await request(server)
        .get('/api/v1/users?search=Task%20Three%20Tie')
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .expect(200);
      const list = response.body as ListUsersBody;
      expect(list.data.map((user) => user.id)).toEqual([
        lowerTieBreakerId,
        higherTieBreakerId,
      ]);
    } finally {
      await admin.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [
        [lowerTieBreakerId, higherTieBreakerId],
      ]);
    }
  });

  it('reads a same-Tenant User profile as Director and Accountant', async () => {
    const expectedProfile = {
      id: workerId,
      full_name: 'Aziz Karimov',
      phone: workerPhone,
      worker_code: 'W-0042',
      role: 'WORKER',
      status: 'ACTIVE',
      language: 'uz',
      avatar_url: null,
      department: { id: departmentId, name: 'Tikarish Line 1', code: 'L1' },
      foreman: {
        id: foremanId,
        full_name: 'Akbar Toshmatov',
        phone: foremanPhone,
      },
    };

    for (const token of [directorAccessToken, accountantAccessToken]) {
      const response = await request(server)
        .get(`/api/v1/users/${workerId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(response.body).toMatchObject({
        success: true,
        data: expectedProfile,
      });
      expect((response.body as ReadUserBody).data.created_at).toEqual(
        expect.any(String),
      );
    }

    const unassignedResponse = await request(server)
      .get(`/api/v1/users/${unassignedWorkerId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .expect(200);
    expect((unassignedResponse.body as ReadUserBody).data).toMatchObject({
      department: null,
      foreman: null,
    });
  });

  it('reads malformed User IDs as a controlled validation error', async () => {
    const response = await request(server)
      .get('/api/v1/users/not-a-uuid')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .expect(400);

    const body = response.body as ErrorEnvelopeBody;
    expect(body).toMatchObject({
      success: false,
      error: { code: 'VALIDATION_ERROR' },
    });
    expect(body.error.message).toContain('uuid');
  });

  it('reads only self and actively assigned Workers as a Foreman', async () => {
    await request(server)
      .get(`/api/v1/users/${foremanId}`)
      .set('Authorization', `Bearer ${foremanAccessToken}`)
      .expect(200);
    await request(server)
      .get(`/api/v1/users/${workerId}`)
      .set('Authorization', `Bearer ${foremanAccessToken}`)
      .expect(200);

    for (const id of [unassignedWorkerId, directorId]) {
      const response = await request(server)
        .get(`/api/v1/users/${id}`)
        .set('Authorization', `Bearer ${foremanAccessToken}`)
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'USER_NOT_FOUND' },
      });
    }
  });

  it('forbids a Worker from listing or reading Users', async () => {
    await request(server)
      .get('/api/v1/users')
      .set('Authorization', `Bearer ${workerAccessToken}`)
      .expect(403);
    await request(server)
      .get(`/api/v1/users/${workerId}`)
      .set('Authorization', `Bearer ${workerAccessToken}`)
      .expect(403);
  });

  it('conceals cross-Tenant User IDs when reading', async () => {
    for (const token of [
      directorAccessToken,
      accountantAccessToken,
      foremanAccessToken,
    ]) {
      const response = await request(server)
        .get(`/api/v1/users/${secondTenantUserId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'USER_NOT_FOUND' },
      });
    }
  });

  it('updates mutable User fields and records only changed values', async () => {
    const response = await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .set('User-Agent', 'TexERP Task 4 E2E')
      .send({
        full_name: 'Updated User',
        language: 'ru',
        avatar_url: 'https://cdn.example.com/users/updated.png',
      })
      .expect(200);

    expect(response.body).toMatchObject({
      success: true,
      data: {
        id: mutableUserId,
        full_name: 'Updated User',
        phone: '+998901230019',
        worker_code: 'W-UPDATE',
        role: 'WORKER',
        status: 'ACTIVE',
        language: 'ru',
        avatar_url: 'https://cdn.example.com/users/updated.png',
        department: null,
        foreman: null,
      },
    });
    expect((response.body as ReadUserBody).data.created_at).toEqual(
      expect.any(String),
    );

    const audit = await admin.query<UserUpdatedAuditRow>(
      `SELECT actor_id, actor_role, before_state, after_state,
              ip_address::text, user_agent
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_id = $2
         AND action = 'USER_UPDATED'`,
      [tenantId, mutableUserId],
    );
    expect(audit.rows).toEqual([
      {
        actor_id: directorId,
        actor_role: 'DIRECTOR',
        before_state: {
          full_name: 'Mutable User',
          language: 'uz',
          avatar_url: null,
        },
        after_state: {
          full_name: 'Updated User',
          language: 'ru',
          avatar_url: 'https://cdn.example.com/users/updated.png',
        },
        ip_address: '::ffff:127.0.0.1/128',
        user_agent: 'TexERP Task 4 E2E',
      },
    ]);
  });

  it('updates a User avatar to null', async () => {
    const response = await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({ avatar_url: null })
      .expect(200);

    expect(response.body).toMatchObject({
      success: true,
      data: { id: mutableUserId, avatar_url: null },
    });
  });

  it('updates: skips persistence and auditing when all values are identical', async () => {
    await admin.query(
      `UPDATE users
       SET updated_at = '2020-01-01T00:00:00.000Z'
       WHERE tenant_id = $1 AND id = $2`,
      [tenantId, mutableUserId],
    );
    const before = await admin.query<{
      updated_at: Date;
      audit_count: string;
    }>(
      `SELECT u.updated_at,
              count(a.id) FILTER (WHERE a.action = 'USER_UPDATED')::text AS audit_count
       FROM users u
       LEFT JOIN audit_events a
         ON a.tenant_id = u.tenant_id AND a.aggregate_id = u.id
       WHERE u.tenant_id = $1 AND u.id = $2
       GROUP BY u.updated_at`,
      [tenantId, mutableUserId],
    );

    const response = await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({ full_name: 'Updated User', language: 'ru', avatar_url: null })
      .expect(200);

    expect(response.body).toMatchObject({
      success: true,
      data: {
        id: mutableUserId,
        full_name: 'Updated User',
        language: 'ru',
        avatar_url: null,
      },
    });
    const after = await admin.query<{
      updated_at: Date;
      audit_count: string;
    }>(
      `SELECT u.updated_at,
              count(a.id) FILTER (WHERE a.action = 'USER_UPDATED')::text AS audit_count
       FROM users u
       LEFT JOIN audit_events a
         ON a.tenant_id = u.tenant_id AND a.aggregate_id = u.id
       WHERE u.tenant_id = $1 AND u.id = $2
       GROUP BY u.updated_at`,
      [tenantId, mutableUserId],
    );
    expect(after.rows).toEqual(before.rows);
  });

  it('updates: audits only changed fields in a mixed request', async () => {
    await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Updated User',
        language: 'ru',
        avatar_url: 'https://cdn.example.com/users/mixed.png',
      })
      .expect(200);

    const audit = await admin.query<{
      before_state: Record<string, unknown>;
      after_state: Record<string, unknown>;
    }>(
      `SELECT before_state, after_state
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_id = $2
         AND action = 'USER_UPDATED'
         AND after_state->>'avatar_url' = $3`,
      [tenantId, mutableUserId, 'https://cdn.example.com/users/mixed.png'],
    );
    expect(audit.rows).toEqual([
      {
        before_state: { avatar_url: null },
        after_state: {
          avatar_url: 'https://cdn.example.com/users/mixed.png',
        },
      },
    ]);
  });

  it('updates: forbids an Accountant', async () => {
    const response = await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${accountantAccessToken}`)
      .send({ full_name: 'Forbidden Update' })
      .expect(403);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'FORBIDDEN' },
    });
  });

  it('updates: conceals cross-Tenant User IDs', async () => {
    const response = await request(server)
      .patch(`/api/v1/users/${secondTenantUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({ full_name: 'Cross Tenant Update' })
      .expect(404);

    expect(response.body).toMatchObject({
      success: false,
      error: { code: 'USER_NOT_FOUND' },
    });
  });

  it('updates: rejects immutable User fields', async () => {
    const immutableFields: Record<string, unknown>[] = [
      { phone: '+998901239999' },
      { worker_code: 'IMMUTABLE' },
      { role: 'ACCOUNTANT' },
      { status: 'DEACTIVATED' },
      { department_id: departmentId },
      { foreman_id: foremanId },
    ];

    for (const body of immutableFields) {
      await request(server)
        .patch(`/api/v1/users/${mutableUserId}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send(body)
        .expect(400);
    }
  });

  it('updates: rejects an empty body with a stable application error', async () => {
    const response = await request(server)
      .patch(`/api/v1/users/${mutableUserId}`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({})
      .expect(400);

    expect(response.body).toEqual({
      success: false,
      error: {
        code: 'EMPTY_UPDATE',
        message: 'Yangilash maydonlari berilmagan',
      },
    });
  });

  it('updates: inserts the audit event before changing the User', async () => {
    await admin.query(`
      CREATE OR REPLACE FUNCTION task_4_check_user_update()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.worker_code = 'W-UPDATE'
           AND NOT EXISTS (
             SELECT 1
             FROM audit_events
             WHERE tenant_id = NEW.tenant_id
               AND aggregate_id = NEW.id
               AND action = 'USER_UPDATED'
               AND after_state->>'full_name' = NEW.full_name
           ) THEN
          RAISE EXCEPTION 'Task 4 audit event must precede User update';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_4_check_user_update
      BEFORE UPDATE ON users
      FOR EACH ROW EXECUTE FUNCTION task_4_check_user_update()
    `);

    try {
      await request(server)
        .patch(`/api/v1/users/${mutableUserId}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({ full_name: 'Audit First User' })
        .expect(200);
    } finally {
      await admin.query(
        'DROP TRIGGER IF EXISTS task_4_check_user_update ON users',
      );
      await admin.query('DROP FUNCTION IF EXISTS task_4_check_user_update()');
    }
  });

  it('updates: rolls back the audit event when persistence fails', async () => {
    await admin.query(`
      CREATE OR REPLACE FUNCTION task_4_check_user_update()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.full_name = 'Rejected Update' THEN
          RAISE EXCEPTION 'forced Task 4 User update failure';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_4_check_user_update
      BEFORE UPDATE ON users
      FOR EACH ROW EXECUTE FUNCTION task_4_check_user_update()
    `);

    try {
      await request(server)
        .patch(`/api/v1/users/${mutableUserId}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({ full_name: 'Rejected Update' })
        .expect(500);
    } finally {
      await admin.query(
        'DROP TRIGGER IF EXISTS task_4_check_user_update ON users',
      );
      await admin.query('DROP FUNCTION IF EXISTS task_4_check_user_update()');
    }

    const effects = await admin.query<{
      full_name: string;
      rejected_audits: string;
    }>(
      `SELECT u.full_name,
              count(a.id) FILTER (
                WHERE a.after_state->>'full_name' = 'Rejected Update'
              )::text AS rejected_audits
       FROM users u
       LEFT JOIN audit_events a
         ON a.tenant_id = u.tenant_id AND a.aggregate_id = u.id
       WHERE u.tenant_id = $1 AND u.id = $2
       GROUP BY u.full_name`,
      [tenantId, mutableUserId],
    );
    expect(effects.rows).toEqual([
      { full_name: 'Audit First User', rejected_audits: '0' },
    ]);
  });

  it('deactivates: rejects self-deactivation with a stable error', async () => {
    const response = await request(server)
      .post(`/api/v1/users/${directorId}/deactivate`)
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({})
      .expect(400);

    expect(response.body).toEqual({
      success: false,
      error: {
        code: 'CANNOT_DEACTIVATE_SELF',
        message: "Direktor o'zini nofaol qila olmaydi",
      },
    });
  });

  it('deactivates and reactivates only as a Director', async () => {
    for (const action of ['deactivate', 'reactivate']) {
      const response = await request(server)
        .post(`/api/v1/users/${deactivatedWorkerId}/${action}`)
        .set('Authorization', `Bearer ${accountantAccessToken}`)
        .send({})
        .expect(403);

      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'FORBIDDEN' },
      });
    }
  });

  it('deactivates and reactivates: conceals cross-Tenant User IDs', async () => {
    for (const action of ['deactivate', 'reactivate']) {
      const response = await request(server)
        .post(`/api/v1/users/${secondTenantUserId}/${action}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(404);

      expect(response.body).toMatchObject({
        success: false,
        error: { code: 'USER_NOT_FOUND' },
      });
    }
  });

  it('deactivates and reactivates: reject malformed User IDs', async () => {
    for (const action of ['deactivate', 'reactivate']) {
      const response = await request(server)
        .post(`/api/v1/users/not-a-uuid/${action}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(400);

      const body = response.body as ErrorEnvelopeBody;
      expect(body).toMatchObject({
        success: false,
        error: { code: 'VALIDATION_ERROR' },
      });
      expect(body.error.message).toContain('uuid');
    }
  });

  it('deactivates and reactivates: accepts only an empty body', async () => {
    for (const action of ['reactivate', 'deactivate']) {
      const rejected = await request(server)
        .post(`/api/v1/users/${deactivatedWorkerId}/${action}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({ unexpected: true })
        .expect(400);

      const body = rejected.body as ErrorEnvelopeBody;
      expect(body).toMatchObject({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
        },
      });
      expect(body.error.message).toEqual(
        expect.arrayContaining([
          expect.stringContaining('unexpected should not exist'),
        ]),
      );

      await request(server)
        .post(`/api/v1/users/${deactivatedWorkerId}/${action}`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(200);
    }
  });

  it('deactivates and reactivates with audit-first session revocation', async () => {
    const secondLogin = await request(server)
      .post('/api/v1/auth/login')
      .send({ phone: workerPhone, pin: '4826' })
      .expect(200);
    const secondWorkerAccessToken = (secondLogin.body as LoginBody).data
      .access_token;
    const secondWorkerRefreshToken = (secondLogin.body as LoginBody).data
      .refresh_token;
    const alreadyRevokedSessionId = randomUUID();
    const expiredSessionId = randomUUID();

    await admin.query(
      `INSERT INTO user_sessions
        (id, tenant_id, user_id, refresh_token_hash, expires_at, revoked_at, revoked_reason)
       VALUES
        ($1, $2, $3, $4, now() + interval '1 day', now(), 'LOGOUT'),
        ($5, $2, $3, $6, now() - interval '1 day', NULL, NULL)`,
      [
        alreadyRevokedSessionId,
        tenantId,
        workerId,
        `task-5-already-revoked-${alreadyRevokedSessionId}`,
        expiredSessionId,
        `task-5-expired-${expiredSessionId}`,
      ],
    );
    const sessionBaseline = await admin.query<{
      active_sessions: string;
      already_revoked_sessions: string;
      expired_sessions: string;
    }>(
      `SELECT
         count(*) FILTER (
           WHERE revoked_at IS NULL AND expires_at > now()
         )::text AS active_sessions,
         count(*) FILTER (WHERE revoked_at IS NOT NULL)::text AS already_revoked_sessions,
         count(*) FILTER (
           WHERE revoked_at IS NULL AND expires_at <= now()
         )::text AS expired_sessions
       FROM user_sessions
       WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId, workerId],
    );
    expect(sessionBaseline.rows).toEqual([
      {
        active_sessions: '2',
        already_revoked_sessions: '1',
        expired_sessions: '1',
      },
    ]);

    await admin.query(`
      CREATE OR REPLACE FUNCTION task_5_check_user_lifecycle()
      RETURNS trigger AS $$
      BEGIN
        IF OLD.status = 'ACTIVE' AND NEW.status = 'DEACTIVATED'
           AND NOT EXISTS (
             SELECT 1 FROM audit_events
             WHERE tenant_id = NEW.tenant_id
               AND aggregate_id = NEW.id
               AND action = 'USER_DEACTIVATED'
           ) THEN
          RAISE EXCEPTION 'Task 5 deactivation audit must precede User update';
        END IF;
        IF OLD.status = 'DEACTIVATED' AND NEW.status = 'ACTIVE'
           AND NOT EXISTS (
             SELECT 1 FROM audit_events
             WHERE tenant_id = NEW.tenant_id
               AND aggregate_id = NEW.id
               AND action = 'USER_REACTIVATED'
           ) THEN
          RAISE EXCEPTION 'Task 5 reactivation audit must precede User update';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_5_check_user_lifecycle
      BEFORE UPDATE OF status ON users
      FOR EACH ROW EXECUTE FUNCTION task_5_check_user_lifecycle()
    `);

    try {
      const deactivation = await request(server)
        .post(`/api/v1/users/${workerId}/deactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .set('User-Agent', 'TexERP Task 5 E2E')
        .send({})
        .expect(200);

      expect(deactivation.body).toEqual({
        success: true,
        data: {
          message: 'Foydalanuvchi nofaol qilindi',
          sessions_revoked: 2,
        },
      });

      const deactivatedState = await admin.query<{
        status: string;
        deactivated_at: Date | null;
        deactivated_by: string | null;
        active_sessions: string;
        revoked_sessions: string;
      }>(
        `SELECT u.status, u.deactivated_at, u.deactivated_by,
                count(s.id) FILTER (WHERE s.revoked_at IS NULL)::text AS active_sessions,
                count(s.id) FILTER (
                  WHERE s.revoked_at IS NOT NULL
                    AND s.revoked_reason = 'DEACTIVATED'
                )::text AS revoked_sessions
         FROM users u
         LEFT JOIN user_sessions s
           ON s.tenant_id = u.tenant_id AND s.user_id = u.id
         WHERE u.tenant_id = $1 AND u.id = $2
         GROUP BY u.status, u.deactivated_at, u.deactivated_by`,
        [tenantId, workerId],
      );
      expect(deactivatedState.rows[0]?.deactivated_at).toBeInstanceOf(Date);
      expect(deactivatedState.rows[0]).toMatchObject({
        status: 'DEACTIVATED',
        deactivated_by: directorId,
        active_sessions: '0',
        revoked_sessions: '3',
      });

      for (const token of [workerAccessToken, secondWorkerAccessToken]) {
        await request(server)
          .get(`/api/v1/users/${workerId}`)
          .set('Authorization', `Bearer ${token}`)
          .expect(401);
      }
      for (const token of [workerRefreshToken, secondWorkerRefreshToken]) {
        const response = await request(server)
          .post('/api/v1/auth/refresh')
          .send({ refresh_token: token })
          .expect(401);
        expect(response.body).toMatchObject({
          success: false,
          error: { code: 'INVALID_REFRESH_TOKEN' },
        });
      }

      const duplicateDeactivation = await request(server)
        .post(`/api/v1/users/${workerId}/deactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(400);
      expect(duplicateDeactivation.body).toMatchObject({
        success: false,
        error: { code: 'USER_ALREADY_DEACTIVATED' },
      });

      const reactivation = await request(server)
        .post(`/api/v1/users/${workerId}/reactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .set('User-Agent', 'TexERP Task 5 E2E')
        .send({})
        .expect(200);
      expect(reactivation.body).toEqual({
        success: true,
        data: { message: 'Foydalanuvchi faollashtirildi' },
      });

      const reactivatedState = await admin.query<{
        status: string;
        deactivated_at: Date | null;
        deactivated_by: string | null;
        revoked_sessions: string;
      }>(
        `SELECT u.status, u.deactivated_at, u.deactivated_by,
                count(s.id) FILTER (WHERE s.revoked_at IS NOT NULL)::text AS revoked_sessions
         FROM users u
         LEFT JOIN user_sessions s
           ON s.tenant_id = u.tenant_id AND s.user_id = u.id
         WHERE u.tenant_id = $1 AND u.id = $2
         GROUP BY u.status, u.deactivated_at, u.deactivated_by`,
        [tenantId, workerId],
      );
      expect(reactivatedState.rows).toEqual([
        {
          status: 'ACTIVE',
          deactivated_at: null,
          deactivated_by: null,
          revoked_sessions: '4',
        },
      ]);

      const duplicateReactivation = await request(server)
        .post(`/api/v1/users/${workerId}/reactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(400);
      expect(duplicateReactivation.body).toMatchObject({
        success: false,
        error: { code: 'USER_ALREADY_ACTIVE' },
      });

      for (const token of [workerAccessToken, secondWorkerAccessToken]) {
        await request(server)
          .get(`/api/v1/users/${workerId}`)
          .set('Authorization', `Bearer ${token}`)
          .expect(401);
      }
      for (const token of [workerRefreshToken, secondWorkerRefreshToken]) {
        const response = await request(server)
          .post('/api/v1/auth/refresh')
          .send({ refresh_token: token })
          .expect(401);
        expect(response.body).toMatchObject({
          success: false,
          error: { code: 'INVALID_REFRESH_TOKEN' },
        });
      }

      const audits = await admin.query<UserLifecycleAuditRow>(
        `SELECT action, actor_id, actor_role, before_state, after_state,
                ip_address::text, user_agent
         FROM audit_events
         WHERE tenant_id = $1
           AND aggregate_id = $2
           AND action IN ('USER_DEACTIVATED', 'USER_REACTIVATED')
         ORDER BY occurred_at ASC`,
        [tenantId, workerId],
      );
      expect(audits.rows).toHaveLength(2);
      expect(typeof audits.rows[0]?.after_state.deactivated_at).toBe('string');
      expect(audits.rows[0]).toMatchObject({
        action: 'USER_DEACTIVATED',
        actor_id: directorId,
        actor_role: 'DIRECTOR',
        before_state: {
          status: 'ACTIVE',
          deactivated_at: null,
          deactivated_by: null,
        },
        after_state: {
          status: 'DEACTIVATED',
          deactivated_by: directorId,
        },
        ip_address: '::ffff:127.0.0.1/128',
        user_agent: 'TexERP Task 5 E2E',
      });
      expect(typeof audits.rows[1]?.before_state.deactivated_at).toBe('string');
      expect(audits.rows[1]).toMatchObject({
        action: 'USER_REACTIVATED',
        actor_id: directorId,
        actor_role: 'DIRECTOR',
        before_state: {
          status: 'DEACTIVATED',
          deactivated_by: directorId,
        },
        after_state: {
          status: 'ACTIVE',
          deactivated_at: null,
          deactivated_by: null,
        },
        ip_address: '::ffff:127.0.0.1/128',
        user_agent: 'TexERP Task 5 E2E',
      });
    } finally {
      await admin.query(
        'DROP TRIGGER IF EXISTS task_5_check_user_lifecycle ON users',
      );
      await admin.query(
        'DROP FUNCTION IF EXISTS task_5_check_user_lifecycle()',
      );
    }
  });

  it('deactivates safely after a concurrent successful login holding the User lock', async () => {
    const raceUserId = randomUUID();
    const racePhone = '+998901230020';
    const suffix = raceUserId.replaceAll('-', '');
    const functionName = `users_e2e_login_barrier_${suffix}`;
    const triggerName = `users_e2e_login_barrier_${suffix}`;
    const lockKey = Number.parseInt(suffix.slice(0, 7), 16);
    const lockClient = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    let loginPromise: Promise<request.Response> | undefined;
    let deactivationPromise: Promise<request.Response> | undefined;
    let loginPid: number | undefined;
    let deactivationPid: number | undefined;
    let accessToken: string | undefined;

    await lockClient.connect();
    try {
      await admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES ($1, $2, $3, $4, 'Login Race User', $5, 'WORKER', 'ACTIVE')`,
        [
          raceUserId,
          tenantId,
          racePhone,
          await bcrypt.hash('4826', 4),
          `LR-${raceUserId.slice(0, 8)}`,
        ],
      );
      await lockClient.query('SELECT pg_advisory_lock($1)', [lockKey]);
      await admin.query(`
        CREATE FUNCTION ${functionName}()
        RETURNS trigger AS $$
        BEGIN
          IF NEW.user_id = '${raceUserId}'::uuid THEN
            PERFORM pg_advisory_xact_lock(${lockKey});
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);
      await admin.query(`
        CREATE TRIGGER ${triggerName}
        AFTER INSERT ON user_sessions
        FOR EACH ROW EXECUTE FUNCTION ${functionName}()
      `);

      loginPromise = request(server)
        .post('/api/v1/auth/login')
        .send({ phone: racePhone, pin: '4826' })
        .then((response) => response);
      loginPid = await waitForAdvisoryLockWaiter(lockClient, lockKey);

      deactivationPromise = request(server)
        .post(`/api/v1/users/${raceUserId}/deactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .then((response) => response);
      deactivationPid = await waitForBlockedQuery(
        loginPid,
        'SELECT status, deactivated_at, deactivated_by',
      );
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);

      const [login, deactivation] = await withTimeout(
        Promise.all([loginPromise, deactivationPromise]),
        'Timed out waiting for concurrent login and deactivation',
      );
      expect(login.status).toBe(200);
      expect(deactivation.status).toBe(200);
      const tokens = (login.body as LoginBody).data;
      accessToken = tokens.access_token;
      await expectAccessAndRefreshRejected(
        raceUserId,
        tokens.access_token,
        tokens.refresh_token,
      );
    } finally {
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);
      let settleError: unknown;
      try {
        await settleRequests([loginPromise, deactivationPromise]);
      } catch (error) {
        settleError = error;
        await terminateTestBackends([loginPid, deactivationPid]);
        await settleRequests([loginPromise, deactivationPromise]);
      }
      await admin.query(
        `DROP TRIGGER IF EXISTS ${triggerName} ON user_sessions`,
      );
      await admin.query(`DROP FUNCTION IF EXISTS ${functionName}()`);
      await admin.query(
        'DELETE FROM audit_events WHERE aggregate_id = $1 OR actor_id = $1',
        [raceUserId],
      );
      await admin.query('DELETE FROM user_sessions WHERE user_id = $1', [
        raceUserId,
      ]);
      await admin.query('DELETE FROM users WHERE id = $1', [raceUserId]);
      await cleanupRaceRedis(racePhone, accessToken ? [accessToken] : []);
      await lockClient.end();
      expect(settleError).toBeUndefined();
    }
  });

  it('deactivates safely after a concurrent refresh transaction', async () => {
    const raceUserId = randomUUID();
    const racePhone = '+998901230021';
    const suffix = raceUserId.replaceAll('-', '');
    const functionName = `users_e2e_refresh_barrier_${suffix}`;
    const triggerName = `users_e2e_refresh_barrier_${suffix}`;
    const lockKey = Number.parseInt(suffix.slice(0, 7), 16);
    const lockClient = new Client({
      connectionString:
        process.env.DATABASE_ADMIN_URL ??
        'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    let refreshPromise: Promise<request.Response> | undefined;
    let deactivationPromise: Promise<request.Response> | undefined;
    let refreshPid: number | undefined;
    let deactivationPid: number | undefined;
    let accessToken: string | undefined;

    await lockClient.connect();
    try {
      await admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES ($1, $2, $3, $4, 'Refresh Race User', $5, 'WORKER', 'ACTIVE')`,
        [
          raceUserId,
          tenantId,
          racePhone,
          await bcrypt.hash('4826', 4),
          `RR-${raceUserId.slice(0, 8)}`,
        ],
      );
      const login = await request(server)
        .post('/api/v1/auth/login')
        .send({ phone: racePhone, pin: '4826' })
        .expect(200);
      const originalRefreshToken = (login.body as LoginBody).data.refresh_token;

      await lockClient.query('SELECT pg_advisory_lock($1)', [lockKey]);
      await admin.query(`
        CREATE FUNCTION ${functionName}()
        RETURNS trigger AS $$
        BEGIN
          IF NEW.user_id = '${raceUserId}'::uuid
             AND OLD.refresh_token_hash <> NEW.refresh_token_hash THEN
            PERFORM pg_advisory_xact_lock(${lockKey});
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);
      await admin.query(`
        CREATE TRIGGER ${triggerName}
        AFTER UPDATE OF refresh_token_hash ON user_sessions
        FOR EACH ROW EXECUTE FUNCTION ${functionName}()
      `);

      refreshPromise = request(server)
        .post('/api/v1/auth/refresh')
        .send({ refresh_token: originalRefreshToken })
        .then((response) => response);
      refreshPid = await waitForAdvisoryLockWaiter(lockClient, lockKey);

      deactivationPromise = request(server)
        .post(`/api/v1/users/${raceUserId}/deactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .then((response) => response);
      deactivationPid = await waitForBlockedQuery(
        refreshPid,
        'SELECT status, deactivated_at, deactivated_by',
      );
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);

      const [refresh, deactivation] = await withTimeout(
        Promise.all([refreshPromise, deactivationPromise]),
        'Timed out waiting for concurrent refresh and deactivation',
      );
      expect(refresh.status).toBe(200);
      expect(deactivation.status).toBe(200);
      const rotatedTokens = (refresh.body as RefreshBody).data;
      accessToken = rotatedTokens.access_token;
      await expectAccessAndRefreshRejected(
        raceUserId,
        rotatedTokens.access_token,
        rotatedTokens.refresh_token,
      );
      const originalRefresh = await request(server)
        .post('/api/v1/auth/refresh')
        .send({ refresh_token: originalRefreshToken })
        .expect(401);
      expect(originalRefresh.body).toMatchObject({
        success: false,
        error: { code: 'INVALID_REFRESH_TOKEN' },
      });
    } finally {
      await lockClient.query('SELECT pg_advisory_unlock($1)', [lockKey]);
      let settleError: unknown;
      try {
        await settleRequests([refreshPromise, deactivationPromise]);
      } catch (error) {
        settleError = error;
        await terminateTestBackends([refreshPid, deactivationPid]);
        await settleRequests([refreshPromise, deactivationPromise]);
      }
      await admin.query(
        `DROP TRIGGER IF EXISTS ${triggerName} ON user_sessions`,
      );
      await admin.query(`DROP FUNCTION IF EXISTS ${functionName}()`);
      await admin.query(
        'DELETE FROM audit_events WHERE aggregate_id = $1 OR actor_id = $1',
        [raceUserId],
      );
      await admin.query('DELETE FROM user_sessions WHERE user_id = $1', [
        raceUserId,
      ]);
      await admin.query('DELETE FROM users WHERE id = $1', [raceUserId]);
      await cleanupRaceRedis(racePhone, accessToken ? [accessToken] : []);
      await lockClient.end();
      expect(settleError).toBeUndefined();
    }
  });

  it('deactivates: rolls back its audit event when persistence fails', async () => {
    await admin.query(`
      CREATE OR REPLACE FUNCTION task_5_check_user_lifecycle()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.id = '${unassignedWorkerId}'::uuid
           AND NEW.status = 'DEACTIVATED' THEN
          RAISE EXCEPTION 'forced Task 5 User deactivation failure';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_5_check_user_lifecycle
      BEFORE UPDATE OF status ON users
      FOR EACH ROW EXECUTE FUNCTION task_5_check_user_lifecycle()
    `);

    try {
      await request(server)
        .post(`/api/v1/users/${unassignedWorkerId}/deactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(500);
    } finally {
      await admin.query(
        'DROP TRIGGER IF EXISTS task_5_check_user_lifecycle ON users',
      );
      await admin.query(
        'DROP FUNCTION IF EXISTS task_5_check_user_lifecycle()',
      );
    }

    const effects = await admin.query<{ status: string; audit_count: string }>(
      `SELECT u.status, count(a.id)::text AS audit_count
       FROM users u
       LEFT JOIN audit_events a
         ON a.tenant_id = u.tenant_id
        AND a.aggregate_id = u.id
        AND a.action = 'USER_DEACTIVATED'
       WHERE u.tenant_id = $1 AND u.id = $2
       GROUP BY u.status`,
      [tenantId, unassignedWorkerId],
    );
    expect(effects.rows).toEqual([{ status: 'ACTIVE', audit_count: '0' }]);
  });

  it('reactivates: rolls back its audit event when persistence fails', async () => {
    const baseline = await admin.query<{ audit_count: string }>(
      `SELECT count(*)::text AS audit_count
       FROM audit_events
       WHERE tenant_id = $1
         AND aggregate_id = $2
         AND action = 'USER_REACTIVATED'`,
      [tenantId, deactivatedWorkerId],
    );
    await admin.query(`
      CREATE OR REPLACE FUNCTION task_5_check_user_lifecycle()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.id = '${deactivatedWorkerId}'::uuid
           AND NEW.status = 'ACTIVE' THEN
          RAISE EXCEPTION 'forced Task 5 User reactivation failure';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_5_check_user_lifecycle
      BEFORE UPDATE OF status ON users
      FOR EACH ROW EXECUTE FUNCTION task_5_check_user_lifecycle()
    `);

    try {
      await request(server)
        .post(`/api/v1/users/${deactivatedWorkerId}/reactivate`)
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({})
        .expect(500);
    } finally {
      await admin.query(
        'DROP TRIGGER IF EXISTS task_5_check_user_lifecycle ON users',
      );
      await admin.query(
        'DROP FUNCTION IF EXISTS task_5_check_user_lifecycle()',
      );
    }

    const effects = await admin.query<{ status: string; audit_count: string }>(
      `SELECT u.status, count(a.id)::text AS audit_count
       FROM users u
       LEFT JOIN audit_events a
         ON a.tenant_id = u.tenant_id
        AND a.aggregate_id = u.id
        AND a.action = 'USER_REACTIVATED'
       WHERE u.tenant_id = $1 AND u.id = $2
       GROUP BY u.status`,
      [tenantId, deactivatedWorkerId],
    );
    expect(effects.rows).toEqual([
      { status: 'DEACTIVATED', audit_count: baseline.rows[0]?.audit_count },
    ]);
  });

  it('rejects creation of another Director', async () => {
    const response = await request(server)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${directorAccessToken}`)
      .send({
        full_name: 'Nodira Aliyeva',
        phone: '+998901230002',
        worker_code: 'D-0002',
        role: 'DIRECTOR',
        initial_pin: '4321',
      })
      .expect(400);

    expect(response.body).toEqual({
      success: false,
      error: {
        code: 'CANNOT_CREATE_DIRECTOR',
        message: 'Direktor boshqa direktor yarata olmaydi',
      },
    });
  });

  it('rejects department_id and foreman_id as deferred User creation fields', async () => {
    for (const deferredField of ['department_id', 'foreman_id'] as const) {
      const response = await request(server)
        .post('/api/v1/users')
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .send({
          full_name: 'Nodira Aliyeva',
          phone: '+998901230002',
          worker_code: 'W-0044',
          role: 'WORKER',
          initial_pin: '4321',
          [deferredField]: randomUUID(),
        })
        .expect(400);

      const body = response.body as ErrorEnvelopeBody;
      expect(body).toMatchObject({
        success: false,
        error: { code: 'VALIDATION_ERROR' },
      });
      expect(body.error.message).toEqual(
        expect.arrayContaining([
          expect.stringContaining(`${deferredField} should not exist`),
        ]),
      );
    }
  });

  it('rolls back the audit event when the User insert fails', async () => {
    await admin.query(`
      CREATE OR REPLACE FUNCTION task_1_reject_user_insert()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.worker_code = 'ROLLBACK' THEN
          RAISE EXCEPTION 'forced Task 1 User insert failure';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    `);
    await admin.query(`
      CREATE TRIGGER task_1_reject_user
      BEFORE INSERT ON users
      FOR EACH ROW EXECUTE FUNCTION task_1_reject_user_insert()
    `);

    try {
      await request(server)
        .post('/api/v1/users')
        .set('Authorization', `Bearer ${directorAccessToken}`)
        .set('User-Agent', 'TexERP Task 1 Rollback E2E')
        .send({
          full_name: 'Rollback User',
          phone: '+998901230003',
          worker_code: 'ROLLBACK',
          role: 'WORKER',
          initial_pin: '4321',
        })
        .expect(500);
    } finally {
      await admin.query('DROP TRIGGER IF EXISTS task_1_reject_user ON users');
      await admin.query('DROP FUNCTION IF EXISTS task_1_reject_user_insert()');
    }

    const rolledBackEffects = await admin.query<{ kind: string }>(
      `SELECT 'user' AS kind
       FROM users
       WHERE tenant_id = $1 AND phone = $2
       UNION ALL
       SELECT 'audit' AS kind
       FROM audit_events
       WHERE tenant_id = $1
         AND action = 'USER_CREATED'
         AND after_state->>'phone' = $2`,
      [tenantId, '+998901230003'],
    );
    expect(rolledBackEffects.rows).toEqual([]);
  });
});
