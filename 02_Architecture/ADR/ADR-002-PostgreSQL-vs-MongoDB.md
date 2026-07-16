# ADR-002: PostgreSQL vs MongoDB as Primary Database

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Database Architect  
**Category:** Data Storage  

---

## Context

TexERP is a financial system at its core. Payroll calculations, production records, and audit trails require:
- **ACID transactions** (payroll finalization must be atomic)
- **Data integrity** (foreign key constraints between workers, operations, records)
- **Complex aggregations** (payroll = sum of records per worker per period)
- **Row-Level Security** (multi-tenant isolation)
- **Immutable audit logs**
- **7-year data retention** with legal compliance

Two primary options were evaluated: **PostgreSQL** and **MongoDB**.

---

## Decision

**PostgreSQL 15+ is chosen as the primary database.**

---

## Rationale

| Criterion | PostgreSQL | MongoDB |
|-----------|-----------|---------|
| ACID Transactions | Full ACID; multi-table transactions | Multi-document transactions supported but less ergonomic |
| Foreign Key Constraints | Native, enforced at DB level | Not supported; application must enforce |
| Row-Level Security (RLS) | Native, built-in | Not available; must be done at application layer |
| Complex Aggregations (SUM, GROUP BY) | Excellent; SQL aggregations are first-class | Aggregation pipeline is powerful but complex |
| JSON/flexible data | JSONB column type (indexed, queryable) | Native document store |
| Schema migrations | Well-tooled (Flyway, Liquibase, Prisma) | Schema-less; migrations are application responsibility |
| Payroll calculation | SQL window functions, SUM, GROUP BY | MongoDB aggregation pipeline |
| Audit log (append-only) | TABLE with INSERT-only permissions | MongoDB oplog or custom collection |
| Multi-tenant RLS | Native RLS policies | Must be enforced at application layer — high risk |
| Data integrity | Enforced at DB level | Application must enforce — error-prone |
| Reporting / Analytics | Excellent with complex JOINs | Aggregation pipeline; less readable |
| Existing team expertise | Strong PostgreSQL knowledge | Limited MongoDB experience |

**The decisive factors:**

1. **Row-Level Security (RLS)** is the architectural foundation of multi-tenancy in TexERP. PostgreSQL's native RLS provides a true database-level safety net. In MongoDB, all tenant isolation must be enforced at the application layer — a single missing `tenant_id` filter is a critical data leak.

2. **ACID transactions for payroll.** Payroll finalization involves: locking the period, committing calculation results, sending notifications — all atomically. PostgreSQL handles this natively.

3. **Foreign key constraints** prevent orphaned records (e.g., a production record referencing a deleted operation). MongoDB has no FK support.

4. **Financial data + 7-year legal retention** is best served by PostgreSQL's proven reliability in financial systems.

---

## JSONB for Flexibility

PostgreSQL's `JSONB` type gives us document-store flexibility where needed (audit `before_state`/`after_state`, notification `data`, `metadata` columns) while keeping structured data fully relational. This eliminates the need for MongoDB in most "schema flexibility" use cases.

---

## Consequences

**Positive:**
- Full ACID guarantees for payroll finalization
- RLS enforces tenant isolation at the database layer (defense in depth)
- Complex reporting queries are straightforward SQL
- PostgreSQL is battle-tested in financial systems
- Rich ecosystem: PgBouncer, pg_partman, pgcrypto, PostGIS (future)

**Negative:**
- Less flexible schema changes require migrations
- Horizontal write scaling is harder than MongoDB (though not needed at our scale)
- JSON handling is powerful but more verbose than MongoDB

**Risks mitigated:**
- Multi-tenant data leak risk is dramatically reduced by database-level RLS
- Data integrity is enforced at the DB level, not just the application layer

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| MongoDB | No RLS, no FK constraints, application-level tenant isolation is a critical security risk |
| MySQL / MariaDB | No RLS, weaker JSON support, less advanced for our use case |
| CockroachDB | PostgreSQL-compatible, but adds operational complexity; not needed at MVP scale |
| Supabase (managed PostgreSQL) | Would accelerate V1 development — remains an option for managed PostgreSQL hosting |
