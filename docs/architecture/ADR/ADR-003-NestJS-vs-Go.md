# ADR-003: NestJS vs Go for Backend API

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Backend Architect  
**Category:** Backend Framework  

---

## Context

TexERP needs a backend API that:
- Serves the Flutter mobile app (REST JSON)
- Serves the Super Admin web panel (REST JSON)
- Handles background jobs (payroll calculation, Excel/PDF export, push notifications)
- Enforces multi-tenant RLS and RBAC
- Is maintainable by a team of 2–4 backend engineers
- Can be built and deployed within 4–5 months for MVP

Two primary options were considered: **NestJS (Node.js / TypeScript)** and **Go (Gin or Fiber)**.

---

## Decision

**NestJS (Node.js / TypeScript) is chosen as the backend framework.**

---

## Rationale

| Criterion | NestJS (TypeScript) | Go (Gin/Fiber) |
|-----------|---------------------|---------------|
| Developer productivity | Very high; decorators, DI, modules | Moderate; more verbose, less abstraction |
| Type safety | Full TypeScript + class-validator | Strong static typing but different paradigm |
| RBAC / Guards | Built-in Guard system; ClaimsGuard, RolesGuard | Manual middleware; no built-in RBAC |
| ORM / Database | TypeORM or Prisma (excellent PostgreSQL support) | GORM (good but less feature-rich) |
| Background jobs | BullMQ + NestJS integration (native package) | Asynq (good but less integrated) |
| Testing | Jest integration; unit + e2e testing built-in | Go's testing package; excellent but more manual |
| Swagger / OpenAPI | @nestjs/swagger auto-generates from decorators | Manual OpenAPI spec or go-swagger |
| Event-driven | @nestjs/event-emitter, BullMQ native | Manual implementation |
| Team expertise | Team has strong TypeScript/NestJS background | Team has no Go experience |
| Time-to-MVP | 4 months | 6–7 months (learning curve) |
| Performance (RPS) | ~10,000–50,000 req/s (sufficient) | ~100,000+ req/s (overkill for V1) |
| Memory usage | Higher (~150 MB per process) | Lower (~20 MB per process) |
| Concurrency model | Event loop (non-blocking I/O) | Goroutines (true parallelism) |
| Hiring | Large Node.js/TypeScript talent pool | Smaller Go pool in target market |

**The decisive factors:**

1. **Team expertise in TypeScript/NestJS** eliminates a 2–3 month learning curve. For a startup MVP, velocity matters more than raw performance.

2. **NestJS's built-in patterns** (Guards for RBAC, Interceptors for tenant isolation, Pipes for validation) map directly to TexERP's requirements. Implementing these in Go would require significant custom code.

3. **BullMQ integration** for background jobs (payroll calculation, export generation) is first-class in the NestJS ecosystem.

4. **Performance is not the bottleneck at MVP scale.** At 50 tenants × 500 workers = 25,000 users, NestJS's performance is more than adequate.

---

## Performance Considerations

At scale (V2: 500 tenants, 50,000 concurrent users), Node.js's single-threaded event loop could become a bottleneck for CPU-intensive operations (payroll calculation for 10,000 workers). This is mitigated by:
- Offloading all CPU-intensive work to BullMQ workers (separate processes)
- Horizontal scaling of API servers (stateless design)
- PostgreSQL doing the heavy aggregation work (not Node.js)

If V3 requires >500,000 concurrent users, a migration to Go or a hybrid architecture (Go for high-performance services, NestJS for CRUD APIs) would be considered at that time.

---

## Consequences

**Positive:**
- Fast development velocity (4-month MVP timeline achievable)
- Rich ecosystem: @nestjs/jwt, @nestjs/bull, @nestjs/swagger, @nestjs/typeorm
- Strong TypeScript types shared between frontend (web admin) and backend
- Large talent pool for hiring

**Negative:**
- Higher memory footprint than Go
- Event loop can be blocked by CPU-intensive operations (mitigated by workers)
- Node.js is less suitable for systems programming (not relevant here)

**Risks mitigated:**
- Performance risk: all CPU-intensive work is in BullMQ workers, not the API server
- Scalability risk: horizontal scaling of stateless NestJS instances is straightforward

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| Go (Gin/Fiber) | No team experience; 2–3 month learning curve kills MVP timeline |
| Django (Python) | Good for rapid dev but less TypeScript alignment; ORM is less suited to complex PostgreSQL features |
| Rails (Ruby) | Same concerns as Django; no team experience |
| Spring Boot (Java) | Heavy; slow startup time; Java verbosity adds development time |
| FastAPI (Python) | Python for ML workers is planned; separating API (TypeScript) and workers (Python) is acceptable as a V2 strategy |
