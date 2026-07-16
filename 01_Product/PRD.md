# Product Requirements Document (PRD)
# TexERP — Digital Production Management Platform for Textile & Garment Factories

---

**Document Version:** 1.0.0  
**Status:** Draft — Pending Review  
**Created:** 2026-07-16  
**Last Updated:** 2026-07-16  
**Owner:** Product Team  
**Audience:** Software Architects, Backend Engineers, Mobile Engineers, QA, Stakeholders  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Problem](#2-business-problem)
3. [Vision](#3-vision)
4. [Goals](#4-goals)
5. [Non-Goals](#5-non-goals)
6. [User Personas](#6-user-personas)
7. [User Roles & Permissions](#7-user-roles--permissions)
8. [Functional Requirements](#8-functional-requirements)
9. [Non-Functional Requirements](#9-non-functional-requirements)
10. [Success Metrics](#10-success-metrics)
11. [Risks](#11-risks)
12. [Assumptions](#12-assumptions)
13. [Business Rules](#13-business-rules)
14. [User Stories](#14-user-stories)
15. [Acceptance Criteria](#15-acceptance-criteria)
16. [Future Roadmap](#16-future-roadmap)
17. [MVP Scope (V1)](#17-mvp-scope-v1)
18. [V2 Scope](#18-v2-scope)
19. [V3 Scope](#19-v3-scope)
20. [Technical Constraints](#20-technical-constraints)
21. [Open Questions](#21-open-questions)
22. [Glossary](#22-glossary)

---

## 1. Executive Summary

**TexERP** is a cloud-based, multi-tenant SaaS platform purpose-built for textile and garment manufacturing factories. The system replaces paper-based production tracking, manual payroll calculation, and siloed Excel workflows with a unified, real-time digital platform.

The primary interface is a **Flutter mobile application** (Android & iOS) used by all factory-floor personnel — workers, foremen, accountants, warehouse staff, and directors. A **lightweight web panel** exists exclusively for the **Super Admin** (software owner) to manage tenants, subscriptions, and system-level configuration.

The MVP focuses on three core modules:
- **Production Tracking** — workers submit work; foremen approve or reject
- **Payroll Calculation** — accountants compute wages from approved production records
- **Basic Reporting** — directors and managers view real-time dashboards

The platform is designed to onboard hundreds of factories as independent tenants with strict data isolation, role-based access control, and subscription management.

---

## 2. Business Problem

### 2.1 Current State

Textile and garment factories in the target market operate production tracking and payroll using entirely manual, paper-based processes:

| Step | Current Method | Problem |
|------|---------------|---------|
| Worker submits work | Handwritten paper record | Illegible, lost, duplicated |
| Foreman verifies | Manual visual check | No audit trail, subjective |
| Accountant enters data | Manual Excel entry | Time-consuming, error-prone |
| Payroll calculated | Manual formula in Excel | Wrong calculations, disputes |
| Reporting | Ad-hoc Excel reports | No real-time, backward-looking only |
| Management oversight | Physical presence or phone | No remote visibility |

### 2.2 Pain Points (Quantified)

- **Human Errors:** Accountants re-enter thousands of rows per month; error rates estimated at 3-8%
- **Time Loss:** Payroll preparation takes 3-7 days per cycle; should take < 4 hours
- **Fake Records:** Workers or foremen can inflate production counts with no digital evidence
- **Duplicate Records:** Same production entry entered multiple times across multiple paper sheets
- **No Real-Time Visibility:** Management cannot see production status without walking the floor
- **Dispute Resolution:** Without an audit trail, worker-foreman disputes have no evidence base
- **Scalability:** As factories grow, manual processes break down completely

### 2.3 Opportunity

The target market (Central Asia, specifically Uzbekistan and surrounding region) has thousands of small-to-medium textile factories that are actively digitizing. There is no dominant, locally-adapted, mobile-first solution in this market. TexERP can capture this whitespace by being:
- Affordable (SaaS subscription)
- Mobile-first (no PC required on the factory floor)
- Uzbek/Russian language-native
- Fast to onboard (< 1 day)

---

## 3. Vision

> **"Every garment factory, regardless of size, can track every unit of production, pay every worker accurately, and give every manager real-time visibility — all from a mobile phone."**

TexERP will become the operating system of the textile factory floor. Within 5 years, the platform will serve 500+ factories across Central Asia and expand into South/Southeast Asia. The system will evolve from production tracking to a full AI-augmented factory management suite, including demand forecasting, quality control, machine health monitoring, and automated compliance reporting.

---

## 4. Goals

### 4.1 Business Goals

| # | Goal | Target |
|---|------|--------|
| BG-01 | Achieve product-market fit in the Uzbekistan market | 20 paying tenants within 6 months of launch |
| BG-02 | Generate recurring SaaS revenue | MRR of $10,000+ by month 12 |
| BG-03 | Expand to 3 countries within 24 months | UZ, KZ, KG markets |
| BG-04 | Build a platform that scales to 500+ tenants | Multi-tenant architecture from day 1 |

### 4.2 Product Goals

| # | Goal | Target |
|---|------|--------|
| PG-01 | Eliminate paper production records | 100% digital submissions at go-live |
| PG-02 | Reduce payroll preparation time | From 3-7 days to < 4 hours |
| PG-03 | Reduce payroll errors | From ~5% error rate to < 0.1% |
| PG-04 | Provide real-time production visibility | Dashboard refresh <= 60 seconds |
| PG-05 | Achieve high mobile adoption | >= 90% of workers actively submitting via app within 30 days |
| PG-06 | Simple onboarding | Factory fully operational on platform within 1 business day |

### 4.3 User Goals

| Role | Goal |
|------|------|
| Worker | Submit work easily, view accurate pay, trust the system |
| Foreman | Approve/reject quickly, monitor team performance |
| Accountant | Generate accurate payroll fast, export to existing systems |
| Director | See factory performance at a glance, anytime, anywhere |
| Super Admin | Manage all tenants efficiently from a web panel |

---

## 5. Non-Goals

The following are explicitly **out of scope** for V1 MVP:

| # | Non-Goal | Rationale |
|---|----------|-----------|
| NG-01 | Full ERP (Finance, Procurement, CRM) | Out of scope; focus on production floor |
| NG-02 | Machine IoT integration | Complex infrastructure; deferred to V3 |
| NG-03 | AI/ML forecasting | Data needed first; deferred to V3 |
| NG-04 | Customer-facing order portal | B2B sales workflow; deferred to V2 |
| NG-05 | HR module (hiring, contracts, leaves) | Deferred to V2 |
| NG-06 | Full accounting/GL module | Factories use separate accounting systems |
| NG-07 | Biometric attendance integration | Hardware dependency; deferred to V2 |
| NG-08 | Desktop app for factory users | Mobile-first; no desktop app planned |
| NG-09 | Offline-first full sync | Partial offline only in V1; full sync V2 |
| NG-10 | Third-party ERP integrations (1C, SAP) | Deferred to V2 |

---

## 6. User Personas

### Persona 1 — Aziz (Worker)
- **Age:** 22
- **Education:** Secondary school
- **Tech literacy:** Low — uses WhatsApp, TikTok
- **Device:** Low-to-mid range Android phone (2-4 GB RAM)
- **Language:** Uzbek
- **Context:** Sewing machine operator, completes 50-200 operations per day
- **Pain:** Does not trust manual payroll calculation; sometimes paid wrong amount
- **Need:** Simple interface to record work and verify own pay
- **Key friction:** Will abandon app if more than 3 taps to submit work

### Persona 2 — Murod (Foreman)
- **Age:** 35
- **Education:** Technical college
- **Tech literacy:** Medium — uses Excel occasionally
- **Device:** Mid-range Android phone
- **Language:** Uzbek/Russian
- **Context:** Manages 15-40 workers; walks the floor all day
- **Pain:** Loses paper records; workers dispute his verification
- **Need:** Quick mobile approvals, team productivity at a glance
- **Key friction:** Needs to approve in bulk; one-by-one is too slow

### Persona 3 — Nilufar (Accountant)
- **Age:** 40
- **Education:** University (Finance/Accounting)
- **Tech literacy:** Medium — experienced Excel user
- **Device:** Android phone + occasional PC
- **Language:** Uzbek/Russian
- **Context:** Handles payroll for 50-300 workers
- **Pain:** Spends a full week every month just entering data and fixing errors
- **Need:** Automatic payroll calculation from approved records; Excel export
- **Key friction:** Must be able to export in familiar format for auditors

### Persona 4 — Sherzod (Director)
- **Age:** 48
- **Education:** University
- **Tech literacy:** Low-medium — prefers visual dashboards
- **Device:** iPhone or high-end Android
- **Language:** Russian/Uzbek
- **Context:** Owns or manages 1-3 factories; rarely on floor
- **Pain:** Cannot see real-time production; relies on end-of-day verbal reports
- **Need:** Real-time KPI dashboard, anywhere, anytime
- **Key friction:** Dashboard must be instantly readable without explanation

### Persona 5 — Warehouse Keeper (Bekzod)
- **Age:** 30
- **Education:** Secondary
- **Tech literacy:** Low
- **Device:** Android phone
- **Language:** Uzbek
- **Context:** Receives fabric rolls, issues cutting bundles to production
- **Pain:** Inventory discrepancies due to paper-based receive/issue records
- **Need:** Simple receive/issue interface with running inventory balance

### Persona 6 — Super Admin (Software Owner)
- **Age:** 28-40
- **Education:** Technical
- **Tech literacy:** High — uses web tools, dashboards
- **Device:** Desktop/Laptop browser
- **Language:** Uzbek/English
- **Context:** Manages the SaaS product itself
- **Need:** Tenant management, subscription billing, feature flags, system health

---

## 7. User Roles & Permissions

### 7.1 Role Hierarchy

```
Super Admin (Platform Level)
    └── Director (Tenant Level)
            ├── Accountant
            ├── Foreman
            │     └── Worker (assigned to Foreman)
            └── Warehouse
```

### 7.2 Permission Matrix

| Permission | Worker | Foreman | Accountant | Warehouse | Director | Super Admin |
|-----------|:------:|:-------:|:----------:|:---------:|:--------:|:-----------:|
| Login (Mobile) | YES | YES | YES | YES | YES | NO |
| Login (Web Panel) | NO | NO | NO | NO | NO | YES |
| Submit production record | YES | NO | NO | NO | NO | NO |
| View own production history | YES | YES | NO | NO | NO | NO |
| View own payroll | YES | YES | NO | NO | NO | NO |
| Approve/reject production | NO | YES | NO | NO | NO | NO |
| Correct production quantity | NO | YES | NO | NO | NO | NO |
| Add comments to records | NO | YES | YES | NO | NO | NO |
| View assigned team records | NO | YES | YES | NO | NO | NO |
| View ALL records (tenant) | NO | NO | YES | NO | YES | NO |
| Calculate payroll | NO | NO | YES | NO | NO | NO |
| Export Excel/PDF | NO | NO | YES | NO | YES | NO |
| Manage payroll periods | NO | NO | YES | NO | NO | NO |
| Receive inventory | NO | NO | NO | YES | NO | NO |
| Issue materials | NO | NO | NO | YES | NO | NO |
| View inventory levels | NO | NO | YES | YES | YES | NO |
| View all dashboards | NO | NO | NO | NO | YES | NO |
| Manage workers (CRUD) | NO | NO | NO | NO | YES | NO |
| Manage foremen | NO | NO | NO | NO | YES | NO |
| Manage operations/rates | NO | NO | YES | NO | YES | NO |
| View tenant KPIs | NO | NO | NO | NO | YES | YES |
| Manage tenants | NO | NO | NO | NO | NO | YES |
| Manage subscriptions | NO | NO | NO | NO | NO | YES |
| Manage plans/pricing | NO | NO | NO | NO | NO | YES |
| Feature flags | NO | NO | NO | NO | NO | YES |
| System configuration | NO | NO | NO | NO | NO | YES |
| Impersonate tenant | NO | NO | NO | NO | NO | YES |

### 7.3 Role Assignment Rules

- A user can have **only one role** per tenant
- A **Director** can assign roles to users within their tenant
- A **Foreman** is linked to a specific set of workers; they can only see records for their assigned workers
- A **Worker** can only see their own records — never another worker's data
- **Super Admin** has no factory role and cannot interact with production data

---

## 8. Functional Requirements

### 8.1 Authentication & Authorization (AUTH)

#### AUTH-001 — Mobile Login
- The system SHALL provide phone number + PIN-based authentication for mobile users
- PIN must be 4-6 digits
- Failed login attempts SHALL be rate-limited: 5 attempts = 15-minute lockout
- A "Forgot PIN" flow SHALL send an OTP to the registered phone number
- Session tokens (JWT) SHALL expire after 24 hours; refresh tokens after 30 days

#### AUTH-002 — Web Panel Login (Super Admin Only)
- Super Admin SHALL authenticate via email + password on the web panel
- Two-Factor Authentication (2FA via TOTP) SHALL be mandatory for Super Admin
- Web session SHALL expire after 8 hours of inactivity

#### AUTH-003 — Multi-Tenancy Isolation
- Every API request SHALL include a tenant identifier (resolved from JWT claims)
- No cross-tenant data access SHALL be possible at the API or database level
- Row-Level Security (RLS) SHALL be enforced at the database layer

#### AUTH-004 — Role-Based Access Control (RBAC)
- All API endpoints SHALL enforce RBAC based on the authenticated user's role
- Frontend navigation SHALL hide/disable features not available to the current role
- Privilege escalation attempts SHALL return HTTP 403 and be logged

---

### 8.2 Tenant & Subscription Management (TENANT)

#### TENANT-001 — Tenant Creation (Super Admin)
- Super Admin SHALL create a new tenant with: company name, legal name, address, contact email, phone, country, timezone, language preference
- Each tenant SHALL receive a unique tenant_id (UUID)
- A unique subdomain SHALL be optionally assignable (e.g., acmefactory.texerp.com)

#### TENANT-002 — Subscription Plans
- Super Admin SHALL define subscription plans with: plan name, price, billing cycle (monthly/annual), feature set, user limit, storage quota
- Plans available: Starter, Professional, Enterprise
- Each tenant SHALL be assigned exactly one active plan at any time

#### TENANT-003 — Subscription Lifecycle
- Super Admin SHALL activate, suspend, or terminate a tenant subscription
- When suspended: all tenant users receive a "Subscription suspended" message on login; data is preserved
- When terminated after grace period (30 days): data is scheduled for deletion

#### TENANT-004 — Feature Flags
- Super Admin SHALL enable/disable specific modules per tenant (e.g., enable Warehouse module for some tenants, not others)
- Feature flags SHALL take effect without app restart (server-side evaluation)

#### TENANT-005 — Tenant Metrics (Super Admin Dashboard)
- Super Admin SHALL view: active tenants, monthly active users per tenant, total production records, subscription revenue, system health metrics

---

### 8.3 User Management (USERS)

#### USERS-001 — Worker Registration
- Director SHALL register new workers with: full name, phone number, role, date of birth (optional), position/job title, assigned foreman
- System SHALL generate a unique worker_code (e.g., W-0042)
- Initial PIN SHALL be auto-generated and communicated verbally or via SMS

#### USERS-002 — User Profile
- All users SHALL view and edit: profile photo, display name, phone number (requires OTP verification to change)
- Workers SHALL NOT be able to change their role or assigned foreman

#### USERS-003 — Worker Deactivation
- Director SHALL deactivate a worker (soft delete); deactivated workers cannot log in
- Historical records of deactivated workers SHALL be preserved

#### USERS-004 — Foreman-Worker Assignment
- Director SHALL assign workers to a foreman
- A worker SHALL be assigned to exactly one foreman at any time
- Reassignment creates an audit log entry

---

### 8.4 Production Module (PROD)

#### PROD-001 — Operation Catalog
- Director/Accountant SHALL maintain an operation catalog: operation name, operation code, unit (pieces/meters/kg), unit price (piece rate), product/order context
- Operations SHALL be activatable/deactivatable
- Example: "Collar Sewing — Polo Shirt, 450 UZS/piece"

#### PROD-002 — Worker Submits Production Record
- Worker SHALL select: date, operation, quantity
- Worker MAY add an optional note (max 280 characters)
- System SHALL auto-fill: worker identity, timestamp, foreman assignment
- Submission creates a record in status = PENDING
- Worker SHALL NOT be able to submit a record for a date more than 3 calendar days in the past (configurable per tenant)
- Worker SHALL NOT edit or delete a submitted record once submitted

#### PROD-003 — Bulk Submission
- Worker SHALL submit multiple operations in one session (one-by-one or a batch list)
- Total batch SHALL not exceed 50 line items per submission session

#### PROD-004 — Foreman Approves/Rejects
- Foreman SHALL see a list of PENDING records for their assigned workers
- Foreman SHALL approve or reject each record
- On Approve: record status = APPROVED; quantity is locked
- On Reject: Foreman MUST provide a rejection reason (from predefined list + optional free text); record status = REJECTED
- Foreman SHALL be able to correct the quantity before approving (quantity_corrected != quantity_submitted); a correction MUST include a mandatory comment
- Foreman SHALL approve/reject in bulk (select multiple records, approve all)
- Once APPROVED, Foreman CANNOT change the record (only Director can override — see PROD-007)

#### PROD-005 — Pending Approval Notifications
- Foreman SHALL receive a push notification when new records are submitted by their workers
- Notification SHALL include: worker name, operation, quantity, date

#### PROD-006 — Worker Sees Status
- Worker SHALL see real-time status of all their submitted records: PENDING / APPROVED / REJECTED
- On rejection, worker SHALL see the foreman's rejection reason
- Worker SHALL NOT resubmit a rejected record directly; they must discuss with foreman who can manually enter a corrected record on their behalf

#### PROD-007 — Director Override
- Director SHALL be able to approve or reject any record, including already-APPROVED records
- Every director override SHALL create an immutable audit log entry: who changed, what changed, when, reason
- This is an exceptional action and SHALL require a mandatory reason input

#### PROD-008 — Production Record Audit Trail
- Every state change on a production record SHALL be logged with: actor, role, timestamp, old value, new value, reason
- Audit logs SHALL be immutable (append-only)
- Audit trail SHALL be viewable by Accountant and Director

#### PROD-009 — Daily Production Summary
- System SHALL automatically calculate and store a daily summary per worker: total operations, total quantity, total earned amount (from approved records only)
- Summary SHALL update in real-time as records are approved

#### PROD-010 — Duplicate Detection
- System SHALL detect and warn if a worker submits the same operation + date combination more than once
- Warning SHALL be shown; submission is blocked unless worker explicitly confirms (as a second operation on the same day is valid in some cases)

---

### 8.5 Payroll Module (PAY)

#### PAY-001 — Payroll Period Management
- Accountant SHALL define payroll periods: start date, end date, period name (e.g., "July 2026 First Half")
- Payroll periods SHALL NOT overlap for the same tenant

#### PAY-002 — Payroll Calculation
- Accountant SHALL trigger payroll calculation for a selected period
- System SHALL aggregate all APPROVED production records within the period for each worker
- Calculation formula: Total Pay = Sum of (quantity_approved × operation_unit_price) per worker
- System SHALL support additional adjustments: bonuses, deductions, advances (manual entries by Accountant)
- Calculation runs in the background; Accountant is notified on completion

#### PAY-003 — Payroll Review
- Accountant SHALL review the calculated payroll before finalizing
- Individual worker payroll breakdown SHALL be viewable: list of operations, quantities, rates, subtotals, adjustments, final amount
- Accountant SHALL edit adjustments (bonuses/deductions) before finalization
- System SHALL prevent editing after payroll is FINALIZED

#### PAY-004 — Payroll Finalization
- Accountant SHALL finalize a payroll period
- Finalization locks all records in the period; no further editing is possible
- Finalized payroll is marked as FINALIZED
- System SHALL send push notifications to each worker with their final payroll amount

#### PAY-005 — Worker Views Own Payroll
- Worker SHALL see their payroll for each finalized period: total amount, breakdown by operation, adjustments
- Worker SHALL NOT see other workers' payroll

#### PAY-006 — Payroll Export
- Accountant SHALL export finalized payroll as:
  - Excel (.xlsx) — columnar format: worker name, worker code, operations, quantities, rates, total
  - PDF — formatted payroll slip per worker OR all workers in one file
- Export SHALL complete within 30 seconds for up to 500 workers

#### PAY-007 — Payroll Period Re-Opening
- Director SHALL authorize re-opening of a FINALIZED payroll period
- Re-opening creates an audit entry
- Only Director can authorize; Accountant executes

#### PAY-008 — Advance Tracking
- Accountant SHALL record salary advances given to workers within a period
- Advances are automatically deducted in the period's final payroll calculation
- Worker shall see their outstanding advance balance

---

### 8.6 Warehouse Module (WARE)

#### WARE-001 — Material Master
- Director/Accountant SHALL maintain a material catalog: material name, code, unit of measure (meters, kg, rolls, pieces), category
- Materials SHALL be activatable/deactivatable

#### WARE-002 — Stock Receipts
- Warehouse user SHALL record incoming materials: material, quantity, supplier name, receipt date, notes, optional photo attachment
- Each receipt creates a positive stock movement

#### WARE-003 — Material Issuance
- Warehouse user SHALL issue materials to production: material, quantity, destination (section/line), date, notes
- Each issuance creates a negative stock movement
- System SHALL prevent issuance if quantity exceeds available stock (configurable: hard block or warning)

#### WARE-004 — Inventory Balance
- System SHALL maintain a real-time inventory balance per material
- Balance = Sum(receipts) minus Sum(issuances)
- Balance viewable by: Warehouse, Accountant, Director

#### WARE-005 — Inventory Report
- System SHALL generate an inventory report: current stock per material, movements by date range, low-stock alerts

#### WARE-006 — Low-Stock Alerts
- System SHALL allow configuring a minimum stock threshold per material
- When stock drops below threshold, push notification is sent to: Warehouse user + Director

---

### 8.7 Reporting & Analytics (REPORT)

#### REPORT-001 — Director Dashboard
- Director SHALL see a real-time dashboard with:
  - Today's total production (units)
  - Today's total earned amount
  - Pending approvals count
  - Worker productivity ranking (top/bottom 5)
  - Production trend chart (last 7/30 days)
  - Payroll summary for current period

#### REPORT-002 — Foreman Dashboard
- Foreman SHALL see:
  - Pending approvals from their team
  - Team production today vs. target (if target is set)
  - Worker-level breakdown

#### REPORT-003 — Production Report (Accountant/Director)
- Filterable by: date range, worker, foreman, operation, status
- Exportable as Excel/PDF
- Shows: submitted qty, approved qty, rejected qty, variance, earned amount

#### REPORT-004 — Payroll Summary Report
- Total payroll by period
- Per-worker payroll history
- Average daily earnings per worker
- Exportable

#### REPORT-005 — Worker Performance Report
- Per-worker productivity trends
- Approval/rejection rates
- Top/bottom performers

#### REPORT-006 — Warehouse Report
- Stock movement by date range
- Current inventory levels
- Consumption rate analysis

---

### 8.8 Notifications (NOTIF)

#### NOTIF-001 — Push Notifications
- System SHALL use FCM (Firebase Cloud Messaging) for push notifications

| Event | Recipient |
|-------|-----------|
| Worker submits record | Foreman |
| Record approved | Worker |
| Record rejected (with reason) | Worker |
| Payroll finalized | Worker |
| Low stock alert | Warehouse + Director |
| Subscription expiring in 7 days | Director |
| Subscription expired | Director |

#### NOTIF-002 — In-App Notification Center
- All notifications SHALL be visible in an in-app notification center
- Notifications SHALL show: timestamp, read/unread status, action link
- Notifications SHALL persist for 90 days

#### NOTIF-003 — Notification Preferences
- Users SHALL opt out of specific notification types (except critical system notifications)

---

### 8.9 Offline Support (OFFLINE)

#### OFFLINE-001 — Offline Production Submission
- Workers SHALL be able to submit production records while offline
- Records are stored locally (SQLite on device) and synced when connectivity is restored
- Sync conflict resolution: server timestamp wins; user is notified if a conflict was detected

#### OFFLINE-002 — Foreman Offline View
- Foreman SHALL be able to view cached pending records while offline
- Approval/rejection SHALL be queued and synced when online

#### OFFLINE-003 — Data Freshness Indicator
- App SHALL display a "Last synced: X minutes ago" indicator when offline

---

### 8.10 Super Admin Web Panel (ADMIN)

#### ADMIN-001 — Tenant Management
- Create, view, update, suspend, terminate tenants
- View tenant details: registration info, plan, user count, storage used, last activity

#### ADMIN-002 — Plan Management
- Create and manage subscription plans
- Update plan features, limits, and pricing
- Plan changes apply to new subscriptions; existing subscriptions use the plan as of their start date

#### ADMIN-003 — System Health Dashboard
- API error rate, response time (P95), database query times
- Active sessions count
- Queue depths (for background jobs)
- Storage usage per tenant

#### ADMIN-004 — Audit Log Viewer
- Super Admin SHALL view system-level audit logs (tenant actions, admin actions)

#### ADMIN-005 — Impersonation (Read-Only)
- Super Admin SHALL be able to view any tenant's data in read-only mode for support purposes
- All impersonation sessions SHALL be logged

---

## 9. Non-Functional Requirements

### 9.1 Performance

| Metric | Requirement |
|--------|-------------|
| API Response Time (P95) | < 500ms for standard queries |
| API Response Time (P99) | < 2000ms for complex aggregations |
| Dashboard Load Time | < 3 seconds on 4G connection |
| Payroll Calculation (500 workers) | < 60 seconds |
| Excel Export (500 workers) | < 30 seconds |
| Push Notification Delivery | < 5 seconds from trigger event |
| App Cold Start | < 3 seconds on mid-range Android |
| Database Write (production record) | < 200ms |

### 9.2 Scalability

| Metric | Requirement |
|--------|-------------|
| Concurrent Users (MVP) | 1,000 simultaneous |
| Concurrent Users (V2) | 10,000 simultaneous |
| Tenants (MVP) | 50 |
| Tenants (V2) | 500 |
| Records per Tenant per Month | Up to 500,000 |
| Total Records (Platform) | Up to 50M records (V2) |

### 9.3 Reliability

| Metric | Requirement |
|--------|-------------|
| Uptime SLA | 99.5% monthly (MVP); 99.9% (V2) |
| Planned Maintenance Window | Sundays 02:00-04:00 UTC |
| RTO (Recovery Time Objective) | < 4 hours |
| RPO (Recovery Point Objective) | < 1 hour |
| Database Backup Frequency | Every 6 hours; 30-day retention |

### 9.4 Security

| Requirement | Detail |
|-------------|--------|
| Data Encryption at Rest | AES-256 |
| Data Encryption in Transit | TLS 1.3 |
| JWT Token Security | RS256 signing; short-lived access tokens (24h) |
| Multi-Tenancy Isolation | Row-Level Security (PostgreSQL RLS) enforced |
| API Rate Limiting | 100 req/min per user; 1000 req/min per tenant |
| PII Protection | Phone numbers, names encrypted at field level |
| SQL Injection Prevention | Parameterized queries / ORM only |
| Audit Logging | All data mutations logged with actor, timestamp |
| OWASP Top 10 | Compliance mandatory before V1 launch |
| Penetration Testing | Required before V1 public launch |

### 9.5 Usability

| Requirement | Detail |
|-------------|--------|
| Target Devices | Android 8.0+; iOS 13+ |
| Minimum Screen Resolution | 360x640px |
| Languages Supported (V1) | Uzbek (primary), Russian |
| Accessibility | WCAG 2.1 AA compliance for text sizing and contrast |
| Onboarding Tutorial | First-time user tutorial (skippable) |
| Error Messages | All errors in user's language, actionable |
| Network Tolerance | App functional on 2G/3G with graceful degradation |

### 9.6 Maintainability

| Requirement | Detail |
|-------------|--------|
| API Versioning | All APIs versioned (e.g., /api/v1/) |
| Code Coverage | Minimum 70% unit test coverage (backend) |
| CI/CD | Automated build, test, and deploy pipeline |
| Monitoring | Centralized logging (ELK or Loki); alerting on error spike |
| Feature Flags | Server-side feature flags for safe rollouts |
| Database Migrations | All schema changes via versioned migration scripts |

### 9.7 Compliance & Legal

- Data residency: Data stored in-region (Uzbekistan or nearest CIS region)
- GDPR-readiness: Right to erasure (for personal data where applicable)
- Data retention: Production records retained for minimum 5 years
- Payroll records: Retained for minimum 7 years (local legal requirement)

---

## 10. Success Metrics

### 10.1 North Star Metric

> **Weekly Active Workers** — the number of unique workers who submit at least one production record per week

### 10.2 Key Performance Indicators (KPIs)

| Category | Metric | V1 Target | V2 Target |
|----------|--------|-----------|-----------|
| Adoption | % Workers submitting daily | >= 80% | >= 95% |
| Adoption | Avg time-to-first-submission (new worker) | < 10 min | < 5 min |
| Quality | Payroll calculation error rate | < 0.1% | < 0.01% |
| Quality | Record rejection rate (foreman) | Baseline TBD | Track trend |
| Efficiency | Payroll preparation time | < 4 hours | < 1 hour |
| Reliability | Platform uptime | 99.5% | 99.9% |
| Business | Paying tenants | 20 @ Month 6 | 100 @ Month 18 |
| Business | MRR | $5K @ Month 6 | $30K @ Month 18 |
| Business | Monthly Churn Rate | < 3% | < 2% |
| Engagement | DAU/MAU ratio per tenant | > 0.6 | > 0.75 |
| Support | Critical bug resolution time | < 24 hours | < 8 hours |

---

## 11. Risks

### 11.1 Risk Register

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R-01 | Low tech literacy among workers — low adoption | High | High | Extreme UI simplicity; mandatory onboarding by factory; in-app tutorial |
| R-02 | Factory management resistance to change | Medium | High | Director-first onboarding; visible ROI dashboard within Day 1 |
| R-03 | Poor internet connectivity on factory floor | High | High | Offline-first submission; sync on connectivity restore |
| R-04 | Workers share login credentials | Medium | Medium | PIN-based auth; device binding (optional V2); foreman awareness training |
| R-05 | Foremen gaming the system (bulk-approving fake work) | Medium | High | Anomaly detection alerts; director audit access; approval time logging |
| R-06 | Multi-tenant data leak due to RLS misconfiguration | Low | Critical | Automated RLS test suite; regular penetration testing |
| R-07 | Payroll calculation bug causing incorrect payments | Low | Critical | Formula unit tests; dual calculation check; accountant review step |
| R-08 | Competitor enters market | Medium | Medium | Fast feature velocity; local language + support as moat |
| R-09 | Tenant churns before ROI demonstrated | Medium | High | Onboarding success team; 30-day active monitoring |
| R-10 | App store rejection (Google/Apple) | Low | Medium | Follow platform guidelines strictly; test before submission |
| R-11 | Server cost overrun at scale | Medium | Medium | Per-tenant resource quotas; auto-scaling with cost alerts |
| R-12 | Key engineer departure | Medium | Medium | Documentation; knowledge sharing; avoid single points of failure |

---

## 12. Assumptions

| # | Assumption |
|---|-----------|
| A-01 | Every worker has a personal Android smartphone (or factory provides shared devices) |
| A-02 | Factory has at least occasional WiFi or mobile data coverage |
| A-03 | The Director or factory admin will drive internal adoption |
| A-04 | Piece-rate is the dominant payment model (per-unit, not hourly) |
| A-05 | Factories operate on a monthly or semi-monthly payroll cycle |
| A-06 | Uzbek and Russian are sufficient for V1; no other languages needed |
| A-07 | Factories have stable operation catalogs (not changing daily) |
| A-08 | A single factory has 10-500 workers in V1 scope |
| A-09 | Super Admin manages billing manually (no automated payment gateway in V1) |
| A-10 | FCM is available and not blocked in target market |
| A-11 | Factories will not require integration with existing ERP in V1 |
| A-12 | Phone numbers are unique per worker (no worker shares a number) |

---

## 13. Business Rules

> See also: BusinessRules.md for the full detailed rule set.

### 13.1 Production Records

| Rule ID | Rule |
|---------|------|
| BR-001 | A production record can only be submitted for dates within the last 3 days (configurable per tenant, max 7 days) |
| BR-002 | Once APPROVED, a production record can only be modified by a Director with mandatory audit logging |
| BR-003 | A REJECTED record cannot be resubmitted by the worker; the foreman must create a corrected entry |
| BR-004 | Quantity submitted must be a positive integer (no decimals, no zero, no negative) |
| BR-005 | A foreman can only view/approve records from workers assigned to them |
| BR-006 | A worker can only submit records for operations that are ACTIVE in the operation catalog |
| BR-007 | Duplicate detection: same worker + same operation + same date — warning shown; second submission blocked unless explicitly confirmed |
| BR-008 | If a foreman corrects a quantity, the corrected quantity is used in payroll (not the submitted quantity) |
| BR-009 | Only APPROVED records are included in payroll calculation (PENDING and REJECTED are excluded) |

### 13.2 Payroll

| Rule ID | Rule |
|---------|------|
| BR-010 | Payroll periods cannot overlap for the same tenant |
| BR-011 | A payroll period cannot be finalized if there are PENDING records within the period (system warns; accountant must confirm or wait for foreman approvals) |
| BR-012 | Once FINALIZED, a payroll period can only be reopened with Director authorization |
| BR-013 | Advances are deducted from the same period they are recorded in |
| BR-014 | Payroll calculation always uses the unit price of the operation as it was at the time of record submission (price changes do not retroactively affect past records) |

### 13.3 Users & Access

| Rule ID | Rule |
|---------|------|
| BR-015 | A worker cannot see any other worker's data — ever |
| BR-016 | A foreman can only see records for their currently assigned workers (historical records of previously-assigned workers remain accessible to the foreman who was assigned at the time of the record) |
| BR-017 | Deactivated users cannot log in; their historical data is preserved |
| BR-018 | Phone numbers must be unique within a tenant |
| BR-019 | A user cannot be assigned two roles simultaneously within the same tenant |

### 13.4 Tenant

| Rule ID | Rule |
|---------|------|
| BR-020 | A suspended tenant's data is preserved for 30 days before deletion |
| BR-021 | Each tenant's data is fully isolated; no cross-tenant queries are permitted at any layer |
| BR-022 | Feature flags are per-tenant; enabling a module for one tenant has no effect on others |
| BR-023 | User limits are enforced per plan; adding users beyond plan limit is blocked (Super Admin can raise limit) |

---

## 14. User Stories

### 14.1 Worker Stories

| ID | Story | Priority |
|----|-------|----------|
| US-W-01 | As a Worker, I want to log in with my phone number and PIN so that I can access the app securely | Must Have |
| US-W-02 | As a Worker, I want to submit my daily production by selecting operation and quantity so that my work is recorded digitally | Must Have |
| US-W-03 | As a Worker, I want to see the status of my submitted records (Pending/Approved/Rejected) so that I know if my work was accepted | Must Have |
| US-W-04 | As a Worker, I want to see the rejection reason when my record is rejected so that I understand why | Must Have |
| US-W-05 | As a Worker, I want to view my production history for any date range so that I can track my own output | Should Have |
| US-W-06 | As a Worker, I want to view my finalized payroll so that I can verify my pay is correct | Must Have |
| US-W-07 | As a Worker, I want to receive a push notification when my record is approved or rejected so that I stay informed | Should Have |
| US-W-08 | As a Worker, I want to submit records even when I have no internet so that connectivity does not stop my workflow | Should Have |
| US-W-09 | As a Worker, I want to see my running total earnings for the current period so that I can estimate my paycheck | Should Have |
| US-W-10 | As a Worker, I want an in-app tutorial on first login so that I understand how to use the app | Must Have |

### 14.2 Foreman Stories

| ID | Story | Priority |
|----|-------|----------|
| US-F-01 | As a Foreman, I want to see all pending records from my workers so that I can review and approve them | Must Have |
| US-F-02 | As a Foreman, I want to approve a production record with one tap so that the approval process is fast | Must Have |
| US-F-03 | As a Foreman, I want to reject a record with a mandatory reason so that the worker understands why | Must Have |
| US-F-04 | As a Foreman, I want to correct a quantity before approving it so that the approved value is accurate | Must Have |
| US-F-05 | As a Foreman, I want to bulk-approve multiple records at once so that I do not have to approve one-by-one | Should Have |
| US-F-06 | As a Foreman, I want to receive a push notification when my workers submit records so that I can approve promptly | Must Have |
| US-F-07 | As a Foreman, I want to see my team's productivity summary for today so that I can track progress | Should Have |
| US-F-08 | As a Foreman, I want to add comments to any record so that I can document context | Should Have |
| US-F-09 | As a Foreman, I want to view a worker's full history for the current period so that I can spot anomalies | Could Have |

### 14.3 Accountant Stories

| ID | Story | Priority |
|----|-------|----------|
| US-A-01 | As an Accountant, I want to create a payroll period so that I can group records for calculation | Must Have |
| US-A-02 | As an Accountant, I want to calculate payroll for a period with one action so that I do not need to do it manually | Must Have |
| US-A-03 | As an Accountant, I want to review the calculated payroll before finalizing so that I can catch errors | Must Have |
| US-A-04 | As an Accountant, I want to add bonuses and deductions to individual worker payrolls so that I can handle exceptions | Must Have |
| US-A-05 | As an Accountant, I want to finalize a payroll period so that it is locked and cannot be changed | Must Have |
| US-A-06 | As an Accountant, I want to export the finalized payroll as Excel so that I can submit to management | Must Have |
| US-A-07 | As an Accountant, I want to export individual payroll slips as PDF so that I can give them to workers | Should Have |
| US-A-08 | As an Accountant, I want to record salary advances so that they are automatically deducted at month end | Should Have |
| US-A-09 | As an Accountant, I want to see all approved records not yet in any payroll period so that nothing is missed | Should Have |
| US-A-10 | As an Accountant, I want to view a production report filtered by foreman, worker, or operation so that I can audit data | Should Have |

### 14.4 Warehouse Stories

| ID | Story | Priority |
|----|-------|----------|
| US-WH-01 | As a Warehouse user, I want to record incoming materials so that stock is updated | Must Have |
| US-WH-02 | As a Warehouse user, I want to record material issuance to production so that consumption is tracked | Must Have |
| US-WH-03 | As a Warehouse user, I want to see current inventory levels so that I know what is in stock | Must Have |
| US-WH-04 | As a Warehouse user, I want to be notified when stock falls below minimum threshold so that I can reorder | Should Have |

### 14.5 Director Stories

| ID | Story | Priority |
|----|-------|----------|
| US-D-01 | As a Director, I want to see a real-time production dashboard so that I know factory performance at a glance | Must Have |
| US-D-02 | As a Director, I want to see today's production vs. target so that I can assess if we are on track | Should Have |
| US-D-03 | As a Director, I want to view worker productivity rankings so that I can identify top and bottom performers | Should Have |
| US-D-04 | As a Director, I want to approve a payroll period re-opening so that corrections can be made | Must Have |
| US-D-05 | As a Director, I want to override any production record with a mandatory reason and audit trail so that I can fix critical errors | Must Have |
| US-D-06 | As a Director, I want to register new workers and assign them to foremen so that I can manage the team | Must Have |
| US-D-07 | As a Director, I want to export any report as Excel or PDF so that I can share with stakeholders | Should Have |

### 14.6 Super Admin Stories

| ID | Story | Priority |
|----|-------|----------|
| US-SA-01 | As Super Admin, I want to create a new tenant so that a new factory can start using the system | Must Have |
| US-SA-02 | As Super Admin, I want to assign a subscription plan to a tenant so that billing is configured | Must Have |
| US-SA-03 | As Super Admin, I want to suspend or terminate a tenant so that I can manage the service lifecycle | Must Have |
| US-SA-04 | As Super Admin, I want to view platform-level health metrics so that I can monitor system performance | Must Have |
| US-SA-05 | As Super Admin, I want to enable/disable specific modules per tenant so that I can offer tiered features | Should Have |
| US-SA-06 | As Super Admin, I want to view a read-only version of any tenant's data for support purposes | Should Have |

---

## 15. Acceptance Criteria

### AC-W-02 — Worker Submits Production Record

**Given** a logged-in Worker on the production submission screen  
**When** they select an operation, enter a valid quantity (positive integer), and tap Submit  
**Then:**
- A production record is created with status = PENDING
- The record appears in the Worker's history list with "Pending" badge
- A push notification is sent to the assigned Foreman within 5 seconds
- The submission screen resets for the next entry
- The submitted date is within the allowed back-date window (3 days by default)

**Edge Cases:**
- If quantity is 0 or negative: validation error shown; record not created
- If operation is inactive: operation does not appear in dropdown
- If same operation + same date exists: duplicate warning shown; second submit blocked

---

### AC-F-04 — Foreman Corrects Quantity

**Given** a Foreman viewing a PENDING record  
**When** they tap "Correct & Approve", enter a new quantity, and provide a mandatory comment  
**Then:**
- Record status = APPROVED
- quantity_approved = corrected value (not original submitted value)
- quantity_submitted is preserved unchanged
- Audit log entry is created: actor = Foreman, action = QUANTITY_CORRECTED, old = submitted qty, new = corrected qty, comment = foreman's comment, timestamp
- Worker sees status = APPROVED with a note "(quantity adjusted)"
- Payroll calculation uses quantity_approved

---

### AC-A-02 — Payroll Calculation

**Given** a finalized payroll period with 100 workers and 3,000 approved records  
**When** Accountant triggers "Calculate Payroll"  
**Then:**
- Background job runs
- Each worker's pay = Sum(quantity_approved × operation_unit_price) + bonuses - deductions
- All records use the unit price as stored AT TIME OF SUBMISSION
- Calculation completes within 60 seconds
- Accountant receives in-app notification: "Payroll calculated. Review before finalizing."
- Records with status not equal to APPROVED are excluded

**Validation:**
- If any operation's unit price is NULL: calculation fails; error message lists affected operations
- Re-running calculation overwrites previous unfinalized draft

---

### AC-TENANT-001 — Tenant Creation

**Given** Super Admin is logged into the web panel  
**When** they fill in company name, legal name, contact email, phone, country, timezone, plan, and submit  
**Then:**
- New tenant record created with a unique UUID
- A Director user account is automatically created (with a generated temporary password sent to contact email)
- Tenant is in ACTIVE status
- Tenant appears in tenant list within 3 seconds
- Feature flags default to the selected plan's defaults

---

### AC-AUTH-001 — Mobile Login Rate Limiting

**Given** a user with valid phone number  
**When** they enter an incorrect PIN 5 times consecutively  
**Then:**
- Account is locked for 15 minutes
- A clear message is shown: "Too many attempts. Try again in 15 minutes."
- Further login attempts during lockout are rejected
- After 15 minutes, login attempts resume normally

---

### AC-OFFLINE-001 — Offline Submission

**Given** a Worker with no internet connection  
**When** they submit a production record  
**Then:**
- Record is stored locally (SQLite)
- UI shows "Saved offline — will sync when connected"
- When connectivity is restored, record syncs to server automatically
- Synced record is created with status = PENDING on server
- Worker is notified: "1 offline record synced"
- If server rejects record on sync (e.g., duplicate), Worker sees an error notification

---

## 16. Future Roadmap

```
2026 Q3    MVP (V1) Launch
            Production Module
            Payroll Module
            Warehouse Module (basic)
            Role-based access
            Super Admin Web Panel

2026 Q4    V1.1 — Stability & Feedback
            Bug fixes from first 20 tenants
            Performance optimizations
            UX improvements based on user feedback

2027 Q1    V2 — Growth Features
            Orders Module (customer orders to production plan)
            Planning Module (production scheduling)
            Attendance Module (manual + QR-based check-in)
            HR Module (employee contracts, leaves)
            Advanced Analytics (charts, trends, benchmarks)
            1C / SAP export adapter
            API for third-party integrations

2027 Q3    V2.5 — Quality & Compliance
            Quality Control Module (defect tracking per batch)
            ISO compliance reports
            Multi-factory dashboard for Directors

2028 Q1    V3 — Intelligence & Scale
            Machine Management (downtime, maintenance)
            IoT Gateway (machine data ingestion)
            AI Demand Forecasting
            AI Production Planning recommendations
            Automated payroll anomaly detection
            Marketplace for integrations
```

---

## 17. MVP Scope (V1)

### Included in V1

| Module | Features |
|--------|---------|
| Authentication | Phone + PIN login; OTP reset; JWT sessions; RBAC; multi-tenancy |
| User Management | Worker/Foreman/Accountant/Warehouse/Director creation; role assignment; deactivation |
| Operation Catalog | Create/edit/deactivate operations with unit prices |
| Production Tracking | Worker submission; Foreman approve/reject/correct; Director override; audit trail |
| Notifications | Push notifications via FCM for production events |
| Payroll | Period management; calculation; adjustments; finalization; worker view; Excel/PDF export |
| Warehouse (Basic) | Receipts; issuance; real-time balance; low-stock alert |
| Dashboards | Director real-time dashboard; Foreman team dashboard; Worker self-stats |
| Reports | Production report; payroll report; warehouse report with filters and export |
| Offline | Worker submission offline; sync on reconnect |
| Super Admin Panel | Tenant CRUD; subscription plans; feature flags; system health; impersonation (read-only) |
| Languages | Uzbek; Russian |

### Not Included in V1 (Deferred)
- Orders Module
- Planning / Scheduling
- Attendance (clock-in/out)
- HR (contracts, leaves)
- IoT / Machine integration
- AI features
- Third-party integrations (1C, SAP)
- Quality Control

---

## 18. V2 Scope

| # | Feature | Description |
|---|---------|-------------|
| V2-01 | Orders Module | Record customer orders (style, quantity, delivery date) linked to production |
| V2-02 | Production Planning | Create daily/weekly production plans per line; track plan vs. actual |
| V2-03 | Attendance Module | QR-code or manual clock-in/out; attendance reports linked to payroll |
| V2-04 | HR Module | Employee contracts, leave management, basic HR records |
| V2-05 | Advanced Analytics | Trend charts, benchmarking, customizable dashboard widgets |
| V2-06 | 1C / Excel Import Adapter | Import workers, operations, and historical data from Excel or 1C |
| V2-07 | Third-party API | Public REST API for tenant data integration |
| V2-08 | Multi-factory | Director manages 2+ factories from a single login |
| V2-09 | Biometric Attendance | Integration with fingerprint attendance hardware |
| V2-10 | Full Offline Sync | Complete offline mode with full CRDT-based conflict resolution |
| V2-11 | Payment Gateway | Automated subscription billing (Stripe or local gateway) |
| V2-12 | Custom Roles | Tenant admins define custom roles beyond 5 base roles |

---

## 19. V3 Scope

| # | Feature | Description |
|---|---------|-------------|
| V3-01 | Machine Management | Machine register; downtime logging; maintenance schedules |
| V3-02 | IoT Gateway | Ingest real-time data from sewing machine counters and sensors |
| V3-03 | AI Demand Forecasting | Forecast order volumes based on historical patterns |
| V3-04 | AI Planning | Auto-generate optimized production plans |
| V3-05 | Quality Control | Defect tracking; inline QC; AQL sampling; reject rate analytics |
| V3-06 | Anomaly Detection | Automatically flag unusual payroll or production patterns |
| V3-07 | Supplier Portal | Supplier-facing web portal for purchase orders and material delivery |
| V3-08 | BI Integration | Native connectors for Power BI, Tableau, Google Data Studio |
| V3-09 | White-label | Platform reselling; custom branding per tenant |
| V3-10 | Marketplace | Third-party plugin marketplace for tenant customizations |

---

## 20. Technical Constraints

### 20.1 Platform

| Constraint | Detail |
|-----------|--------|
| Mobile Primary | Flutter (Dart) — single codebase for Android & iOS |
| Min Android Version | Android 8.0 (API Level 26) |
| Min iOS Version | iOS 13.0 |
| Web (Admin only) | Modern web app; latest 2 versions of Chrome, Firefox, Safari, Edge |
| Backend Language | To be decided by architecture team (recommended: Go or Node.js/NestJS for API; Python for async workers) |
| Database | PostgreSQL 15+ with Row-Level Security |
| Cache | Redis for session store, rate limiting, short-lived caches |
| Message Queue | RabbitMQ or Redis Streams for background jobs (payroll calculation, export generation) |
| Object Storage | S3-compatible (for photo attachments, exports) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Auth | JWT (RS256); OTP via SMS gateway (local UZ provider preferred) |
| Hosting | Cloud-native; Docker + Kubernetes recommended; initial VPS acceptable for MVP |

### 20.2 Multi-Tenancy Architecture

| Aspect | Approach |
|--------|---------|
| Data Isolation | Shared database; schema separation via PostgreSQL Row-Level Security (tenant_id on every table) |
| Tenant Identification | JWT claim tenant_id; all API queries auto-filtered by tenant context |
| Alternative (V2+) | Per-tenant schema isolation for enterprise tenants (optional) |

### 20.3 API Design

| Constraint | Detail |
|-----------|--------|
| Style | RESTful JSON API |
| Versioning | URL path versioning (/api/v1/) |
| Documentation | OpenAPI 3.0 spec auto-generated |
| Auth | Bearer token (JWT) in Authorization header |
| Rate Limiting | Per user and per tenant; headers returned on every response |
| Pagination | Cursor-based pagination for list endpoints |
| Error Format | RFC 7807 (Problem Details for HTTP APIs) |

### 20.4 Mobile Constraints

| Constraint | Detail |
|-----------|--------|
| State Management | Bloc/Cubit pattern (Flutter) |
| Local Storage | SQLite (via sqflite) for offline records |
| Network | Dio HTTP client with retry logic |
| Localization | Flutter intl / flutter_localizations |
| Push | firebase_messaging package |
| Minimum RAM | 2 GB device RAM (app targets) |

---

## 21. Open Questions

| # | Question | Owner | Priority | Status |
|---|---------|-------|----------|--------|
| OQ-01 | What is the exact back-date window for worker submissions? (3 days default — is this correct for all factories?) | Product | High | Open |
| OQ-02 | Should piece rates support decimal values (e.g., 450.5 UZS/piece) or integers only? | Product | High | Open |
| OQ-03 | Is SMS OTP feasible in all target markets? Which SMS provider? (Eskiz.uz? Playmobile?) | Tech | High | Open |
| OQ-04 | What is the billing model — per user, per factory, or flat subscription? | Business | Critical | Open |
| OQ-05 | Are there legal requirements for digital payroll records in Uzbekistan that we must comply with? | Legal | High | Open |
| OQ-06 | Should the app support a "line" or "section" concept below foreman level for large factories (500+ workers)? | Product | Medium | Open |
| OQ-07 | Does the Warehouse module need to track material by batch/lot number in V1? | Product | Medium | Open |
| OQ-08 | What happens to PENDING records at payroll period close? Force-reject? Hold? Alert? | Product | High | Open |
| OQ-09 | Should Directors see payroll amounts per worker, or only totals? | Product | Medium | Open |
| OQ-10 | Is offline support required for Foreman approvals in V1, or only for Worker submissions? | Tech | High | Open |
| OQ-11 | Should the system support multiple currencies (UZS, KZT, KGS) from V1? | Business | High | Open |
| OQ-12 | What is the maximum number of workers per foreman? Should it be enforced? | Product | Low | Open |
| OQ-13 | Is the payment gateway integration in scope for V1 or managed manually by Super Admin? | Business | High | Open |
| OQ-14 | Should worker submissions require geofencing (physically at factory)? | Product | Low | Open |
| OQ-15 | Which cloud provider? (AWS, Google Cloud, local UZ datacenter, or hybrid?) | Tech | High | Open |

---

## 22. Glossary

| Term | Definition |
|------|-----------|
| Tenant | A single factory or company using the platform as an independent, isolated customer |
| Super Admin | The software owner / system operator who manages the SaaS platform itself |
| Director | The highest-privilege user within a tenant; typically the factory owner or general manager |
| Foreman | A supervisor responsible for a group of workers; approves production records |
| Worker | A factory floor employee who submits production records |
| Accountant | A finance role responsible for payroll calculation and reporting |
| Warehouse | A role responsible for receiving materials and issuing them to production |
| Operation | A specific sewing or production task with a defined unit price (e.g., "Collar Sewing — Polo") |
| Operation Catalog | The tenant's master list of all billable operations with their piece rates |
| Production Record | A single submission by a worker: operation + quantity + date |
| Piece Rate | A payment model where workers are paid per unit of work completed |
| Payroll Period | A defined date range for payroll calculation (e.g., 1-15 July 2026) |
| Payroll Finalization | The action of locking a payroll period; no further edits allowed after this |
| PENDING | Status of a production record awaiting foreman review |
| APPROVED | Status of a production record verified and approved by the foreman |
| REJECTED | Status of a production record denied by the foreman, with a reason |
| Quantity Submitted | The quantity as originally entered by the worker |
| Quantity Approved | The quantity as confirmed (or corrected) by the foreman; used in payroll |
| Audit Trail | An immutable, append-only log of all changes to a record: who, what, when, why |
| RLS | Row-Level Security — a PostgreSQL feature used to enforce per-tenant data isolation |
| FCM | Firebase Cloud Messaging — used for push notifications to mobile devices |
| JWT | JSON Web Token — used for stateless authentication |
| OTP | One-Time Password — sent via SMS for PIN reset |
| RBAC | Role-Based Access Control — permissions are assigned to roles, not individuals |
| MVP | Minimum Viable Product — the smallest version of the product with core value |
| MRR | Monthly Recurring Revenue |
| DAU/MAU | Daily Active Users / Monthly Active Users ratio — a measure of engagement |
| CRDT | Conflict-free Replicated Data Type — used for offline sync conflict resolution |
| KPI | Key Performance Indicator |
| SLA | Service Level Agreement |
| RTO | Recovery Time Objective — maximum acceptable downtime |
| RPO | Recovery Point Objective — maximum acceptable data loss |
| OWASP | Open Web Application Security Project — standard web security guidelines |
| AQL | Acceptable Quality Level — a standard for sampling-based quality inspection |

---

*End of PRD — Version 1.0.0*  
*Next Review: Before Architecture Design begins*  
*Document Owner: Product Team*
