import { randomUUID } from 'node:crypto';
import { Client } from 'pg';
import { DataSource } from 'typeorm';
import { TenantDatabase } from '../../src/infrastructure/database/tenant-database';

const adminUrl =
  process.env.DATABASE_ADMIN_URL ??
  'postgresql://texerp:texerp@localhost:5432/texerp';
const appUrl =
  process.env.DATABASE_URL ??
  'postgresql://texerp_app:texerp_app@localhost:5432/texerp';

describe('PostgreSQL tenant isolation', () => {
  const admin = new Client({ connectionString: adminUrl });
  const app = new Client({ connectionString: appUrl });
  const tenantA = randomUUID();
  const tenantB = randomUUID();
  const userA = randomUUID();
  const userB = randomUUID();
  const foremanA = randomUUID();
  const foremanB = randomUUID();
  const departmentA = randomUUID();
  const departmentB = randomUUID();
  const foremanAssignmentA = randomUUID();
  const foremanAssignmentB = randomUUID();
  const operationA = randomUUID();
  const operationB = randomUUID();
  const operationPriceA = randomUUID();
  const operationPriceB = randomUUID();
  const auditEvent = randomUUID();
  const auditEventB = randomUUID();
  const materialA = randomUUID();
  const materialB = randomUUID();
  const stockMovementA = randomUUID();
  const stockMovementB = randomUUID();
  const tenantSettingA = randomUUID();
  const tenantSettingB = randomUUID();
  const notificationA = randomUUID();
  const notificationB = randomUUID();
  const notificationPreferenceA = randomUUID();
  const notificationPreferenceB = randomUUID();
  const notificationTemplateA = randomUUID();
  const notificationTemplateB = randomUUID();
  const reportExportA = randomUUID();
  const reportExportB = randomUUID();
  const featureFlagA = randomUUID();
  const featureFlagB = randomUUID();
  const subscriptionPlan = randomUUID();
  const tenantSubscription = randomUUID();
  const platformUser = randomUUID();
  const platformSession = randomUUID();
  const platformAuditEvent = randomUUID();

  beforeAll(async () => {
    await admin.connect();
    await app.connect();
    await admin.query(
      `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Tenant A', $2), ($3, 'Tenant B', $4)`,
      [tenantA, `tenant-a-${tenantA}`, tenantB, `tenant-b-${tenantB}`],
    );
    await admin.query(
      `INSERT INTO users
        (id, tenant_id, phone, pin_hash, full_name, worker_code, role)
       VALUES
        ($1, $2, '+998901111111', 'hash', 'Worker A', 'W-A', 'WORKER'),
        ($3, $4, '+998902222222', 'hash', 'Worker B', 'W-B', 'WORKER'),
        ($5, $2, '+998903333333', 'hash', 'Foreman A', 'F-A', 'FOREMAN'),
        ($6, $4, '+998904444444', 'hash', 'Foreman B', 'F-B', 'FOREMAN')`,
      [userA, tenantA, userB, tenantB, foremanA, foremanB],
    );
    await admin.query(
      `INSERT INTO audit_events
        (id, tenant_id, aggregate_type, aggregate_id, action, actor_id, actor_role)
       VALUES
        ($1, $2, 'USER', $3, 'CREATED', $3, 'WORKER'),
        ($4, $5, 'USER', $6, 'CREATED', $6, 'WORKER')`,
      [auditEvent, tenantA, userA, auditEventB, tenantB, userB],
    );
    await admin.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
       VALUES
        ($1, $2, 'Department A', 'D-A', $3),
        ($4, $5, 'Department B', 'D-B', $6)`,
      [departmentA, tenantA, foremanA, departmentB, tenantB, foremanB],
    );
    await admin.query(
      `INSERT INTO foreman_assignments
        (id, tenant_id, worker_id, foreman_id, department_id, assigned_by)
       VALUES
        ($1, $2, $3, $4, $5, $4),
        ($6, $7, $8, $9, $10, $9)`,
      [
        foremanAssignmentA,
        tenantA,
        userA,
        foremanA,
        departmentA,
        foremanAssignmentB,
        tenantB,
        userB,
        foremanB,
        departmentB,
      ],
    );
    await admin.query(
      `INSERT INTO user_sessions
        (id, tenant_id, user_id, refresh_token_hash, expires_at)
       VALUES
        ($1, $2, $3, 'hash-a', now() + interval '1 day'),
        ($4, $5, $6, 'hash-b', now() + interval '1 day')`,
      [randomUUID(), tenantA, userA, randomUUID(), tenantB, userB],
    );
    await admin.query(
      `INSERT INTO operations
        (id, tenant_id, name, code, unit, unit_price, created_by)
       VALUES
        ($1, $2, 'Operation A', 'OP-A', 'PIECE', 45000, $3),
        ($4, $5, 'Operation B', 'OP-B', 'PIECE', 55000, $6)`,
      [operationA, tenantA, userA, operationB, tenantB, userB],
    );
    await admin.query(
      `INSERT INTO operation_price_history
        (id, tenant_id, operation_id, unit_price, effective_from, changed_by)
       VALUES
        ($1, $2, $3, 45000, now(), $4),
        ($5, $6, $7, 55000, now(), $8)`,
      [operationPriceA, tenantA, operationA, userA, operationPriceB, tenantB, operationB, userB],
    );

    await admin.query(
      `INSERT INTO materials
        (id, tenant_id, code, name, unit, created_by)
       VALUES
        ($1, $2, 'MAT-A', 'Material A', 'KG', $3),
        ($4, $5, 'MAT-B', 'Material B', 'KG', $6)`,
      [materialA, tenantA, userA, materialB, tenantB, userB],
    );

    await admin.query(
      `INSERT INTO stock_movements
        (id, tenant_id, material_id, type, quantity, unit_snapshot, movement_date, recorded_by)
       VALUES
        ($1, $2, $3, 'RECEIPT', 100, 'KG', current_date, $4),
        ($5, $6, $7, 'RECEIPT', 200, 'KG', current_date, $8)`,
      [stockMovementA, tenantA, materialA, userA, stockMovementB, tenantB, materialB, userB],
    );

    await admin.query(
      `INSERT INTO tenant_settings
        (id, tenant_id)
       VALUES
        ($1, $2),
        ($3, $4)`,
      [tenantSettingA, tenantA, tenantSettingB, tenantB],
    );

    await admin.query(
      `INSERT INTO notifications
        (id, tenant_id, recipient_id, type, title_uz, title_ru, body_uz, body_ru, channel)
       VALUES
        ($1, $2, $3, 'ENTRY_APPROVED', 'Tasdiq A', 'Одобрено A', 'Body A', 'Тело A', 'BOTH'),
        ($4, $5, $6, 'ENTRY_APPROVED', 'Tasdiq B', 'Одобрено B', 'Body B', 'Тело B', 'BOTH')`,
      [notificationA, tenantA, userA, notificationB, tenantB, userB],
    );

    await admin.query(
      `INSERT INTO notification_preferences
        (id, tenant_id, user_id, notification_type, is_enabled)
       VALUES
        ($1, $2, $3, 'ENTRY_APPROVED', true),
        ($4, $5, $6, 'ENTRY_APPROVED', true)`,
      [notificationPreferenceA, tenantA, userA, notificationPreferenceB, tenantB, userB],
    );

    await admin.query(
      `INSERT INTO notification_templates
        (id, tenant_id, type, channel, title_uz, title_ru, body_uz, body_ru)
       VALUES
        ($1, $2, 'TEST_OVERRIDE', 'BOTH', 'Tenant A override', 'Переопределение A', 'Body A', 'Тело A'),
        ($3, $4, 'TEST_OVERRIDE', 'BOTH', 'Tenant B override', 'Переопределение B', 'Body B', 'Тело B')`,
      [notificationTemplateA, tenantA, notificationTemplateB, tenantB],
    );

    await admin.query(
      `INSERT INTO report_exports
        (id, tenant_id, report_type, filters, requested_by)
       VALUES
        ($1, $2, 'PRODUCTION', '{}', $3),
        ($4, $5, 'PRODUCTION', '{}', $6)`,
      [reportExportA, tenantA, userA, reportExportB, tenantB, userB],
    );

    await admin.query(
      `INSERT INTO tenant_feature_flags
        (id, tenant_id, feature_key, is_enabled)
       VALUES
        ($1, $2, 'TEST_FEATURE', true),
        ($3, $4, 'TEST_FEATURE', true)`,
      [featureFlagA, tenantA, featureFlagB, tenantB],
    );

    await admin.query(
      `INSERT INTO subscription_plans
        (id, name, description, user_limit, features)
       VALUES
        ($1, $2, 'Isolation test plan', 10, '["module.test"]'::jsonb)`,
      [subscriptionPlan, `test-plan-${subscriptionPlan}`],
    );

    await admin.query(
      `INSERT INTO tenant_subscriptions
        (id, tenant_id, plan_id, billing_cycle, status)
       VALUES
        ($1, $2, $3, 'MONTHLY', 'ACTIVE')`,
      [tenantSubscription, tenantA, subscriptionPlan],
    );

    await admin.query(
      `INSERT INTO platform_users
        (id, email, password_hash, full_name)
       VALUES
        ($1, $2, 'hash', 'Platform Admin')`,
      [platformUser, `platform-${platformUser}@example.com`],
    );

    await admin.query(
      `INSERT INTO platform_sessions
        (id, platform_user_id, refresh_token_hash, expires_at)
       VALUES
        ($1, $2, 'hash', now() + interval '1 day')`,
      [platformSession, platformUser],
    );

    await admin.query(
      `INSERT INTO platform_audit_events
        (id, event_type, actor_id, tenant_id, target_type, target_id, payload)
       VALUES
        ($1, 'TENANT_ACCESSED', $2, $3, 'TENANT', $3, '{}')`,
      [platformAuditEvent, platformUser, tenantA],
    );
  });

  afterAll(async () => {
    await admin.query('DELETE FROM platform_sessions WHERE platform_user_id = $1', [
      platformUser,
    ]);
    await admin.query(
      'DELETE FROM platform_audit_events WHERE tenant_id IN ($1, $2) OR actor_id = $3',
      [tenantA, tenantB, platformUser],
    );
    await admin.query(
      'DELETE FROM tenant_subscriptions WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM subscription_plans WHERE id = $1', [subscriptionPlan]);
    await admin.query('DELETE FROM platform_users WHERE id = $1', [platformUser]);
    await admin.query(
      'DELETE FROM notification_templates WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM report_exports WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM notifications WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query(
      'DELETE FROM notification_preferences WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM stock_movements WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM materials WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM tenant_settings WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query(
      'DELETE FROM tenant_feature_flags WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM audit_events WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query(
      'DELETE FROM operation_price_history WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM operations WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query(
      'DELETE FROM foreman_assignments WHERE tenant_id IN ($1, $2)',
      [tenantA, tenantB],
    );
    await admin.query('DELETE FROM user_sessions WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM departments WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM users WHERE tenant_id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await admin.query('DELETE FROM tenants WHERE id IN ($1, $2)', [
      tenantA,
      tenantB,
    ]);
    await app.end();
    await admin.end();
  });

  it('returns only rows belonging to the current tenant', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    const result = await app.query<{ id: string }>(
      `SELECT id FROM users WHERE role = 'WORKER'`,
    );

    expect(result.rows).toEqual([{ id: userA }]);
  });

  it('rejects a phone number already used by another tenant', async () => {
    await expect(
      admin.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role)
         VALUES ($1, $2, '+998901111111', 'hash', 'Duplicate phone', 'W-DUP', 'WORKER')`,
        [randomUUID(), tenantB],
      ),
    ).rejects.toMatchObject({ code: '23505' });
  });

  it('returns no tenant rows when tenant context is absent', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', '', false)`);

    const result = await app.query('SELECT id FROM users');

    expect(result.rows).toHaveLength(0);
  });

  it('rejects writes for another tenant', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    await expect(
      app.query(
        `INSERT INTO users
          (id, tenant_id, phone, pin_hash, full_name, worker_code, role)
         VALUES ($1, $2, '+998903333333', 'hash', 'Intruder', 'W-X', 'WORKER')`,
        [randomUUID(), tenantB],
      ),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('isolates Department and Foreman Assignment reads and writes for the runtime role', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    const departments = await app.query<{ id: string }>(
      'SELECT id FROM departments',
    );
    const assignments = await app.query<{ id: string }>(
      'SELECT id FROM foreman_assignments',
    );
    expect(departments.rows).toEqual([{ id: departmentA }]);
    expect(assignments.rows).toEqual([{ id: foremanAssignmentA }]);

    await expect(
      app.query(
        `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
         VALUES ($1, $2, 'Cross-tenant Department', $3, $4)`,
        [randomUUID(), tenantB, `X-${randomUUID().slice(0, 8)}`, foremanB],
      ),
    ).rejects.toMatchObject({ code: '42501' });
    await expect(
      app.query(
        `INSERT INTO foreman_assignments
          (id, tenant_id, worker_id, foreman_id, department_id, assigned_by,
           unassigned_at)
         VALUES ($1, $2, $3, $4, $5, $4, now() + interval '1 second')`,
        [randomUUID(), tenantB, userB, foremanB, departmentB],
      ),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('isolates Operation and price-history reads and writes for the runtime role', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    const operations = await app.query<{ id: string }>(
      'SELECT id FROM operations ORDER BY id',
    );
    const prices = await app.query<{ operation_id: string }>(
      'SELECT operation_id FROM operation_price_history ORDER BY operation_id',
    );
    expect(operations.rows).toEqual([{ id: operationA }]);
    expect(prices.rows).toEqual([{ operation_id: operationA }]);

    await expect(
      app.query(
        `INSERT INTO operations
          (id, tenant_id, name, unit, unit_price, created_by)
         VALUES ($1, $2, 'Cross-tenant operation', 'PIECE', 1, $3)`,
        [randomUUID(), tenantB, userB],
      ),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('denies the runtime role access to the platform tenant catalog', async () => {
    await expect(app.query('SELECT id FROM tenants')).rejects.toMatchObject({
      code: '42501',
    });
  });

  it('rejects foreign keys that point to another tenant', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    await expect(
      app.query(
        `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
         VALUES ($1, $2, 'Invalid department', 'INVALID', $3)`,
        [randomUUID(), tenantA, foremanB],
      ),
    ).rejects.toMatchObject({ code: '23503' });
  });

  it('keeps audit events immutable for the runtime role', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    await expect(
      app.query(`UPDATE audit_events SET action = 'TAMPERED' WHERE id = $1`, [
        auditEvent,
      ]),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query(`DELETE FROM audit_events WHERE id = $1`, [auditEvent]),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it.each([
    'departments',
    'foreman_assignments',
    'user_sessions',
    'audit_events',
    'operations',
    'operation_price_history',
  ])('isolates the %s table', async (table) => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    const result = await app.query<{ tenant_id: string }>(
      `SELECT tenant_id FROM ${table}`,
    );

    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]?.tenant_id).toBe(tenantA);
  });

  const isolationCases: Array<{
    table: string;
    sql: string;
    params: unknown[];
  }> = [
    {
      table: 'materials',
      sql: `INSERT INTO materials
        (id, tenant_id, code, name, unit, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      params: [randomUUID(), tenantB, 'CROSS-MAT', 'Cross material', 'KG', userB],
    },
    {
      table: 'stock_movements',
      sql: `INSERT INTO stock_movements
        (id, tenant_id, material_id, type, quantity, unit_snapshot, movement_date, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      params: [
        randomUUID(),
        tenantB,
        materialB,
        'RECEIPT',
        1,
        'KG',
        new Date().toISOString().split('T')[0],
        userB,
      ],
    },
    {
      table: 'tenant_settings',
      sql: `INSERT INTO tenant_settings (id, tenant_id) VALUES ($1, $2)`,
      params: [randomUUID(), tenantB],
    },
    {
      table: 'notifications',
      sql: `INSERT INTO notifications
        (id, tenant_id, recipient_id, type, title_uz, title_ru, body_uz, body_ru, channel)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      params: [
        randomUUID(),
        tenantB,
        userB,
        'ENTRY_APPROVED',
        'Cross title',
        'Cross title ru',
        'Cross body',
        'Cross body ru',
        'BOTH',
      ],
    },
    {
      table: 'notification_preferences',
      sql: `INSERT INTO notification_preferences
        (id, tenant_id, user_id, notification_type, is_enabled)
       VALUES ($1, $2, $3, $4, $5)`,
      params: [randomUUID(), tenantB, userB, 'ENTRY_APPROVED', true],
    },
    {
      table: 'report_exports',
      sql: `INSERT INTO report_exports
        (id, tenant_id, report_type, filters, requested_by)
       VALUES ($1, $2, $3, $4, $5)`,
      params: [randomUUID(), tenantB, 'PRODUCTION', '{}', userB],
    },
  ];

  it.each(isolationCases)(
    'isolates the $table table',
    async ({ table, sql, params }) => {
      await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
        tenantA,
      ]);

      const result = await app.query<{ tenant_id: string }>(
        `SELECT tenant_id FROM ${table}`,
      );

      expect(result.rows).toHaveLength(1);
      expect(result.rows[0]?.tenant_id).toBe(tenantA);

      await expect(app.query(sql, params)).rejects.toMatchObject({
        code: '42501',
      });
    },
  );

  it.each([
    'materials',
    'stock_movements',
    'tenant_settings',
    'notifications',
    'notification_preferences',
    'report_exports',
  ])(
    'returns no %s rows when tenant context is absent',
    async (table) => {
      await app.query(`SELECT set_config('app.current_tenant_id', '', false)`);

      const result = await app.query(`SELECT id FROM ${table}`);

      expect(result.rows).toHaveLength(0);
    },
  );

  it('stock_movements are immutable for the app role', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    await expect(
      app.query('UPDATE stock_movements SET quantity = 999 WHERE id = $1', [
        stockMovementA,
      ]),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query('DELETE FROM stock_movements WHERE id = $1', [stockMovementA]),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('notification_templates platform defaults are readable but tenant overrides are isolated', async () => {
    await app.query(`SELECT set_config('app.current_tenant_id', $1, false)`, [
      tenantA,
    ]);

    const result = await app.query<{ id: string; tenant_id: string | null }>(
      'SELECT id, tenant_id FROM notification_templates',
    );

    const defaultIds = result.rows
      .filter((row) => row.tenant_id === null)
      .map((row) => row.id);
    const tenantAIds = result.rows
      .filter((row) => row.tenant_id === tenantA)
      .map((row) => row.id);
    const tenantBIds = result.rows
      .filter((row) => row.tenant_id === tenantB)
      .map((row) => row.id);

    expect(defaultIds.length).toBeGreaterThan(0);
    expect(tenantAIds).toEqual([notificationTemplateA]);
    expect(tenantBIds).toHaveLength(0);

    await expect(
      app.query(
        `INSERT INTO notification_templates
          (id, tenant_id, type, channel, title_uz, title_ru, body_uz, body_ru)
         VALUES ($1, NULL, 'PLATFORM_DEFAULT', 'BOTH', 'Title', 'Title', 'Body', 'Body')`,
        [randomUUID()],
      ),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('denies the app role access to platform tables', async () => {
    await expect(
      app.query('SELECT id FROM subscription_plans'),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query('SELECT id FROM tenant_subscriptions'),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query('SELECT id FROM platform_users'),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query('SELECT id FROM platform_audit_events'),
    ).rejects.toMatchObject({ code: '42501' });

    await expect(
      app.query('SELECT id FROM tenant_feature_flags'),
    ).rejects.toMatchObject({ code: '42501' });
  });

  it('clears transaction-local tenant context after the operation', async () => {
    const dataSource = new DataSource({ type: 'postgres', url: appUrl });
    await dataSource.initialize();
    const tenantDatabase = new TenantDatabase(dataSource);

    try {
      const inside = await tenantDatabase.withTenant(tenantA, (manager) =>
        manager.query<unknown[]>('SELECT id FROM users'),
      );
      const outside = await dataSource.query<unknown[]>('SELECT id FROM users');

      expect(inside).toHaveLength(2);
      expect(outside).toHaveLength(0);
    } finally {
      await dataSource.destroy();
    }
  });
});
