# Organization and Foreman Assignments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Tenant-isolated Department management, time-bounded Foreman Assignment lifecycle operations, and a Foreman's current Worker list.

**Architecture:** Add an `OrganizationModule` beside IAM, with focused Department and Foreman Assignment services/controllers using the existing `TenantDatabase` transaction boundary and IAM guards. Preserve the existing history schema, serialize assignment mutations by locking the Worker, and test behavior through HTTP plus PostgreSQL RLS.

**Tech Stack:** NestJS 11, TypeScript 5.8, TypeORM raw SQL transactions, PostgreSQL 17 forced RLS, class-validator, Jest 30, Supertest.

## Global Constraints

- Use canonical domain terms: Tenant, User, Worker, Foreman, Department, and Foreman Assignment.
- Keep `POST /users` unchanged; assignment is a separate operation.
- Assignment input contains only `department_id`; derive the Foreman from the Department.
- Historical Foreman Assignment rows are never overwritten except to set `unassigned_at` when ending the active relationship.
- Changing a Department's designated Foreman does not rewrite existing Foreman Assignments.
- Every data operation runs through `TenantDatabase.withTenant()`.
- Mutations write audit events before state changes in the same transaction.
- Cross-Tenant and wrong-domain-role identifiers are concealed as not found.
- Do not commit changes unless the user explicitly requests a commit.

## File Structure

- Create `07_Backend/src/modules/organization/organization.module.ts`: module composition and IAM guard reuse.
- Create `07_Backend/src/modules/organization/application/departments.service.ts`: Department list/create/update use cases.
- Create `07_Backend/src/modules/organization/application/foreman-assignments.service.ts`: assignment lifecycle and Foreman Worker query.
- Create `07_Backend/src/modules/organization/application/dto/create-department.dto.ts`: Department creation validation.
- Create `07_Backend/src/modules/organization/application/dto/update-department.dto.ts`: Department patch validation.
- Create `07_Backend/src/modules/organization/application/dto/list-departments-query.dto.ts`: strict `include_inactive` parsing.
- Create `07_Backend/src/modules/organization/application/dto/set-foreman-assignment.dto.ts`: assignment Department UUID validation.
- Create `07_Backend/src/modules/organization/application/errors/*.error.ts`: typed Organization application errors.
- Create `07_Backend/src/modules/organization/presentation/departments.controller.ts`: Department routes and envelopes.
- Create `07_Backend/src/modules/organization/presentation/foreman-assignments.controller.ts`: Worker action and Foreman list routes.
- Create `07_Backend/src/modules/organization/presentation/organization-exception.filter.ts`: stable Organization error mapping.
- Modify `07_Backend/src/modules/iam/iam.module.ts`: export reusable guards.
- Modify `07_Backend/src/app.module.ts`: register `OrganizationModule`.
- Create `07_Backend/test/organization.e2e-spec.ts`: public API, audit, isolation, and concurrency coverage.
- Modify `07_Backend/test/database/tenant-isolation.integration-spec.ts`: explicit Organization-table RLS write assertions.
- Modify `04_API/APIContract.md`: bind the new endpoints, response shapes, and errors.

---

### Task 1: Department API

**Files:**
- Create: `07_Backend/src/modules/organization/application/dto/create-department.dto.ts`
- Create: `07_Backend/src/modules/organization/application/dto/update-department.dto.ts`
- Create: `07_Backend/src/modules/organization/application/dto/list-departments-query.dto.ts`
- Create: `07_Backend/src/modules/organization/application/departments.service.ts`
- Create: `07_Backend/src/modules/organization/application/errors/department-not-found.error.ts`
- Create: `07_Backend/src/modules/organization/application/errors/department-name-already-exists.error.ts`
- Create: `07_Backend/src/modules/organization/application/errors/department-code-already-exists.error.ts`
- Create: `07_Backend/src/modules/organization/application/errors/foreman-not-found.error.ts`
- Create: `07_Backend/src/modules/organization/application/errors/empty-department-update.error.ts`
- Create: `07_Backend/src/modules/organization/presentation/departments.controller.ts`
- Create: `07_Backend/src/modules/organization/presentation/organization-exception.filter.ts`
- Create: `07_Backend/src/modules/organization/organization.module.ts`
- Modify: `07_Backend/src/modules/iam/iam.module.ts`
- Modify: `07_Backend/src/app.module.ts`
- Create: `07_Backend/test/organization.e2e-spec.ts`

**Interfaces:**
- Consumes: `TenantDatabase.withTenant<T>()`, `AccessTokenClaims`, `JwtAuthGuard`, `RolesGuard`, `@Roles()`.
- Produces: `DepartmentsService.list(tenantId, query)`, `create(tenantId, actor, dto, metadata)`, and `update(tenantId, actor, departmentId, dto, metadata)`.

- [ ] **Step 1: Add failing Department E2E cases**

Create the Organization fixture with two Tenants, Director/Foreman/Worker tokens, and tests proving:

```ts
await request(server)
  .post('/api/v1/departments')
  .set('Authorization', `Bearer ${directorToken}`)
  .send({ name: 'Sewing Line 1', code: 'SL-1', foreman_id: foremanId })
  .expect(201)
  .expect(({ body }) => {
    expect(body).toMatchObject({
      success: true,
      data: {
        name: 'Sewing Line 1',
        code: 'SL-1',
        is_active: true,
        foreman: { id: foremanId, full_name: 'Primary Foreman' },
        worker_count: 0,
      },
    });
  });
```

Cover active-only listing, `include_inactive=true`, patching all mutable fields, empty/unknown fields, invalid UUIDs, wrong User role, inactive Foreman, duplicate name/code, non-Director mutation denial, and cross-Tenant concealment.

- [ ] **Step 2: Run the focused E2E suite and verify RED**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: FAIL because the Department routes do not exist.

- [ ] **Step 3: Add strict DTOs and typed errors**

Use class-validator shapes equivalent to:

```ts
export class CreateDepartmentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(30)
  code!: string;

  @IsUUID()
  foreman_id!: string;
}

export class UpdateDepartmentDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(255) name?: string;
  @IsOptional() @IsString() @MinLength(1) @MaxLength(30) code?: string;
  @IsOptional() @IsUUID() foreman_id?: string;
  @IsOptional() @IsBoolean() is_active?: boolean;
}
```

Parse `include_inactive` only from literal `true`/`false`; reject values such as `1`, `yes`, and an empty string.

- [ ] **Step 4: Implement Department transactions**

Return this stable representation from one private query used after mutations:

```ts
interface DepartmentView {
  id: string;
  name: string;
  code: string;
  is_active: boolean;
  foreman: { id: string; full_name: string } | null;
  worker_count: number;
}
```

Validate the selected Foreman with:

```sql
SELECT id
FROM users
WHERE tenant_id = $1
  AND id = $2
  AND role = 'FOREMAN'
  AND status = 'ACTIVE'
```

For create/update, insert `DEPARTMENT_CREATED` or `DEPARTMENT_UPDATED` audit state before the Department mutation. Lock updates with `SELECT ... FOR UPDATE`. Detect PostgreSQL `23505` constraints `departments_tenant_name_key` and `departments_tenant_code_key` and map them to the corresponding conflict errors.

- [ ] **Step 5: Wire controllers, filter, guards, and module**

Expose `JwtAuthGuard` and `RolesGuard` from `IamModule`, import `IamModule` into `OrganizationModule`, and register `OrganizationModule` in `AppModule`. Map errors to the spec envelope and status codes. Use `@Roles('DIRECTOR')` for mutations and all four roles for listing.

- [ ] **Step 6: Run Department E2E and static checks**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: Department cases PASS.

Run: `npm run typecheck && npm run lint`

Expected: both commands exit 0.

---

### Task 2: Foreman Assignment Lifecycle

**Files:**
- Create: `07_Backend/src/modules/organization/application/dto/set-foreman-assignment.dto.ts`
- Create: `07_Backend/src/modules/organization/application/foreman-assignments.service.ts`
- Create: `07_Backend/src/modules/organization/application/errors/worker-not-found.error.ts`
- Create: `07_Backend/src/modules/organization/application/errors/department-has-no-foreman.error.ts`
- Create: `07_Backend/src/modules/organization/presentation/foreman-assignments.controller.ts`
- Modify: `07_Backend/src/modules/organization/presentation/organization-exception.filter.ts`
- Modify: `07_Backend/src/modules/organization/organization.module.ts`
- Modify: `07_Backend/test/organization.e2e-spec.ts`

**Interfaces:**
- Consumes: `SetForemanAssignmentDto { department_id: string }` and Organization errors from Task 1.
- Produces: `ForemanAssignmentsService.setAssignment(tenantId, actor, workerId, dto, metadata)` and `unassign(tenantId, actor, workerId, metadata)`.

- [ ] **Step 1: Add failing lifecycle E2E cases**

Test the public action routes:

```ts
await request(server)
  .put(`/api/v1/users/${workerId}/foreman-assignment`)
  .set('Authorization', `Bearer ${directorToken}`)
  .send({ department_id: departmentId })
  .expect(200)
  .expect(({ body }) => {
    expect(body).toMatchObject({
      success: true,
      data: {
        worker: { id: workerId },
        department: { id: departmentId },
        foreman: { id: foremanId },
      },
    });
  });
```

Cover initial assignment, same-target idempotency, reassignment, idempotent unassignment, wrong/inactive Worker, inactive/missing Department, Department with missing/inactive Foreman, invalid/unknown request fields, non-Director denial, and cross-Tenant concealment. Query PostgreSQL to prove ended/new rows and audit states.

- [ ] **Step 2: Run lifecycle cases and verify RED**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: FAIL because assignment routes do not exist.

- [ ] **Step 3: Implement serialized set/reassign transaction**

Inside `withTenant`, lock and validate the Worker first:

```sql
SELECT id, full_name
FROM users
WHERE tenant_id = $1
  AND id = $2
  AND role = 'WORKER'
  AND status = 'ACTIVE'
FOR UPDATE
```

Then lock the Department and derive its Foreman:

```sql
SELECT d.id, d.name, d.code, f.id AS foreman_id, f.full_name AS foreman_name
FROM departments d
LEFT JOIN users f
  ON f.tenant_id = d.tenant_id
 AND f.id = d.foreman_id
 AND f.role = 'FOREMAN'
 AND f.status = 'ACTIVE'
WHERE d.tenant_id = $1 AND d.id = $2 AND d.is_active = true
FOR UPDATE OF d
```

Lock the current assignment. If its Department and Foreman match, return it without writing. Otherwise create a UUIDv7 assignment ID, write one audit event, end the previous row with the same timestamp, and insert the new row with `assigned_by = actor.sub`.

- [ ] **Step 4: Implement idempotent unassignment**

Lock and validate the active Worker, then lock the active assignment. If absent, return `{ message: 'Ishchi brigadirdan ajratildi' }` without an audit event. If present, insert `FOREMAN_UNASSIGNED` before setting `unassigned_at`.

- [ ] **Step 5: Add controller and error mappings**

Use a `@Controller({ path: 'users', version: '1' })` controller with:

```ts
@Put(':workerId/foreman-assignment')
@Delete(':workerId/foreman-assignment')
```

Apply `ParseUUIDPipe`, `JwtAuthGuard`, `RolesGuard`, and `@Roles('DIRECTOR')`. Map `WORKER_NOT_FOUND`, `DEPARTMENT_NOT_FOUND`, and `DEPARTMENT_HAS_NO_FOREMAN` exactly as specified.

- [ ] **Step 6: Run lifecycle E2E and static checks**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: Department and assignment lifecycle cases PASS.

Run: `npm run typecheck && npm run lint`

Expected: both commands exit 0.

---

### Task 3: Foreman Worker List

**Files:**
- Modify: `07_Backend/src/modules/organization/application/foreman-assignments.service.ts`
- Modify: `07_Backend/src/modules/organization/presentation/foreman-assignments.controller.ts`
- Modify: `07_Backend/test/organization.e2e-spec.ts`

**Interfaces:**
- Consumes: authenticated `AccessTokenClaims` from the existing JWT guard.
- Produces: `ForemanAssignmentsService.listMyWorkers(tenantId, foremanId): Promise<UserSummary[]>`.

- [ ] **Step 1: Add failing Foreman visibility tests**

Test `GET /api/v1/users/me/workers` returns only active Workers whose active assignment records the authenticated Foreman. Prove deterministic ordering, exclusion after unassignment, exclusion of another Foreman's Workers, no cross-Tenant rows, and denial for Director/Accountant/Worker tokens.

- [ ] **Step 2: Run focused E2E and verify RED**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: FAIL with 404 for the new route.

- [ ] **Step 3: Implement the scoped query**

Use the existing User summary shape and this visibility predicate:

```sql
FROM users u
JOIN foreman_assignments fa
  ON fa.tenant_id = u.tenant_id
 AND fa.worker_id = u.id
 AND fa.foreman_id = $2
 AND fa.unassigned_at IS NULL
LEFT JOIN departments d
  ON d.tenant_id = fa.tenant_id AND d.id = fa.department_id
LEFT JOIN users f
  ON f.tenant_id = fa.tenant_id AND f.id = fa.foreman_id
WHERE u.tenant_id = $1
  AND u.role = 'WORKER'
  AND u.status = 'ACTIVE'
ORDER BY u.full_name ASC, u.id ASC
```

Return `{ success: true, data }` without pagination.

- [ ] **Step 4: Wire the Foreman-only route and verify**

Add `@Get('me/workers')` before parameterized action routes and apply `@Roles('FOREMAN')`.

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: all Organization E2E cases PASS.

---

### Task 4: Concurrency and PostgreSQL Isolation

**Files:**
- Modify: `07_Backend/test/organization.e2e-spec.ts`
- Modify: `07_Backend/test/database/tenant-isolation.integration-spec.ts`
- Modify if needed: `07_Backend/src/modules/organization/application/foreman-assignments.service.ts`

**Interfaces:**
- Consumes: Worker-row locking implemented in Task 2 and existing forced RLS policies.
- Produces: executable proof that only one active Foreman Assignment can survive races and Organization writes cannot cross Tenant boundaries.

- [ ] **Step 1: Add a deterministic concurrent reassignment test**

Hold a PostgreSQL lock on the target Worker row, start two PUT requests selecting different Departments, wait until both requests are blocked, release the lock, then assert both requests return 200 and this query returns exactly one row:

```sql
SELECT id, department_id, foreman_id
FROM foreman_assignments
WHERE tenant_id = $1 AND worker_id = $2 AND unassigned_at IS NULL
```

Also assert the assignment history has valid non-decreasing timestamps and exactly the expected audit count.

- [ ] **Step 2: Run the race test repeatedly**

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts -t "serializes concurrent reassignment"`

Expected: PASS on three consecutive runs without timeout or unique-constraint responses.

- [ ] **Step 3: Add explicit RLS write tests**

With `app.current_tenant_id` set to Tenant A, assert runtime-role attempts to insert a Tenant B Department and Foreman Assignment reject with PostgreSQL `42501`. Assert SELECTs from both tables return only Tenant A rows.

- [ ] **Step 4: Run integration and Organization suites**

Run: `npm run test:integration -- --runInBand`

Expected: all integration tests PASS.

Run: `npm run test:e2e -- --runInBand test/organization.e2e-spec.ts`

Expected: all Organization E2E tests PASS.

---

### Task 5: API Contract and Full Verification

**Files:**
- Modify: `04_API/APIContract.md`
- Modify if verification finds defects: Organization implementation and tests from Tasks 1-4.

**Interfaces:**
- Consumes: final HTTP behavior from Tasks 1-4.
- Produces: binding API documentation matching the shipped routes and a fully verified backend.

- [ ] **Step 1: Update the binding API contract**

Document exact Department validation/errors and add:

```md
### `PUT /users/:workerId/foreman-assignment`
**Roles:** DIRECTOR
**Request:** `{ "department_id": "<uuid>" }`

### `DELETE /users/:workerId/foreman-assignment`
**Roles:** DIRECTOR

### `GET /users/me/workers`
**Roles:** FOREMAN
```

Remove statements that Department/Foreman functionality is currently rejected where the new slice supersedes them, while retaining the rule that `POST /users` does not accept assignment fields. Add all Organization error codes to the global error table.

- [ ] **Step 2: Format and inspect the final diff**

Run: `npm run format`

Expected: Prettier completes successfully and changes only TypeScript test/source formatting.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 3: Run the complete backend verification matrix**

Run: `npm run typecheck`

Run: `npm run lint`

Run: `npm test -- --runInBand`

Run: `npm run test:integration -- --runInBand`

Run: `npm run test:e2e -- --runInBand`

Run: `npm run build`

Expected: every command exits 0.

- [ ] **Step 4: Review scope and worktree**

Confirm the implementation matches `docs/superpowers/specs/2026-07-16-organization-foreman-assignments-design.md`, no assignment fields were added to `POST /users`, no historical rows are rewritten beyond `unassigned_at`, and unrelated worktree files such as `skills-lock.json` remain untouched.
