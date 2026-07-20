import bcrypt from 'bcrypt';
import { Client } from 'pg';
import { randomUUID } from 'crypto';

async function seed() {
  const admin = new Client({
    connectionString:
      process.env.DATABASE_ADMIN_URL ??
      'postgresql://texerp:texerp@localhost:5432/texerp',
  });

  await admin.connect();

  // Clean existing data (order matters for FK constraints)
  await admin.query('DELETE FROM audit_events');
  await admin.query('DELETE FROM operation_price_history');
  await admin.query('DELETE FROM operations');
  await admin.query('DELETE FROM foreman_assignments');
  await admin.query('DELETE FROM user_sessions');
  await admin.query('DELETE FROM departments');
  await admin.query('DELETE FROM users');
  await admin.query('DELETE FROM tenants');

  // Create tenant
  const tenantId = randomUUID();
  await admin.query(
    `INSERT INTO tenants (id, name, slug, status, timezone, language, currency)
     VALUES ($1, 'Test Factory', 'test-factory', 'ACTIVE', 'Asia/Tashkent', 'uz', 'UZS')`,
    [tenantId],
  );

  // Hash the PIN '1234' for all test users
  const pinHash = await bcrypt.hash('1234', 4);

  // Create Director
  const directorId = randomUUID();
  await admin.query(
    `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
     VALUES ($1, $2, '+998901234567', $3, 'Test Director', 'DIR-001', 'DIRECTOR', 'ACTIVE', 'uz')`,
    [directorId, tenantId, pinHash],
  );

  // Create Foreman
  const foremanId = randomUUID();
  await admin.query(
    `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
     VALUES ($1, $2, '+998901234568', $3, 'Test Foreman', 'FOR-001', 'FOREMAN', 'ACTIVE', 'uz')`,
    [foremanId, tenantId, pinHash],
  );

  // Create Worker
  const workerId = randomUUID();
  await admin.query(
    `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
     VALUES ($1, $2, '+998901234569', $3, 'Test Worker', 'WRK-001', 'WORKER', 'ACTIVE', 'uz')`,
    [workerId, tenantId, pinHash],
  );

  // Create Department with Foreman
  const departmentId = randomUUID();
  await admin.query(
    `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
     VALUES ($1, $2, 'Assembly', 'ASM-01', $3)`,
    [departmentId, tenantId, foremanId],
  );

  // Create Operations with prices
  await admin.query(
    `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, created_by)
     VALUES
       ($1, $2, 'Collar sewing', 'COL-SEW', 'PIECE', 45000, 1, $3),
       ($4, $2, 'Sleeve attach', 'SLV-ATT', 'PIECE', 38000, 2, $3),
       ($5, $2, 'Button sewing', 'BTN-SEW', 'PIECE', 12000, 3, $3)`,
    [randomUUID(), tenantId, directorId, randomUUID(), randomUUID()],
  );

  console.log('Seed complete!');
  console.log('Test users (PIN: 1234):');
  console.log('  Director: +998901234567');
  console.log('  Foreman:  +998901234568');
  console.log('  Worker:   +998901234569');

  await admin.end();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
