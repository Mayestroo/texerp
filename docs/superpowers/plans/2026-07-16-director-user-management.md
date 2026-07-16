# Director User Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tenant-isolated, audited Director User-management endpoints for creating, listing, reading, updating, deactivating, and reactivating Users.

**Architecture:** Keep User management in IAM while separating it from authentication through `UsersController` and `UsersService`. Authenticate with the existing JWT guard, authorize with a metadata-driven role guard, and execute every database operation through `TenantDatabase.withTenant()` so PostgreSQL RLS remains the final isolation boundary.

**Tech Stack:** NestJS 11, TypeScript 5.8, PostgreSQL 17 with forced RLS, TypeORM transactions, bcrypt, class-validator, Jest, Supertest.

## Global Constraints

- Phone numbers are globally unique in the MVP; one User belongs to exactly one Tenant.
- `worker_code` is unique within one Tenant and immutable after creation.
- Department placement and Foreman Assignment mutation are deferred.
- The HTTP API and PostgreSQL isolation boundary are the only test seams.
- Audit events are inserted before mutations in the same transaction.
- Cross-tenant identifiers must return `USER_NOT_FOUND`.
- Do not create commits unless the user explicitly requests them.

## File Map

- Create `07_Backend/src/modules/iam/presentation/roles.decorator.ts`: endpoint role metadata.
- Create `07_Backend/src/modules/iam/presentation/roles.guard.ts`: authenticated role enforcement.
- Create `07_Backend/src/modules/iam/application/dto/create-user.dto.ts`: create payload validation.
- Create `07_Backend/src/modules/iam/application/dto/list-users-query.dto.ts`: list filters and pagination validation.
- Create `07_Backend/src/modules/iam/application/dto/update-user.dto.ts`: mutable-field-only validation.
- Create `07_Backend/src/modules/iam/application/users.service.ts`: tenant-scoped User use cases and audit-first transactions.
- Create `07_Backend/src/modules/iam/presentation/users.controller.ts`: `/users` HTTP endpoints.
- Modify `07_Backend/src/modules/iam/iam.module.ts`: register controller, service, and guard.
- Create `07_Backend/test/users.e2e-spec.ts`: public behavior coverage.
- Modify `04_API/APIContract.md`: align global phone uniqueness and deferred assignment fields.

---

### Task 1: Director Creates a User

**Files:**
- Create: `07_Backend/test/users.e2e-spec.ts`
- Create: `07_Backend/src/modules/iam/presentation/roles.decorator.ts`
- Create: `07_Backend/src/modules/iam/presentation/roles.guard.ts`
- Create: `07_Backend/src/modules/iam/application/dto/create-user.dto.ts`
- Create: `07_Backend/src/modules/iam/application/users.service.ts`
- Create: `07_Backend/src/modules/iam/presentation/users.controller.ts`
- Modify: `07_Backend/src/modules/iam/iam.module.ts`

**Interfaces:**
- Consumes: `JwtAuthGuard`, `AuthenticatedRequest`, `TenantDatabase.withTenant()`, `uuidv7()`.
- Produces: `@Roles(...roles)`, `RolesGuard`, `UsersService.create(tenantId, actor, dto, metadata)`, and `POST /api/v1/users`.

- [ ] **Step 1: Write the failing creation test**

Seed one Tenant with Director and Worker credentials. Log in through `/api/v1/auth/login`, then exercise only the public endpoint:

```ts
const response = await request(server)
  .post('/api/v1/users')
  .set('Authorization', `Bearer ${directorAccessToken}`)
  .send({
    full_name: 'Malika Yusupova',
    phone: '+998901230001',
    worker_code: 'W-0043',
    role: 'WORKER',
    initial_pin: '4321',
  })
  .expect(201);

expect(response.body).toMatchObject({
  success: true,
  data: {
    full_name: 'Malika Yusupova',
    worker_code: 'W-0043',
    role: 'WORKER',
    status: 'ACTIVE',
  },
});
```

- [ ] **Step 2: Run the test and verify red**

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts -t "creates a Worker"`

Expected: FAIL with HTTP 404 because `/api/v1/users` does not exist.

- [ ] **Step 3: Add role metadata and enforcement**

Implement metadata with `SetMetadata('roles', roles)` and a `RolesGuard` using `Reflector.getAllAndOverride`. The guard reads `AuthenticatedRequest.user.role` and throws `ForbiddenException` with code `FORBIDDEN` unless the role is allowed.

- [ ] **Step 4: Add strict create DTO validation**

Define fields and validation:

```ts
full_name: string; // @IsString, @Length(2, 255)
phone: string; // @Matches(/^\+998\d{9}$/)
worker_code: string; // @Matches(/^[A-Za-z0-9_-]{1,20}$/)
role: 'WORKER' | 'FOREMAN' | 'ACCOUNTANT'; // @IsIn
initial_pin: string; // @Matches(/^\d{4}$/)
language?: 'uz' | 'ru'; // @IsOptional, @IsIn
```

Do not declare `department_id`, `foreman_id`, or `DIRECTOR`; global validation must reject them.

- [ ] **Step 5: Implement audit-first creation**

In one tenant transaction:

1. Generate the User ID.
2. Hash `initial_pin` with bcrypt cost 12 before entering the transaction.
3. Insert `USER_CREATED` into `audit_events`, excluding `initial_pin` and `pin_hash` from `after_state`.
4. Insert the User with `created_by = actor.sub`.
5. Map PostgreSQL unique violations by constraint: `users_phone_key` to `PHONE_ALREADY_EXISTS`; `users_tenant_id_worker_code_key` to `WORKER_CODE_ALREADY_EXISTS`.

- [ ] **Step 6: Wire the controller and module**

Expose `POST /users` with `@UseGuards(JwtAuthGuard, RolesGuard)`, `@Roles('DIRECTOR')`, and HTTP 201. Pass request IP and user agent into the service. Register `UsersController`, `UsersService`, and `RolesGuard` in `IamModule`.

- [ ] **Step 7: Verify creation and authorization**

Add and run tests proving:

```ts
await createAsDirector(validWorker).expect(201);
await createAsWorker(validWorker).expect(403);
await createAsDirector({ ...validWorker, role: 'DIRECTOR' }).expect(400);
await createAsDirector({ ...validWorker, department_id: randomUUID() }).expect(400);
```

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts`

Expected: all Task 1 tests PASS.

### Task 2: Duplicate Identity Constraints

**Files:**
- Modify: `07_Backend/test/users.e2e-spec.ts`
- Modify: `07_Backend/src/modules/iam/application/users.service.ts`

**Interfaces:**
- Consumes: `UsersService.create()` from Task 1.
- Produces: stable conflict envelopes for globally duplicate phone and tenant-local duplicate worker code.

- [ ] **Step 1: Write duplicate tests**

Create one User successfully, then assert:

```ts
expect(duplicatePhone.body).toMatchObject({
  success: false,
  error: { code: 'PHONE_ALREADY_EXISTS' },
});
expect(duplicateCode.body).toMatchObject({
  success: false,
  error: { code: 'WORKER_CODE_ALREADY_EXISTS' },
});
```

Both responses must be HTTP 409. Add a second Tenant fixture and prove that its existing phone conflicts globally while its worker code does not conflict in the Director's Tenant.

- [ ] **Step 2: Run and verify red**

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts -t "duplicate"`

Expected: FAIL until database errors map to the documented envelopes.

- [ ] **Step 3: Map only known unique constraints**

Catch `QueryFailedError`, inspect PostgreSQL error code `23505` and `constraint`, and throw `ConflictException` only for the two known constraints. Re-throw unknown database errors.

- [ ] **Step 4: Run and verify green**

Run the duplicate tests and then the complete User E2E file. Expected: PASS.

### Task 3: List and Read Users

**Files:**
- Create: `07_Backend/src/modules/iam/application/dto/list-users-query.dto.ts`
- Modify: `07_Backend/src/modules/iam/application/users.service.ts`
- Modify: `07_Backend/src/modules/iam/presentation/users.controller.ts`
- Modify: `07_Backend/test/users.e2e-spec.ts`

**Interfaces:**
- Consumes: role guards and tenant transaction boundary.
- Produces: `UsersService.list()`, `UsersService.getById()`, `GET /api/v1/users`, and `GET /api/v1/users/:id`.

- [ ] **Step 1: Write list and read tests**

Assert Director and Accountant can list/read, Worker receives 403, default listing excludes deactivated Users, search matches case-insensitive full name or exact/partial worker code, and cross-tenant IDs return:

```ts
{
  success: false,
  error: { code: 'USER_NOT_FOUND' }
}
```

with HTTP 404.

- [ ] **Step 2: Run and verify red**

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts -t "lists|reads"`

Expected: FAIL with HTTP 404 routes.

- [ ] **Step 3: Implement validated filters**

The query DTO supports `role`, `status`, `search`, `page`, and `limit`; transform numeric strings and enforce page >= 1 and limit between 1 and 200. Leave `department_id` and `foreman_id` deferred and rejected by whitelist validation.

- [ ] **Step 4: Implement deterministic tenant queries**

Use parameterized SQL within `withTenant()`. Build only whitelisted filter fragments. Return:

```ts
{
  data: UserSummary[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
    has_next: boolean;
  };
}
```

Order by `full_name ASC, id ASC`. Profile queries left join the active Foreman Assignment, Department, and Foreman, returning nullable nested objects.

- [ ] **Step 5: Add role-aware visibility**

Director and Accountant can read any same-Tenant User. Foreman reads only themselves or a Worker with an active assignment to `actor.sub`; otherwise return `USER_NOT_FOUND`. Worker is blocked by `RolesGuard`.

- [ ] **Step 6: Run and verify green**

Run the focused tests, the full User E2E file, and `npm run test:integration`. Expected: PASS.

### Task 4: Update Mutable User Fields

**Files:**
- Create: `07_Backend/src/modules/iam/application/dto/update-user.dto.ts`
- Modify: `07_Backend/src/modules/iam/application/users.service.ts`
- Modify: `07_Backend/src/modules/iam/presentation/users.controller.ts`
- Modify: `07_Backend/test/users.e2e-spec.ts`

**Interfaces:**
- Consumes: profile mapping from Task 3.
- Produces: `UsersService.update()` and `PATCH /api/v1/users/:id`.

- [ ] **Step 1: Write update tests**

Assert a Director can update `full_name`, `language`, and nullable `avatar_url`; an Accountant receives 403; cross-tenant ID receives 404; and `phone`, `worker_code`, `role`, `status`, `department_id`, and `foreman_id` each receive 400 from whitelist validation.

- [ ] **Step 2: Run and verify red**

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts -t "updates"`

Expected: FAIL with route missing.

- [ ] **Step 3: Implement DTO and non-empty validation**

Declare only the three mutable fields with optional validators. Reject `{}` in the service with a 400 `EMPTY_UPDATE` error.

- [ ] **Step 4: Implement audit-first update**

Within one tenant transaction, lock and read the User, return `USER_NOT_FOUND` if absent, insert `USER_UPDATED` with only changed fields in `before_state` and `after_state`, then perform a parameterized update and return the complete profile.

- [ ] **Step 5: Run and verify green**

Run focused and full User E2E tests. Expected: PASS.

### Task 5: Deactivate and Reactivate Users

**Files:**
- Modify: `07_Backend/src/modules/iam/application/users.service.ts`
- Modify: `07_Backend/src/modules/iam/presentation/users.controller.ts`
- Modify: `07_Backend/test/users.e2e-spec.ts`

**Interfaces:**
- Consumes: database deactivation trigger from `1752661000000-CreateAuthLookup.ts`.
- Produces: `UsersService.deactivate()`, `UsersService.reactivate()`, and the two lifecycle endpoints.

- [ ] **Step 1: Write lifecycle tests**

Cover these public behaviors:

```ts
await deactivateSelf().expect(400); // CANNOT_DEACTIVATE_SELF
await deactivateActiveUser().expect(200); // sessions_revoked is exact
await useFormerAccessToken().expect(401);
await deactivateAgain().expect(400); // USER_ALREADY_DEACTIVATED
await reactivateUser().expect(200);
await reactivateAgain().expect(400); // USER_ALREADY_ACTIVE
await useFormerAccessToken().expect(401); // old sessions remain revoked
```

- [ ] **Step 2: Run and verify red**

Run: `npm run test:e2e -- --runInBand test/users.e2e-spec.ts -t "deactivates|reactivates"`

Expected: FAIL with missing routes.

- [ ] **Step 3: Implement audit-first deactivation**

Lock the target row, enforce state and self-deactivation rules, count active sessions, insert `USER_DEACTIVATED`, then update status and deactivation metadata. The existing trigger updates session rows in the same transaction. Return `{ message, sessions_revoked }`.

- [ ] **Step 4: Implement audit-first reactivation**

Lock the target row, require `DEACTIVATED`, insert `USER_REACTIVATED`, then set status to `ACTIVE` and clear `deactivated_at` and `deactivated_by`. Do not modify session rows.

- [ ] **Step 5: Run and verify green**

Run focused and complete User E2E tests. Expected: PASS.

### Task 6: Contract Alignment and Release Verification

**Files:**
- Modify: `04_API/APIContract.md`
- Modify if review requires: files introduced in Tasks 1-5.

**Interfaces:**
- Consumes: all User-management endpoints.
- Produces: aligned documentation and verified backend slice.

- [ ] **Step 1: Align the API contract**

Change User creation phone uniqueness from tenant-local to global. Mark `department_id` and `foreman_id` as deferred to the Foreman Assignment slice, remove them from the current request example, document optional `language`, and document `CANNOT_CREATE_DIRECTOR`, `EMPTY_UPDATE`, `USER_ALREADY_ACTIVE`, and immutable-field validation behavior.

- [ ] **Step 2: Format touched TypeScript files**

Run Prettier only on files changed by this plan, not the entire repository.

- [ ] **Step 3: Run static and build gates**

Run in parallel:

```bash
npm run typecheck
npm run lint
npm run build
```

Expected: all commands exit 0.

- [ ] **Step 4: Run all test gates sequentially**

```bash
npm test -- --runInBand
npm run test:integration
npm run test:e2e -- --runInBand
npm audit --audit-level=high
```

Expected: all tests pass and audit reports zero high-severity vulnerabilities.

- [ ] **Step 5: Review the implementation**

Use the code-review skill against the design specification. Resolve every critical/high finding and rerun affected tests followed by the full gates.
