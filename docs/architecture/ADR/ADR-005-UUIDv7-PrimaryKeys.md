# ADR-005: UUIDv7 vs UUIDv4 as Primary Key Strategy

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Database Architect  
**Category:** Database Design  

---

## Context

Every table in TexERP uses a UUID primary key. The choice of UUID version has significant impact on:
- **Index performance** (B-tree fragmentation due to random vs sequential inserts)
- **Storage efficiency** (index bloat)
- **Time-correlation** (ability to derive approximate creation order from the ID itself)
- **Privacy** (whether the ID reveals creation timing)
- **Client safety** (IDs exposed to mobile app clients)

Three approaches were evaluated:
1. **Auto-increment integers** (BIGSERIAL)
2. **UUIDv4** (random)
3. **UUIDv7** (time-ordered random)

---

## Decision

**UUIDv7 is chosen as the primary key type for all tables.**

---

## Technical Background

### UUIDv4 (Random)
```
Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
Example: f47ac10b-58cc-4372-a567-0e02b2c3d479
Sortable: No
Time-ordered: No
Index fragmentation: HIGH (random inserts cause B-tree page splits)
```

### UUIDv7 (Time-ordered)
```
Format: 018a1b2c-3d4e-7xxx-yxxx-xxxxxxxxxxxx
Example: 018c4e6b-7f8a-7a3b-b234-56789abcdef0
Sortable: Yes (by time at millisecond precision)
Time-ordered: Yes (monotonically increasing within same millisecond)
Index fragmentation: LOW (sequential-ish inserts, similar to BIGSERIAL)
```

### BIGSERIAL (Auto-increment)
```
Format: 1, 2, 3, ..., 9223372036854775807
Sortable: Yes
Time-ordered: Yes
Index fragmentation: Very Low
Security: UNSAFE (exposes entity count; enumerable by clients)
Multi-node: Requires coordination (sequences are per-node)
```

---

## Comparison

| Criterion | BIGSERIAL | UUIDv4 | UUIDv7 |
|-----------|:---------:|:------:|:------:|
| Global uniqueness | No | Yes | Yes |
| Sequential inserts (index perf.) | Excellent | Poor | Good |
| Index fragmentation | Minimal | High | Low |
| Sortable by creation time | Yes | No | Yes |
| Safe to expose to client | No (enumerable) | Yes | Yes |
| Reveals creation time | Indirectly | No | Yes (ms precision) |
| Multi-node safe | No | Yes | Yes |
| Standard support | Universal | Universal | RFC 9562 (2024) |
| PostgreSQL native support | gen_random_uuid() is v4 | Native | Via extension or app-layer |
| Storage size | 8 bytes | 16 bytes | 16 bytes |

---

## Why Not UUIDv4?

**Index fragmentation is the primary concern.** UUIDv4 generates completely random values. When inserted into a B-tree index (PostgreSQL's default), random values cause page splits at arbitrary positions, leading to:
- High index fragmentation over time
- Increased I/O (pages read per query)
- Larger index size (index bloat due to half-empty pages)

At 390,000 production records per month (per average tenant) × 100 tenants = 39 million inserts/month, this becomes a significant performance issue.

**Benchmark data from PostgreSQL community:**
- UUIDv4: ~40% more I/O than sequential IDs for index inserts
- UUIDv7: ~5% more I/O than sequential IDs (near-sequential due to time prefix)

---

## Why Not BIGSERIAL?

- **Not safe to expose to clients.** API responses include entity IDs. A client seeing `production_records/47382` knows there are approximately 47,382 records before theirs — a data leak.
- **Not globally unique.** Cannot be safely distributed across multiple database nodes without coordination.
- **Enumerable.** Attackers can sequentially try IDs to probe for accessible resources.

---

## UUIDv7 Generation

Since PostgreSQL does not yet have a native `gen_uuid_v7()` function (as of PG15), UUIDv7 is generated in two ways:

1. **Application-layer (primary):** NestJS service generates UUIDv7 using the `uuid7` npm package before inserting rows. This is the default.
2. **Database function (optional):** A PostgreSQL function `gen_uuid_v7()` can be added via extension or PL/pgSQL for cases where the DB must generate IDs (triggers, etc.).

```
UUIDv7 structure:
  [48-bit Unix timestamp ms][4-bit version=7][12-bit random][2-bit variant][62-bit random]
  
This means IDs generated within the same millisecond maintain temporal ordering
and IDs across milliseconds are monotonically ordered.
```

---

## Privacy Consideration

UUIDv7 encodes a millisecond-precision timestamp in the first 48 bits. This means:
- Anyone with the UUID can determine approximately when the record was created
- This is **acceptable** for TexERP because:
  - IDs are only visible to authenticated users within the same tenant
  - Production record creation time is not sensitive information
  - The timestamp precision is milliseconds (not a meaningful privacy concern)

If this becomes a concern in the future, the timestamp bits can be obfuscated using a deterministic encryption layer before exposing to clients.

---

## Implementation

```typescript
// In NestJS entity base class
import { v7 as uuidv7 } from 'uuid';

export abstract class BaseEntity {
  id: string = uuidv7();  // Generated before DB insert
  created_at: Date = new Date();
  updated_at: Date = new Date();
}
```

---

## Consequences

**Positive:**
- Near-sequential inserts reduce B-tree fragmentation (better write performance at scale)
- Global uniqueness across all tenants and future microservices
- Safe to expose to API clients (not enumerable)
- Approximate creation order is derivable (useful for audit log ordering and debugging)

**Negative:**
- UUIDv7 is RFC 9562 (2024) — newer standard; some library support may lag
- 16 bytes vs 8 bytes (BIGSERIAL); at 50M records, this is ~400 MB extra storage (acceptable)
- Application must generate UUIDs (vs database auto-generating them) — slight architectural overhead

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| BIGSERIAL | Enumerable; not globally unique; unsafe to expose to clients |
| UUIDv4 | High index fragmentation at scale; no temporal ordering |
| ULID | Similar to UUIDv7 but less standard; UUID compatibility is preferred |
| Snowflake ID | Requires central ID generator service; operational overhead |
