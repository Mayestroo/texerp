# Task 2.1 — Worker Production Entry Submission

## Status

**DONE**

## Files Created / Modified

### New files

- `src/infrastructure/database/migrations/1752800000000-CreateProductionEntries.ts`
  - Creates `production_entries` table with tenant-isolated composite FKs, snapshot columns, status check, quantity/currency checks, duplicate-detection partial unique index, and pending queue index.
  - Enables and forces RLS with `app.current_tenant_id` policy.
  - Adds a SECURITY DEFINER helper function `production_back_date_window()` so the app role can read the tenant back-date window without direct `tenants` table access.

- `src/modules/production/production.module.ts`
  - Registers controller, service, and exception filter; imports `IamModule` for guards.

- `src/modules/production/application/dto/create-operation-entry.dto.ts`
  - Validates `operation_id` (UUID), `quantity` (int 1–9999), `record_date` (`YYYY-MM-DD`), and optional `worker_note` (max 500).

- `src/modules/production/application/errors/`
  - `operation-not-found.error.ts`
  - `operation-inactive.error.ts`
  - `duplicate-entry.error.ts` (carries `existing_entry_id`)
  - `worker-not-active.error.ts`
  - `record-date-out-of-range.error.ts` (carries `allowed_from`)

- `src/modules/production/application/production-entries.service.ts`
  - Validates active worker and active operation with `FOR UPDATE` locks.
  - Reads tenant back-date window, checks duplicate pending entry, writes `PRODUCTION_ENTRY_CREATED` audit event before inserting the row.
  - Returns `OperationEntryView` with operation snapshot and price snapshot.

- `src/modules/production/presentation/production-entries.controller.ts`
  - `POST /api/v1/production/entries`, role-restricted to `WORKER`, returns 201.

- `src/modules/production/presentation/production-exception.filter.ts`
  - Maps domain errors to stable envelopes: `OPERATION_NOT_FOUND` (404), `OPERATION_INACTIVE` (400), `DUPLICATE_ENTRY` (409 + `existing_entry_id`), `WORKER_NOT_ACTIVE` (400), `RECORD_DATE_OUT_OF_RANGE` (400 + `allowed_from`).

- `test/production-entries.e2e-spec.ts`
  - End-to-end tests covering successful creation, price snapshot capture, duplicate 409, inactive operation, invalid date format, role-based 403, cross-tenant 404, and back-date-window 400.

### Modified files

- `src/app.module.ts`
  - Imported and registered `ProductionModule`.

## Commands Run

```bash
npm run lint
npm run typecheck
npm run migration:run
npm run test:e2e -- production-entries.e2e-spec.ts
npm test
npm run test:integration
```

## Test Results

### Lint

```
> texerp-backend@0.1.0 lint
> eslint "{src,test}/**/*.ts"

(no output — success)
```

### Type check

```
> texerp-backend@0.1.0 typecheck
> tsc --noEmit

(no output — success)
```

### Migrations

```
> texerp-backend@0.1.0 migration:run
> typeorm-ts-node-commonjs migration:run -d src/infrastructure/database/data-source.ts

Migration CreateProductionEntries1752800000000 has been executed successfully.
```

### Production Entries E2E

```
> texerp-backend@0.1.0 test:e2e
> jest --config test/jest-e2e.json production-entries.e2e-spec.ts

Test Suites: 1 passed, 1 total
Tests:       8 passed, 8 total
```

### Unit tests

```
> texerp-backend@0.1.0 test
> jest

Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total
```

### Integration tests

```
> texerp-backend@0.1.0 test:integration
> jest --config test/jest-integration.json --runInBand

Test Suites: 1 passed, 1 total
Tests:       16 passed, 16 total
```

## Notes

- The back-date window is read from `tenants.back_date_window_days` via a SECURITY DEFINER function to preserve the existing permission model where `texerp_app` does not have direct `tenants` table access.
- Audit-before-mutation is enforced: the `PRODUCTION_ENTRY_CREATED` audit event is inserted before the `production_entries` row in the same transaction.
- Price snapshots are captured at submission time so future operation changes do not affect historical records.
- Cross-tenant operation IDs are rejected as `OPERATION_NOT_FOUND` because RLS + the tenant-scoped query cannot see them.
