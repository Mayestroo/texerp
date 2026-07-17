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
  const auditEvent = randomUUID();
  const auditEventB = randomUUID();

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
  });

  afterAll(async () => {
    await admin.query('DELETE FROM audit_events WHERE tenant_id IN ($1, $2)', [
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
