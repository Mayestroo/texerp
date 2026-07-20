# ADR-001: Flutter vs React Native for Mobile Application

---

**Status:** ACCEPTED  
**Date:** 2026-07-16  
**Deciders:** Tech Lead, Product Manager  
**Category:** Mobile Platform  

---

## Context

TexERP requires a mobile application for Android and iOS that serves factory workers, foremen, accountants, warehouse staff, and directors. The app must:
- Run smoothly on low-to-mid range Android devices (2–4 GB RAM)
- Support offline production submission (SQLite local storage)
- Render consistently on Android 8.0+ and iOS 13+
- Achieve near-native performance (smooth list scrolling with 200+ records)
- Be maintainable by a small team (2–3 mobile engineers)

Two viable options were evaluated: **Flutter** and **React Native**.

---

## Decision

**Flutter (Dart) is chosen as the mobile framework.**

---

## Rationale

| Criterion | Flutter | React Native |
|-----------|---------|-------------|
| UI consistency across platforms | Renders its own widgets (identical on Android + iOS) | Uses native components (OS-version differences possible) |
| Performance on low-end Android | Compiled to native ARM; smooth on 2 GB RAM | JS bridge adds overhead; less smooth on low-end devices |
| Offline SQLite support | `sqflite` package is mature and well-documented | `react-native-sqlite-storage` is functional but less maintained |
| Single codebase | Full single codebase | Generally single codebase; but some native modules needed |
| Team skillset | Team has Dart/Flutter experience | Would require retraining or new hire |
| Uzbek/Cyrillic typography | Flutter's text rendering handles Cyrillic reliably | Depends on native OS text engine; occasional rendering bugs |
| Hot reload / DX | Excellent hot reload | Excellent hot reload |
| App size | Slightly larger (~15 MB baseline) | Slightly smaller (~10 MB baseline) |
| Ecosystem maturity | Growing fast; Google-backed | Very mature; Meta-backed |
| Pub.dev packages for our needs | Sufficient (sqflite, firebase_messaging, bloc, go_router) | Sufficient but JS ecosystem is larger |

**Key deciding factors:**
1. **Pixel-perfect consistency** is critical because the UI must be usable in bright factory lighting on various cheap Android models. Flutter's own rendering engine guarantees identical behavior.
2. **Offline SQLite performance** is a hard requirement. Flutter's `sqflite` has proven production performance.
3. **Team has Flutter experience** — switching would add 3–4 months of onboarding.

---

## Consequences

**Positive:**
- Single Dart codebase for Android + iOS
- Consistent UI across all device models
- Strong offline support
- Bloc/Cubit state management is well-suited for complex approval workflows

**Negative:**
- Dart is less common than JavaScript; harder to hire for
- Flutter ecosystem is smaller than React Native's for some edge-case packages
- App binary size is slightly larger (~15–25 MB vs ~10–15 MB)

**Risks mitigated:**
- Low-end device performance risk mitigated by Flutter's AOT compilation
- Hiring risk mitigated by team's existing Dart knowledge

---

## Alternatives Rejected

| Alternative | Reason Rejected |
|-------------|----------------|
| React Native | Lower performance on low-end Android; team retraining cost |
| Native Android (Kotlin) + Native iOS (Swift) | Double the engineering cost; two separate codebases |
| Ionic / Capacitor | Web-based; unacceptable performance for production floor use |
| PWA | No push notification support on iOS; offline limitations |
