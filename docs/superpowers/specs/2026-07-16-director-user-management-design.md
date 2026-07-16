# Director User Management Design

## Scope

Implement the Director-facing User management slice within the existing IAM module:

- `GET /api/v1/users`
- `POST /api/v1/users`
- `GET /api/v1/users/:id`
- `PATCH /api/v1/users/:id`
- `POST /api/v1/users/:id/deactivate`
- `POST /api/v1/users/:id/reactivate`

Department placement and Foreman Assignment creation are deferred to the next slice. The create and update endpoints therefore do not accept `department_id` or `foreman_id` yet. Self-profile and PIN-management endpoints are also outside this slice.

## Domain Rules

- A phone number identifies exactly one User globally in the MVP.
- A `worker_code` is unique within a Tenant.
- A Director may create Workers, Foremen, and Accountants, but not another Director.
- The initial PIN is exactly four digits and is stored only as a bcrypt hash.
- Phone, `worker_code`, and role are immutable after creation.
- A Director may update `full_name`, `language`, and `avatar_url`.
- A Director cannot deactivate themselves.
- Deactivation preserves historical data and revokes all active sessions.
- Reactivation does not restore revoked sessions; the User must log in again.
- Every query and mutation is constrained to the authenticated Tenant.

## Authorization

The existing JWT guard authenticates the request and validates the session against PostgreSQL. A role guard will provide endpoint authorization.

- Director: list, read, create, update, deactivate, reactivate.
- Accountant: list and read only.
- Foreman: may read an assigned Worker once Foreman Assignments exist; without an active assignment the request returns not found.
- Worker: no access to these management endpoints.

Cross-tenant identifiers return `USER_NOT_FOUND` rather than revealing that another Tenant owns the User.

## Architecture

User management remains in the IAM module but is separated from authentication:

- `UsersController` owns HTTP mapping and metadata extraction.
- `UsersService` owns authorization-aware use cases and tenant transactions.
- DTOs own request validation and reject unknown or immutable fields.
- `RolesGuard` and a role decorator express endpoint policy.

The service uses `TenantDatabase.withTenant()` for all tenant data access. Mutations insert an immutable audit event before changing the User in the same transaction. A failed mutation rolls back both operations.

## Endpoint Behavior

### List Users

`GET /users` supports role, status, search, page, and limit filters from the API contract. The default status is `ACTIVE`, page is 1, limit is 50, and limit is capped at 200. Results are ordered deterministically by `full_name`, then `id`. Department and Foreman fields are returned as `null` until assignments exist.

### Create User

`POST /users` accepts `full_name`, `phone`, `worker_code`, `role`, `initial_pin`, and optional `language`. It returns HTTP 201 with the new User summary. Duplicate phone and worker code constraints map to `PHONE_ALREADY_EXISTS` and `WORKER_CODE_ALREADY_EXISTS` conflict responses.

### Read User

`GET /users/:id` returns the profile shape defined by the API contract. A missing, cross-tenant, or unauthorized User returns `USER_NOT_FOUND`.

### Update User

`PATCH /users/:id` accepts only `full_name`, `language`, and `avatar_url`. At least one field is required. It returns the updated profile.

### Deactivate User

`POST /users/:id/deactivate` rejects self-deactivation and already-deactivated Users. The existing database trigger revokes active sessions. The response reports the number of sessions that were active before deactivation.

### Reactivate User

`POST /users/:id/reactivate` rejects already-active Users. It clears deactivation metadata but does not alter historical session rows.

## Errors

Errors use the existing `{ success: false, error: { code, message } }` envelope.

- `FORBIDDEN`: authenticated role cannot use the endpoint.
- `USER_NOT_FOUND`: User is absent, outside the Tenant, or outside Foreman visibility.
- `PHONE_ALREADY_EXISTS`: phone is already globally registered.
- `WORKER_CODE_ALREADY_EXISTS`: code exists in the Tenant.
- `CANNOT_CREATE_DIRECTOR`: attempted Director creation.
- `CANNOT_DEACTIVATE_SELF`: Director targeted themselves.
- `USER_ALREADY_DEACTIVATED`: duplicate deactivation.
- `USER_ALREADY_ACTIVE`: duplicate reactivation.
- Validation failures return HTTP 400 without reaching the service.

## Test Seams

Behavior is tested through the public HTTP API and the PostgreSQL isolation boundary.

E2E coverage includes Director creation, read/list/update, duplicate constraints, role denial, immutable-field rejection, self-deactivation rejection, deactivation session revocation, reactivation, and cross-tenant concealment. Integration coverage confirms tenant isolation for User queries and writes. Tests do not call service internals.

## Deferred Work

- Department CRUD
- Foreman Assignment creation and reassignment
- Department and Foreman filters beyond existing assignment data
- Self-profile and PIN changes
- OTP PIN reset
- Flutter screens
