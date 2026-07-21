import bcrypt from 'bcrypt';
import { Client } from 'pg';
import { randomUUID } from 'crypto';

async function seedStaging() {
  const connectionString =
    process.env.DATABASE_URL ??
    process.env.DATABASE_ADMIN_URL ??
    'postgresql://texerp:staging_secure_password_123@localhost:5432/texerp_staging';

  console.log(`Connecting to database for staging seed: ${connectionString.replace(/:[^:@]+@/, ':****@')}`);
  const client = new Client({ connectionString });
  await client.connect();

  try {
    console.log('--- Cleaning Staging Seed Target Data ---');
    // Order matters due to foreign keys
    await client.query("DELETE FROM audit_events WHERE tenant_id IN (SELECT id FROM tenants WHERE slug = 'staging-factory')");
    await client.query("DELETE FROM user_sessions WHERE user_id IN (SELECT id FROM users WHERE tenant_id IN (SELECT id FROM tenants WHERE slug = 'staging-factory'))");
    await client.query("DELETE FROM departments WHERE tenant_id IN (SELECT id FROM tenants WHERE slug = 'staging-factory')");
    await client.query("DELETE FROM operations WHERE tenant_id IN (SELECT id FROM tenants WHERE slug = 'staging-factory')");
    await client.query("DELETE FROM users WHERE tenant_id IN (SELECT id FROM tenants WHERE slug = 'staging-factory')");
    await client.query("DELETE FROM tenants WHERE slug = 'staging-factory'");

    // 1. Create Staging Tenant
    const tenantId = randomUUID();
    await client.query(
      `INSERT INTO tenants (id, name, slug, status, timezone, language, currency)
       VALUES ($1, 'TexERP Staging Factory', 'staging-factory', 'ACTIVE', 'Asia/Tashkent', 'uz', 'UZS')`,
      [tenantId],
    );

    const pinHash = await bcrypt.hash('1234', 4);

    // 2. Create Director
    const directorId = randomUUID();
    await client.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
       VALUES ($1, $2, '+998900000001', $3, 'Staging Director', 'DIR-STG-01', 'DIRECTOR', 'ACTIVE', 'uz')`,
      [directorId, tenantId, pinHash],
    );

    // 3. Create Foremen
    const foreman1Id = randomUUID();
    const foreman2Id = randomUUID();
    await client.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
       VALUES 
         ($1, $2, '+998900000002', $3, 'Foreman Alisher', 'FOR-STG-01', 'FOREMAN', 'ACTIVE', 'uz'),
         ($4, $2, '+998900000003', $3, 'Foreman Bobur', 'FOR-STG-02', 'FOREMAN', 'ACTIVE', 'uz')`,
      [foreman1Id, tenantId, pinHash, foreman2Id],
    );

    // 4. Create Departments
    const sewingDeptId = randomUUID();
    const cuttingDeptId = randomUUID();
    const packagingDeptId = randomUUID();
    await client.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
       VALUES 
         ($1, $2, 'Sewing Line 1', 'SEW-01', $3),
         ($4, $2, 'Cutting Section', 'CUT-01', $5),
         ($6, $2, 'Packaging & QC', 'PKG-01', $3)`,
      [sewingDeptId, tenantId, foreman1Id, cuttingDeptId, foreman2Id, packagingDeptId],
    );

    // 5. Create 20 Workers
    const workerIds: string[] = [];
    for (let i = 1; i <= 20; i++) {
      const wId = randomUUID();
      workerIds.push(wId);
      const codeNum = i.toString().padStart(3, '0');
      const phoneNum = `+99890100${codeNum}`;
      await client.query(
        `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
         VALUES ($1, $2, $3, $4, $5, $6, 'WORKER', 'ACTIVE', 'uz')`,
        [wId, tenantId, phoneNum, pinHash, `Staging Worker ${i}`, `WRK-STG-${codeNum}`],
      );
    }

    // 6. Create Operations
    const opCollar = randomUUID();
    const opSleeve = randomUUID();
    const opPocket = randomUUID();
    const opHemming = randomUUID();
    const opPacking = randomUUID();

    await client.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, created_by)
       VALUES
         ($1, $2, 'Collar Assembly', 'STG-COL', 'PIECE', 4500, 1, $3),
         ($4, $2, 'Sleeve Attachment', 'STG-SLV', 'PIECE', 3800, 2, $3),
         ($5, $2, 'Pocket Sewing', 'STG-PCK', 'PIECE', 2900, 3, $3),
         ($6, $2, 'Bottom Hemming', 'STG-HEM', 'PIECE', 2200, 4, $3),
         ($7, $2, 'Ironing & Folding', 'STG-IRN', 'PIECE', 1500, 5, $3)`,
      [opCollar, tenantId, directorId, opSleeve, opPocket, opHemming, opPacking],
    );

    console.log('✅ Staging Tenant successfully seeded!');
    console.log(`Tenant ID: ${tenantId}`);
    console.log('Test Credentials (PIN for all: 1234):');
    console.log('  Director:  +998900000001');
    console.log('  Foreman 1: +998900000002');
    console.log('  Foreman 2: +998900000003');
    console.log('  Workers:   +99890100001 through +99890100020');
  } catch (error) {
    console.error('❌ Staging Seed Error:', error);
    throw error;
  } finally {
    await client.end();
  }
}

seedStaging().catch(() => process.exit(1));
