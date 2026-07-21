import bcrypt from 'bcrypt';
import { Client } from 'pg';
import { randomUUID } from 'crypto';

interface FactoryConfig {
  name: string;
  slug: string;
  adminPhone: string;
  adminName: string;
  currency: string;
  timezone: string;
  initialWorkerCount: number;
}

async function onboardFactoryTenant() {
  const factoryConfig: FactoryConfig = {
    name: process.env.FACTORY_NAME || 'Samarkand Garments LLC',
    slug: process.env.FACTORY_SLUG || 'samarkand-garments',
    adminPhone: process.env.FACTORY_ADMIN_PHONE || '+998935001122',
    adminName: process.env.FACTORY_ADMIN_NAME || 'Javohir Karimov',
    currency: process.env.FACTORY_CURRENCY || 'UZS',
    timezone: process.env.FACTORY_TIMEZONE || 'Asia/Tashkent',
    initialWorkerCount: parseInt(process.env.INITIAL_WORKERS || '30', 10),
  };

  const connectionString =
    process.env.DATABASE_URL ||
    process.env.DATABASE_ADMIN_URL ||
    'postgresql://texerp:texerp@localhost:5432/texerp';

  console.log(`🏭 Onboarding New Factory Tenant: "${factoryConfig.name}"...`);

  const client = new Client({ connectionString });
  await client.connect();

  try {
    // 1. Create Factory Tenant
    const tenantId = randomUUID();
    await client.query(
      `INSERT INTO tenants (id, name, slug, status, timezone, language, currency)
       VALUES ($1, $2, $3, 'ACTIVE', $4, 'uz', $5)`,
      [tenantId, factoryConfig.name, factoryConfig.slug, factoryConfig.timezone, factoryConfig.currency],
    );

    const pinHash = await bcrypt.hash('1234', 4);

    // 2. Create Factory Director/Admin
    const directorId = randomUUID();
    await client.query(
      `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status, language)
       VALUES ($1, $2, $3, $4, $5, 'DIR-001', 'DIRECTOR', 'ACTIVE', 'uz')`,
      [directorId, tenantId, factoryConfig.adminPhone, pinHash, factoryConfig.adminName],
    );

    // 3. Create Default Departments
    const sewingDeptId = randomUUID();
    const cuttingDeptId = randomUUID();
    const qcDeptId = randomUUID();

    await client.query(
      `INSERT INTO departments (id, tenant_id, name, code, foreman_id)
       VALUES 
         ($1, $2, 'Main Sewing Line', 'SEW-01', $3),
         ($4, $2, 'Fabric Cutting Workshop', 'CUT-01', $3),
         ($5, $2, 'Quality Inspection & Packing', 'QC-01', $3)`,
      [sewingDeptId, tenantId, directorId, cuttingDeptId, qcDeptId],
    );

    // 4. Create Standard Textile Piecework Operations
    await client.query(
      `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, created_by)
       VALUES
         ($1, $2, 'Shirt Collar Stitching', 'ST-COL', 'PIECE', 5000, 1, $3),
         ($4, $2, 'Sleeve Hemming & Attach', 'ST-SLV', 'PIECE', 4200, 2, $3),
         ($5, $2, 'Front Button Sewing', 'ST-BTN', 'PIECE', 1800, 3, $3),
         ($6, $2, 'Final Pressing & Folding', 'ST-PRS', 'PIECE', 2500, 4, $3)`,
      [randomUUID(), tenantId, directorId, randomUUID(), randomUUID(), randomUUID()],
    );

    console.log(`\n🎉 Factory "${factoryConfig.name}" onboarded successfully!`);
    console.log(`====================================================`);
    console.log(`Tenant ID:    ${tenantId}`);
    console.log(`Director:     ${factoryConfig.adminName}`);
    console.log(`Admin Phone:  ${factoryConfig.adminPhone}`);
    console.log(`Initial PIN:  1234`);
    console.log(`30-Day Trial: Active until ${new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString().split('T')[0]}`);
    console.log(`====================================================\n`);
  } catch (error) {
    console.error('❌ Factory Onboarding Failed:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

onboardFactoryTenant();
