# Database

Database implementation follows `02_Architecture/DatabaseArchitecture.md` and the ADRs in `02_Architecture/ADR/`. This folder is the execution guide for PostgreSQL 15+.

## Design Baseline

- Shared database and shared schema for V1/V2.
- Every tenant-scoped table has a non-null `tenant_id`.
- UUIDv7 is used for primary keys.
- A user phone number is globally unique for unambiguous MVP login (ADR-009).
- PostgreSQL Row-Level Security is the final tenant-isolation boundary.
- Financial and operational history is append-only or soft-deleted.
- Monetary values use integer UZS tiyin at API boundaries and exact `numeric` values in calculation queries.
- Historical production and payroll rows retain price, worker, foreman, and operation snapshots.

## Canonical Schema Areas

| Area | Main tables | Owner |
|---|---|---|
| Platform | `tenants`, `subscription_plans`, `tenant_subscriptions`, `tenant_feature_flags` | Platform |
| Identity | `users`, `user_sessions`, `device_tokens` | IAM |
| Organization | `departments`, `foreman_assignments` | Organization |
| Production | `operations`, `operation_price_history`, `production_records`, `production_record_audit_log` | Production |
| Payroll | `payroll_periods`, `payroll_calculations`, `payroll_adjustments`, `advance_payments`, `payroll_exports` | Payroll |
| Warehouse | `materials`, `stock_movements` | Warehouse |
| Notifications | `notifications`, `notification_preferences` | Notifications |
| Audit | `audit_events` | Audit |

## Migration Rules

1. Every schema change is a numbered, forward-only migration.
2. Migrations must be safe to run once and fail clearly on partial application.
3. Destructive changes require a two-release expand/contract migration.
4. New tenant-scoped tables must include `tenant_id`, an RLS policy, and tenant-aware indexes in the same migration.
5. Production, payroll, stock, and audit mutations require integration tests for constraints and audit behavior.
6. Seed data is limited to reference data and local development fixtures; production seeds never contain real personal data.

## Required Database Tests

- Cross-tenant reads, updates, and deletes are denied under the application role.
- Missing tenant context returns no rows and cannot be silently treated as a platform query.
- Duplicate idempotency keys return the original production record.
- Payroll periods cannot overlap within a tenant.
- A finalized payroll period cannot be mutated.
- Stock movements cannot be updated or deleted by the application role.
- Audit events cannot be updated or deleted by the application role.

## Planned Artifacts

- `ERD.md` — simplified entity relationship and ownership map.
- `TableDefinitions.md` — approved DDL conventions and table contracts.
- `RLSPolicies.md` — RLS roles, session context, and policy examples.
- `IndexingStrategy.md` — query-driven index inventory and review process.
- `SeedData.md` — safe reference and development seed data.
- `BackupStrategy.md` — backup, restore, and recovery procedures.
- `Migrations/` — versioned SQL migrations when implementation begins.

## Source of Truth

The architecture document is authoritative for entity shape and tenancy. The API contract is authoritative for serialized types and monetary representation. A migration must not introduce behavior that is absent from both documents without an ADR.
