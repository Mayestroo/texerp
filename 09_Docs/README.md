# Documentation

This folder contains documentation used by operators, factory administrators, support staff, and engineers after implementation starts.

## Planned Documents

- `UserGuide.md` — role-based everyday workflows.
- `AdminGuide.md` — tenant onboarding, users, operations, settings, subscriptions, and flags.
- `OperationsRunbook.md` — deploy, monitor, backup, restore, queue, and incident procedures.
- `SupportGuide.md` — common user problems and escalation rules.
- `ReleaseNotes.md` — customer-facing changes by app/API version.
- `Glossary.md` — canonical textile, payroll, production, and system terms.

## Documentation Rules

- User-facing instructions are Uzbek-first with Russian equivalents where supported.
- Procedures identify role, prerequisites, steps, expected result, and recovery path.
- Screenshots and recordings use synthetic tenants and masked identities.
- Every operational procedure states its risk and whether it is reversible.
- API, database, security, and architecture behavior is referenced rather than duplicated.

## Minimum Support Playbooks

1. Worker cannot log in or reset a PIN.
2. Offline production record is pending or failed to sync.
3. Foreman cannot see or approve a record.
4. Payroll calculation is stuck or contains an unexpected total.
5. Export is processing, failed, or expired.
6. User was deactivated or tenant access was suspended.
7. Low-stock or warehouse movement discrepancy.
8. Suspected duplicate or unauthorized access.

## Ownership

- Product owns user language and workflow documentation.
- Engineering owns API, deployment, and recovery procedures.
- Security owns incident response and access-control procedures.
- Support owns troubleshooting and escalation content.
