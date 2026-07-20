# ADR-008: Soft Delete Strategy — No Hard Deletes

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Product Manager, Legal Advisor  
**Category:** Data Integrity / Compliance  

---

## Context

In a financial ERP system, "deleting" data is rarely truly deleting it. A worker being "removed" from the system shouldn't erase their payroll records. An operation being "retired" shouldn't invalidate existing production records that reference it.

The question is: **how do we handle entity lifecycle termination without destroying data integrity?**

---

## Decision

**All entities in TexERP use soft delete patterns. Hard deletes are prohibited for all production entities.**

The specific soft delete mechanism varies by entity type:

| Entity Type | Soft Delete Mechanism |
|-------------|----------------------|
| Users | `status = DEACTIVATED` + `deactivated_at` |
| Operations | `is_active = false` |
| Materials | `is_active = false` |
| Payroll Periods | `status = CANCELLED` (DRAFT only) |
| Payroll Adjustments | `deleted_at` timestamp |
| Advance Payments | `deleted_at` timestamp |
| Tenant Feature Flags | Delete allowed (no legal requirement; reversible via re-insert) |
| Notifications | `archived_at` timestamp (after 90 days) |
| Production Records | **Never deactivated** — status transitions only |
| Stock Movements | **Never deactivated** — corrections via new CORRECTION movements |
| Audit Events | **Never deactivated or archived** — legally protected |

---

## Why No Hard Deletes?

### Referential Integrity

A production record references an `operation_id`. If the operation is hard-deleted:
- Foreign key constraint prevents the delete (if FK is enforced) — error
- OR: the production record now has a broken reference — data corruption

With soft delete (`is_active = false`):
- The operation still exists in the database
- The FK reference remains valid
- The production record can display the operation name and price correctly
- The operation snapshot on the record remains meaningful

### Legal Retention

- Payroll records: 7-year legal retention (Uzbek labor law)
- Audit logs: 7-year retention
- Production records: 5-year retention
- **Hard delete = legal non-compliance**

### Dispute Resolution

A worker disputes their payroll 6 months after finalization. With soft delete:
- All records, approvals, corrections, and audit logs are intact
- The exact chain of events can be reconstructed

With hard deletes, any of these could be missing.

### Audit Trail

An immutable audit trail requires that the referenced entities still exist. If a user who approved a production record is hard-deleted, the audit entry "approved_by: user_abc" becomes meaningless — no one can look up who "user_abc" was.

---

## Implementation Per Entity

### Users

```
DEACTIVATED state:
  users.status = 'DEACTIVATED'
  users.deactivated_at = now()
  users.deactivated_by = director_id

Effects:
  - All active sessions revoked immediately
  - User cannot log in
  - Historical records, approvals, and payroll are preserved
  - User appears in reports as "Aziz Karimov (Deactivated)"
  - Foreign key references remain valid

Reactivation:
  - Director sets status = 'ACTIVE'
  - User can log in with existing PIN (or reset it)
```

### Operations

```
DEACTIVATED state:
  operations.is_active = false

Effects:
  - Operation disappears from worker submission dropdown
  - PENDING records referencing this operation remain approvable
  - Payroll calculations use the snapshot price, not the current (deactivated) operation
  - Reports show operation as "(Deactivated)" but values are correct
```

### PII Anonymization (After 2 Years of Deactivation)

For deactivated users who have been inactive for 2 years, GDPR-style anonymization runs:
```
users.full_name = 'Anonymous Worker [worker_code]'
users.phone = 'REDACTED'
users.date_of_birth = NULL
users.avatar_url = NULL

All production records, payroll records, and audit logs:
  - Still reference users.id (FK intact)
  - Display name now shows 'Anonymous Worker W-0042' instead of real name
```

This satisfies right-to-erasure requirements while maintaining financial record integrity.

---

## Exception: What CAN Be Hard-Deleted?

| Entity | Hard Delete Allowed? | Condition |
|--------|---------------------|-----------|
| `tenant_feature_flags` | Yes | Always reversible; no history requirement |
| `notification_preferences` | Yes | User preferences, no legal requirement |
| `device_tokens` | Yes | Replaced on re-registration |
| `user_sessions` (expired) | Yes | Expired sessions; cleaned up by cron job |
| Tenant data (after 30-day grace) | Yes | Super Admin terminates tenant; all data deleted per schedule |
| `payroll_exports` (file links) | Yes | S3 files expire; DB row can be cleaned after 30 days |

---

## Query Patterns for Soft Delete

NestJS services must ALWAYS filter soft-deleted entities:

```typescript
// Correct — excludes deactivated users
findActiveWorkers(tenantId): Promise<User[]> {
  return this.repo.find({
    where: { tenant_id: tenantId, status: 'ACTIVE' }
  });
}

// Correct — foreman sees deactivated workers' historical records
findRecordsByForeman(foremanId, dateRange): Promise<ProductionRecord[]> {
  // Records from deactivated workers are included (worker status not filtered here)
  return this.repo.find({
    where: { foreman_id: foremanId, record_date: Between(dateRange.start, dateRange.end) }
  });
}
```

**Convention:** Any method that should NOT include soft-deleted entities must explicitly filter them. A global scope filter is NOT applied at the ORM level (too many cases where you need to see deactivated entities).

---

## Consequences

**Positive:**
- Legal compliance (retention periods enforced by policy, not by DB constraints)
- Referential integrity maintained (FKs always valid)
- Full audit trail available indefinitely
- Dispute resolution is always possible

**Negative:**
- Queries must always include soft-delete filters (`WHERE status = 'ACTIVE'`, `WHERE is_active = true`)
- Partial index on active entities required for performance
- "Garbage" accumulates in tables over time (mitigated by archiving strategy)
- PII anonymization process must be carefully implemented

**Risks mitigated:**
- Accidental data loss: impossible without a deliberate, authorized multi-step process
- Legal non-compliance: retention is structurally guaranteed
- Referential integrity corruption: impossible (entities always exist as long as referenced)

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| Hard delete all entities | Legal non-compliance; referential integrity corruption risk |
| Cascade hard delete | Destroys financial history; illegal |
| Archive to separate tables on delete | Complicates queries; two places to check for data |
| Foreign key SET NULL on delete | Breaks audit trails (who approved this record? NULL.) |
