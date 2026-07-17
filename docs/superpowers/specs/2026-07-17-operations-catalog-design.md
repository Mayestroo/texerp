# Operations Catalog Design

## Scope

Implement the backend-only Operations Catalog required before Workers can submit Production Entries:

- `GET /api/v1/operations`
- `POST /api/v1/operations`
- `PATCH /api/v1/operations/:id`
- `POST /api/v1/operations/:id/deactivate`
- `POST /api/v1/operations/:id/activate`

Operation categories, recently used operations, Flutter screens, Production Entry submission, and price snapshotting on Production Entries remain deferred.

## Domain Rules

- An Operation belongs to exactly one Tenant.
- An Operation has a Tenant-unique name and an optional Tenant-unique code.
- An Operation's unit is selected at creation from `PIECE`, `METER`, or `PAIR` and is immutable thereafter. This preserves the meaning of historical quantities.
- `unit_price` is a positive integer measured in tiyin. The currency is always `UZS` for the MVP.
- An Operation is active when created. Deactivation is a soft delete; it never removes the Operation, its rate history, or future Production Entry snapshots.
- Each Operation has exactly one current price interval, identified by `effective_to IS NULL`.
- Creating an Operation starts its initial price interval. Changing its price closes the current interval and starts a new one at the same database-sourced timestamp.
- Metadata-only changes do not create a price-history row. No-op requests do not create audit events or price-history rows.
- Every query and mutation is constrained to the authenticated Tenant.

## Architecture

Add an `OperationsModule` as a bounded context separate from IAM and Organization:

- `OperationsController` maps the HTTP API and extracts request metadata.
- `OperationsService` owns catalog use cases, rate-history consistency, and audit-first mutations.
- DTOs validate inputs and reject unknown fields.
- An Operations exception filter maps application errors to the existing error envelope.
- The existing JWT and role guards authenticate and authorize requests.
- `TenantDatabase.withTenant()` remains the only application data-access boundary.

### Database Migration

Create an `operation_unit` PostgreSQL enum and two forced-RLS tables:

- `operations`: UUIDv7 ID, Tenant ID, name, nullable code, unit, current `unit_price`, `UZS` currency, `sort_order`, active state, creator, and timestamps. Tenant-unique constraints enforce names and supplied codes.
- `operation_price_history`: UUIDv7 ID, Tenant ID, Operation ID, price, `UZS` currency, effective interval, changer, and creation timestamp. A partial unique index on `(tenant_id, operation_id)` where `effective_to IS NULL` permits only one current price interval.

The history table has Tenant-scoped foreign keys to its Operation and the User who changed the rate. Both tables enable and force the existing Tenant RLS policy.

Price changes lock the Operation row before reading or changing its current rate interval. The service obtains one timestamp from PostgreSQL with `clock_timestamp()`, closes the active interval using that timestamp, inserts the next interval with the same timestamp, and updates the Operation's current price. This serializes competing price changes and prevents overlapping current rates.

## Authorization

- All authenticated roles may list active Operations.
- Only Directors may create, update, deactivate, or activate Operations.
- Only Directors may request inactive Operations or `ALL` statuses.
- Missing and cross-Tenant Operation IDs return `OPERATION_NOT_FOUND` and do not reveal existence.

## Endpoint Behavior

### List Operations

`GET /operations` accepts optional `status` and `search` query parameters. `status` defaults to `ACTIVE`. Directors may request `ACTIVE`, `INACTIVE`, or `ALL`; other roles receive `FORBIDDEN` when requesting a non-active status. Search matches an Operation's name or code. Results are ordered by `sort_order`, name, and ID.

Each list item contains `id`, `name`, `code`, `unit`, `unit_price`, `currency`, `is_active`, and `sort_order`.

### Create Operation

`POST /operations` accepts:

```json
{
  "name": "Yoqa tikish",
  "code": "COL-SEW",
  "unit": "PIECE",
  "unit_price": 45000,
  "sort_order": 1
}
```

`code` and `sort_order` are optional. The endpoint returns HTTP 201 with the Operation representation. It writes an `OPERATION_CREATED` audit event before inserting the Operation and its first price-history interval in one transaction.

### Update Operation

`PATCH /operations/:id` accepts any non-empty combination of `name`, `code`, `unit_price`, and `sort_order`. It does not accept `unit` or `is_active`.

A price change returns the updated Operation plus `price_changed: true`, `old_price`, `new_price`, and `effective_from`. A metadata-only update returns `price_changed: false`. An unchanged patch returns the current Operation without an audit event. A patch containing a price change writes one `OPERATION_PRICE_CHANGED` event with every changed field; a metadata-only patch writes `OPERATION_UPDATED`.

### Deactivate and Activate Operation

`POST /operations/:id/deactivate` and `POST /operations/:id/activate` are idempotent Director actions. They return `{ "success": true }`. A state transition writes `OPERATION_DEACTIVATED` or `OPERATION_ACTIVATED` before updating the Operation; an already-matching state performs no write and emits no audit event.

## Auditing

Every state-changing mutation inserts an immutable audit event before its related state changes in the same Tenant transaction:

- `OPERATION_CREATED`
- `OPERATION_UPDATED`
- `OPERATION_PRICE_CHANGED`
- `OPERATION_DEACTIVATED`
- `OPERATION_ACTIVATED`

Audit state contains the Operation fields relevant to the action. Price-change state includes both prices and the database-sourced effective timestamp. If any mutation step fails, the transaction rolls back its audit event and all associated catalog changes.

## Errors

Errors use the existing `{ success: false, error: { code, message } }` envelope.

- `OPERATION_NOT_FOUND` (404): absent or cross-Tenant Operation.
- `OPERATION_NAME_ALREADY_EXISTS` (409): name exists in the authenticated Tenant.
- `OPERATION_CODE_ALREADY_EXISTS` (409): supplied code exists in the authenticated Tenant.
- `EMPTY_UPDATE` (400): an Operation patch has no mutable fields.
- `FORBIDDEN` (403): an authenticated role cannot use the endpoint or request inactive Operations.
- Request validation failures, including zero or negative prices, invalid units, and unknown fields, return HTTP 400 before service execution.

## API Contract Alignment

The API contract will describe the delivered catalog endpoints without `category_id`. Operation category management and `GET /operations/recently-used` remain documented as deferred work rather than implemented endpoints.

## Test Seams

Behavior is tested through the public HTTP API and the PostgreSQL isolation boundary.

E2E coverage includes:

- Active-list visibility for every role; Director-only inactive and all-status visibility; search and deterministic ordering.
- Director creation, strict validation, Tenant-unique name and code conflicts, and role denial.
- Metadata patching, price updates, exact price-history interval transitions, immutable-unit rejection, and no-op behavior.
- Idempotent activation and deactivation, audit event contents, and omission of audit events for no-ops.
- Cross-Tenant concealment for reads and mutations.
- Competing price updates on one Operation, proving exactly one current price-history interval remains.

Database integration tests prove forced RLS isolation for reads and writes in both new tables, including the partial current-rate constraint.

## Deferred Work

- Operation categories and category filtering.
- Recently used Operations.
- Flutter catalog management and selection screens.
- Production Entry creation, which snapshots the active Operation's name, code, unit price, and currency.
- Catalog caching and invalidation.
