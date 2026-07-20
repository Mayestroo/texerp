# Task 2.1 Review Fixes

## What was fixed

### 1. Wrong error code for date out of window (Critical)
- Renamed `RecordDateOutOfRangeError` to `DateOutOfWindowError`.
  - New file: `src/modules/production/application/errors/date-out-of-window.error.ts`
  - Removed old file: `src/modules/production/application/errors/record-date-out-of-range.error.ts`
- Updated all imports in:
  - `src/modules/production/application/production-entries.service.ts`
  - `src/modules/production/presentation/production-exception.filter.ts`
- Changed HTTP error code from `RECORD_DATE_OUT_OF_RANGE` to `DATE_OUT_OF_WINDOW` in `production-exception.filter.ts`.
- Updated E2E test expectation in `test/production-entries.e2e-spec.ts`.

### 2. Concurrent duplicate race returns 500 instead of 409 (Important)
- Wrapped the transactional work in `ProductionEntriesService.create` with a `try/catch`.
- Added `isDuplicateEntryViolation` helper to detect Postgres unique-violation `23505` on the `production_entries_duplicate_check` constraint.
- On detection, re-queried the existing pending entry in a fresh tenant-scoped read and threw `DuplicateEntryError(existingId)` so the filter returns HTTP 409 with `existing_entry_id`.
- Added `mapUniqueViolation` for future unique-constraint mappings, matching the pattern in `OperationsService`.

### 3. Missing `foreman` field in response (Important)
- Extended `OperationEntryView` with `foreman: { id: string; full_name: string } | null`.
- Added `findActiveForeman` helper that joins `foreman_assignments` and `users` for the worker's active assignment.
- Included the foreman object in the `create` response.
- Updated the E2E `EntryView` interface and asserted the foreman in the happy-path test.

## Files changed
- `src/modules/production/application/errors/date-out-of-window.error.ts` (created)
- `src/modules/production/application/errors/record-date-out-of-range.error.ts` (deleted)
- `src/modules/production/application/production-entries.service.ts`
- `src/modules/production/presentation/production-exception.filter.ts`
- `test/production-entries.e2e-spec.ts`

## Test results

```text
$ npm run lint
> texerp-backend@0.1.0 lint
> eslint "{src,test}/**/*.ts"
(pass)

$ npm run typecheck
> texerp-backend@0.1.0 typecheck
> tsc --noEmit
(pass)

$ npm test
> texerp-backend@0.1.0 test
> jest
Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total

$ npm run test:integration
> texerp-backend@0.1.0 test:integration
> jest --config test/jest-integration.json --runInBand
Test Suites: 1 passed, 1 total
Tests:       16 passed, 16 total

$ npm run test:e2e -- production-entries.e2e-spec.ts
> texerp-backend@0.1.0 test:e2e
> jest --config test/jest-e2e.json production-entries.e2e-spec.ts
Test Suites: 1 passed, 1 total
Tests:       8 passed, 8 total
```

## Status
DONE
