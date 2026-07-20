# API Design

This folder will contain all API specification documents.

## Planned Documents

- `APIConventions.md` — Naming, versioning, pagination, error format standards
- `AuthAPI.md` — Login, OTP, refresh token, logout endpoints
- `UsersAPI.md` — User CRUD, role assignment, deactivation
- `ProductionAPI.md` — Submit record, list records, approve, reject, correct
- `PayrollAPI.md` — Period management, calculation, finalization, export
- `WarehouseAPI.md` — Material catalog, receipts, issuances, balance
- `ReportsAPI.md` — Dashboard data, production reports, payroll reports
- `NotificationsAPI.md` — List, mark read, preferences
- `TenantAPI.md` — Tenant CRUD, subscriptions, feature flags (Super Admin)
- `openapi.yaml` — Full OpenAPI 3.0 specification (auto-generated from code)

## API Conventions Summary

- Base URL: `https://api.texerp.com/api/v1/`
- Auth: `Authorization: Bearer <JWT>`
- Pagination: Cursor-based (`?cursor=xxx&limit=20`)
- Errors: RFC 7807 Problem Details format
- Dates: ISO 8601 (UTC)
- IDs: UUID v4

## Status

> Pending — API design begins after Database design is complete.
