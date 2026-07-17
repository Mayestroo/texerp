# Organization and Foreman Assignments Design

## Scope

Implement the backend Organization slice for Department management and time-bounded Foreman Assignments:

- `GET /api/v1/departments`
- `POST /api/v1/departments`
- `PATCH /api/v1/departments/:id`
- `PUT /api/v1/users/:workerId/foreman-assignment`
- `DELETE /api/v1/users/:workerId/foreman-assignment`
- `GET /api/v1/users/me/workers`

Flutter screens, self-profile endpoints, and accepting `department_id` or `foreman_id` during User creation remain deferred.

## Domain Rules

- A Department belongs to exactly one Tenant and has a Tenant-unique name and code.
- A Department designates one active Foreman before Workers can be assigned to it.
- A Foreman Assignment is the time-bounded relationship identifying the Foreman responsible for a Worker.
- A Worker has at most one active Foreman Assignment.
- Assignment input selects a Department; the service derives the Foreman from that Department.
- Worker, Department, and Foreman must be active and belong to the authenticated Tenant when an assignment is created.
- Reassignment ends the current Foreman Assignment and inserts a new row. Historical rows are never overwritten.
- Changing a Department's designated Foreman affects future assignments only. Existing active and historical Foreman Assignments retain their recorded Foreman.
- Deactivating a Department prevents new assignments but does not alter existing Foreman Assignments.
- Every query and mutation is constrained to the authenticated Tenant.

## Architecture

Add an `OrganizationModule` as a separate bounded context from IAM:

- `DepartmentsController` and `DepartmentsService` own Department HTTP behavior and use cases.
- `ForemanAssignmentsController` and `ForemanAssignmentsService` own assignment lifecycle behavior and the Foreman's Worker list.
- DTOs validate input and reject unknown fields.
- Existing IAM JWT and role guards are reused for authentication and endpoint authorization.
- `TenantDatabase.withTenant()` is the only data-access boundary.

No migration is required. The existing `departments` and `foreman_assignments` tables already provide forced RLS, Tenant-scoped foreign keys, history timestamps, and the partial unique index enforcing one active assignment per Worker.

Assignment mutations lock the Worker row before reading or changing the active assignment. This serializes concurrent assignment requests for the same Worker. Department updates lock the Department row; assignment creation locks its selected Department while deriving the Foreman.

## Authorization

- All authenticated roles may list Departments.
- Only Directors may create or update Departments.
- Only Directors may assign, reassign, or unassign Workers.
- Only Foremen may call `GET /users/me/workers`.
- Missing, cross-Tenant, and wrong-role resource identifiers return the relevant not-found error and do not reveal resource existence.

## Endpoint Behavior

### List Departments

`GET /departments` accepts `include_inactive`, defaulting to `false`. It returns Departments ordered by name and then ID. Each item contains `id`, `name`, `code`, `is_active`, the designated Foreman summary or `null`, and `worker_count`. The count includes active Foreman Assignments recorded against that Department, including assignments whose recorded Foreman differs from the Department's current designated Foreman.

### Create Department

`POST /departments` accepts `name`, `code`, and `foreman_id`. The Foreman must be an active User with role `FOREMAN` in the Tenant. The endpoint returns HTTP 201 with the Department representation. Tenant-duplicate name or code conflicts map to stable conflict errors.

### Update Department

`PATCH /departments/:id` accepts any non-empty combination of `name`, `code`, `foreman_id`, and `is_active`. `foreman_id` may be a Foreman UUID but not `null`; removing a designated Foreman is outside this slice. An unchanged request returns the current representation without an audit event. Updating the designated Foreman does not rewrite active Foreman Assignments.

### Assign or Reassign Worker

`PUT /users/:workerId/foreman-assignment` accepts:

```json
{
  "department_id": "019..."
}
```

The target User must be an active Worker. The Department must be active and have an active designated Foreman. If the Worker's current active assignment already records the selected Department and its current designated Foreman, the operation is idempotent and returns that assignment. Otherwise, the service uses one timestamp to end the current assignment, if present, and insert the new assignment. The response contains assignment ID, Worker summary, Department summary, Foreman summary, and `assigned_at`.

### Unassign Worker

`DELETE /users/:workerId/foreman-assignment` ends the current assignment with `unassigned_at = now()`. If no active assignment exists, the operation is idempotent. It returns HTTP 200 with a success message in both cases.

### List My Workers

`GET /users/me/workers` returns active Workers with active Foreman Assignments whose recorded `foreman_id` is the authenticated Foreman. Results use the existing User summary shape and are ordered by full name and then ID. This MVP endpoint is not paginated.

## Audit Events

Mutations write immutable audit events before their state change in the same transaction:

- `DEPARTMENT_CREATED`
- `DEPARTMENT_UPDATED`
- `FOREMAN_ASSIGNED`
- `FOREMAN_REASSIGNED`
- `FOREMAN_UNASSIGNED`

Idempotent no-op requests do not write audit events. Reassignment uses one event whose before state identifies the ended assignment and whose after state identifies the new assignment.

## Errors

Errors use the existing `{ success: false, error: { code, message } }` envelope.

- `DEPARTMENT_NOT_FOUND` (404): absent, cross-Tenant, or concealed Department.
- `DEPARTMENT_NAME_ALREADY_EXISTS` (409): name already exists in the Tenant.
- `DEPARTMENT_CODE_ALREADY_EXISTS` (409): code already exists in the Tenant.
- `FOREMAN_NOT_FOUND` (404): selected User is absent, cross-Tenant, inactive, or not a Foreman.
- `WORKER_NOT_FOUND` (404): target User is absent, cross-Tenant, inactive, or not a Worker.
- `DEPARTMENT_HAS_NO_FOREMAN` (400): the selected Department has no active designated Foreman.
- `EMPTY_UPDATE` (400): Department patch has no mutable fields.
- `FORBIDDEN` (403): the authenticated role cannot use the endpoint.
- Request validation failures return HTTP 400 before service execution.

## Test Seams

Behavior is tested through the public HTTP API and PostgreSQL isolation boundary.

E2E coverage includes:

- Department listing, inactive filtering, creation, update, uniqueness conflicts, authorization, and Tenant concealment.
- Assignment, idempotent assignment, reassignment history, idempotent unassignment, role validation, active-state validation, authorization, and Tenant concealment.
- Foreman Worker-list scoping, exclusion after unassignment, and exclusion from other Foremen and Tenants.
- Audit event state and omission for idempotent no-ops.
- Concurrent reassignment of one Worker, proving only one active assignment remains.

Existing database integration tests continue to verify forced RLS. New integration assertions cover Tenant isolation for Department and Foreman Assignment reads and writes where E2E coverage cannot directly exercise the database boundary.

## Deferred Work

- Flutter Director Department and assignment screens.
- Flutter Foreman Worker-list screen.
- Department and Foreman filters on `GET /users`.
- Assignment input during `POST /users`.
- Foreman Assignment history APIs.
- Bulk assignment and bulk reassignment.
- Automatic reassignment when a Department's designated Foreman changes.
