# API Contract
# TexERP — REST API Specification

---

**Document Version:** 1.0.0  
**Status:** Approved  
**Created:** 2026-07-16  
**Depends On:** Core Specification, UX Specification  
**Consumed By:** NestJS Backend, Flutter App  

> **Rule:** This document is the contract between the Flutter team and the NestJS team.  
> Backend implements exactly what is specified here. Flutter calls exactly what is documented.  
> Any deviation requires a version update to this document and review by both teams.

---

## Table of Contents

1. [Global Conventions](#1-global-conventions)
2. [Authentication](#2-authentication)
3. [Auth Module](#3-auth-module)
4. [Users & Profile Module](#4-users--profile-module)
5. [Departments Module](#5-departments-module)
6. [Operations Module](#6-operations-module)
7. [Production Module](#7-production-module)
8. [Sync Module (Offline)](#8-sync-module-offline)
9. [Payroll Module](#9-payroll-module)
10. [Dashboard Module](#10-dashboard-module)
11. [Reports Module](#11-reports-module)
12. [Notifications Module](#12-notifications-module)
13. [Settings Module](#13-settings-module)
14. [Error Reference](#14-error-reference)

---

## 1. Global Conventions

### Base URL

```
Production:   https://api.texerp.uz/v1
Staging:      https://api-staging.texerp.uz/v1
Local:        http://localhost:3000/v1
```

### Request Headers (All Authenticated Requests)

```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept-Language: uz          (or 'ru' — affects error messages)
X-App-Version: 1.0.0         (Flutter app version)
X-Platform: android          (or 'ios')
```

### Standard Success Response Envelope

```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2026-07-16T10:30:00.000Z",
    "requestId": "req_01J5K..."
  }
}
```

### Paginated List Response

```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "limit": 25,
    "total": 247,
    "totalPages": 10,
    "hasNext": true,
    "hasPrev": false
  }
}
```

### Standard Error Response

```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Noto'g'ri telefon yoki PIN kod",
    "details": null
  },
  "meta": {
    "timestamp": "2026-07-16T10:30:00.000Z",
    "requestId": "req_01J5K..."
  }
}
```

### Validation Error Response (422)

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Kiritilgan ma'lumotlar noto'g'ri",
    "details": [
      { "field": "quantity", "message": "Miqdor 1 dan 9999 gacha bo'lishi kerak" },
      { "field": "operation_id", "message": "Operatsiya tanlanmagan" }
    ]
  }
}
```

### Common Query Parameters (List Endpoints)

| Param | Type | Default | Description |
|-------|------|:-------:|-------------|
| `page` | integer | 1 | Page number |
| `limit` | integer | 25 | Items per page (max: 100) |
| `sort` | string | entity-specific | Sort field |
| `order` | `asc`\|`desc` | `desc` | Sort direction |

### Date Format

All dates: **ISO 8601** in UTC.  
`record_date` (date-only fields): **YYYY-MM-DD** format.  
All `_at` timestamps: **YYYY-MM-DDTHH:mm:ss.sssZ** format.

### Amounts

All monetary amounts are in **integer UZS tiyin** representation.  
Display value = amount / 100.  
Example: `45000000` = `450,000.00 so'm`

---

## 2. Authentication

### Token Lifecycle

```
POST /auth/login
  → access_token (JWT, 15 min TTL)
  → refresh_token (opaque, 30 days TTL)

Authenticated requests:
  Authorization: Bearer <access_token>

Token expiry (401 response):
  → POST /auth/refresh with refresh_token
  → new access_token issued

Logout:
  → POST /auth/logout (revokes refresh_token)
```

### JWT Payload

```json
{
  "sub": "01J5K4M8N9P0Q1R2S3T4U5V6W7",
  "tenant_id": "01J5K4M8N9P0Q1R2S3T4U5V6W7",
  "role": "WORKER",
  "phone": "+998901234567",
  "iat": 1752654600,
  "exp": 1752655500
}
```

### Role Values

`WORKER` · `FOREMAN` · `ACCOUNTANT` · `DIRECTOR` · `SUPER_ADMIN`

---

## 3. Auth Module

### `POST /auth/login`

Authenticate with phone number and PIN. Returns tokens.

**Auth required:** No

**Request:**

```json
{
  "phone": "+998901234567",
  "pin": "1234",
  "fcm_token": "fCM_token_string_here"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| `phone` | string | ✅ | Uzbekistan format: +998XXXXXXXXX |
| `pin` | string | ✅ | Exactly 4 numeric digits |
| `fcm_token` | string | ❌ | Firebase Cloud Messaging token |

**Response 200:**

```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "rt_01J5K4M8N9P0Q1R2S3T4U5V6W7_opaque",
    "expires_in": 900,
    "user": {
      "id": "01J5K4M8N9P0Q1R2S3T4U5V6W7",
      "full_name": "Aziz Karimov",
      "worker_code": "W-0042",
      "role": "WORKER",
      "language": "uz",
      "avatar_url": null,
      "department": {
        "id": "...",
        "name": "Tikarish Line 1"
      },
      "foreman": {
        "id": "...",
        "full_name": "Akbar Toshmatov"
      }
    }
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `INVALID_CREDENTIALS` | 401 | Wrong phone or PIN |
| `ACCOUNT_DEACTIVATED` | 403 | User is deactivated |
| `ACCOUNT_LOCKED` | 429 | Correct credentials for an account locked after 5 failures; includes `retry_after_seconds` |
| `TENANT_SUSPENDED` | 403 | Tenant is suspended |

---

### `POST /auth/refresh`

Exchange a refresh token for a new access token.

**Auth required:** No (uses refresh_token body)

**Request:**

```json
{
  "refresh_token": "rt_01J5K4M8N9P0Q1R2S3T4U5V6W7_opaque"
}
```

**Response 200:**

```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "rt_01J5K4M8N9P0Q1R2S3T4U5V6W8_opaque",
    "expires_in": 900
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `INVALID_REFRESH_TOKEN` | 401 | Token not found or already used |
| `REFRESH_TOKEN_EXPIRED` | 401 | Token older than 30 days |

---

### `POST /auth/logout`

Revoke the current refresh token.

**Auth required:** Yes

**Request:**

```json
{
  "refresh_token": "rt_01J5K4M8N9P0Q1R2S3T4U5V6W7_opaque"
}
```

**Response 200:**

```json
{ "success": true, "data": { "message": "Tizimdan chiqildi" } }
```

---

### `POST /auth/otp/send`

Send OTP SMS to a registered phone for PIN reset.

**Auth required:** No

**Request:**

```json
{
  "phone": "+998901234567"
}
```

**Response 200:**

```json
{
  "success": true,
  "data": {
    "otp_token": "otp_01J5K4M8N9P0Q1R2S3T4U5V6W7",
    "expires_in_seconds": 300,
    "retry_after_seconds": 120
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `PHONE_NOT_FOUND` | 404 | No user with this phone in any active tenant |
| `OTP_RATE_LIMITED` | 429 | Too many OTP requests; includes `retry_after_seconds` |

---

### `POST /auth/otp/verify`

Verify the 6-digit OTP code.

**Auth required:** No

**Request:**

```json
{
  "otp_token": "otp_01J5K4M8N9P0Q1R2S3T4U5V6W7",
  "code": "123456"
}
```

**Response 200:**

```json
{
  "success": true,
  "data": {
    "reset_token": "prst_01J5K4M8N9P0Q1R2S3T4U5V6W7",
    "expires_in_seconds": 600
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `INVALID_OTP` | 400 | Wrong code |
| `OTP_EXPIRED` | 400 | Code expired (5 min TTL) |
| `OTP_MAX_ATTEMPTS` | 429 | 3 failed attempts |

---

### `POST /auth/pin/reset`

Set a new PIN using the verified reset token.

**Auth required:** No

**Request:**

```json
{
  "reset_token": "prst_01J5K4M8N9P0Q1R2S3T4U5V6W7",
  "new_pin": "5678",
  "confirm_pin": "5678"
}
```

**Response 200:**

```json
{ "success": true, "data": { "message": "PIN kod muvaffaqiyatli o'zgartirildi" } }
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `INVALID_RESET_TOKEN` | 400 | Token not found or expired |
| `PIN_MISMATCH` | 400 | `new_pin` ≠ `confirm_pin` |
| `WEAK_PIN` | 400 | Sequential or repeated digits (1111, 1234, 0000) |

---

## 4. Users & Profile Module

### `GET /users/me`

Get current user's profile.

**Auth required:** Yes (all roles)

**Response 200:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K4M8N9P0Q1R2S3T4U5V6W7",
    "full_name": "Aziz Karimov",
    "phone": "+998901234567",
    "worker_code": "W-0042",
    "role": "WORKER",
    "status": "ACTIVE",
    "language": "uz",
    "avatar_url": "https://storage.texerp.uz/avatars/tenant123/user456.jpg",
    "department": {
      "id": "01J5K...",
      "name": "Tikarish Line 1",
      "code": "L1"
    },
    "foreman": {
      "id": "01J5K...",
      "full_name": "Akbar Toshmatov",
      "phone": "+998901112233"
    },
    "created_at": "2026-01-15T08:00:00.000Z"
  }
}
```

---

### `PATCH /users/me`

Update current user's own preferences.

**Auth required:** Yes (all roles)

**Request:**

```json
{
  "language": "ru",
  "avatar_url": "https://storage.texerp.uz/avatars/..."
}
```

Only `language`, `avatar_url` can be self-updated. Other fields require Director.

**Response 200:** Updated user object (same as `GET /users/me`)

---

### `POST /users/me/pin`

Change own PIN (requires current PIN for verification).

**Auth required:** Yes (all roles)

**Request:**

```json
{
  "current_pin": "1234",
  "new_pin": "5678",
  "confirm_pin": "5678"
}
```

**Response 200:**

```json
{ "success": true, "data": { "message": "PIN kod o'zgartirildi" } }
```

**Errors:** `WRONG_CURRENT_PIN` (401) · `PIN_MISMATCH` (400) · `WEAK_PIN` (400)

---

### `PUT /users/me/fcm-token`

Update Firebase push notification token (called on app launch and when token refreshes).

**Auth required:** Yes

**Request:**

```json
{ "fcm_token": "new_fcm_token_string" }
```

**Response 200:** `{ "success": true }`

---

### `GET /users`

List all users in the tenant.

**Auth required:** Yes · **Roles:** DIRECTOR, ACCOUNTANT (read-only)

**Query Parameters:**

| Param | Type | Default | Options |
|-------|------|:-------:|---------|
| `role` | string | all | `WORKER`, `FOREMAN`, `ACCOUNTANT`, `DIRECTOR` |
| `status` | string | `ACTIVE` | `ACTIVE`, `DEACTIVATED`, `ALL` |
| `search` | string | — | Case-insensitive partial match on full name or worker code |
| `page` | integer | 1 | |
| `limit` | integer | 50 | max 200 |

`department_id` and `foreman_id` filters are deferred to the Foreman Assignment slice and are currently rejected with HTTP 400 validation errors. Results are ordered by `full_name` ascending, then `id` ascending.

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "full_name": "Aziz Karimov",
      "worker_code": "W-0042",
      "phone": "+998901234567",
      "role": "WORKER",
      "status": "ACTIVE",
      "avatar_url": null,
      "department": { "id": "...", "name": "Tikarish Line 1" },
      "foreman": { "id": "...", "full_name": "Akbar Toshmatov" }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 1,
    "total_pages": 1,
    "has_next": false
  }
}
```

The default listing contains only active Users. `status=ALL` includes both active and deactivated Users.

---

### `POST /users`

Create a new user account.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:**

```json
{
  "full_name": "Malika Yusupova",
  "phone": "+998901234568",
  "worker_code": "W-0043",
  "role": "WORKER",
  "initial_pin": "4321",
  "language": "uz"
}
```

| Field | Type | Required | Notes |
|-------|------|:--------:|-------|
| `full_name` | string | ✅ | |
| `phone` | string | ✅ | Must be globally unique across all Tenants |
| `worker_code` | string | ✅ | Must be unique within the Tenant |
| `role` | enum | ✅ | WORKER, FOREMAN, ACCOUNTANT |
| `initial_pin` | string | ✅ | 4 digits |
| `language` | enum | ❌ | `uz` or `ru`; defaults to `uz` |

`department_id` and `foreman_id` are deferred to the Foreman Assignment slice. They are not accepted by this endpoint and are rejected with HTTP 400 validation errors.

**Response 201:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "full_name": "Malika Yusupova",
    "worker_code": "W-0043",
    "role": "WORKER",
    "status": "ACTIVE"
  }
}
```

**Errors:** `PHONE_ALREADY_EXISTS` (409) · `WORKER_CODE_ALREADY_EXISTS` (409) · `CANNOT_CREATE_DIRECTOR` (400) · HTTP 400 request validation

Creating another Director is not allowed and returns `CANNOT_CREATE_DIRECTOR` (400).

---

### `GET /users/:id`

Get a single user's profile.

**Auth required:** Yes · **Roles:** DIRECTOR (any user); FOREMAN (own team only); ACCOUNTANT (any)

**Response 200:** Same structure as `GET /users/me` but for specified user.

A Foreman can read their own profile or a Worker with an active Foreman Assignment to them. Missing, cross-Tenant, and out-of-scope User IDs all return `USER_NOT_FOUND` (404).

---

### `PATCH /users/:id`

Update user info.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** Partial update — include only fields to change.

```json
{
  "full_name": "Malika Yusupova-Nazarova",
  "language": "ru",
  "avatar_url": "https://storage.texerp.uz/avatars/tenant123/user456.jpg"
}
```

Only `full_name`, `language`, and nullable `avatar_url` are mutable. `phone`, `worker_code`, `role`, `status`, `department_id`, and `foreman_id` are immutable or managed by another workflow; supplying any of them is rejected with an HTTP 400 validation error. An empty object is rejected with `EMPTY_UPDATE` (400). A non-empty request containing only unchanged values succeeds without writing an audit event or updating the User.

**Response 200:** Updated complete profile (same structure as `GET /users/:id`).

**Errors:** `USER_NOT_FOUND` (404) · `EMPTY_UPDATE` (400) · HTTP 400 request validation

---

### `POST /users/:id/deactivate`

Deactivate a User and revoke their sessions. `sessions_revoked` is the exact number of unrevoked, unexpired sessions active immediately before deactivation.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** Empty body `{}`

**Response 200:**

```json
{
  "success": true,
  "data": { "message": "Foydalanuvchi nofaol qilindi", "sessions_revoked": 2 }
}
```

**Errors:** `USER_NOT_FOUND` (404) · `CANNOT_DEACTIVATE_SELF` (400) · `USER_ALREADY_DEACTIVATED` (400)

---

### `POST /users/:id/reactivate`

Reactivate a deactivated user.

**Auth required:** Yes · **Roles:** DIRECTOR

**Response 200:**

```json
{ "success": true, "data": { "message": "Foydalanuvchi faollashtirildi" } }
```

Reactivation clears the User's deactivation metadata but does not restore revoked sessions. The User must log in again.

**Errors:** `USER_NOT_FOUND` (404) · `USER_ALREADY_ACTIVE` (400)

---

## 5. Departments Module

### `GET /departments`

List all departments in the tenant.

**Auth required:** Yes · **Roles:** All

**Query:** `?include_inactive=false` (default)

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "name": "Tikarish Line 1",
      "code": "L1",
      "is_active": true,
      "foreman": {
        "id": "01J5K...",
        "full_name": "Akbar Toshmatov"
      },
      "worker_count": 24
    }
  ]
}
```

---

### `POST /departments`

Create a department.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:**

```json
{
  "name": "Tikarish Line 3",
  "code": "L3",
  "foreman_id": "01J5K..."
}
```

**Response 201:** Created department object.

---

### `PATCH /departments/:id`

Update a department.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** Partial update (name, code, foreman_id, is_active).

**Response 200:** Updated department object.

---

## 6. Operations Module

### `GET /operations`

List all operations in the tenant.

**Auth required:** Yes · **Roles:** All

**Query Parameters:**

| Param | Type | Default | Notes |
|-------|------|:-------:|-------|
| `status` | string | `ACTIVE` | `ACTIVE`, `INACTIVE`, `ALL` (Director only for ALL/INACTIVE) |
| `category_id` | UUIDv7 | — | Filter by category |
| `search` | string | — | Search by name or code |

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "name": "Yoqa tikish",
      "code": "OP-001",
      "category": {
        "id": "01J5K...",
        "name": "Yoqa operatsiyalari"
      },
      "unit": "PIECE",
      "unit_price": 45000,
      "currency": "UZS",
      "is_active": true,
      "sort_order": 1
    }
  ]
}
```

**Note for Workers:** Response includes only `ACTIVE` operations; `unit_price` included for price preview in Submit screen.

---

### `GET /operations/recently-used`

Get the current user's last 3 used operations.

**Auth required:** Yes · **Roles:** WORKER

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "name": "Yoqa tikish",
      "unit": "PIECE",
      "unit_price": 45000,
      "last_used_at": "2026-07-15T17:30:00.000Z"
    }
  ]
}
```

---

### `POST /operations`

Create an operation.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:**

```json
{
  "name": "Qo'l tikish",
  "code": "OP-012",
  "category_id": "01J5K...",
  "unit": "PIECE",
  "unit_price": 52000,
  "sort_order": 12
}
```

| Field | Type | Required | Notes |
|-------|------|:--------:|-------|
| `name` | string | ✅ | Unique in tenant |
| `code` | string | ❌ | Unique if provided |
| `category_id` | UUIDv7 | ❌ | |
| `unit` | enum | ✅ | `PIECE`, `METER`, `PAIR` |
| `unit_price` | integer | ✅ | In tiyin (smallest unit) |

**Response 201:** Created operation object.

---

### `PATCH /operations/:id`

Update an operation. Price changes logged to history.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** Partial update.

```json
{
  "name": "Qo'l tikish (yangilangan)",
  "unit_price": 55000
}
```

**Response 200:** Updated operation object. Includes:

```json
{
  "price_changed": true,
  "old_price": 52000,
  "new_price": 55000,
  "effective_from": "2026-07-16T10:30:00.000Z"
}
```

---

### `POST /operations/:id/deactivate`

Deactivate an operation. Existing records unaffected.

**Auth required:** Yes · **Roles:** DIRECTOR

**Response 200:** `{ "success": true }`

---

### `POST /operations/:id/activate`

Reactivate an operation.

**Auth required:** Yes · **Roles:** DIRECTOR

**Response 200:** `{ "success": true }`

---

### `GET /operation-categories`

List operation categories.

**Auth required:** Yes · **Roles:** All

**Response 200:** Array of `{ id, name, sort_order, operation_count }`

---

### `POST /operation-categories`

Create a category.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** `{ "name": "Yoqa operatsiyalari", "sort_order": 1 }`

**Response 201:** Created category object.

---

## 7. Production Module

### `POST /production/entries`

Submit a production record.

**Auth required:** Yes · **Roles:** WORKER

**Request:**

```json
{
  "operation_id": "01J5K...",
  "quantity": 85,
  "record_date": "2026-07-16",
  "bundle_code": "B-2024",
  "offline_created_at": "2026-07-16T10:15:00.000Z",
  "client_idempotency_key": "local_uuid_from_sqlite_01J5K..."
}
```

| Field | Type | Required | Notes |
|-------|------|:--------:|-------|
| `operation_id` | UUIDv7 | ✅ | Must be ACTIVE |
| `quantity` | integer | ✅ | 1–9999 |
| `record_date` | date | ✅ | Within back-date window |
| `bundle_code` | string | ❌ | Free text, max 50 chars |
| `offline_created_at` | datetime | ❌ | If submitted from offline queue |
| `client_idempotency_key` | string | ✅ | Unique key from client to prevent duplicates on retry |

**Response 201:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "status": "PENDING",
    "operation": {
      "id": "01J5K...",
      "name": "Yoqa tikish",
      "unit": "PIECE"
    },
    "quantity_submitted": 85,
    "unit_price_snapshot": 45000,
    "record_date": "2026-07-16",
    "submitted_at": "2026-07-16T10:30:00.000Z",
    "foreman": {
      "id": "01J5K...",
      "full_name": "Akbar Toshmatov"
    }
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `OPERATION_NOT_FOUND` | 404 | Operation doesn't exist in tenant |
| `OPERATION_INACTIVE` | 400 | Operation is deactivated |
| `DATE_OUT_OF_WINDOW` | 400 | record_date outside back-date window; includes `allowed_from` |
| `DUPLICATE_ENTRY` | 409 | Same worker + operation + date already exists; includes `existing_entry_id` |
| `NO_FOREMAN_ASSIGNED` | 400 | Worker has no active foreman assignment |
| `IDEMPOTENT_REPLAY` | 200 | Same `client_idempotency_key` — returns original record (not error) |

---

### `GET /production/entries`

List production entries with filters.

**Auth required:** Yes · **Roles:** All (scoped by role — see below)

**Role scoping:**

| Role | Sees |
|------|------|
| WORKER | Only own records |
| FOREMAN | Own team's records |
| ACCOUNTANT | All tenant records |
| DIRECTOR | All tenant records |

**Query Parameters:**

| Param | Type | Default | Notes |
|-------|------|:-------:|-------|
| `worker_id` | UUIDv7 | — | Director/Accountant: filter by worker |
| `foreman_id` | UUIDv7 | — | Director: filter by foreman |
| `status` | string | all | `PENDING`, `APPROVED`, `REJECTED`, `LINKED` |
| `date_from` | date | — | YYYY-MM-DD |
| `date_to` | date | — | YYYY-MM-DD |
| `operation_id` | UUIDv7 | — | Filter by operation |
| `page` | integer | 1 | |
| `limit` | integer | 25 | max 100 |
| `sort` | string | `submitted_at` | `submitted_at`, `record_date`, `quantity` |
| `order` | string | `desc` | |

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "status": "PENDING",
      "worker": {
        "id": "01J5K...",
        "full_name": "Aziz Karimov",
        "worker_code": "W-0042"
      },
      "operation": {
        "id": "01J5K...",
        "name": "Yoqa tikish",
        "unit": "PIECE"
      },
      "quantity_submitted": 85,
      "quantity_approved": null,
      "unit_price_snapshot": 45000,
      "record_date": "2026-07-16",
      "submitted_at": "2026-07-16T10:30:00.000Z",
      "is_suspicious": false,
      "bundle_code": null
    }
  ],
  "pagination": { ... }
}
```

---

### `GET /production/entries/:id`

Get a single production entry with full audit trail.

**Auth required:** Yes · **Roles:** All (scoped as above)

**Response 200:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "status": "APPROVED",
    "worker": { "id": "...", "full_name": "Aziz Karimov", "worker_code": "W-0042" },
    "foreman_snapshot": { "id": "...", "full_name": "Akbar Toshmatov" },
    "operation": { "id": "...", "name": "Yoqa tikish", "unit": "PIECE" },
    "quantity_submitted": 85,
    "quantity_approved": 72,
    "unit_price_snapshot": 45000,
    "operation_name_snapshot": "Yoqa tikish",
    "record_date": "2026-07-16",
    "bundle_code": null,
    "is_suspicious": false,
    "submitted_at": "2026-07-16T10:30:00.000Z",
    "approved_at": "2026-07-16T11:15:00.000Z",
    "correction_comment": "Ikki smenaning birga kiritilishi",
    "payroll_period_id": null,
    "audit_trail": [
      {
        "action": "CREATED",
        "actor": { "id": "...", "full_name": "Aziz Karimov", "role": "WORKER" },
        "old_status": null,
        "new_status": "PENDING",
        "old_quantity": null,
        "new_quantity": 85,
        "reason": null,
        "occurred_at": "2026-07-16T10:30:00.000Z"
      },
      {
        "action": "CORRECTED",
        "actor": { "id": "...", "full_name": "Akbar Toshmatov", "role": "FOREMAN" },
        "old_status": "PENDING",
        "new_status": "APPROVED",
        "old_quantity": 85,
        "new_quantity": 72,
        "reason": "Ikki smenaning birga kiritilishi",
        "occurred_at": "2026-07-16T11:15:00.000Z"
      }
    ]
  }
}
```

---

### `POST /production/entries/:id/approve`

Approve a production entry.

**Auth required:** Yes · **Roles:** FOREMAN (own team), DIRECTOR (any)

**Request:** Empty body `{}`

**Response 200:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "status": "APPROVED",
    "quantity_approved": 85,
    "approved_at": "2026-07-16T11:15:00.000Z"
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `ENTRY_NOT_PENDING` | 400 | Entry is not in PENDING status |
| `NOT_YOUR_TEAM` | 403 | Foreman trying to approve worker not in their team |
| `ENTRY_LOCKED` | 400 | Entry is LINKED to a finalized payroll period |

---

### `POST /production/entries/:id/reject`

Reject a production entry.

**Auth required:** Yes · **Roles:** FOREMAN (own team), DIRECTOR (any)

**Request:**

```json
{
  "reason": "Noto'g'ri miqdor",
  "reason_detail": "Optional free text"
}
```

| Field | Type | Required | Notes |
|-------|------|:--------:|-------|
| `reason` | string | ✅ | Predefined: `WRONG_QUANTITY`, `FAKE_RECORD`, `WRONG_OPERATION`, `DUPLICATE`, `OTHER` |
| `reason_detail` | string | ❌ | Required when `reason = OTHER`; min 10 chars |

**Response 200:**

```json
{
  "success": true,
  "data": { "id": "01J5K...", "status": "REJECTED", "rejected_at": "..." }
}
```

**Errors:** Same as approve + `REASON_REQUIRED` (400)

---

### `POST /production/entries/:id/correct-approve`

Correct the quantity and approve.

**Auth required:** Yes · **Roles:** FOREMAN (own team), DIRECTOR (any)

**Request:**

```json
{
  "correct_quantity": 72,
  "comment": "Ikki smenaning birga kiritilishi — ajratib kiritildi"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| `correct_quantity` | integer | ✅ | 1–9999; must differ from `quantity_submitted` |
| `comment` | string | ✅ | Min 10 characters |

**Response 200:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "status": "APPROVED",
    "quantity_submitted": 85,
    "quantity_approved": 72,
    "correction_comment": "...",
    "approved_at": "..."
  }
}
```

**Errors:** `SAME_QUANTITY` (400) · `COMMENT_REQUIRED` (400) · `ENTRY_NOT_PENDING` (400)

---

### `POST /production/entries/bulk-approve`

Approve multiple entries at once.

**Auth required:** Yes · **Roles:** FOREMAN (own team), DIRECTOR (any)

**Request:**

```json
{
  "entry_ids": [
    "01J5K...",
    "01J5K...",
    "01J5K..."
  ]
}
```

| Validation | Rule |
|-----------|------|
| Max entries | 50 per request |
| All must be PENDING | Non-PENDING entries are skipped (not errored) |
| Foreman scope | Entries not in foreman's team are rejected with `NOT_YOUR_TEAM` in results |

**Response 200:**

```json
{
  "success": true,
  "data": {
    "total_requested": 25,
    "approved": 23,
    "skipped": 2,
    "results": [
      { "entry_id": "01J5K...", "status": "APPROVED" },
      { "entry_id": "01J5K...", "status": "SKIPPED", "reason": "NOT_PENDING" }
    ]
  }
}
```

---

## 8. Sync Module (Offline)

### `POST /production/sync`

Submit multiple entries from the offline queue.

**Auth required:** Yes · **Roles:** WORKER

**Request:**

```json
{
  "entries": [
    {
      "client_idempotency_key": "local_abc123",
      "operation_id": "01J5K...",
      "quantity": 85,
      "record_date": "2026-07-16",
      "bundle_code": null,
      "offline_created_at": "2026-07-16T10:15:00.000Z"
    },
    {
      "client_idempotency_key": "local_def456",
      "operation_id": "01J5K...",
      "quantity": 62,
      "record_date": "2026-07-15",
      "offline_created_at": "2026-07-15T17:30:00.000Z"
    }
  ]
}
```

**Constraints:**
- Max 100 entries per sync request
- Entries are processed independently (one failure doesn't block others)
- Idempotent: same `client_idempotency_key` returns original result

**Response 200:**

```json
{
  "success": true,
  "data": {
    "total": 2,
    "accepted": 1,
    "rejected": 1,
    "results": [
      {
        "client_idempotency_key": "local_abc123",
        "status": "ACCEPTED",
        "entry_id": "01J5K...",
        "entry_status": "PENDING"
      },
      {
        "client_idempotency_key": "local_def456",
        "status": "REJECTED",
        "error_code": "DATE_OUT_OF_WINDOW",
        "error_message": "Sana juda eski"
      }
    ]
  }
}
```

---

## 9. Payroll Module

### `GET /payroll/periods`

List payroll periods.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Query:** `?status=ALL` (default: ALL) · `?page=1&limit=20`

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "name": "Iyul 2026 — 1-yarm",
      "start_date": "2026-07-01",
      "end_date": "2026-07-15",
      "status": "CALCULATED",
      "worker_count": 98,
      "total_gross": 4820000000,
      "total_final": 4650000000,
      "calculated_at": "2026-07-16T09:30:00.000Z",
      "finalized_at": null,
      "created_at": "2026-07-16T08:00:00.000Z"
    }
  ],
  "pagination": { ... }
}
```

---

### `POST /payroll/periods`

Create a new payroll period.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:**

```json
{
  "name": "Iyul 2026 — 2-yarm",
  "start_date": "2026-07-16",
  "end_date": "2026-07-31"
}
```

**Response 201:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "name": "Iyul 2026 — 2-yarm",
    "start_date": "2026-07-16",
    "end_date": "2026-07-31",
    "status": "DRAFT",
    "pending_entries_count": 12
  }
}
```

**Errors:**

| Code | HTTP | Condition |
|------|:----:|-----------|
| `PERIOD_OVERLAP` | 409 | Dates overlap with existing period; includes `conflicting_period_id` |
| `INVALID_DATE_RANGE` | 400 | end_date ≤ start_date |

---

### `GET /payroll/periods/:id`

Get period details with worker calculation summary.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Response 200:**

```json
{
  "success": true,
  "data": {
    "id": "01J5K...",
    "name": "Iyul 2026 — 1-yarm",
    "start_date": "2026-07-01",
    "end_date": "2026-07-15",
    "status": "CALCULATED",
    "worker_count": 98,
    "total_gross": 4820000000,
    "total_final": 4650000000,
    "pending_entries_count": 3,
    "calculated_at": "2026-07-16T09:30:00.000Z",
    "calculations": [
      {
        "worker": {
          "id": "01J5K...",
          "full_name": "Aziz Karimov",
          "worker_code": "W-0042"
        },
        "total_pieces": 1200,
        "gross_earnings": 54000000,
        "total_bonuses": 5000000,
        "total_deductions": 0,
        "total_advances": 10000000,
        "advance_carryforward": 0,
        "final_pay": 49000000,
        "has_adjustments": true
      }
    ],
    "pagination": { "page": 1, "limit": 50, ... }
  }
}
```

---

### `POST /payroll/periods/:id/calculate`

Trigger the payroll calculation background job.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:** Empty body `{}`

**Response 202 Accepted:**

```json
{
  "success": true,
  "data": {
    "job_id": "job_01J5K...",
    "message": "Hisob-kitob boshlandi",
    "poll_url": "/v1/payroll/periods/01J5K.../status"
  }
}
```

**Errors:** `PERIOD_NOT_DRAFT_OR_CALCULATED` (400) · `CALCULATION_ALREADY_RUNNING` (409)

---

### `GET /payroll/periods/:id/status`

Poll calculation status (called every 3 seconds from Flutter while CALCULATING).

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Response 200:**

```json
{
  "success": true,
  "data": {
    "status": "CALCULATING",
    "progress": {
      "processed": 45,
      "total": 98,
      "current_worker": "Aziz Karimov"
    }
  }
}
```

When done: `"status": "CALCULATED"` — Flutter stops polling.

---

### `GET /payroll/periods/:id/calculations/:workerId`

Get one worker's detailed payroll breakdown.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR; WORKER (own only, FINALIZED periods)

**Response 200:**

```json
{
  "success": true,
  "data": {
    "worker": { "id": "...", "full_name": "Aziz Karimov", "worker_code": "W-0042" },
    "period": { "id": "...", "name": "Iyul 2026 — 1-yarm", "status": "CALCULATED" },
    "total_pieces": 1200,
    "gross_earnings": 54000000,
    "operations_breakdown": [
      {
        "operation_name": "Yoqa tikish",
        "quantity": 720,
        "unit_price": 45000,
        "subtotal": 32400000
      },
      {
        "operation_name": "Qo'l tikish",
        "quantity": 480,
        "unit_price": 45000,
        "subtotal": 21600000
      }
    ],
    "adjustments": [
      {
        "id": "01J5K...",
        "type": "BONUS",
        "amount": 5000000,
        "reason": "Rejim uchun bonus",
        "created_by": { "full_name": "Dilnoza Umarova" },
        "created_at": "2026-07-16T10:00:00.000Z"
      }
    ],
    "advances": [
      {
        "id": "01J5K...",
        "amount": 10000000,
        "given_date": "2026-07-10",
        "reason": null,
        "created_by": { "full_name": "Dilnoza Umarova" }
      }
    ],
    "advance_carryforward": 0,
    "total_bonuses": 5000000,
    "total_deductions": 0,
    "total_advances": 10000000,
    "final_pay": 49000000,
    "calculation_version": 2,
    "entries_count": 18,
    "entries_url": "/v1/production/entries?worker_id=01J5K...&payroll_period_id=01J5K..."
  }
}
```

---

### `POST /payroll/periods/:id/adjustments`

Add a bonus or deduction.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:**

```json
{
  "worker_id": "01J5K...",
  "type": "BONUS",
  "amount": 5000000,
  "reason": "Rejim uchun bonus"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| `worker_id` | UUIDv7 | ✅ | Must be in this period's calculations |
| `type` | enum | ✅ | `BONUS` or `DEDUCTION` |
| `amount` | integer | ✅ | > 0 (in tiyin) |
| `reason` | string | ✅ | Min 5 characters |

**Response 201:** Created adjustment object.

**Errors:** `PERIOD_FINALIZED` (400) · `WORKER_NOT_IN_PERIOD` (400)

---

### `DELETE /payroll/periods/:id/adjustments/:adjustmentId`

Remove an adjustment (before finalization).

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Response 200:** `{ "success": true }`

**Errors:** `PERIOD_FINALIZED` (400) · `ADJUSTMENT_NOT_FOUND` (404)

---

### `POST /payroll/periods/:id/advances`

Record an advance payment.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:**

```json
{
  "worker_id": "01J5K...",
  "amount": 10000000,
  "given_date": "2026-07-10",
  "reason": "Tibbiy ehtiyoj"
}
```

**Response 201:** Created advance object.

---

### `POST /payroll/periods/:id/finalize`

Finalize the payroll period. Irreversible.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:**

```json
{
  "confirmed": true
}
```

`confirmed: true` is required — prevents accidental finalization.

**Response 200:**

```json
{
  "success": true,
  "data": {
    "message": "Davr yakunlandi",
    "period_id": "01J5K...",
    "workers_notified": 98,
    "entries_linked": 1847,
    "total_final_pay": 4650000000
  }
}
```

**Errors:** `PERIOD_NOT_CALCULATED` (400) · `CONFIRMATION_REQUIRED` (400) · `PERIOD_ALREADY_FINALIZED` (400)

---

### `POST /payroll/periods/:id/export`

Queue an Excel export job.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Request:** Empty body `{}`

**Response 202:**

```json
{
  "success": true,
  "data": {
    "export_id": "exp_01J5K...",
    "message": "Excel tayyorlanmoqda",
    "estimated_seconds": 30
  }
}
```

When ready: user receives a push notification of type `EXPORT_READY` containing the download URL.

---

### `GET /payroll/periods/:id/export/:exportId`

Get export download URL.

**Auth required:** Yes · **Roles:** ACCOUNTANT, DIRECTOR

**Response 200:**

```json
{
  "success": true,
  "data": {
    "status": "READY",
    "download_url": "https://storage.texerp.uz/exports/tenant123/period456_20260716.xlsx",
    "expires_at": "2026-07-16T12:00:00.000Z",
    "file_size_bytes": 245760
  }
}
```

`status` values: `PROCESSING` · `READY` · `FAILED`

---

## 10. Dashboard Module

### `GET /dashboard`

Get the role-specific dashboard data. Backend determines data based on JWT role.

**Auth required:** Yes · **Roles:** All

**Response 200 (WORKER):**

```json
{
  "success": true,
  "data": {
    "role": "WORKER",
    "today": {
      "total_pieces": 247,
      "estimated_earnings": 11115000,
      "records_count": 3,
      "approved_count": 2,
      "pending_count": 1,
      "rejected_count": 0
    },
    "recent_records": [
      {
        "id": "01J5K...",
        "operation_name": "Yoqa tikish",
        "quantity_submitted": 85,
        "status": "APPROVED",
        "record_date": "2026-07-16",
        "submitted_at": "2026-07-16T10:30:00.000Z"
      }
    ],
    "current_period": {
      "id": "01J5K...",
      "name": "Iyul 2026 — 1-yarm",
      "status": "CALCULATED",
      "final_pay": null
    }
  }
}
```

**Response 200 (FOREMAN):**

```json
{
  "success": true,
  "data": {
    "role": "FOREMAN",
    "pending_count": 12,
    "today": {
      "team_total_pieces": 2847,
      "active_workers_count": 22,
      "total_workers": 24
    },
    "top_performers_today": [
      { "worker": { "id": "...", "full_name": "Aziz Karimov" }, "total_pieces": 340 }
    ],
    "recent_approvals": [
      {
        "entry_id": "01J5K...",
        "worker_name": "Malika Yusupova",
        "action": "APPROVED",
        "occurred_at": "2026-07-16T10:45:00.000Z"
      }
    ]
  }
}
```

**Response 200 (DIRECTOR):**

```json
{
  "success": true,
  "data": {
    "role": "DIRECTOR",
    "today": {
      "total_pieces": 12340,
      "pending_count": 47,
      "active_workers": 89,
      "total_workers": 98
    },
    "top_performers_today": [ ... ],
    "current_period": {
      "id": "01J5K...",
      "name": "Iyul 2026 — 1-yarm",
      "status": "CALCULATED",
      "days_remaining": null,
      "total_final_pay": 4650000000
    },
    "alerts": [
      { "type": "HIGH_PENDING", "message": "47 ta yozuv kutilmoqda", "severity": "WARNING" }
    ]
  }
}
```

---

## 11. Reports Module

### `GET /reports/production`

Generate a production report.

**Auth required:** Yes · **Roles:** DIRECTOR, ACCOUNTANT; FOREMAN (own team only)

**Query Parameters:**

| Param | Type | Required | Notes |
|-------|------|:--------:|-------|
| `date_from` | date | ✅ | YYYY-MM-DD |
| `date_to` | date | ✅ | YYYY-MM-DD (max range: 31 days) |
| `group_by` | string | ✅ | `worker`, `operation`, `date`, `foreman` |
| `worker_id` | UUIDv7 | ❌ | |
| `foreman_id` | UUIDv7 | ❌ | |
| `operation_id` | UUIDv7 | ❌ | |
| `department_id` | UUIDv7 | ❌ | |

**Response 200 (group_by=worker):**

```json
{
  "success": true,
  "data": {
    "period": { "from": "2026-07-01", "to": "2026-07-15" },
    "total_pieces": 127840,
    "total_earnings": 5752800000,
    "rows": [
      {
        "worker": { "id": "...", "full_name": "Aziz Karimov", "worker_code": "W-0042" },
        "total_pieces": 1200,
        "operations_count": 3,
        "gross_earnings": 54000000,
        "records_count": 18
      }
    ]
  },
  "pagination": { ... }
}
```

---

### `POST /reports/production/export`

Queue a production report Excel export.

**Auth required:** Yes · **Roles:** DIRECTOR, ACCOUNTANT

**Request:** Same filters as GET query params, in body.

```json
{
  "date_from": "2026-07-01",
  "date_to": "2026-07-15",
  "group_by": "worker"
}
```

**Response 202:** Same as payroll export — returns `export_id`.

---

## 12. Notifications Module

### `GET /notifications`

List notifications for the current user.

**Auth required:** Yes · **Roles:** All

**Query Parameters:**

| Param | Type | Default |
|-------|------|:-------:|
| `status` | `ALL`\|`UNREAD` | `ALL` |
| `page` | integer | 1 |
| `limit` | integer | 30 |

**Response 200:**

```json
{
  "success": true,
  "data": [
    {
      "id": "01J5K...",
      "type": "ENTRY_APPROVED",
      "title": "Yozuv tasdiqlandi",
      "body": "Akbar Toshmatov 'Yoqa tikish' uchun 85 dona yozuvingizni tasdiqladi",
      "data": {
        "entry_id": "01J5K...",
        "deep_link": "/worker/history/01J5K..."
      },
      "is_read": false,
      "created_at": "2026-07-16T11:15:00.000Z",
      "read_at": null
    }
  ],
  "unread_count": 3,
  "pagination": { ... }
}
```

---

### `POST /notifications/mark-read`

Mark multiple notifications as read.

**Auth required:** Yes · **Roles:** All

**Request:**

```json
{
  "notification_ids": ["01J5K...", "01J5K..."],
  "mark_all": false
}
```

Set `mark_all: true` to mark all as read (ignores `notification_ids`).

**Response 200:**

```json
{ "success": true, "data": { "marked_count": 3 } }
```

---

## 13. Settings Module

### `GET /settings`

Get organization settings.

**Auth required:** Yes · **Roles:** DIRECTOR

**Response 200:**

```json
{
  "success": true,
  "data": {
    "organization_id": "01J5K...",
    "name": "Bahor Textile LLC",
    "timezone": "Asia/Tashkent",
    "language": "uz",
    "currency": "UZS",
    "back_date_window_days": 3,
    "suspicious_quantity_multiplier": 3,
    "payroll_min_pay": 0,
    "duplicate_window_minutes": 60
  }
}
```

---

### `PATCH /settings`

Update organization settings.

**Auth required:** Yes · **Roles:** DIRECTOR

**Request:** Partial update.

```json
{
  "back_date_window_days": 5,
  "suspicious_quantity_multiplier": 4
}
```

**Response 200:** Updated settings object.

**Validation:** `back_date_window_days` must be 1–7.

---

## 14. Error Reference

### HTTP Status Codes

| Status | Meaning |
|:------:|---------|
| 200 | OK |
| 201 | Created |
| 202 | Accepted (async job queued) |
| 400 | Bad Request (business rule violation) |
| 401 | Unauthorized (missing or invalid token) |
| 403 | Forbidden (token valid but role insufficient) |
| 404 | Not Found |
| 409 | Conflict (duplicate, overlap) |
| 422 | Unprocessable Entity (validation errors) |
| 429 | Too Many Requests (rate limited) |
| 500 | Internal Server Error |
| 503 | Service Unavailable (maintenance) |

### Application Error Codes

| Code | HTTP | Description |
|------|:----:|-------------|
| `INVALID_CREDENTIALS` | 401 | Wrong phone or PIN |
| `ACCOUNT_DEACTIVATED` | 403 | User account deactivated |
| `ACCOUNT_LOCKED` | 429 | Too many failed login attempts |
| `TENANT_SUSPENDED` | 403 | Tenant suspended |
| `TOKEN_EXPIRED` | 401 | JWT access token expired |
| `TOKEN_INVALID` | 401 | JWT signature invalid or malformed |
| `REFRESH_TOKEN_EXPIRED` | 401 | Refresh token expired |
| `INVALID_REFRESH_TOKEN` | 401 | Refresh token not found |
| `INSUFFICIENT_ROLE` | 403 | Role not permitted for this action |
| `WRONG_CURRENT_PIN` | 401 | Current PIN verification failed |
| `WEAK_PIN` | 400 | Sequential or trivial PIN |
| `PIN_MISMATCH` | 400 | New PIN and confirm PIN don't match |
| `INVALID_OTP` | 400 | Wrong OTP code |
| `OTP_EXPIRED` | 400 | OTP code expired |
| `OTP_MAX_ATTEMPTS` | 429 | Too many OTP verification attempts |
| `OTP_RATE_LIMITED` | 429 | Too many OTP send requests |
| `PHONE_NOT_FOUND` | 404 | Phone not registered |
| `PHONE_ALREADY_EXISTS` | 409 | Phone already registered globally |
| `WORKER_CODE_ALREADY_EXISTS` | 409 | Worker code already in use within the Tenant |
| `CANNOT_CREATE_DIRECTOR` | 400 | A Director cannot create another Director |
| `EMPTY_UPDATE` | 400 | No mutable User fields supplied |
| `USER_NOT_FOUND` | 404 | User absent, cross-Tenant, or outside Foreman visibility |
| `CANNOT_DEACTIVATE_SELF` | 400 | Director cannot deactivate own account |
| `USER_ALREADY_DEACTIVATED` | 400 | User already deactivated |
| `USER_ALREADY_ACTIVE` | 400 | User already active |
| `OPERATION_NOT_FOUND` | 404 | Operation ID not found |
| `OPERATION_INACTIVE` | 400 | Submitting against inactive operation |
| `DATE_OUT_OF_WINDOW` | 400 | record_date outside allowed range |
| `DUPLICATE_ENTRY` | 409 | Same worker+operation+date already exists |
| `NO_FOREMAN_ASSIGNED` | 400 | Worker has no active foreman assignment |
| `ENTRY_NOT_PENDING` | 400 | Cannot approve/reject non-PENDING entry |
| `ENTRY_LOCKED` | 400 | Entry LINKED to finalized period |
| `NOT_YOUR_TEAM` | 403 | Foreman cannot act on another team's worker |
| `SAME_QUANTITY` | 400 | correct-approve with same quantity as submitted |
| `PERIOD_OVERLAP` | 409 | Payroll period dates overlap existing period |
| `PERIOD_FINALIZED` | 400 | Action not allowed on finalized period |
| `PERIOD_NOT_CALCULATED` | 400 | Cannot finalize non-CALCULATED period |
| `PERIOD_NOT_DRAFT_OR_CALCULATED` | 400 | Cannot calculate from this status |
| `CALCULATION_ALREADY_RUNNING` | 409 | Another calculation job is running |
| `PERIOD_ALREADY_FINALIZED` | 400 | Period already finalized |
| `CONFIRMATION_REQUIRED` | 400 | `confirmed: true` not provided |
| `WORKER_NOT_IN_PERIOD` | 400 | Worker has no calculation in this period |
| `VALIDATION_ERROR` | 422 | Input validation failed (see `details` array) |
| `RESOURCE_NOT_FOUND` | 404 | Generic not found |
| `INTERNAL_ERROR` | 500 | Unhandled server error |

### Rate Limits

| Endpoint | Limit | Window |
|----------|:-----:|:------:|
| `POST /auth/login` | 10 | 15 min per IP |
| `POST /auth/otp/send` | 3 | 10 min per phone |
| `POST /auth/otp/verify` | 5 | per otp_token |
| `POST /production/entries` | 100 | 1 min per user |
| `POST /production/sync` | 10 | 1 min per user |
| All other endpoints | 300 | 1 min per user |

---

*End of API Contract — Version 1.0.0*  
*Total endpoints: 52*  
*Backend team implements; Flutter team calls; this document is the binding agreement between both.*  
*Version must increment for any breaking change. Additive changes (new optional fields) do not require version bump.*
