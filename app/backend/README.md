# Backend

TexERP backend is a NestJS modular monolith. It exposes the REST contract in `04_API/APIContract.md` and implements the boundaries in `02_Architecture/ArchitectureBlueprint.md`.

## Runtime Components

- NestJS HTTP application.
- PostgreSQL 15+ with RLS and versioned migrations.
- Redis for cache, rate limiting, sessions, and BullMQ queues.
- S3-compatible object storage for private exports and images.
- FCM and SMS adapters behind infrastructure interfaces.
- Prometheus/Grafana, Sentry, and structured JSON logs.

## Module Ownership

`platform`, `iam`, `organization`, `production`, `payroll`, `warehouse`, `notifications`, `reports`, `audit`, `settings`, and `subscription` are bounded modules. A module owns its domain rules and repositories. Cross-module behavior uses domain events or dedicated read models, never another module's repository.

## Request Flow

```text
HTTP request
  -> request ID and logging
  -> JWT and tenant guards
  -> DTO validation and sanitization
  -> application use case
  -> domain aggregate and invariants
  -> audit-before-mutation transaction
  -> repository commit
  -> domain event / background job
  -> API response envelope
```

## Implementation Rules

- Controllers translate HTTP to commands and never contain business logic.
- Use cases throw domain/application exceptions, not HTTP exceptions.
- Repositories accept explicit tenant context; raw cross-tenant queries are prohibited.
- Financial values use integer tiyin at the API boundary and exact arithmetic internally.
- Queue jobs are idempotent, retryable, observable, and have dead-letter handling.
- Every mutation has an audit action and a corresponding authorization test.
- Every endpoint has contract tests against the API examples.

## Local Development

1. Run `npm install`.
2. Start PostgreSQL and Redis with `docker compose up -d --wait`.
3. Copy `.env.example` to a local, untracked `.env` file.
4. Run `npm run migration:run` with `DATABASE_ADMIN_URL` configured.
5. Start the API with `npm run start:dev`.
6. Open `http://localhost:3000/api/v1/health` to verify the process.

Use the non-superuser `DATABASE_URL` for the application. `DATABASE_ADMIN_URL` is only for migrations; using it at runtime bypasses PostgreSQL RLS.

## Implemented Foundation

- NestJS 11 bootstrap with validated environment configuration.
- Helmet security headers and strict DTO validation defaults.
- PostgreSQL 17 and Redis 7 local containers.
- Initial tenant, user, department, foreman assignment, session, and audit schema.
- Forced RLS policies and a separate least-privilege application database role.
- Unit, HTTP e2e, and cross-tenant database integration tests.
- RS256 phone/PIN login, lockout, refresh rotation, and logout.

## Quality Gates

- Formatting and linting.
- Type checking and migration validation.
- Domain unit tests.
- Repository and RLS integration tests.
- API and role authorization tests.
- End-to-end tests for login, production submission/approval, payroll finalization, and offline sync.
- Security test for cross-tenant isolation.
