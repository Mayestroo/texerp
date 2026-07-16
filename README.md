# TexERP — Digital Production Management Platform

> A multi-tenant SaaS platform for textile and garment factories.  
> Mobile-first. Flutter + PostgreSQL. Built for Central Asia.

---

## Project Overview

TexERP eliminates paper-based production tracking and manual payroll from garment factories. Workers submit work via mobile app. Foremen approve digitally. Accountants calculate payroll in minutes. Directors see everything in real-time.

**Version:** 1.0 (MVP Planning Phase)  
**Status:** Pre-Development — Documentation Baseline Complete  
**Primary Platform:** Flutter Mobile (Android & iOS)  
**Admin Panel:** Web (Super Admin only)  

---

## Repository Structure

```
texerp/
├── 01_Product/
│   ├── PRD.md               ← Full Product Requirements Document (22 sections)
│   ├── Vision.md            ← Product vision, market, strategic pillars
│   └── BusinessRules.md     ← Authoritative business logic rules (37 rules)
│
├── 02_Architecture/
│   └── README.md            ← Architecture documents and ADR index
│
├── 03_Database/
│   └── README.md            ← Database implementation guide
│
├── 04_API/
│   └── README.md            ← API specifications (pending)
│
├── 05_UIUX/
│   └── README.md            ← UX delivery index; canonical specs in 03_UISpec
│
├── 06_Flutter/
│   └── README.md            ← Flutter architecture and delivery guide
│
├── 07_Backend/
│   └── README.md            ← NestJS backend implementation guide
│
├── 08_Deployment/
│   └── README.md            ← Environments, release, and recovery guide
│
└── 09_Docs/
    └── README.md            ← User, support, and operations documentation index
```

---

## User Roles

| Role | Interface | Responsibility |
|------|-----------|---------------|
| Worker | Mobile | Submit production records |
| Foreman | Mobile | Approve/reject/correct records |
| Accountant | Mobile | Calculate and export payroll |
| Warehouse | Mobile | Manage inventory |
| Director | Mobile | Dashboards, oversight, approvals |
| Super Admin | Web Panel | Tenant and platform management |

---

## Core Modules (MVP V1)

- **Authentication** — Phone + PIN, JWT, RBAC, multi-tenancy
- **Production Tracking** — Submit, approve, reject, correct, audit trail
- **Payroll** — Periods, calculation, finalization, Excel/PDF export
- **Warehouse** — Receipts, issuances, real-time inventory
- **Reports & Dashboards** — Role-specific real-time views
- **Notifications** — FCM push + in-app notification center
- **Super Admin Panel** — Tenant/subscription/feature management

---

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| Product Documentation | COMPLETE | PRD, Vision, Business Rules |
| Architecture Design | COMPLETE | System design, DB schema, API spec |
| UI/UX Design | COMPLETE | Screen flows, interaction rules, design system |
| Backend Development | Pending | API, services, background jobs |
| Flutter Development | Pending | Mobile app for all roles |
| QA & Testing | Pending | Unit, integration, UAT |
| Launch (MVP) | Target: 2026 Q3 | First 20 tenants |

---

## Key Documents

- [PRD.md](./01_Product/PRD.md) — Complete product requirements (start here)
- [Vision.md](./01_Product/Vision.md) — Product vision and strategy
- [BusinessRules.md](./01_Product/BusinessRules.md) — All business logic rules (37 rules)
- [BusinessAnalysis.md](./01_Product/BusinessAnalysis.md) — Full domain analysis: 6 workflows, 155 business rules, 100+ edge cases, 10 process diagrams, manufacturing glossary
- [Security](./05_Security/README.md) — Security baseline, threat controls, and release gate

---

## Technology Stack (Planned)

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) |
| Backend API | NestJS or Go (TBD) |
| Database | PostgreSQL 15+ with RLS |
| Cache | Redis |
| Message Queue | BullMQ / Redis Streams |
| Push Notifications | Firebase Cloud Messaging |
| Object Storage | S3-compatible |
| Hosting | Docker + Kubernetes |
| Admin Web Panel | React or Next.js |

---

*TexERP — Making every factory floor digital.*
