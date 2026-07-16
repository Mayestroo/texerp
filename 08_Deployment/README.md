# Deployment

TexERP deploys as containerized services around the modular monolith: API, background workers, PostgreSQL, Redis, object storage, and observability. V1 favors a simple single-region setup; Kubernetes remains the later scaling target.

## Environments

| Environment | Purpose | Data policy |
|---|---|---|
| Local | Developer feedback | Synthetic data only |
| CI | Automated checks | Ephemeral containers |
| Staging | Release candidate and UAT | Sanitized fixtures only |
| Production | Customer traffic | Encrypted tenant data |

Each environment has separate credentials, storage buckets, signing keys, and database instances. Production secrets are supplied by a secret manager.

## Deployment Units

- `texerp-api` — stateless NestJS HTTP service.
- `texerp-worker` — BullMQ consumers and scheduled jobs.
- PostgreSQL — primary transactional database with automated backups.
- Redis — cache, rate limits, token revocation, and queues.
- S3-compatible storage — private exports, avatars, and warehouse images.
- Reverse proxy/WAF — TLS termination, security headers, request limits, and health routing.

## Release Flow

```text
Pull request -> format/lint/typecheck -> unit tests -> integration/RLS tests
  -> build immutable images -> staging migration dry run -> UAT
  -> approval -> production expand migration -> deploy API/workers -> smoke tests
```

Database migrations run before code that depends on them. Destructive schema changes use expand/contract releases. API changes remain backward compatible within `/v1`.

## Health and Recovery

- Liveness checks that the process is running.
- Readiness checks for database and Redis connectivity.
- Metrics for latency, errors, queue depth, job failures, DB pool use, and quotas.
- Structured logs with request ID, trace ID, module, tenant ID, and actor ID where safe.
- Alerts for API errors, P95 latency, failed payroll, cross-tenant attempts, DLQ growth, saturation, and certificate expiry.

V1 target: RPO <= 15 minutes and RTO <= 4 hours. Backups are encrypted, retained according to the database policy, and restored in a scheduled verification exercise.

Application rollback redeploys the previous immutable image. Database rollback uses a forward corrective migration; production migrations are never manually edited or reversed in place. Feature flags can contain a bad release while it is investigated.

## Production Smoke Tests

- Login and token refresh.
- Tenant-scoped profile and dashboard request.
- Production record creation and approval in a test tenant.
- Queue enqueue and worker completion.
- Private export URL generation and expiry.
- RLS cross-tenant denial.
