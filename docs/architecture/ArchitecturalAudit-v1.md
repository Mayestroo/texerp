# Architectural Audit — Database Architecture v1.0.0
# TexERP

---

**Document Version:** 1.0.0  
**Audit Date:** 2026-07-16  
**Format:** 📄 Design → 🔍 Critical Analysis → 🛠 Recommendation → ✅ Decision  

---

> This document is a structured self-audit of the Database Architecture (DatabaseArchitecture.md v1.0.0).  
> It applies the ERP Architect's critical lens to every major design decision.  
> This is the step between "first draft" and "approved architecture".

---

## Audit Item 1: Is `production_records` a single table or should it be split?

### 📄 Current Design
`production_records` is one wide table with 30+ columns covering: submission data, approval data, rejection data, correction data, director override data, payroll link, offline sync status.

### 🔍 Critical Analysis

**Arguments FOR splitting:**

| Concern | Detail |
|---------|--------|
| Single Responsibility | The table mixes submission concerns, approval concerns, correction concerns, and payroll linking |
| Null proliferation | When status = PENDING, `approved_at`, `approved_by`, `rejected_at`, `rejected_by`, `correction_comment` are all NULL — wasted space |
| Cognitive load | 30+ columns on one table is hard to reason about |

**Arguments AGAINST splitting:**

| Concern | Detail |
|---------|--------|
| Query complexity | If split, every approval status query requires a JOIN — for the highest-frequency query in the system |
| Transaction safety | A single atomic UPDATE handles state transitions cleanly; with split tables, cross-table updates require explicit transactions |
| Performance | The approval queue (Foreman's main screen) fetches thousands of records with status + worker + date — single table is faster |
| The null columns are small | NULL columns in PostgreSQL cost approximately 1 bit per column in the null bitmap — not a meaningful storage concern |

### 🛠 Recommendation

**Keep as one wide table.** The null proliferation is not a meaningful cost in PostgreSQL. The JOIN cost on the highest-frequency query (approval queue) is not worth the "normalization" benefit.

**However:** Add a PostgreSQL partial index strategy:
- `WHERE status = 'PENDING'` — covers approval queue
- `WHERE status = 'APPROVED' AND payroll_period_id IS NULL` — covers unattached approved records
- `WHERE corrected_by IS NOT NULL` — covers correction audit queries

### ✅ Decision: **KEEP single table** with targeted partial indexes.

---

## Audit Item 2: Should `Operation` and `OperationCategory` be separate entities?

### 📄 Current Design
`operations` table has a `category varchar(100)` column. Category is a free-text string (e.g., "Collar Operations", "Sleeve Assembly").

### 🔍 Critical Analysis

**Arguments FOR separate `operation_categories` table:**
- Consistent category names (no typos like "Collar" vs "collar" vs "Collars")
- Category-level reporting (total production per category)
- Category-level unit prices (category default price)
- Hierarchical categories in the future (e.g., Category > Sub-category)

**Arguments AGAINST:**
- A separate table adds a JOIN to every operation query
- Category names are displayed to workers (low-literacy users) — simpler is better
- Unique constraint on category name can enforce consistency without a separate table
- In V1, categories are rarely queried independently

### 🛠 Recommendation

**For V1:** Keep `category` as a `varchar(100)` with a **separate `operation_categories` lookup table** referenced by FK. This enforces consistent naming without requiring a full JOIN on every query (category_id is an integer, fast lookup).

**Revised Design:**
- Add `operation_categories (id SERIAL PK, tenant_id, name, sort_order)`
- `operations.category_id → operation_categories.id` (nullable)
- Director manages categories; workers never see category management

### ✅ Decision: **ADD `operation_categories` table** with FK from `operations`. Simple lookup table; no complex join overhead.

---

## Audit Item 3: Is `Bundle` a missing entity?

### 📄 Current Design
The Business Analysis Document describes bundles (groups of cut pieces) as a core factory concept. The current `production_records` table has no `bundle_id` column.

### 🔍 Critical Analysis

**What is a Bundle?**
- A physical group of 10–50 cut pieces
- Tagged with: bundle number, style, color, size, quantity
- Workers receive a bundle, perform their operation on all pieces, pass to next station
- Bundle tracking enables: loss prevention, WIP tracking, traceability

**Arguments FOR adding Bundle entity in V1:**
- Factories use bundle tracking in real-world operations
- "Production cannot exceed bundle quantity" (BR-002 in Business Analysis) requires a bundle reference
- Without bundles, a worker could submit 500 pieces for an operation when only 100 pieces were in the bundle — no validation possible
- Enables WIP tracking (where is bundle #0042 right now?)

**Arguments AGAINST adding Bundle in V1:**
- Adds significant complexity: factories must create and manage bundles digitally
- In the initial MVP, quantity validation is done by Foreman visual check, not system enforcement
- Bundle management requires Orders module (to know how many pieces per style) — not in V1
- Adding bundles without Orders creates a half-implemented feature

### 🛠 Recommendation

**DEFER Bundle entity to V2.** Add a placeholder column in V1:
- `production_records.bundle_code varchar(50) NULLABLE` — free-text bundle identifier
- Workers can optionally enter their bundle code; no validation applied
- V2: Bundle becomes a first-class entity linked to Orders

This way V1 collects bundle data informally, V2 formalizes it.

### ✅ Decision: **ADD `bundle_code varchar(50) NULLABLE`** to `production_records`. **DEFER full Bundle entity to V2** (when Orders module is available).

---

## Audit Item 4: Payroll — Event-Driven Calculation vs Snapshot Storage

### 📄 Current Design
Payroll calculation produces a `payroll_calculations` table that stores the result (snapshot: `gross_earnings`, `final_pay`, etc.). On recalculation, the row is overwritten (version increment).

### 🔍 Critical Analysis

**Alternative: Event-driven calculation only (no snapshot)**
- `PayrollCalculationService` re-computes from `production_records` on every request
- No `payroll_calculations` table; computation is always live
- Pro: always up-to-date; no stale data
- Con: computation of 500 workers × 50,000 records takes 60 seconds — not acceptable for every view load

**Alternative: Event sourcing for payroll**
- Store every calculation event; current state is derived from replaying events
- Pro: full history of every calculation attempt
- Con: massive complexity for V1; replay time grows with data volume

**Current design analysis:**
- `payroll_calculations` stores the LATEST calculated result per worker per period
- `calculation_version` tracks how many times it was recalculated
- FINALIZED state makes the calculation immutable
- The audit log records who triggered each calculation

**Concern:** When an Accountant makes adjustments and recalculates, the previous draft is overwritten. If they want to compare "what was the payroll before I added this bonus?", they cannot.

### 🛠 Recommendation

**Add calculation history:**
- Keep `payroll_calculations` as the current draft/final snapshot
- Add `payroll_calculation_history (payroll_calculation_id, version, snapshot JSONB, calculated_at, calculated_by)` — stores each version as a JSONB snapshot
- This enables "show me what the payroll looked like before the last recalculation"
- History is append-only; only kept for FINALIZED periods (drafts can be overwritten without history)

### ✅ Decision: **ADD `payroll_calculation_history`** table with JSONB snapshots. Only populated when period transitions to FINALIZED (not for every draft recalculation, which would be excessive).

---

## Audit Item 5: Is the Audit Log a Separate Service or a Table?

### 📄 Current Design
`audit_events` is a PostgreSQL table. The `AuditWriterService` writes to it directly (synchronously, write-before-mutation pattern). The table is in the same PostgreSQL instance as all other data.

### 🔍 Critical Analysis

**Arguments FOR a separate Audit Service (microservice):**
- Decouples audit from the main application
- Could use a specialized audit database (e.g., append-only WORM storage)
- Easier to scale independently
- Could ship audit events to external SIEM systems

**Arguments AGAINST:**
- Adds network latency to every mutation (audit write is synchronous, before-mutation)
- If the audit service is down, should mutations be blocked? (availability vs. auditability trade-off)
- Microservice overhead is premature for V1
- PostgreSQL table with INSERT-only permissions achieves the same immutability guarantee

**The write-before pattern requires synchronous audit write:**
```
If audit service is a separate HTTP service:
  Audit HTTP call → Audit service writes → Main mutation runs
  If audit service is slow: mutation is delayed
  If audit service is down: mutation is blocked (audit-first policy) OR skipped (audit-eventually policy)
  
If audit is a same-DB table:
  Audit INSERT → Mutation UPDATE — atomic in same transaction
  If DB is down: both fail together (consistency guaranteed)
```

**Same-transaction audit is stronger than cross-service audit.** The audit write and the mutation are atomic — there is no window where the mutation succeeds but the audit doesn't.

### 🛠 Recommendation

**Keep `audit_events` as a PostgreSQL table in V1.** In V3, when event sourcing is adopted, the event store naturally becomes the audit source, and can be externalized then.

Add: A nightly job exports audit events to S3 (Parquet format) for long-term archival and SIEM integration. This gives the benefits of external audit log access without the V1 complexity.

### ✅ Decision: **KEEP `audit_events` as a PostgreSQL table.** Add S3 export job for long-term archival.

---

## Audit Item 6: Stock Movement `balance_after` — Trigger vs Application Layer

### 📄 Current Design
`stock_movements.balance_after` stores the running balance after each movement. This is maintained by the application layer (service calculates current balance + new movement = balance_after, then inserts).

### 🔍 Critical Analysis

**Risk:** If two concurrent issuances happen simultaneously:
1. Transaction A reads balance: 100m
2. Transaction B reads balance: 100m
3. Transaction A issues 80m → writes balance_after = 20m
4. Transaction B issues 80m → writes balance_after = 20m (WRONG — should be -60m, but blocked by constraint)

**Solution needed:** Optimistic or pessimistic locking on stock movements.

**Options:**
1. **SELECT FOR UPDATE on material row** — pessimistic lock; guarantees serialized writes
2. **PostgreSQL Advisory Locks** — per-material locks
3. **Optimistic locking with retry** — CAS pattern
4. **SERIALIZABLE transaction isolation** — strongest guarantee, highest overhead
5. **Dedicated `stock_balance` table with FOR UPDATE** — separate balance row locked per material

### 🛠 Recommendation

**Add a `stock_balances` table:**
```
stock_balances (
  material_id PK FK → materials,
  tenant_id NOT NULL,
  current_balance decimal(14,3) NOT NULL DEFAULT 0,
  updated_at timestamptz
)
```

Stock movement workflow:
```
BEGIN TRANSACTION
  SELECT current_balance FROM stock_balances WHERE material_id = $1 FOR UPDATE
  -- Now locked; concurrent transactions wait
  new_balance = current_balance ± quantity
  IF new_balance < 0 AND hard_block_mode THEN RAISE ERROR
  INSERT INTO stock_movements (..., balance_after = new_balance, ...)
  UPDATE stock_balances SET current_balance = new_balance WHERE material_id = $1
COMMIT
```

This guarantees: (1) no race condition on balance, (2) balance_after is always accurate, (3) hard-block constraint is enforced atomically.

### ✅ Decision: **ADD `stock_balances` table** with `SELECT FOR UPDATE` locking pattern. Remove application-layer balance calculation in favor of this atomic approach.

---

## Audit Item 7: `foreman_id` on `production_records` — Snapshot or Live FK?

### 📄 Current Design
`production_records.foreman_id` is a snapshot of the foreman at submission time (stored on the record).

### 🔍 Critical Analysis

**Business Rule (BR-005, BR-082):** A foreman can only approve records from workers assigned to them. If a worker is reassigned, the NEW foreman can only approve records submitted AFTER the reassignment.

**With `foreman_id` snapshot on the record:**
- Each record knows exactly which foreman was responsible at submission time
- New foreman sees new records; old foreman's records stay with old foreman
- This is CORRECT behavior

**Alternative: Always query current assignment:**
- JOIN `production_records` → `foreman_assignments` WHERE `assigned_at < record.submitted_at AND (unassigned_at IS NULL OR unassigned_at > record.submitted_at)`
- This is complex and slow
- Snapshot is simpler and faster

### 🛠 Recommendation

**Keep the `foreman_id` snapshot on `production_records`.** The snapshot IS the correct behavior — it captures accountability at the time of submission. The complex JOIN alternative achieves the same result at higher query cost.

**Add an index:** `(tenant_id, foreman_id, status)` on `production_records` — already in the design; confirm it's implemented as a composite index.

### ✅ Decision: **KEEP `foreman_id` snapshot**. Correct by design.

---

## Summary of Audit Decisions

| # | Audit Item | Decision |
|---|-----------|----------|
| 1 | Split `production_records`? | ❌ Keep single table + partial indexes |
| 2 | `Operation` vs `OperationCategory`? | ✅ Add `operation_categories` lookup table |
| 3 | Bundle entity in V1? | 🔄 Add `bundle_code` nullable field; defer full Bundle to V2 |
| 4 | Payroll calculation history? | ✅ Add `payroll_calculation_history` JSONB table |
| 5 | Audit as separate service? | ❌ Keep as PostgreSQL table; add S3 nightly export |
| 6 | Stock balance concurrency? | ✅ Add `stock_balances` table with SELECT FOR UPDATE |
| 7 | `foreman_id` snapshot? | ✅ Correct by design; keep |

---

## Post-Audit: Updated Architecture Notes

The following changes must be reflected in the next version of `DatabaseArchitecture.md`:

1. Add `operation_categories` table
2. Add `bundle_code varchar(50) NULLABLE` to `production_records`
3. Add `payroll_calculation_history` table
4. Add `stock_balances` table (replaces application-layer balance tracking on `stock_movements`)
5. Document `SELECT FOR UPDATE` locking pattern for stock movements
6. Add S3 nightly audit export job to deployment documentation

---

*End of Architectural Audit — Version 1.0.0*  
*Status: Complete — Changes to be incorporated in DatabaseArchitecture.md v1.1.0*
