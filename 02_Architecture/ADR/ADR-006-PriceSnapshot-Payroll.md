# ADR-006: Price Snapshot vs Real-Time Price Lookup for Payroll

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Product Manager, Database Architect, Domain Expert  
**Category:** Domain / Data Model  

---

## Context

In TexERP, workers are paid piece-rate (per operation completed). Each operation has a unit price (e.g., "Collar Sewing = 450 UZS/piece"). This price can change at any time — the Director or Accountant may update it.

**The question:** When payroll is calculated at month-end, which price should be used for a record submitted 3 weeks ago?

**Option A — Real-time lookup:** Always use the *current* price of the operation when calculating payroll.  
**Option B — Price snapshot:** Capture the price *at the moment of record submission* and store it permanently on the record.

---

## Decision

**Option B — Price Snapshot is chosen.**

At the moment a production record is created, the system captures and permanently stores:
- `unit_price_snapshot` — the operation's unit price at that exact moment
- `currency_snapshot` — the currency at that moment
- `operation_name_snapshot` — the operation name at that moment

Payroll calculation uses `unit_price_snapshot`, never the current price.

---

## Rationale

### Scenario: Why Real-Time Lookup Fails

Consider this sequence:
1. July 1: Worker sews 100 collars @ 450 UZS/piece = 45,000 UZS expected
2. July 15: Director increases price to 600 UZS/piece (new rate for new orders)
3. July 31: Accountant runs payroll

With **real-time lookup**, the worker gets paid: 100 × 600 = 60,000 UZS  
This is wrong — the worker did the work when the rate was 450 UZS.

Alternatively:
1. July 1: Worker sews 200 collars @ 450 UZS/piece = 90,000 UZS expected
2. July 10: Director reduces price to 300 UZS/piece (cost cutting)
3. July 31: Accountant runs payroll

With **real-time lookup**, the worker gets paid: 200 × 300 = 60,000 UZS  
The worker would rightfully dispute this — they submitted work at the agreed rate.

### Legal and Trust Requirements

Payroll is a legally binding agreement. The price at the time of work is the contractually applicable price. Retroactive price changes affecting already-submitted work would:
- Violate worker trust (the primary adoption risk)
- Expose the factory to labor law disputes
- Create audit trail inconsistencies

### Why Not Just Look Up the Historical Price at Query Time?

An alternative to snapshot storage would be to join `production_records` → `operation_price_history` using the `submitted_at` timestamp to find the price that was active at that time.

This is technically equivalent, but:
1. **Performance:** Every payroll calculation query would require a join against `operation_price_history` per record — significantly more complex and slower
2. **Correctness risk:** The join condition (`submitted_at BETWEEN effective_from AND effective_to`) is complex and easy to get wrong (off-by-one second errors, timezone issues)
3. **No `operation_price_history` is needed for the snapshot approach** — `operation_price_history` still exists for audit, but payroll never queries it

**The snapshot on the record is the simplest, most correct, most performant solution.**

---

## What Is Snapshotted

```
On ProductionRecord creation:
  unit_price_snapshot       = operations.unit_price (at this instant)
  currency_snapshot         = operations.currency (at this instant)
  operation_name_snapshot   = operations.name (at this instant)
  operation_code_snapshot   = operations.code (at this instant)
  foreman_id                = worker's current foreman assignment (at this instant)
```

**The `operation_name_snapshot` is important** because if the operation is renamed or deleted later, the payroll slip still shows the meaningful name the worker saw when they submitted.

---

## Payroll Calculation Formula

```
For each worker, for each approved record in the period:
  line_amount = record.quantity_approved × record.unit_price_snapshot

worker_gross_earnings = SUM(line_amount) over all records
worker_final_pay = worker_gross_earnings + bonuses - deductions - advances
```

**The current `operations.unit_price` is never read during payroll calculation.**

---

## Price Change Workflow (Application Layer)

When a Director/Accountant updates an operation's unit price:
1. `operations.unit_price` updated to new value
2. Previous price written to `operation_price_history` with `effective_to = now()`
3. New price written to `operation_price_history` with `effective_from = now()`, `effective_to = NULL`
4. All FUTURE records will snapshot the new price
5. All EXISTING records retain their old snapshot — **untouched**

---

## Consequences

**Positive:**
- Payroll is always calculated at the agreed-upon price — legally and ethically correct
- Simple payroll calculation (no complex historical price joins)
- Performance: payroll query is a simple SUM on `quantity_approved × unit_price_snapshot`
- Worker trust: submitted price cannot be changed retroactively
- Immutable record: snapshot makes each production record self-contained

**Negative:**
- Slightly more data per record (4 additional snapshot columns)
- A denormalization: operation name stored in two places (snapshot + catalog)
- If a price was entered incorrectly (e.g., 4500 instead of 450), fixing it requires a Director override flow — the snapshot cannot be silently corrected

**Risks mitigated:**
- Payroll dispute risk: worker can always see the price their record was calculated at
- Price change affecting historical payroll: structurally impossible

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| Real-time price lookup | Retroactive price changes affect historical records — legally and ethically wrong |
| Historical price join at query time | Complex join logic; performance overhead; correctness risk |
| Versioned operation records | More complex data model; snapshot achieves the same with less complexity |
