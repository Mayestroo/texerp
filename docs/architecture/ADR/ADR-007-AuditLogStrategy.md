# ADR-007: Audit Log Strategy — Dual-Layer Audit Architecture

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Database Architect, Product Manager  
**Category:** Audit / Compliance  

---

## Context

TexERP handles financial data (payroll), personal data (worker identity), and legally required records. The system must maintain an immutable audit trail for:
- Compliance (7-year payroll retention)
- Dispute resolution (who approved what, when, with what quantity)
- Security (who accessed what, when)
- Anomaly detection (rubber-stamp approvals, suspicious submission patterns)

Four approaches were evaluated:
1. **Single global `audit_events` table** — all mutations logged centrally
2. **Domain-specific audit tables** — each module has its own audit log
3. **Dual-layer: domain-specific + global** — both approaches combined
4. **Full Event Sourcing** — audit log IS the source of truth; no separate state tables

---

## Decision

**Dual-Layer Audit Architecture is chosen:**
- **Layer 1:** Domain-specific `production_record_audit_log` — optimized for user-facing queries
- **Layer 2:** Global `audit_events` — comprehensive, cross-aggregate compliance log

Full event sourcing is deferred to V3.

---

## Layer 1: Domain-Specific Audit Log

**Table:** `production_record_audit_log`

**Purpose:** Fast, readable audit trail for production records specifically. Used in the mobile app UI ("Show history of this record").

**Written by:** `ProductionRecordService` directly, synchronously on every state change.

**Structure:**
```
record_id, action, actor_id, actor_role,
old_status, new_status, old_quantity, new_quantity,
reason, occurred_at
```

**Query pattern:**
```sql
SELECT * FROM production_record_audit_log
WHERE record_id = $1
ORDER BY occurred_at ASC;
```
→ Returns the complete, ordered history of a single record in one fast query.

**Why domain-specific?** The global `audit_events` table uses JSONB for before/after state and is optimized for cross-aggregate queries. For "show me the history of this one record" with a readable timeline, a structured domain-specific table with typed columns is faster and simpler to query.

---

## Layer 2: Global Audit Events

**Table:** `audit_events`

**Purpose:** Platform-wide, compliance-grade audit log. Every mutation across all bounded contexts. Used for:
- Super Admin compliance reports
- Cross-aggregate anomaly detection
- Legal discovery (7-year retention)
- Security investigation (who logged in, when, from where)

**Written by:** `AuditWriterService` — called BEFORE every mutation (write-before pattern).

**Structure:**
```
tenant_id, aggregate_type, aggregate_id, action,
actor_id, actor_role, before_state (JSONB), after_state (JSONB),
reason, ip_address, user_agent, occurred_at
```

**Key requirement:** Written BEFORE the mutation — if the mutation fails, the audit entry shows the intent. If the mutation succeeds, the intent is the action. This ensures the audit never misses an attempted change.

**Write-before pattern:**
```
1. AuditWriterService.write({aggregate, action, before_state, actor, reason})
2. COMMIT audit entry
3. Execute mutation (approve, reject, finalize, etc.)
4. COMMIT mutation
5. If mutation fails: audit entry still exists (shows attempted action)
```

---

## Why NOT Full Event Sourcing for V1?

Full Event Sourcing means the `audit_events` (event store) IS the source of truth, and current state is derived by replaying events. This is architecturally elegant but:

| Concern | Event Sourcing | CRUD + Audit Log |
|---------|---------------|-----------------|
| Complexity | Very High | Low-Medium |
| Query current state | Requires projection/read model | Direct table query |
| Time to implement | 3–4 months extra | Included in CRUD |
| Team experience | Very Low | High |
| Debugging | Hard (must replay to understand) | Easy (query current table) |
| V1 timeline impact | Kill the MVP | No impact |

**Event sourcing is planned for V3** when we have:
- Engineering team with ES experience
- Clear need for temporal queries ("what was the state of payroll on July 10 at 2pm?")
- Sufficient data volume where event replay is manageable

**The dual-layer approach is a pragmatic step toward event sourcing** — the `audit_events` table is already an event log. Migrating to full ES in V3 means: (1) make `audit_events` the write source; (2) build CQRS projections for read models.

---

## Immutability Enforcement

```
Database-level enforcement:
  REVOKE UPDATE, DELETE ON audit_events FROM app_readwrite;
  REVOKE UPDATE, DELETE ON production_record_audit_log FROM app_readwrite;
  GRANT INSERT ON audit_events TO app_audit_writer;
  GRANT INSERT ON production_record_audit_log TO app_readwrite;

Application-level enforcement:
  AuditWriterService has no update/delete methods
  Code review policy: any PR touching audit tables is flagged for senior review

Test-level enforcement:
  CI test: attempts UPDATE on audit_events as app_readwrite → must fail
```

---

## Retention and Archiving

| Table | Retention | Archive Trigger | Storage |
|-------|-----------|----------------|---------|
| `production_record_audit_log` | 5 years | Monthly partition archival | S3 Parquet after 2 years |
| `audit_events` | 7 years | Monthly partition archival | S3 Glacier after 2 years |
| Archived audit data | 7 years | Legal hold | S3 Glacier |
| After 7 years | Delete allowed | Legal compliance period ends | Hard delete |

**Exception:** Audit logs for terminated tenants are retained for 7 years after termination, even though the tenant's operational data is deleted.

---

## Consequences

**Positive:**
- Domain log: fast, readable audit queries for user-facing "record history" feature
- Global log: comprehensive compliance and security audit trail
- Immutability enforced at both application and database levels
- Clear path to full event sourcing in V3
- Write-before pattern ensures no mutation goes unaudited

**Negative:**
- Duplication: some events are logged in both tables
- Storage: two audit tables consume more space than one
- Two code paths to maintain (domain writer + global writer)

**Risks mitigated:**
- Audit tampering: DB-level permissions prevent any modification
- Missed events: write-before pattern ensures even failed mutations are recorded
- Legal non-compliance: 7-year retention enforced at storage level

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| Single global audit table only | Slow for user-facing "record history" queries (JSONB filtering overhead) |
| Domain-specific tables only | No cross-aggregate compliance log; harder for Super Admin and legal discovery |
| Full event sourcing (V1) | Complexity too high for MVP timeline; team lacks experience |
| PostgreSQL trigger-based audit | Hard to maintain; doesn't capture application context (actor, reason, IP) |
| Application log files (not DB) | Not queryable; not guaranteed retention; not ACID |
