# Flutter Mobile App

The Flutter app is the mobile client for workers, foremen, accountants, warehouse users, and directors. It follows the folder structure and offline protocol in `02_Architecture/ArchitectureBlueprint.md`, the REST contract in `04_API/APIContract.md`, and the approved UX in `03_UISpec/`.

## Technical Baseline

- Flutter stable channel and Dart null safety.
- BLoC/Cubit for presentation state.
- GoRouter for role-aware navigation and deep links.
- Dio with auth, retry, and request-ID interceptors.
- SQLite for cached read models and the offline mutation queue.
- Secure storage for refresh tokens and device secrets.
- FCM for push notifications.
- Uzbek (`uz`) and Russian (`ru`) localization from ARB files.

## Feature Boundaries

Each feature owns `data`, `domain`, and `presentation` layers. Features expose repositories and use cases, not data-source details. Shared code is limited to networking, persistence, synchronization, theme, routing, failures, and reusable UI.

## Offline Contract

The app must support offline production submission and cached history. Each queued mutation includes a local UUIDv7, operation, payload, creation time, retry count, and sync status. On reconnection the sync manager submits at most 100 entries per request, handles each result independently, and preserves failed items for user review.

Server time is authoritative. A successful replay is idempotent; a duplicate, expired date, deactivated worker, or other rejected item is shown with an actionable reason. Local records must never be silently deleted.

## State and Navigation

Every feature models loading, loaded, empty, failure, offline, and partial-sync states where applicable. Role guards prevent deep-link access to another role's screens. A 401 triggers one refresh attempt; failure clears credentials and shows the session-expired flow.

Refresh tokens are never placed in SQLite, logs, analytics, or crash reports. Push deep links are validated against the current user's role and tenant before navigation.

## Testing Requirements

- Unit tests for validators, mappers, use cases, sync conflicts, and formatters.
- BLoC tests for success, failure, offline, retry, and stale-cache behavior.
- Widget tests for primary forms and destructive confirmations.
- Integration tests for login, production submission, approval, payroll viewing, and token refresh.
- Accessibility checks at light/dark themes and 1.5x text scale.

## Release Checklist

- API version and minimum app version are compatible.
- Uzbek/Russian ARB files contain the same keys.
- Offline queue migration is backward compatible.
- Crash reporting has no secrets or unmasked PII.
- Android and iOS builds pass on supported release devices.
