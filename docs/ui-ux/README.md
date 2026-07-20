# UI/UX

The approved visual and interaction specifications live in `03_UISpec/`:

- [`DesignSystem.md`](../03_UISpec/DesignSystem.md) — tokens, components, accessibility, motion, and dark mode.
- [`UIUXSpecification.md`](../03_UISpec/UIUXSpecification.md) — 30 MVP screens, role flows, states, copy, and navigation.

This folder contains delivery-facing UX artifacts that connect those specifications to implementation.

## UX Rules

- The worker's primary action is production submission and must be reachable within three taps from the home screen.
- Offline state is visible whenever connectivity is unavailable; locally saved records show their sync state.
- Every status uses text, icon, and color. Color alone is not meaningful.
- Minimum interactive target is 48dp.
- Uzbek and Russian strings are maintained together. No screen ships with developer-invented copy.
- Warehouse screens remain reserved for the V1 feature flag and must follow the same role and offline conventions.

## Role Navigation

| Role | Primary destinations |
|---|---|
| Worker | Home, Submit, History, Payroll, Profile |
| Foreman | Home, Pending approvals, Team, Profile |
| Accountant | Home, Production, Payroll, Reports, Profile |
| Warehouse | Home, Inventory, Movements, Reports, Profile |
| Director | Home, Production, Payroll, Team, Reports, Settings, Profile |

## Required UX Deliverables Before Development

1. Route map checked against the API contract and role matrix.
2. Uzbek and Russian copy review by a native speaker.
3. Offline, loading, empty, error, and session-expiry states for every screen.
4. Accessibility pass at 1.5x text scaling and screen-reader labels.
5. Device review on a low-end Android phone and an iPhone reference device.

## Artifact Policy

Figma links, exported wireframes, and user-flow diagrams belong here when available. The markdown specifications remain the reviewable source of truth; design-tool files must not silently change behavior.
