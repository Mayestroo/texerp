# ADR-004: Multi-Tenant Strategy — Shared Database, Shared Schema

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Database Architect, Product Manager  
**Category:** Multi-Tenancy Architecture  

---

## Context

TexERP is a Multi-Tenant SaaS platform that must serve hundreds of factories as independent customers. Tenant isolation, data security, and operational efficiency must all be balanced.

Three strategies were evaluated:

1. **Shared Database, Shared Schema** — All tenants in one DB, one schema, separated by `tenant_id` + RLS
2. **Shared Database, Separate Schema** — One DB, but each tenant has their own PostgreSQL schema (namespace)
3. **Separate Database** — Each tenant gets their own PostgreSQL database instance

---

## Decision

**Shared Database, Shared Schema with PostgreSQL Row-Level Security (RLS) is chosen for V1 and V2.**

A migration path to Separate Schema for large enterprise tenants is planned for V3.

---

## Detailed Analysis

### Option 1: Shared Database, Shared Schema ✅ CHOSEN

**Implementation:**
- Single PostgreSQL cluster
- All tables have `tenant_id UUID NOT NULL` column
- PostgreSQL RLS policies enforce `tenant_id = current_setting('app.current_tenant_id')`
- NestJS middleware sets the PostgreSQL session variable from JWT claims on each request

**Isolation strength:** Medium (software-level + DB-level RLS)  
**Operations complexity:** Low  
**Cost at 100 tenants:** ~$200–500/month (1 managed PostgreSQL instance)  
**Cost at 1000 tenants:** ~$500–2,000/month (scaled instance or read replicas)

**Risks:**
- RLS misconfiguration could leak data across tenants → **mitigated by:** automated cross-tenant isolation tests on every CI build, code review policy for RLS changes
- Single DB point of failure → **mitigated by:** managed PostgreSQL with read replicas and automated failover

---

### Option 2: Shared Database, Separate Schema

**Implementation:**
- Single PostgreSQL cluster
- Each tenant gets their own schema: `tenant_abc123.production_records`
- Application routes queries to the correct schema using `SET search_path = 'tenant_{id}'`

**Isolation strength:** High  
**Operations complexity:** Medium (schema creation on tenant signup, schema migrations must run N times)  
**Cost:** Similar to Option 1 at 100 tenants; migrations become painful at 1000 tenants  
**Migration complexity:** Running a schema migration for 1000 tenants = 1000 migration executions  

**Why not chosen for V1:** Schema-per-tenant dramatically complicates migrations. At 100+ tenants, deploying a schema change requires running it 100+ times — with the risk that some succeed and some fail, leaving the schema in an inconsistent state.

---

### Option 3: Separate Database per Tenant

**Implementation:**
- Each tenant gets a dedicated PostgreSQL instance (or database in a cluster)
- Complete isolation at the infrastructure level
- Application uses a connection routing layer to connect to the correct DB

**Isolation strength:** Very High  
**Operations complexity:** Very High (100 separate DBs to manage, monitor, backup)  
**Cost at 100 tenants:** ~$5,000–20,000/month (100 separate PostgreSQL instances)  
**Cost at 1000 tenants:** Prohibitive  

**Why not chosen:** The cost model is incompatible with an affordable SaaS product. At $50–200/month per factory subscription, we cannot spend $50–200/month on their database alone.

---

## Comparison Summary

| Criterion | Option 1 (Shared Schema) | Option 2 (Separate Schema) | Option 3 (Separate DB) |
|-----------|:------------------------:|:---------------------------:|:----------------------:|
| Isolation strength | Medium | High | Very High |
| Operational complexity | Low | Medium | Very High |
| Cost @ 100 tenants | Low | Low | Very High |
| Cost @ 1000 tenants | Low-Medium | Medium | Prohibitive |
| Migration complexity | Low (run once) | High (run N times) | Very High |
| Cross-tenant analytics (Super Admin) | Easy | Hard (cross-schema) | Very Hard |
| RLS misconfiguration risk | Present (mitigated) | None | None |
| **Winner for V1–V2** | **✅** | | |
| **V3 Enterprise option** | | ✅ | |

---

## RLS Security Model

```
Application flow for every request:

1. JWT received → middleware extracts tenant_id
2. Database connection acquired from pool
3. SET LOCAL app.current_tenant_id = '<tenant_uuid>'
4. Query executes → RLS automatically filters to tenant
5. Connection returned to pool

RLS Policy:
  CREATE POLICY tenant_isolation ON production_records
  FOR ALL
  TO app_readwrite
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
```

**Critical requirement:** RLS must be enabled on ALL tenant-scoped tables. A test suite runs on every CI build that:
1. Creates two test tenants
2. Seeds data for both
3. Authenticates as Tenant A
4. Attempts to query Tenant B's data directly via the API
5. Asserts that no Tenant B data is returned

---

## V3 Migration Path (Enterprise Isolation)

For very large enterprise customers (e.g., 1000+ workers, SLA requirements), the migration path to Separate Schema is:

1. Super Admin marks tenant as `isolation_level = 'SCHEMA'`
2. Background job: creates `tenant_{id}` schema in the same PostgreSQL cluster
3. Migrates all tenant data to the new schema
4. Updates application routing layer to use `SET search_path = 'tenant_{id}'` for this tenant
5. RLS policies are removed for schema-isolated tenants (schema boundary provides isolation)
6. Old shared-schema rows for this tenant are purged

This migration is transparent to the tenant — they experience zero downtime via a blue-green approach.

---

## Consequences

**Positive:**
- Simple, low-cost operation for 0–500 tenants
- Migrations run once across all tenants (not N times)
- Cross-tenant analytics for Super Admin are straightforward SQL
- Fast tenant onboarding (no schema creation needed)

**Negative:**
- RLS misconfiguration is a critical risk (mitigated by test suite)
- All tenants share the same database performance pool (mitigated by connection pooling and quotas)
- Schema isolation not possible in V1 (acceptable for target market)

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| Separate Schema per tenant | Migration complexity at 100+ tenants; chosen as V3 enterprise option only |
| Separate Database per tenant | Cost prohibitive; operational complexity not viable for SaaS startup |
| Application-layer isolation only (no RLS) | Single layer of defense; unacceptable for a financial system |
