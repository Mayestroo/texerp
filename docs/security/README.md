# Security

TexERP uses defense in depth. Security controls are required at the network, authentication, authorization, input, database, storage, audit, and operational layers.

## Security Baseline

- TLS for every network connection; production ingress accepts HTTPS only.
- JWT access tokens are short-lived; refresh tokens are opaque, hashed at rest, rotated, and revocable.
- PINs are stored only as bcrypt hashes. PINs, OTPs, tokens, and secrets are never logged.
- Tenant identity is taken from the verified JWT and enforced by application guards and PostgreSQL RLS.
- Roles are explicit: `WORKER`, `FOREMAN`, `ACCOUNTANT`, `WAREHOUSE`, `DIRECTOR`, `SUPER_ADMIN`.
- All mutation endpoints validate DTOs, reject unknown fields, and return the documented error envelope.
- Audit records are written before financial, identity, approval, inventory, and tenant mutations.
- Files are private and served only through short-lived pre-signed URLs containing tenant-scoped paths.

## Threat Controls

| Threat | Control | Verification |
|---|---|---|
| Cross-tenant access | JWT tenant guard + service scoping + PostgreSQL RLS | Automated isolation suite |
| Credential stuffing | Login rate limits, lockout after five failures, masked security logs | Auth integration tests |
| Token theft | 15-minute access TTL, refresh rotation, revocation, secure device storage | Session tests |
| Injection | Parameterized ORM queries, DTO validation, output encoding | SAST and integration tests |
| Privilege escalation | Role and ownership guards on every command | Authorization matrix tests |
| Replay/duplicate submission | Client idempotency key with tenant-scoped uniqueness | Sync tests |
| Data tampering | Append-only audit and stock records, write-before mutation | Database permission tests |
| File exposure | Private bucket, tenant path, signed URL expiry, content validation | Storage tests |

## Secret Management

Secrets are provided through the deployment secret manager, never committed to git or placed in `.env` files shared with the team. Required secret groups include database credentials, JWT signing keys, Redis credentials, S3 credentials, FCM credentials, SMS provider credentials, and error-tracking DSNs.

## Security Verification Gate

Production release requires passing dependency scanning, secret scanning, static analysis, cross-tenant tests, authentication/authorization tests, backup restore test, and an external penetration test before the first paid tenant.

## Incident Response

1. Detect and preserve logs, request IDs, audit IDs, and affected tenant IDs.
2. Contain by revoking sessions, disabling affected credentials, or suspending the tenant.
3. Assess affected records without altering audit evidence.
4. Eradicate the vulnerability and deploy a reviewed fix.
5. Restore or backfill only through audited migrations.
6. Notify stakeholders according to the incident severity and legal requirements.
7. Record a post-incident review with corrective actions.
