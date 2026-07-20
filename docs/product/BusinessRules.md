# Business Rules Document
# TexERP — Digital Production Management Platform

---

**Document Version:** 1.0.0  
**Status:** Draft  
**Created:** 2026-07-16  
**Owner:** Product Team  
**Audience:** Backend Engineers, QA, Architects  

> This document is the **authoritative source** for all business logic rules.  
> Every rule listed here MUST be enforced at the **API/service layer** — not only at the UI layer.  
> Frontend validation is a UX convenience; backend enforcement is mandatory.

---

## Table of Contents

1. [Production Record Rules](#1-production-record-rules)
2. [Payroll Rules](#2-payroll-rules)
3. [User & Access Rules](#3-user--access-rules)
4. [Tenant Rules](#4-tenant-rules)
5. [Warehouse Rules](#5-warehouse-rules)
6. [Notification Rules](#6-notification-rules)
7. [Audit Trail Rules](#7-audit-trail-rules)
8. [Data Retention Rules](#8-data-retention-rules)

---

## 1. Production Record Rules

### BR-001 — Back-date Limit
- A worker MAY submit a production record for today or up to **N calendar days in the past**
- **Default N = 3**; configurable per tenant; maximum allowed N = 7
- Records for future dates are **always blocked**
- Enforcement: API compares `record_date` against `now()` in the tenant's configured timezone

### BR-002 — Immutability of Approved Records
- Once a production record reaches status = **APPROVED**, it is immutable
- No user (including the Foreman who approved it) can edit or delete it
- **Exception:** A Director may modify an APPROVED record, subject to:
  - A mandatory reason field (min 10 characters)
  - An immutable audit log entry created BEFORE the modification is applied
  - The record entering a "DIRECTOR_MODIFIED" sub-state (still APPROVED for payroll purposes)

### BR-003 — Rejected Record Handling
- A **REJECTED** record cannot be re-activated or resubmitted by the Worker
- The Foreman may manually create a new corrected record on behalf of the Worker
- The new record is a **separate record**; it references the original rejected record ID in its metadata
- The original rejected record is preserved for audit purposes

### BR-004 — Quantity Validation
- `quantity_submitted` must be a **positive integer** (>= 1)
- Decimal quantities are not allowed (pieces are whole units)
- Zero and negative values must be rejected with HTTP 400
- Maximum quantity per single record: **9,999** (configurable per tenant; prevents data entry typos)

### BR-005 — Foreman Scope
- A Foreman can only READ, APPROVE, REJECT, or COMMENT on records belonging to workers currently assigned to them
- If a worker is reassigned to a different foreman AFTER a record is submitted:
  - The original foreman retains read access to that record (it was submitted while under their supervision)
  - Only the **new** foreman can approve records submitted after the reassignment date
  - The **new** foreman cannot approve records submitted before the reassignment date

### BR-006 — Active Operations Only
- Workers may only submit records for operations with status = **ACTIVE** in the operation catalog
- Deactivated operations are hidden from the worker's operation selection list
- If an operation is deactivated AFTER a record is already submitted (PENDING), the PENDING record is unaffected and the Foreman can still approve it

### BR-007 — Duplicate Detection
- **Definition of duplicate:** same `worker_id` + same `operation_id` + same `record_date`
- When a duplicate is detected on submission:
  - A warning is shown: "You already submitted this operation for this date. Are you sure?"
  - Worker must explicitly confirm to proceed (second submission is allowed — some operations may be split across shifts)
  - The second submission is flagged as `is_duplicate_confirmed = true` in the database for reporting purposes
  - Foreman is shown the duplication flag during approval

### BR-008 — Quantity Correction by Foreman
- When a Foreman corrects a quantity:
  - `quantity_submitted` is preserved (unchanged, permanent record of what the worker entered)
  - `quantity_approved` is set to the corrected value
  - `quantity_correction_reason` is mandatory (min 5 characters)
  - `corrected_by` and `corrected_at` are recorded
- Payroll calculation ALWAYS uses `quantity_approved`, never `quantity_submitted`

### BR-009 — Payroll Inclusion Criteria
- Only records with status = **APPROVED** are included in payroll calculation
- PENDING records: excluded (not yet verified)
- REJECTED records: excluded (not accepted)
- DIRECTOR_MODIFIED records: included (they are still APPROVED)
- Records whose `record_date` falls within the payroll period date range are included

### BR-010 — Price Snapshot
- At the moment a production record is created (PENDING), the system MUST snapshot:
  - `operation_unit_price_at_submission` — the unit price of the operation at that moment
- If the operation's unit price changes later, **the snapshot is used for payroll**, not the current price
- This prevents retroactive price changes from affecting past records

---

## 2. Payroll Rules

### BR-011 — Period Non-Overlap
- Two payroll periods for the same tenant CANNOT have overlapping date ranges
- Enforcement: the API must check for overlap before creating or editing a period
- Error message: "A payroll period already exists that overlaps with the selected dates."

### BR-012 — Finalization Gate — Pending Records
- A payroll period CANNOT be finalized if there are PENDING production records whose `record_date` falls within the period
- The system shows a warning: "X records are still pending approval. Finalize anyway?" (Director must confirm if Accountant proceeds anyway — or wait for foreman to approve all)
- If Accountant proceeds anyway, PENDING records are **excluded** from the finalized payroll (not auto-rejected)

### BR-013 — Finalized Period Immutability
- Once a payroll period is FINALIZED:
  - No production records within the period can be edited (even by Director, unless period is reopened)
  - No bonuses or deductions can be added or changed
  - The calculated payroll amounts are frozen
- **Exception:** A Director can authorize a RE-OPEN of the period (see BR-014)

### BR-014 — Period Re-Opening
- Only a **Director** can authorize re-opening of a FINALIZED period
- Re-opening requires a mandatory reason (min 10 characters)
- Re-opening creates an audit log entry: actor, timestamp, reason
- After re-opening, the period status returns to **DRAFT**; Accountant must recalculate and re-finalize
- Worker notifications are sent: "Payroll for [period] has been revised. Please check your updated amount."

### BR-015 — Advance Deduction
- Salary advances are recorded with: worker_id, amount, date, recorded_by (Accountant)
- Advances are deducted within the same payroll period they are recorded in
- Formula: `final_pay = production_earnings + bonuses - deductions - advances`
- If advances exceed earned amount: `final_pay` may be 0 (not negative); outstanding balance carries to next period
- Workers can see their advance balance at any time

### BR-016 — Price Used in Calculation
- Payroll calculation ALWAYS uses `operation_unit_price_at_submission` (the snapshot taken at record submission time)
- This is a hard rule; the current operation price is irrelevant to past records

### BR-017 — Payroll Period Scope
- Each payroll period belongs to exactly one tenant
- Workers from other tenants are never included
- Production records from outside the period date range are never included

---

## 3. User & Access Rules

### BR-018 — Worker Data Isolation
- A Worker can only see their OWN production records, payroll, history, and statistics
- Any API endpoint returning worker-specific data MUST enforce: `WHERE worker_id = current_user.id`
- Attempting to query another worker's data returns HTTP 404 (not 403, to avoid confirming existence)

### BR-019 — Foreman Assignment — Single Assignment
- A Worker is assigned to **exactly one Foreman** at any point in time
- Assigning a Worker to a new Foreman automatically ends the previous assignment
- Assignment history is preserved in an assignments log table

### BR-020 — Deactivated User Rules
- A deactivated user cannot log in; their JWT is invalidated immediately on deactivation
- Deactivated users' historical data is preserved indefinitely
- A deactivated Foreman's PENDING approvals remain PENDING and are visible to Directors/Accountants
- A Director must reassign the deactivated Foreman's workers before production can resume for those workers

### BR-021 — Phone Number Uniqueness
- Phone numbers must be unique within a tenant (not globally)
- The same phone number CAN exist in two different tenants (different factories)
- Format: stored in E.164 format (+998XXXXXXXXX)
- Phone number changes require OTP verification to the new number

### BR-022 — Single Role Per Tenant
- A user account can have only **one role** within a single tenant
- Multi-role is not supported in V1
- One person holding two roles must have two separate accounts (separate phone numbers)

### BR-023 — Role Assignment Authority
- Only a **Director** can assign or change roles within their tenant
- A Foreman cannot assign roles
- A Super Admin cannot assign roles within a tenant (they can only create the initial Director)

---

## 4. Tenant Rules

### BR-024 — Tenant Data Isolation
- ALL database tables that store tenant-specific data MUST include a `tenant_id` column
- PostgreSQL Row-Level Security (RLS) MUST enforce tenant isolation on ALL such tables
- It is a **critical defect** if any API endpoint returns data from a different tenant
- Isolation must be tested with automated cross-tenant data access tests in the test suite

### BR-025 — Suspension Behavior
- When a tenant is SUSPENDED:
  - All tenant users are immediately unable to log in
  - All active JWT tokens for tenant users are invalidated within 60 seconds (via token blacklist or short expiry)
  - Data is fully preserved and readable by Super Admin
  - Super Admin CAN reactivate the tenant at any time

### BR-026 — Termination & Data Deletion
- When a tenant is TERMINATED:
  - Tenant enters a 30-day grace period (data preserved, users cannot log in)
  - After 30 days: all tenant data is scheduled for deletion
  - Deletion is cascaded: users, records, payroll, inventory, notifications, audit logs
  - A deletion confirmation event is logged at the platform level (immutable)
  - Data export is available to the tenant's Director during the grace period

### BR-027 — User Limit Enforcement
- Tenants on a plan with a user limit cannot add more users than the plan allows
- Attempting to add a user beyond the limit returns an error: "User limit reached. Please upgrade your plan."
- Super Admin can manually grant a temporary limit increase

### BR-028 — Feature Flag Enforcement
- If a module is disabled via feature flag for a tenant:
  - The module's API endpoints return HTTP 403: "This module is not enabled for your account."
  - The module does not appear in the mobile app navigation (server-side config drives app navigation)

---

## 5. Warehouse Rules

### BR-029 — Stock Cannot Go Negative (Hard Block Mode)
- If tenant is configured with hard block mode for warehouse:
  - Issuing materials beyond available stock is blocked
  - API returns HTTP 422: "Insufficient stock. Available: X, Requested: Y."
- If tenant is configured with warning mode:
  - Issuance is allowed; a warning flag is set on the movement record
  - Director receives a push notification about the negative stock event

### BR-030 — Stock Balance Calculation
- Balance is calculated in real-time as: `SUM(receipt_quantities) - SUM(issuance_quantities)` per material per tenant
- Balance is never stored as a cached value in V1 (computed on read)
- V2 may introduce a materialized balance view for performance

### BR-031 — Material Code Uniqueness
- Material codes must be unique within a tenant
- Case-insensitive uniqueness: "FAB-001" and "fab-001" are treated as the same code

---

## 6. Notification Rules

### BR-032 — Notification Delivery SLA
- All push notifications must be delivered within 5 seconds of the triggering event
- If FCM delivery fails, the system must retry up to 3 times with exponential backoff
- Failed notifications are logged; not re-queued indefinitely

### BR-033 — Notification Persistence
- All notifications are stored in the in-app notification table
- Notifications are retained for 90 days; older notifications are archived (not deleted)
- Archived notifications are not shown in the app but are available via export for compliance

### BR-034 — Opt-Out Rules
- Users may opt out of non-critical notifications
- Critical notifications (payroll finalized, account suspended, security alerts) CANNOT be opted out of
- Opt-out settings are per-notification-type, per-user

---

## 7. Audit Trail Rules

### BR-035 — Mandatory Audit Events
The following events MUST generate an audit log entry (immutable, append-only):

| Event | Required Fields |
|-------|----------------|
| Production record created | actor, tenant_id, record_id, worker_id, operation_id, quantity, timestamp |
| Production record approved | actor, record_id, quantity_approved, timestamp |
| Production record rejected | actor, record_id, reason, timestamp |
| Quantity corrected | actor, record_id, old_quantity, new_quantity, reason, timestamp |
| Director override | actor, record_id, old_status, new_status, reason, timestamp |
| Payroll period created | actor, period_id, start_date, end_date, timestamp |
| Payroll finalized | actor, period_id, total_amount, worker_count, timestamp |
| Payroll period reopened | actor, period_id, reason, timestamp |
| Worker deactivated | actor, worker_id, timestamp |
| Role changed | actor, target_user_id, old_role, new_role, timestamp |
| Foreman reassignment | actor, worker_id, old_foreman_id, new_foreman_id, timestamp |
| Tenant suspended | super_admin_id, tenant_id, reason, timestamp |
| Super Admin impersonation | super_admin_id, tenant_id, session_start, session_end |

### BR-036 — Audit Log Immutability
- Audit log entries CANNOT be edited or deleted — ever
- Audit log table must NOT have UPDATE or DELETE permissions for any application role
- Audit logs are append-only
- Audit logs are included in database backups

### BR-037 — Audit Log Retention
- Audit logs are retained for **7 years** minimum (payroll audit requirement)
- Audit logs are not subject to tenant data deletion (they are retained even after tenant termination for legal compliance)

---

## 8. Data Retention Rules

| Data Type | Retention Period | Action After Retention |
|-----------|-----------------|----------------------|
| Production records | 5 years | Archive to cold storage |
| Payroll records | 7 years | Archive to cold storage |
| Audit logs | 7 years | Archive to cold storage |
| Push notifications | 90 days active / 7 years archive | Move to archive table |
| User PII (deactivated users) | 2 years after deactivation | Anonymize (name, phone) |
| Deleted tenant data | 30 days grace + immediate deletion | Permanent delete + log event |
| Session tokens | Expire per JWT TTL; purge expired | Purge expired tokens daily |

---

## Rule Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-07-16 | Product Team | Initial version |

---

*End of Business Rules Document — Version 1.0.0*  
*This document must be reviewed and approved by the Lead Architect before development begins.*
