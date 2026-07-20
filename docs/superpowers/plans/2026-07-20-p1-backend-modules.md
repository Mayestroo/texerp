# P1 Backend Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all P1 backend tasks: Notifications completion (preferences + templates), SMS Gateway (Eskiz.uz), Warehouse Module, Reports Module, Settings Module, Platform/Super Admin Module, Rate Limiting, and Cross-tenant isolation tests.

**Architecture:** NestJS 11 modular monolith with PostgreSQL 17 + RLS, Redis for caching/rate-limiting, BullMQ for background jobs, EventEmitter2 for cross-module domain events. Each bounded context owns its domain rules; cross-module communication uses events only. Platform module uses separate admin DataSource (not tenant-scoped).

**Tech Stack:** NestJS 11, TypeORM (raw SQL via TenantDatabase), PostgreSQL 17, Redis (ioredis), BullMQ, exceljs, firebase-admin, Eskiz.uz SMS API, class-validator/class-transformer.

## Global Constraints

- All tenant-scoped tables MUST include `tenant_id` + RLS policy in the same migration.
- UUIDv7 for all primary keys.
- Money: integer UZS tiyin at API boundary; exact `numeric` internally.
- Modules communicate via domain events (EventEmitter2), never direct service imports.
- Audit: append-only, immutable. `REVOKE UPDATE, DELETE` on financial tables from `texerp_app`.
- Stock balance: computed on read (BR-030), never cached in V1.
- Platform module uses `PlatformDatabase` (admin DataSource), NOT `TenantDatabase`.
- Ubiquitous language: Tenant (not Organization), User (not Account), Production Entry (not Production Record), Foreman Assignment (not Team Membership).

## Implementation Order (blocking graph)

```
[0] Shared domain-event bus + ADRs
        │
        ├─► [16] Rate Limiting (independent, parallel)
        ├─► [11] SMS Gateway (independent, parallel)
        ├─► [14] Settings (foundational for 10, 12)
        │         └─► [10] Notifications (depends on settings config)
        │         └─► [12] Warehouse (depends on stock_negative_mode)
        ├─► [13] Reports (independent, reads production tables)
        ├─► [15] Platform (largest, seeds settings/flags on tenant create)
        └─► [17] Isolation tests (LAST, after all migrations land)
```

## ADRs Filed

| ADR | Decision |
|-----|----------|
| ADR-010 | Domain Event Bus: EventEmitter2 in-process + BullMQ for delivery jobs |
| ADR-011 | Tenant operational config: `tenant_settings` canonical; dual-write `tenants.back_date_window_days` until contract migration |
| ADR-012 | Stock balance: computed on read; no cached `balance_after` column in V1 |
| ADR-013 | Platform / Super Admin: separate `PlatformDatabase` (admin DataSource); `platform_users` table separate from `users` |
| ADR-014 | Notification templates: internal catalog table; no public CRUD in MVP; seeded defaults |
| ADR-015 | Rate limiting: Redis fixed-window counters via custom `ThrottlerGuard` |

## Migration Number Plan

| Migration | Timestamp | Tables / Changes |
|-----------|-----------|------------------|
| CreateNotificationTemplates | `1753300000000` | `notification_templates` + seed rows + resolve function |
| CreateWarehouseTables | `1753400000000` | `materials`, `stock_movements` + RLS + immutability |
| CreateReportExports | `1753500000000` | `report_exports` + RLS |
| CreateTenantSettings | `1753600000000` | `tenant_settings` + RLS + backfill + function update |
| ExpandPlatformTables | `1753700000000` | `subscription_plans`, `tenant_subscriptions`, `tenant_feature_flags`, `platform_users`, `platform_sessions`, expand `tenants` |

---

> **Full schema DDL, API contracts, file structures, and event catalogs are in the architect's design deliverable (task ses_07fd8eb20ffe2Zq98neDkU4N71). Each task below references that design.**

---

## Task 0: Shared Domain Event Bus + ADRs

**Files:**
- Create: `src/shared/events/domain-event.ts`
- Create: `src/shared/events/event-names.ts`
- Create: `src/shared/events/domain-event-publisher.ts`
- Create: `docs/architecture/ADR/ADR-010-domain-event-bus.md` through `ADR-015`
- Modify: `package.json` (add `@nestjs/event-emitter`)
- Modify: `app.module.ts` (import `EventEmitterModule`)

**Interfaces:**
- Produces: `DomainEvent<T>` envelope type, `EventNames` constants, `DomainEventPublisher` injectable service
- All modules consume via `@OnEvent()` decorator from `@nestjs/event-emitter`

### Steps

- [ ] **Step 1: Install @nestjs/event-emitter**

```bash
cd app/backend && npm install @nestjs/event-emitter
```

- [ ] **Step 2: Create domain event envelope type**

```typescript
// src/shared/events/domain-event.ts
export interface DomainEvent<T = Record<string, unknown>> {
  event_id: string;
  event_type: string;
  aggregate_type: string;
  aggregate_id: string;
  tenant_id: string | null;
  actor_id: string;
  actor_role: string;
  occurred_at: string;
  payload: T;
  metadata: {
    correlation_id: string;
    causation_id: string | null;
  };
}
```

- [ ] **Step 3: Create event names catalog**

```typescript
// src/shared/events/event-names.ts
export const EventNames = {
  // Production
  PRODUCTION_ENTRY_CREATED: 'ProductionEntryCreated',
  PRODUCTION_ENTRY_APPROVED: 'ProductionEntryApproved',
  PRODUCTION_ENTRY_REJECTED: 'ProductionEntryRejected',
  PRODUCTION_ENTRY_CORRECTED: 'ProductionEntryCorrected',

  // Payroll
  PAYROLL_FINALIZED: 'PayrollFinalized',
  PAYROLL_REOPENED: 'PayrollPeriodReopened',
  PAYROLL_EXPORT_READY: 'PayrollExportReady',

  // Warehouse
  MATERIAL_RECEIVED: 'MaterialReceived',
  MATERIAL_ISSUED: 'MaterialIssued',
  LOW_STOCK_ALERT: 'LowStockAlert',
  NEGATIVE_STOCK_WARNING: 'NegativeStockWarning',

  // Notifications
  REPORT_EXPORT_READY: 'ReportExportReady',

  // Platform
  TENANT_CREATED: 'TenantCreated',
  TENANT_SUSPENDED: 'TenantSuspended',
  TENANT_REACTIVATED: 'TenantReactivated',
  TENANT_TERMINATED: 'TenantTerminated',
  FEATURE_FLAG_CHANGED: 'FeatureFlagChanged',

  // Settings
  TENANT_SETTINGS_UPDATED: 'TenantSettingsUpdated',

  // IAM
  USER_CREATED: 'UserCreated',
  ACCOUNT_LOCKED: 'AccountLocked',

  // Audit
  IMPERSONATION_SESSION_STARTED: 'ImpersonationSessionStarted',
  IMPERSONATION_SESSION_ENDED: 'ImpersonationSessionEnded',
} as const;
```

- [ ] **Step 4: Create domain event publisher**

```typescript
// src/shared/events/domain-event-publisher.ts
import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { DomainEvent } from './domain-event';
import { uuidv7 } from '../common/uuid';

@Injectable()
export class DomainEventPublisher {
  constructor(private readonly eventEmitter: EventEmitter2) {}

  publish<T>(
    eventType: string,
    aggregateType: string,
    aggregateId: string,
    tenantId: string | null,
    actorId: string,
    actorRole: string,
    payload: T,
    correlationId?: string,
    causationId?: string | null,
  ): void {
    const event: DomainEvent<T> = {
      event_id: uuidv7(),
      event_type: eventType,
      aggregate_type: aggregateType,
      aggregate_id: aggregateId,
      tenant_id: tenantId,
      actor_id: actorId,
      actor_role: actorRole,
      occurred_at: new Date().toISOString(),
      payload,
      metadata: {
        correlation_id: correlationId ?? uuidv7(),
        causation_id: causationId ?? null,
      },
    };
    this.eventEmitter.emit(eventType, event);
  }
}
```

- [ ] **Step 5: Register EventEmitterModule in app.module.ts**

Add `EventEmitterModule.forRoot()` to imports in `app.module.ts`.

- [ ] **Step 6: Run typecheck**

```bash
cd app/backend && npm run typecheck
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add shared domain event bus infrastructure"
```

---

## Tasks 10–17

> **Each task below is implemented by dispatching a coder subagent with the architect's design as the brief. After each coder completion, a reviewer subagent MUST review before moving on.**

> **Task details (schema DDL, API contracts, file structures) are in the architect's deliverable — referenced by each task header. The coder subagent receives the full design context in its brief.**

---

### Task 16: Rate Limiting (ThrottlerGuard per endpoint)

**Architect reference:** §Task 16 — Rate Limiting  
**Files:** See architect's `infrastructure/rate-limit/` file structure  
**Depends on:** Task 0 (event bus not required, but do first for ordering)  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:e2e`

---

### Task 11: SMS Gateway (Eskiz.uz + mock)

**Architect reference:** §Task 11 — SMS Gateway  
**Files:** See architect's `infrastructure/sms/` + `workers/sms-dispatch.worker.ts`  
**Depends on:** Task 0 (queue registration)  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:e2e`

---

### Task 14: Settings Module (Tenant config)

**Architect reference:** §Task 14 — Settings Module  
**Files:** See architect's `modules/settings/` file structure + migration `1753600000000`  
**Depends on:** Task 0  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:integration`, `npm run test:e2e`

---

### Task 10: Notifications Module completion (preferences + templates + event listeners)

**Architect reference:** §Task 10 — Notifications Module completion  
**Files:** Delta to existing `modules/notifications/` + migration `1753300000000`  
**Depends on:** Task 0, Task 14 (settings config)  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:e2e`

---

### Task 13: Reports Module (Production reports + Excel export)

**Architect reference:** §Task 13 — Reports Module  
**Files:** See architect's `modules/reports/` file structure + migration `1753500000000`  
**Depends on:** Task 0  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:e2e`

---

### Task 12: Warehouse Module (Materials, StockMovements, low-stock alerts)

**Architect reference:** §Task 12 — Warehouse Module  
**Files:** See architect's `modules/warehouse/` file structure + migration `1753400000000`  
**Depends on:** Task 0, Task 14 (stock_negative_mode setting)  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:integration`, `npm run test:e2e`

---

### Task 15: Platform/Super Admin Module

**Architect reference:** §Task 15 — Platform/Super Admin Module  
**Files:** See architect's `modules/platform/` file structure + migration `1753700000000`  
**Depends on:** Task 0, Task 14 (settings seeding on tenant create)  
**Quality gates:** `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:e2e`

---

### Task 17: Cross-tenant isolation tests for new modules

**Architect reference:** §Task 17 — Cross-tenant isolation tests  
**Files:** Extend `test/database/tenant-isolation.integration-spec.ts`  
**Depends on:** ALL migrations from tasks 10–15 must be applied  
**Quality gates:** `npm run test:integration`
