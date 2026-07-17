# Operations Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Tenant-isolated, Director-managed Operations Catalog with current unit prices, durable price history, and activation lifecycle APIs.

**Architecture:** Add an `OperationsModule` beside IAM and Organization. Its service executes all data access in `TenantDatabase.withTenant()` transactions, locks Operations for price changes, writes audit events before state mutation, and owns the current-rate invariant. A migration creates forced-RLS catalog and price-history tables; public HTTP and PostgreSQL integration tests remain the only test seams.

**Tech Stack:** NestJS 11, TypeScript 5.8, TypeORM 0.3 raw SQL migrations and transactions, PostgreSQL 17, Jest 30, Supertest, pg.

## Global Constraints

- The feature is backend-only; do not create Flutter artifacts.
- Use `Tenant`, `User`, and `Production Entry` domain language from `CONTEXT.md`.
- Use UUIDv7 IDs from `src/shared/utils/uuid.ts` for application-created catalog rows.
- Every catalog table must enable and force the existing `app.current_tenant_id` RLS policy.
- All application data access goes through `TenantDatabase.withTenant()`.
- Units are exactly `PIECE`, `METER`, and `PAIR`; the unit is immutable after creation.
- `unit_price` is a positive integer measured in tiyin; currency is fixed to `UZS`.
- Categories, recent-use data, catalog caching, Production Entry submission, and Flutter screens are out of scope.
- Mutations insert their immutable audit event before state changes in the same transaction. No-op mutations insert no audit event.
- Do not add dependencies.

---

## File Structure

- Create `07_Backend/src/infrastructure/database/migrations/1752750000000-CreateOperationsCatalog.ts`: operation unit enum, catalog tables, constraints, indexes, and forced RLS policy.
- Create `07_Backend/src/modules/operations/operations.module.ts`: module boundary and IAM imports.
- Create `07_Backend/src/modules/operations/application/operations.service.ts`: list, create, update, activate, deactivate, audit, locking, and price-history use cases.
- Create `07_Backend/src/modules/operations/application/dto/create-operation.dto.ts`: creation validation.
- Create `07_Backend/src/modules/operations/application/dto/list-operations-query.dto.ts`: status and search validation.
- Create `07_Backend/src/modules/operations/application/dto/update-operation.dto.ts`: mutable patch validation.
- Create `07_Backend/src/modules/operations/application/errors/operation-not-found.error.ts`: concealed missing Operation error.
- Create `07_Backend/src/modules/operations/application/errors/operation-name-already-exists.error.ts`: Tenant name conflict error.
- Create `07_Backend/src/modules/operations/application/errors/operation-code-already-exists.error.ts`: Tenant code conflict error.
- Create `07_Backend/src/modules/operations/application/errors/empty-operation-update.error.ts`: empty patch error.
- Create `07_Backend/src/modules/operations/presentation/operations.controller.ts`: versioned routes and role declarations.
- Create `07_Backend/src/modules/operations/presentation/operations-exception.filter.ts`: stable catalog error envelopes.
- Modify `07_Backend/src/app.module.ts`: import `OperationsModule`.
- Modify `07_Backend/test/database/tenant-isolation.integration-spec.ts`: seed, clean up, read, and cross-Tenant write checks for both new tables.
- Create `07_Backend/test/operations.e2e-spec.ts`: public HTTP catalog behavior, audit, history, Tenant concealment, and contention tests.
- Modify `04_API/APIContract.md`: align the Operations section to the delivered backend surface and mark categories/recent-use endpoints as deferred.

## Task 1: Operations Schema and Tenant Isolation

**Files:**
- Create: `07_Backend/src/infrastructure/database/migrations/1752750000000-CreateOperationsCatalog.ts`
- Modify: `07_Backend/test/database/tenant-isolation.integration-spec.ts`

**Interfaces:**
- Consumes: the `tenants`, `users`, and `audit_events` tables from `1752660000000-CreateIdentityFoundation.ts`; `TenantDatabase.withTenant()` from `src/infrastructure/database/tenant-database.ts`.
- Produces: `operation_unit`, `operations`, and `operation_price_history` tables available to the Operations module and all later tests.

- [ ] **Step 1: Add a failing RLS integration case for catalog rows**

  Add IDs for two Operations and their first price-history rows next to the existing Department IDs:

  ```ts
  const operationA = randomUUID();
  const operationB = randomUUID();
  const operationPriceA = randomUUID();
  const operationPriceB = randomUUID();
  ```

  In `beforeAll`, after User creation, seed each Tenant with one Operation and one current rate interval:

  ```ts
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
  ```

  Add this test after the Department and Foreman Assignment isolation test:

  ```ts
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
  ```

  Extend the existing `it.each` table list with `operations` and `operation_price_history`, and delete price-history rows before Operations in `afterAll`.

- [ ] **Step 2: Run the integration test and confirm the schema is missing**

  Run from `07_Backend`:

  ```bash
  npm run test:integration -- tenant-isolation.integration-spec.ts
  ```

  Expected: FAIL with PostgreSQL `relation "operations" does not exist`.

- [ ] **Step 3: Add the migration with catalog constraints, indexes, and RLS**

  Create `1752750000000-CreateOperationsCatalog.ts`. Its `up` method must create the enum, tables, and indexes below. Name the uniqueness constraints exactly as shown so application code can map conflicts without relying on generated names.

  ```ts
  await queryRunner.query(`
    CREATE TYPE operation_unit AS ENUM ('PIECE', 'METER', 'PAIR');

    CREATE TABLE operations (
      id uuid PRIMARY KEY,
      tenant_id uuid NOT NULL REFERENCES tenants(id),
      name varchar(255) NOT NULL,
      code varchar(50),
      unit operation_unit NOT NULL,
      unit_price integer NOT NULL,
      currency char(3) NOT NULL DEFAULT 'UZS',
      sort_order integer NOT NULL DEFAULT 0,
      is_active boolean NOT NULL DEFAULT true,
      created_by uuid NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT operations_unit_price_check CHECK (unit_price > 0),
      CONSTRAINT operations_currency_check CHECK (currency = 'UZS'),
      CONSTRAINT operations_tenant_id_id_key UNIQUE (tenant_id, id),
      CONSTRAINT operations_tenant_name_key UNIQUE (tenant_id, name),
      CONSTRAINT operations_tenant_code_key UNIQUE (tenant_id, code),
      FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id)
    );

    CREATE TABLE operation_price_history (
      id uuid PRIMARY KEY,
      tenant_id uuid NOT NULL REFERENCES tenants(id),
      operation_id uuid NOT NULL,
      unit_price integer NOT NULL,
      currency char(3) NOT NULL DEFAULT 'UZS',
      effective_from timestamptz NOT NULL,
      effective_to timestamptz,
      changed_by uuid NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT operation_price_history_unit_price_check CHECK (unit_price > 0),
      CONSTRAINT operation_price_history_currency_check CHECK (currency = 'UZS'),
      CONSTRAINT operation_price_history_dates_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from),
      CONSTRAINT operation_price_history_tenant_id_id_key UNIQUE (tenant_id, id),
      FOREIGN KEY (tenant_id, operation_id) REFERENCES operations(tenant_id, id),
      FOREIGN KEY (tenant_id, changed_by) REFERENCES users(tenant_id, id)
    );

    CREATE INDEX operations_active_catalog_idx
      ON operations (tenant_id, sort_order, name, id) WHERE is_active;
    CREATE INDEX operations_catalog_idx
      ON operations (tenant_id, sort_order, name, id);
    CREATE UNIQUE INDEX operation_price_history_one_current_per_operation
      ON operation_price_history (tenant_id, operation_id)
      WHERE effective_to IS NULL;
  `);
  ```

  Add this RLS loop after the table creation and this exact `down` body:

  ```ts
  for (const table of ['operations', 'operation_price_history']) {
    await queryRunner.query(`
      ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;
      ALTER TABLE ${table} FORCE ROW LEVEL SECURITY;
      CREATE POLICY ${table}_tenant_isolation ON ${table}
        USING (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        )
        WITH CHECK (
          tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::uuid
        );
    `);
  }

  await queryRunner.query(`
    DROP TABLE IF EXISTS operation_price_history;
    DROP TABLE IF EXISTS operations;
    DROP TYPE IF EXISTS operation_unit;
  `);
  ```

- [ ] **Step 4: Run the migration against the local test database**

  Run from `07_Backend`:

  ```bash
  npm run migration:run
  ```

  Expected: TypeORM records `CreateOperationsCatalog1752750000000` in `schema_migrations` without errors.

- [ ] **Step 5: Run the integration test and confirm RLS behavior**

  Run from `07_Backend`:

  ```bash
  npm run test:integration -- tenant-isolation.integration-spec.ts
  ```

  Expected: PASS. The runtime role reads only Tenant A's Operation and history row and receives SQLSTATE `42501` for the Tenant B insert.

- [ ] **Step 6: Commit the schema task**

  ```bash
  git add "07_Backend/src/infrastructure/database/migrations/1752750000000-CreateOperationsCatalog.ts" "07_Backend/test/database/tenant-isolation.integration-spec.ts"
  git commit -m "feat: add operations catalog schema"
  ```

## Task 2: List and Create Operations Through the Public API

**Files:**
- Create: `07_Backend/src/modules/operations/operations.module.ts`
- Create: `07_Backend/src/modules/operations/application/operations.service.ts`
- Create: `07_Backend/src/modules/operations/application/dto/create-operation.dto.ts`
- Create: `07_Backend/src/modules/operations/application/dto/list-operations-query.dto.ts`
- Create: `07_Backend/src/modules/operations/application/errors/operation-not-found.error.ts`
- Create: `07_Backend/src/modules/operations/application/errors/operation-name-already-exists.error.ts`
- Create: `07_Backend/src/modules/operations/application/errors/operation-code-already-exists.error.ts`
- Create: `07_Backend/src/modules/operations/presentation/operations.controller.ts`
- Create: `07_Backend/src/modules/operations/presentation/operations-exception.filter.ts`
- Modify: `07_Backend/src/app.module.ts`
- Create: `07_Backend/test/operations.e2e-spec.ts`

**Interfaces:**
- Consumes: the schema from Task 1; `AccessTokenClaims`, `JwtAuthGuard`, `Roles`, `RolesGuard`, `TenantDatabase`, `uuidv7`, and the existing `{ success, data }` envelope.
- Produces:

  ```ts
  interface OperationView {
    id: string;
    name: string;
    code: string | null;
    unit: 'PIECE' | 'METER' | 'PAIR';
    unit_price: number;
    currency: 'UZS';
    is_active: boolean;
    sort_order: number;
  }

  class OperationsService {
    list(tenantId: string, actor: AccessTokenClaims, query: ListOperationsQueryDto): Promise<OperationView[]>;
    create(tenantId: string, actor: AccessTokenClaims, dto: CreateOperationDto, metadata: RequestMetadata): Promise<OperationView>;
  }
  ```

- [ ] **Step 1: Write failing E2E tests for list, create, and role policy**

  Create `test/operations.e2e-spec.ts` with this fixture. It deliberately uses an isolated Tenant per run so Tenant-unique catalog values and globally unique phone numbers cannot collide with other test suites:

  ```ts
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

  interface LoginBody { data: { access_token: string } }

  describe('Operations Catalog', () => {
    const admin = new Client({
      connectionString: process.env.DATABASE_ADMIN_URL ?? 'postgresql://texerp:texerp@localhost:5432/texerp',
    });
    const tenantId = randomUUID();
    const secondTenantId = randomUUID();
    const directorId = randomUUID();
    const workerId = randomUUID();
    const foremanId = randomUUID();
    const accountantId = randomUUID();
    const secondTenantDirectorId = randomUUID();
    const firstActiveOperationId = randomUUID();
    const secondActiveOperationId = randomUUID();
    const inactiveOperationId = randomUUID();
    const mutableOperationId = randomUUID();
    const secondTenantOperationId = randomUUID();
    const initialPriceHistoryIds = Array.from({ length: 5 }, () => randomUUID());
    const suffix = (Number.parseInt(tenantId.replaceAll('-', '').slice(0, 10), 16) % 10_000_000).toString().padStart(7, '0');
    const phone = (sequence: number): string => `+998${suffix}${sequence.toString().padStart(2, '0')}`;
    let app: INestApplication;
    let server: Server;
    let directorToken: string;
    let workerToken: string;
    let foremanToken: string;
    let accountantToken: string;

    async function login(value: string): Promise<string> {
      const response = await request(server).post('/api/v1/auth/login').send({ phone: value, pin: '4826' }).expect(200);
      return (response.body as LoginBody).data.access_token;
    }

    beforeAll(async () => {
      const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
      await redis.flushdb();
      await redis.quit();
      await admin.connect();
      const pinHash = await bcrypt.hash('4826', 4);
      await admin.query(
        `INSERT INTO tenants (id, name, slug) VALUES ($1, 'Operations Tenant', $2), ($3, 'Other Operations Tenant', $4)`,
        [tenantId, `operations-${tenantId}`, secondTenantId, `operations-${secondTenantId}`],
      );
      await admin.query(
        `INSERT INTO users (id, tenant_id, phone, pin_hash, full_name, worker_code, role, status)
         VALUES
           ($1, $2, $3, $4, 'Director', 'OD-1', 'DIRECTOR', 'ACTIVE'),
           ($5, $2, $6, $4, 'Worker', 'OW-1', 'WORKER', 'ACTIVE'),
           ($7, $2, $8, $4, 'Foreman', 'OF-1', 'FOREMAN', 'ACTIVE'),
           ($9, $2, $10, $4, 'Accountant', 'OA-1', 'ACCOUNTANT', 'ACTIVE'),
           ($11, $12, $13, $4, 'Other Director', 'OD-2', 'DIRECTOR', 'ACTIVE')`,
        [directorId, tenantId, phone(1), pinHash, workerId, phone(2), foremanId, phone(3), accountantId, phone(4), secondTenantDirectorId, secondTenantId, phone(5)],
      );
      await admin.query(
        `INSERT INTO operations (id, tenant_id, name, code, unit, unit_price, sort_order, is_active, created_by)
         VALUES
           ($1, $2, 'Alpha', 'ALPHA', 'PIECE', 100, 1, true, $3),
           ($4, $2, 'Beta', 'BETA', 'METER', 200, 1, true, $3),
           ($5, $2, 'Inactive', 'INACTIVE', 'PAIR', 300, 2, false, $3),
           ($6, $2, 'Mutable', 'MUTABLE', 'PIECE', 45000, 3, true, $3),
           ($7, $8, 'Other Tenant', 'OTHER', 'PIECE', 1, 0, true, $9)`,
        [firstActiveOperationId, tenantId, directorId, secondActiveOperationId, inactiveOperationId, mutableOperationId, secondTenantOperationId, secondTenantId, secondTenantDirectorId],
      );
      await admin.query(
        `INSERT INTO operation_price_history
          (id, tenant_id, operation_id, unit_price, effective_from, changed_by)
         VALUES
          ($1, $2, $3, 100, now(), $4),
          ($5, $2, $6, 200, now(), $4),
          ($7, $2, $8, 300, now(), $4),
          ($9, $2, $10, 45000, now(), $4),
          ($11, $12, $13, 1, now(), $14)`,
        [
          initialPriceHistoryIds[0], tenantId, firstActiveOperationId, directorId,
          initialPriceHistoryIds[1], secondActiveOperationId,
          initialPriceHistoryIds[2], inactiveOperationId,
          initialPriceHistoryIds[3], mutableOperationId,
          initialPriceHistoryIds[4], secondTenantId, secondTenantOperationId, secondTenantDirectorId,
        ],
      );
      const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
      app = module.createNestApplication();
      configureApp(app);
      await app.init();
      server = app.getHttpServer() as Server;
      directorToken = await login(phone(1));
      workerToken = await login(phone(2));
      foremanToken = await login(phone(3));
      accountantToken = await login(phone(4));
    });

    afterAll(async () => {
      await app.close();
      await admin.query('DELETE FROM audit_events WHERE tenant_id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.query('DELETE FROM operation_price_history WHERE tenant_id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.query('DELETE FROM operations WHERE tenant_id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.query('DELETE FROM user_sessions WHERE tenant_id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.query('DELETE FROM users WHERE tenant_id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.query('DELETE FROM tenants WHERE id IN ($1, $2)', [tenantId, secondTenantId]);
      await admin.end();
    });
    // Add the API cases below here, then close this describe block at end of file.
  ```

  Add the following public API cases before creating the module:

  ```ts
  it('lists only active Operations for every authenticated role in deterministic order', async () => {
    const response = await request(server)
      .get('/api/v1/operations')
      .set('Authorization', `Bearer ${workerToken}`)
      .expect(200);

    expect(response.body).toEqual({
      success: true,
      data: [
        expect.objectContaining({ id: firstActiveOperationId, name: 'Alpha', sort_order: 1 }),
        expect.objectContaining({ id: secondActiveOperationId, name: 'Beta', sort_order: 1 }),
        expect.objectContaining({ id: mutableOperationId, name: 'Mutable', sort_order: 3 }),
      ],
    });
  });

  it('lets only a Director create an Operation and starts its first rate interval', async () => {
    const created = await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Collar sewing', code: 'COL-SEW', unit: 'PIECE', unit_price: 45000, sort_order: 2 })
      .expect(201);

    expect(created.body.data).toMatchObject({
      name: 'Collar sewing', code: 'COL-SEW', unit: 'PIECE', unit_price: 45000,
      currency: 'UZS', is_active: true, sort_order: 2,
    });
    const history = await admin.query(
      `SELECT unit_price, effective_to FROM operation_price_history WHERE operation_id = $1`,
      [created.body.data.id],
    );
    expect(history.rows).toEqual([{ unit_price: 45000, effective_to: null }]);
  });

  it.each([workerToken, foremanToken, accountantToken])(
    'denies non-Directors catalog creation',
    async (token) => {
      await request(server)
        .post('/api/v1/operations')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Denied', unit: 'PIECE', unit_price: 1 })
        .expect(403);
    },
  );
  ```

  Also cover a Director's `status=INACTIVE` and `status=ALL` visibility, non-Director rejection for those statuses, name/code conflict envelopes, positive integer validation, unknown-field rejection, and search over name and code. Leave cross-Tenant mutation assertions for Task 3, when those routes exist.

- [ ] **Step 2: Run the new E2E suite and confirm routes are absent**

  Run from `07_Backend`:

  ```bash
  npm run test:e2e -- --runInBand test/operations.e2e-spec.ts
  ```

  Expected: FAIL with HTTP 404 for `/api/v1/operations`.

- [ ] **Step 3: Define input DTOs and application errors**

  Implement the DTOs and error classes exactly as follows:

  ```ts
  // create-operation.dto.ts
  import { IsIn, IsInt, IsString, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';

  export class CreateOperationDto {
    @IsString() @MinLength(1) @MaxLength(255) name!: string;
    @ValidateIf((_object, value) => value !== undefined)
    @IsString() @MinLength(1) @MaxLength(50) code?: string;
    @IsIn(['PIECE', 'METER', 'PAIR']) unit!: 'PIECE' | 'METER' | 'PAIR';
    @IsInt() @Min(1) unit_price!: number;
    @ValidateIf((_object, value) => value !== undefined)
    @IsInt() sort_order?: number;
  }

  // list-operations-query.dto.ts
  import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

  export class ListOperationsQueryDto {
    @IsOptional() @IsIn(['ACTIVE', 'INACTIVE', 'ALL'])
    status: 'ACTIVE' | 'INACTIVE' | 'ALL' = 'ACTIVE';
    @IsOptional() @IsString() @MaxLength(255) search?: string;
  }
  ```

  Use one-line empty error classes matching the Organization convention. The exception filter must map them to these exact responses:

  ```ts
  OPERATION_NOT_FOUND: { status: HttpStatus.NOT_FOUND, message: 'Operatsiya topilmadi' },
  OPERATION_NAME_ALREADY_EXISTS: { status: HttpStatus.CONFLICT, message: 'Operatsiya nomi allaqachon mavjud' },
  OPERATION_CODE_ALREADY_EXISTS: { status: HttpStatus.CONFLICT, message: 'Operatsiya kodi allaqachon mavjud' },
  ```

- [ ] **Step 4: Implement the Operations module, controller, and list/create service methods**

  Register `OperationsModule` in `AppModule`. Its module imports `IamModule`, provides the service and exception filter, and registers `OperationsController`.

  The controller must use `@Controller({ path: 'operations', version: '1' })`, `@UseFilters(OperationsExceptionFilter)`, and `@UseGuards(JwtAuthGuard, RolesGuard)`. Use all four roles for list and `@Roles('DIRECTOR')` for creation. Pass `{ ipAddress: request.ip, userAgent: request.get('user-agent') }` to the service.

  Implement list with one Tenant query and role-aware status policy:

  ```ts
  if (actor.role !== 'DIRECTOR' && query.status !== 'ACTIVE') {
    throw new ForbiddenException();
  }

  return manager.query<OperationView[]>(
    `SELECT id, name, code, unit, unit_price, currency, is_active, sort_order
     FROM operations
     WHERE tenant_id = $1
       AND ($2 = 'ALL' OR is_active = ($2 = 'ACTIVE'))
       AND ($3::text IS NULL OR name ILIKE '%' || $3 || '%' OR code ILIKE '%' || $3 || '%')
     ORDER BY sort_order ASC, name ASC, id ASC`,
    [tenantId, query.status, query.search ?? null],
  );
  ```

  For creation, allocate the Operation and history IDs with `uuidv7()`, read one PostgreSQL `clock_timestamp()` value, insert an `OPERATION_CREATED` audit row first, insert the active Operation, then insert its price-history row using the same timestamp. Catch `QueryFailedError` and map `operations_tenant_name_key` and `operations_tenant_code_key` to the two conflict errors. Return the inserted `OperationView`.

- [ ] **Step 5: Run the E2E suite and confirm list/create behavior passes**

  Run from `07_Backend`:

  ```bash
  npm run test:e2e -- --runInBand test/operations.e2e-spec.ts
  ```

  Expected: PASS for list, search, status authorization, creation, first price interval, validation, role denial, and duplicate conflict cases.

- [ ] **Step 6: Commit the read/create API task**

  ```bash
  git add "07_Backend/src/app.module.ts" "07_Backend/src/modules/operations" "07_Backend/test/operations.e2e-spec.ts"
  git commit -m "feat: add operations catalog API"
  ```

## Task 3: Update Prices, Manage Lifecycle, and Finalize the Contract

**Files:**
- Modify: `07_Backend/src/modules/operations/application/operations.service.ts`
- Create: `07_Backend/src/modules/operations/application/dto/update-operation.dto.ts`
- Create: `07_Backend/src/modules/operations/application/errors/empty-operation-update.error.ts`
- Modify: `07_Backend/src/modules/operations/presentation/operations.controller.ts`
- Modify: `07_Backend/src/modules/operations/presentation/operations-exception.filter.ts`
- Modify: `07_Backend/test/operations.e2e-spec.ts`
- Modify: `04_API/APIContract.md`

**Interfaces:**
- Consumes: `OperationView`, the module, schema, and list/create behavior from Task 2.
- Produces:

  ```ts
  interface UpdateOperationView extends OperationView {
    price_changed: boolean;
    old_price?: number;
    new_price?: number;
    effective_from?: Date;
  }

  class OperationsService {
    update(tenantId: string, actor: AccessTokenClaims, operationId: string, dto: UpdateOperationDto, metadata: RequestMetadata): Promise<UpdateOperationView>;
    setActive(tenantId: string, actor: AccessTokenClaims, operationId: string, isActive: boolean, metadata: RequestMetadata): Promise<void>;
  }
  ```

- [ ] **Step 1: Write failing E2E tests for patching, rate intervals, and lifecycle actions**

  Add these cases to `test/operations.e2e-spec.ts`:

  ```ts
  it('closes the current rate and opens a new rate at one database timestamp', async () => {
    const response = await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ unit_price: 55000 })
      .expect(200);

    expect(response.body.data).toMatchObject({
      unit_price: 55000, price_changed: true, old_price: 45000, new_price: 55000,
    });
    const history = await admin.query(
      `SELECT unit_price, effective_from, effective_to
       FROM operation_price_history
       WHERE operation_id = $1 ORDER BY effective_from`,
      [mutableOperationId],
    );
    expect(history.rows).toHaveLength(2);
    expect(history.rows[0].effective_to).toEqual(history.rows[1].effective_from);
    expect(history.rows[1]).toMatchObject({ unit_price: 55000, effective_to: null });
  });

  it('returns its current representation without audit or history changes for a no-op patch', async () => {
    const before = await admin.query(
      `SELECT count(*)::integer AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_id = $2`,
      [tenantId, mutableOperationId],
    );
    await request(server)
      .patch(`/api/v1/operations/${mutableOperationId}`)
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ unit_price: 55000 })
      .expect(200)
      .expect(({ body }) => expect(body.data.price_changed).toBe(false));
    const after = await admin.query(
      `SELECT count(*)::integer AS count FROM audit_events
       WHERE tenant_id = $1 AND aggregate_id = $2`,
      [tenantId, mutableOperationId],
    );
    expect(after.rows).toEqual(before.rows);
  });

  it('makes activation and deactivation idempotent', async () => {
    await request(server)
      .post(`/api/v1/operations/${mutableOperationId}/deactivate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    await request(server)
      .post(`/api/v1/operations/${mutableOperationId}/deactivate`)
      .set('Authorization', `Bearer ${directorToken}`)
      .expect(200);
    const events = await admin.query(
      `SELECT action FROM audit_events WHERE tenant_id = $1 AND aggregate_id = $2
       ORDER BY occurred_at`,
      [tenantId, mutableOperationId],
    );
    expect(events.rows.filter(({ action }) => action === 'OPERATION_DEACTIVATED')).toHaveLength(1);
  });
  ```

  Add rejection cases for an empty patch (`EMPTY_UPDATE`), a patch containing `unit`, non-Director mutation, and cross-Tenant patch/activation (`OPERATION_NOT_FOUND`). Add an audit assertion that a combined name-and-price patch creates one `OPERATION_PRICE_CHANGED` event containing all changed fields.

  Add these bounded helpers inside the test suite so a failed contention assertion cannot leave blocked database sessions behind:

  ```ts
  async function waitForBlockedOperationLocks(blockerPid: number): Promise<Set<number>> {
    const blocked = new Set<number>();
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const result = await admin.query<{ pid: number }>(
        `SELECT pid FROM pg_stat_activity
         WHERE pid <> pg_backend_pid()
           AND state = 'active'
           AND wait_event_type = 'Lock'
           AND $1::integer = ANY(pg_blocking_pids(pid))
           AND query ILIKE '%FROM operations%'
         ORDER BY pid`,
        [blockerPid],
      );
      result.rows.forEach(({ pid }) => blocked.add(pid));
      if (blocked.size === 2) return blocked;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error('Timed out waiting for both price updates to block');
  }

  async function settleWithin<T>(promise: Promise<T>, message: string): Promise<T> {
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
  ```

  Then create an Operation for the test, lock it in a separate admin client, and release the lock only after both API calls block:

  ```ts
  it('serializes concurrent price changes into one current rate interval', async () => {
    const created = await request(server)
      .post('/api/v1/operations')
      .set('Authorization', `Bearer ${directorToken}`)
      .send({ name: 'Concurrent price operation', unit: 'PIECE', unit_price: 100 })
      .expect(201);
    const operationId = created.body.data.id as string;
    const blocker = new Client({ connectionString: process.env.DATABASE_ADMIN_URL ?? 'postgresql://texerp:texerp@localhost:5432/texerp' });
    let blockedPids = new Set<number>();
    try {
      await blocker.connect();
      await blocker.query('BEGIN');
      const lock = await blocker.query<{ pid: number }>('SELECT pg_backend_pid() AS pid');
      await blocker.query('SELECT id FROM operations WHERE id = $1 FOR UPDATE', [operationId]);
      const first = request(server).patch(`/api/v1/operations/${operationId}`).set('Authorization', `Bearer ${directorToken}`).send({ unit_price: 200 });
      const second = request(server).patch(`/api/v1/operations/${operationId}`).set('Authorization', `Bearer ${directorToken}`).send({ unit_price: 300 });
      blockedPids = await waitForBlockedOperationLocks(lock.rows[0]!.pid);
      await blocker.query('COMMIT');
      const [firstResponse, secondResponse] = await settleWithin(
        Promise.all([first, second]),
        'Timed out settling concurrent price updates',
      );
      expect([firstResponse.status, secondResponse.status]).toEqual([200, 200]);
      const history = await admin.query<{ unit_price: number; effective_from: Date; effective_to: Date | null }>(
        `SELECT unit_price, effective_from, effective_to FROM operation_price_history
         WHERE operation_id = $1 ORDER BY effective_from`,
        [operationId],
      );
      expect(history.rows).toHaveLength(3);
      expect(history.rows.filter(({ effective_to }) => effective_to === null)).toHaveLength(1);
      expect(history.rows[0]!.effective_to).toEqual(history.rows[1]!.effective_from);
      expect(history.rows[1]!.effective_to).toEqual(history.rows[2]!.effective_from);
    } finally {
      await blocker.query('ROLLBACK').catch(() => undefined);
      if (blockedPids.size > 0) {
        await admin.query('SELECT pg_terminate_backend(pid) FROM unnest($1::integer[]) AS blocked(pid)', [[...blockedPids]]);
      }
      await blocker.end().catch(() => undefined);
    }
  });

  // Close the `describe('Operations Catalog', ...)` block after this final case.
  });
  ```

- [ ] **Step 2: Run the E2E suite and confirm mutation routes fail**

  Run from `07_Backend`:

  ```bash
  npm run test:e2e -- --runInBand test/operations.e2e-spec.ts
  ```

  Expected: FAIL because `PATCH /operations/:id` and lifecycle routes do not yet exist.

- [ ] **Step 3: Add patch DTO, errors, controller routes, and exception mapping**

  Add this DTO; it intentionally omits `unit` and `is_active`, so the global `forbidNonWhitelisted` pipe rejects both fields before service execution:

  ```ts
  import { IsInt, IsString, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';

  export class UpdateOperationDto {
    @ValidateIf((_object, value) => value !== undefined)
    @IsString() @MinLength(1) @MaxLength(255) name?: string;
    @ValidateIf((_object, value) => value !== undefined)
    @IsString() @MinLength(1) @MaxLength(50) code?: string;
    @ValidateIf((_object, value) => value !== undefined)
    @IsInt() @Min(1) unit_price?: number;
    @ValidateIf((_object, value) => value !== undefined)
    @IsInt() sort_order?: number;
  }
  ```

  Add `EmptyOperationUpdateError` and map it to HTTP 400 with `{ code: 'EMPTY_UPDATE', message: 'Yangilash maydonlari berilmagan' }`. Add Director-only `@Patch(':id')`, `@Post(':id/deactivate')`, and `@Post(':id/activate')` controller methods. Parse IDs with `new ParseUUIDPipe()`, forward request metadata, and return `{ success: true, data }` for patch or `{ success: true }` for lifecycle actions.

- [ ] **Step 4: Implement locked updates and idempotent state transitions**

  In `OperationsService.update`, reject DTOs where all four mutable fields are `undefined`. Inside one `withTenant` transaction, lock the Operation first:

  ```sql
  SELECT id, name, code, unit, unit_price, currency, is_active, sort_order
  FROM operations
  WHERE tenant_id = $1 AND id = $2
  FOR UPDATE
  ```

  Throw `OperationNotFoundError` when no row exists. Compare only supplied fields to the locked row. Return the current representation with `price_changed: false` when there are no differences.

  For a price change, read a single timestamp using `SELECT clock_timestamp() AS changed_at`; insert one `OPERATION_PRICE_CHANGED` audit event containing every changed field, close the current rate, insert its successor, then update Operation metadata and `unit_price`:

  ```ts
  await manager.query(
    `UPDATE operation_price_history
     SET effective_to = $3
     WHERE tenant_id = $1 AND operation_id = $2 AND effective_to IS NULL`,
    [tenantId, operationId, changedAt],
  );
  await manager.query(
    `INSERT INTO operation_price_history
       (id, tenant_id, operation_id, unit_price, currency, effective_from, changed_by)
     VALUES ($1, $2, $3, $4, 'UZS', $5, $6)`,
    [uuidv7(), tenantId, operationId, nextPrice, changedAt, actor.sub],
  );
  ```

  For a metadata-only change, insert `OPERATION_UPDATED` before the `UPDATE operations` statement. Both audit paths include `before_state`, `after_state`, IP address, and user agent. Map the named uniqueness constraints exactly as in Task 2.

  Implement `setActive` with the same locked Operation query. If its current state already equals `isActive`, return without an audit or update. Otherwise insert `OPERATION_ACTIVATED` or `OPERATION_DEACTIVATED` before updating `is_active` and `updated_at`.

- [ ] **Step 5: Align the API contract with the delivered surface**

  In `04_API/APIContract.md` section 6:

  - Remove `category_id` from `GET /operations` and `POST /operations`.
  - State that `unit_price` is a positive integer in tiyin and that `currency` is `UZS`.
  - State that patch accepts only `name`, `code`, `unit_price`, and `sort_order`; units cannot change after creation.
  - Specify Director-only `INACTIVE` and `ALL` status filtering, idempotent activate/deactivate routes, and the `price_changed`, `old_price`, `new_price`, and `effective_from` patch response fields.
  - Replace the category and recently-used endpoint definitions with one deferred-work note. Do not leave a route in the active contract that this slice does not implement.

- [ ] **Step 6: Run focused and full verification**

  Run from `07_Backend`:

  ```bash
  npm run test:e2e -- --runInBand test/operations.e2e-spec.ts
  npm run test:integration -- tenant-isolation.integration-spec.ts
  npm run typecheck
  npm run lint
  npm run build
  ```

  Expected: all commands pass. The focused E2E suite proves price history, audit-first ordering, Tenant concealment, lifecycle idempotency, and concurrent-price serialization; integration verifies forced RLS.

- [ ] **Step 7: Commit the mutation and contract task**

  ```bash
  git add "04_API/APIContract.md" "07_Backend/src/modules/operations" "07_Backend/test/operations.e2e-spec.ts"
  git commit -m "feat: manage operation prices and lifecycle"
  ```

## Plan Self-Review

- Spec coverage: Task 1 implements the two RLS-protected tables, unique current-rate invariant, and database constraints. Task 2 implements module boundaries, list/create endpoints, authorization, audit-first creation, and public validation. Task 3 implements mutable metadata, immutable units, database-sourced price intervals, lifecycle actions, concurrency protection, stable errors, API contract alignment, and all required tests.
- Placeholder scan: no deferred implementation steps, generic validation instructions, or undefined file paths remain. Deferred product work is explicitly excluded by the global constraints.
- Type consistency: `OperationView`, `UpdateOperationView`, `CreateOperationDto`, `ListOperationsQueryDto`, `UpdateOperationDto`, and `OperationsService` method names are introduced before dependent tasks use them. Table and constraint names match the migration and conflict mapping requirements.
