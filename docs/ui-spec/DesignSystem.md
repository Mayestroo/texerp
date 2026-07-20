# Design System
# TexERP — Flutter Design Language

---

**Document Version:** 1.0.0  
**Status:** Approved  
**Created:** 2026-07-16  
**Depends On:** Core Specification  
**Consumed By:** UX Specification, Flutter Architecture  

> **Purpose:** This document defines every visual and interaction token used across the TexERP Flutter app.  
> A developer implementing any screen should never make a visual decision — every color, every spacing value, every shadow is defined here.  
> "Just pick a color" is not acceptable. Use the system.

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Color System](#2-color-system)
3. [Typography](#3-typography)
4. [Spacing System](#4-spacing-system)
5. [Border Radius](#5-border-radius)
6. [Elevation & Shadows](#6-elevation--shadows)
7. [Iconography](#7-iconography)
8. [Button Components](#8-button-components)
9. [Input Components](#9-input-components)
10. [Card Components](#10-card-components)
11. [Navigation](#11-navigation)
12. [App Bar](#12-app-bar)
13. [Bottom Sheet](#13-bottom-sheet)
14. [Dialog & Alerts](#14-dialog--alerts)
15. [Snackbar & Toast](#15-snackbar--toast)
16. [Status Badges](#16-status-badges)
17. [Loading States](#17-loading-states)
18. [Empty States](#18-empty-states)
19. [Error States](#19-error-states)
20. [Offline State](#20-offline-state)
21. [Dark Mode](#21-dark-mode)
22. [Motion & Animation](#22-motion--animation)
23. [Accessibility](#23-accessibility)
24. [Flutter Implementation Reference](#24-flutter-implementation-reference)

---

## 1. Design Principles

### P-01: Clarity Over Beauty
Factory workers use this app with dirty or sweaty hands, under harsh fluorescent lighting, often on cheap 720p screens. Every element must be large, high-contrast, and unambiguous. We do not sacrifice clarity for aesthetics.

### P-02: Speed of Action
A worker's most frequent action (submit production) must require the fewest possible taps. Primary actions are always large, full-width, and at thumb-reach (bottom of screen). Never make the user scroll to find the action button.

### P-03: Status is Always Visible
A worker should always know the status of their last submission without opening a details screen. A foreman should always see their pending count without tapping anything. Status communicates through color, icon, AND text — never color alone.

### P-04: Offline-First Visual Design
The app must communicate its connectivity state at all times. An offline banner and sync status are permanent fixtures — never hidden. Users who are offline should never wonder "did it save?"

### P-05: One Language, No Ambiguity
Every label, every button, every error message is defined in this spec. No developer invents copy. The exact Uzbek and Russian strings are specified in the UX Specification.

---

## 2. Color System

### 2.1 Brand Colors

```
Primary:        #6C5CE7   — Deep violet. Primary actions, active states, brand identity.
Primary Light:  #A29BFE   — Hover states, selected highlights on dark backgrounds.
Primary Dark:   #4834D4   — Pressed states, links.
```

### 2.2 Semantic Colors

These colors communicate system meaning. They must NEVER be used for decoration.

```
Success:        #00B894   — Approved, completed, positive states.
Success Light:  #55EFC4   — Success backgrounds, chips.

Warning:        #FDCB6E   — Pending, requires attention, caution.
Warning Dark:   #E17055   — Warning pressed states.

Error:          #D63031   — Rejected, failure, destructive actions.
Error Light:    #FF7675   — Error backgrounds.

Info:           #0984E3   — Informational, neutral system messages.
Info Light:     #74B9FF   — Info backgrounds.
```

### 2.3 Neutral Palette

```
Grey 50:    #F8F9FA   — Page background (light mode)
Grey 100:   #F1F3F5   — Card background (light mode)
Grey 200:   #E9ECEF
Grey 300:   #DEE2E6   — Dividers, borders
Grey 400:   #CED4DA
Grey 500:   #ADB5BD   — Placeholder text, disabled
Grey 600:   #868E96   — Secondary text
Grey 700:   #495057   — Body text (light mode)
Grey 800:   #343A40   — Headings (light mode)
Grey 900:   #212529   — Primary text (light mode)
```

### 2.4 Dark Mode Palette

```
Background:     #0D0D14   — App background
Surface:        #1A1A28   — Cards, sheets, modals
Surface Raised: #252538   — Elevated cards (dialogs, bottom sheets)
Border:         #2D2D44   — Dividers, input borders
Text Primary:   #F0F0F8   — Main text
Text Secondary: #9090B0   — Secondary labels, hints
Text Disabled:  #505070   — Disabled text
```

### 2.5 Production Status Colors

These are the most important colors in the app. Workers and foremen make decisions based on them.

| Status | Color | Hex | Dark Mode |
|--------|-------|-----|-----------|
| `PENDING` | Amber | `#FDCB6E` | `#FDCB6E` |
| `APPROVED` | Emerald | `#00B894` | `#00B894` |
| `REJECTED` | Rose | `#D63031` | `#FF7675` |
| `LINKED` | Violet | `#A29BFE` | `#A29BFE` |
| `SUSPICIOUS` | Orange | `#E17055` | `#FDAE61` |

### 2.6 Color Usage Rules

```
DO:
  ✅ Use Primary (#6C5CE7) for the single most important action on a screen
  ✅ Use semantic colors only for their defined meaning
  ✅ Pair every color-coded status with an icon and text label
  ✅ Maintain 4.5:1 contrast ratio minimum for all text

DON'T:
  ❌ Use more than one Primary action button per screen
  ❌ Use Error red for anything that is not an error
  ❌ Use color alone to communicate status (always add icon + text)
  ❌ Create custom colors not defined in this system
```

---

## 3. Typography

### 3.1 Font Family

```
Primary Font:   Inter (Google Fonts)
Fallback:       system-ui, -apple-system, sans-serif

Why Inter:
  - Excellent Uzbek (Latin) and Russian (Cyrillic) character support
  - Optimized for screen readability at small sizes
  - Available as Flutter Google Fonts package
  - Clean, professional appearance
```

### 3.2 Type Scale

| Token | Size | Weight | Line Height | Usage |
|-------|:----:|:------:|:-----------:|-------|
| `display` | 32sp | 700 Bold | 1.2 | Hero numbers (dashboard totals) |
| `headline1` | 24sp | 700 Bold | 1.3 | Page titles |
| `headline2` | 20sp | 600 SemiBold | 1.3 | Section headers |
| `headline3` | 18sp | 600 SemiBold | 1.4 | Card titles |
| `body1` | 16sp | 400 Regular | 1.5 | Primary body text |
| `body2` | 14sp | 400 Regular | 1.5 | Secondary body, list items |
| `label` | 14sp | 500 Medium | 1.4 | Button labels, form labels |
| `caption` | 12sp | 400 Regular | 1.4 | Timestamps, helper text |
| `overline` | 11sp | 500 Medium | 1.4 | ALL CAPS section labels |

### 3.3 Number Display (Financial)

Financial numbers (quantities, earnings) use a tabular numeric variant for alignment in lists.

```
Earnings amount:   24sp / 700 Bold / tabular-nums
Quantity value:    20sp / 600 SemiBold / tabular-nums
Small amount:      16sp / 500 Medium / tabular-nums
```

### 3.4 Typography Rules

```
✅ Minimum readable size: 12sp (never smaller in production)
✅ Maximum line width: 72 characters (wrap text before this)
✅ Heading hierarchy: every screen has exactly one headline1
✅ Uzbek text uses Latin; Russian uses Cyrillic — both supported by Inter
❌ Never use italic text in the main UI (poor readability on cheap screens)
❌ Never manually scale text — use the defined scale only
```

---

## 4. Spacing System

**Base unit: 4px.** All spacing values are multiples of 4.

| Token | Value | Flutter constant | Usage |
|-------|:-----:|:----------------:|-------|
| `space1` | 4px | `AppSpacing.xs` | Micro gap (icon + label) |
| `space2` | 8px | `AppSpacing.sm` | Internal card padding, tight gaps |
| `space3` | 12px | `AppSpacing.md` | Default gap between elements |
| `space4` | 16px | `AppSpacing.lg` | Standard screen padding, card padding |
| `space5` | 20px | `AppSpacing.xl` | Section gap |
| `space6` | 24px | `AppSpacing.xxl` | Large section gap |
| `space8` | 32px | `AppSpacing.xxxl` | Hero section padding |
| `space12` | 48px | `AppSpacing.huge` | Minimum tap target height |

### Screen Padding Convention

```
Horizontal screen padding:  16px (AppSpacing.lg) on all screens
Top padding (below AppBar): 16px
Bottom padding (above nav): 16px + bottom safe area
Section spacing:            24px between major sections
```

---

## 5. Border Radius

| Token | Value | Usage |
|-------|:-----:|-------|
| `radiusXS` | 4px | Tags, small chips |
| `radiusSM` | 8px | Input fields, small cards |
| `radiusMD` | 12px | Standard cards, list items |
| `radiusLG` | 16px | Bottom sheets, modal cards |
| `radiusXL` | 24px | Large hero cards |
| `radiusFull` | 999px | Pills, avatar, circular buttons |

---

## 6. Elevation & Shadows

```
Level 0 — Flat (no shadow):
  Surface background elements; dividers

Level 1 — Subtle (cards):
  box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)
  Usage: Standard content cards

Level 2 — Raised (sticky elements):
  box-shadow: 0 4px 6px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.10)
  Usage: Floating action buttons, sticky headers

Level 3 — Floating (overlays):
  box-shadow: 0 10px 25px rgba(0,0,0,0.25), 0 4px 10px rgba(0,0,0,0.15)
  Usage: Bottom sheets, dialogs, dropdowns

Dark Mode Shadow Note:
  Shadows are less visible on dark backgrounds.
  Use border (1px solid AppColors.border) instead of shadow for card separation in dark mode.
```

---

## 7. Iconography

### Icon Library

**Primary:** Material Symbols (Rounded variant) — available as Flutter package  
**Reason:** Consistent with Material Design 3, excellent readability at small sizes, Rounded variant feels softer and more approachable for workers.

### Icon Sizes

| Context | Size | Token |
|---------|:----:|-------|
| Navigation bar | 24dp | `IconSize.nav` |
| Action buttons | 24dp | `IconSize.action` |
| List item leading | 20dp | `IconSize.list` |
| Small badge/chip | 16dp | `IconSize.small` |
| Hero/display | 32dp | `IconSize.hero` |

### Core Icon Set

| Concept | Icon Name | Used For |
|---------|-----------|---------|
| Submit / Add | `add_circle` | Submit production button |
| Approve | `check_circle` | Approved status, approve action |
| Reject | `cancel` | Rejected status, reject action |
| Pending | `schedule` | Pending status |
| Correct | `edit` | Correct & approve action |
| Worker | `person` | Worker identity |
| Foreman | `supervisor_account` | Foreman role |
| Payroll | `payments` | Payroll module |
| Operation | `build` | Operations/work type |
| History | `history` | Record history |
| Settings | `settings` | Settings screen |
| Dashboard | `dashboard` | Dashboard/home |
| Notification | `notifications` | Notification bell |
| Offline | `cloud_off` | Offline indicator |
| Sync | `sync` | Syncing state |
| Export | `download` | Excel/PDF export |
| Warning | `warning_amber` | Suspicious/warning state |
| Lock | `lock` | Finalized/locked period |
| Calendar | `calendar_today` | Date picker, record date |
| Amount | `account_balance_wallet` | Earnings, payroll amounts |
| Search | `search` | Search/filter |
| Filter | `filter_list` | List filters |
| Bulk | `checklist` | Bulk actions |
| Close | `close` | Dismiss, close |
| Back | `arrow_back` | Navigation back |
| More | `more_vert` | Context menu |

### Icon Rules

```
✅ Always pair icons with text labels in navigation
✅ Use filled icons for active/selected states; outlined for inactive
✅ Status icons must always accompany status color (never color alone)
❌ Do not create custom icons for MVP — use Material Symbols
❌ Do not use icons smaller than 16dp anywhere
```

---

## 8. Button Components

### 8.1 Primary Button

Used for: The single primary action on a screen (Submit, Approve, Calculate, Finalize).

```
Height:           52dp
Width:            Full-width (padding: 16px horizontal)
Background:       Primary (#6C5CE7)
Text:             White, 16sp, 600 SemiBold
Border Radius:    12px (radiusMD)
Padding:          16px horizontal, 14px vertical
Icon:             Optional leading icon (24dp)
Pressed State:    background → Primary Dark (#4834D4), scale 0.98
Disabled State:   background → Grey 300 / Grey 700 (dark), text → Grey 500
Loading State:    Replace label with CircularProgressIndicator (white, 20dp)

Dark mode:        Same — Primary color works on dark background
```

**One rule: ONE primary button per screen.**

---

### 8.2 Secondary Button

Used for: Secondary actions (Cancel, Go Back, View Details).

```
Height:           52dp
Background:       Transparent
Border:           1.5px solid Primary (#6C5CE7)
Text:             Primary (#6C5CE7), 16sp, 600 SemiBold
Border Radius:    12px
Pressed State:    background → Primary with 10% opacity
Disabled State:   border → Grey 400, text → Grey 500
```

---

### 8.3 Danger Button

Used for: Destructive actions ONLY (Reject, Deactivate user, Cancel payroll period).

```
Height:           52dp
Background:       Error (#D63031) / Transparent (outlined variant)
Text:             White (filled) / Error (outlined), 16sp, 600 SemiBold
Border Radius:    12px
Pressed State:    background → darker red
Usage rule:       ALWAYS preceded by a confirmation dialog
```

---

### 8.4 Ghost / Text Button

Used for: Tertiary actions (Skip, View all, Forgot PIN).

```
Height:           44dp
Background:       Transparent (no border)
Text:             Primary or Grey 600, 14sp, 500 Medium
Padding:          8px horizontal
Underline:        Optional (links only)
```

---

### 8.5 Icon Button

Used for: Compact actions in list items or app bars (edit, delete, more options).

```
Size:             44dp × 44dp (minimum tap target)
Background:       Transparent / Surface on pressed
Icon:             24dp, Grey 700 (light) / Grey 300 (dark)
Pressed State:    ripple effect
```

---

### 8.6 Floating Action Button (FAB)

Used on: Worker Home screen (Submit Production — the most important button in the app).

```
Size:             Extended FAB: 56dp height, auto width
Background:       Primary (#6C5CE7)
Icon:             add_circle, 24dp, White
Label:            "Ishni kiritish" / "Добавить работу"
Position:         Bottom center, above bottom navigation bar
Margin:           16px from bottom nav, 16px horizontal
Shadow:           Level 2
Border Radius:    16px
```

---

## 9. Input Components

### 9.1 Text Input Field

```
Height:           56dp
Background:       Surface / Grey 50 (light)
Border:           1px solid Grey 300 (light) / Border color (dark)
Focus Border:     2px solid Primary (#6C5CE7)
Error Border:     2px solid Error (#D63031)
Border Radius:    12px (radiusMD)
Padding:          16px horizontal, 14px vertical
Label:            Floating label, 12sp caption when active
Placeholder:      Grey 500, 16sp body1
Text:             Grey 900 (light) / Text Primary (dark), 16sp body1
Helper Text:      12sp caption, Grey 600
Error Text:       12sp caption, Error red
Leading Icon:     Optional, 20dp, Grey 600
Trailing Icon:    Optional, 20dp (clear, visibility toggle)
```

---

### 9.2 Quantity Input Field

Special component for production quantity input (the most critical worker input).

```
Height:           72dp  ← Taller for easier interaction
Font:             24sp, 700 Bold, tabular-nums, center-aligned
Background:       Surface
Border:           2px solid Grey 300 (unfocused)
Focus Border:     2px solid Primary
Border Radius:    12px
Suffix:           Unit label ("dona", "m", "juft")
Keyboard:         numericKeyboard
Max value:        9999 (enforced at input level)
Min value:        1

Companion buttons: [-] and [+] buttons on left and right (±1 per tap, hold for rapid)
Tap area for [-] and [+]: 44dp minimum
```

---

### 9.3 Dropdown / Select Field

Used for: Operation selection (the most frequent input).

```
Height:           56dp
Appearance:       Same as Text Input Field
Trailing Icon:    keyboard_arrow_down, 20dp
Tap:              Opens bottom sheet with searchable list
Search:           Search bar at top of bottom sheet list
Item Height:      56dp minimum (large touch targets)
Selected Item:    Primary color text, check icon on right
Empty State:      "Operatsiya topilmadi" with search suggestion
Recently Used:    Top 3 recent operations shown first, separated by divider
```

---

### 9.4 Date Picker Field

Used for: Record date selection.

```
Height:           56dp
Appearance:       Same as Text Input Field
Leading Icon:     calendar_today, 20dp
Default:          Today's date
Format:           "DD.MM.YYYY" (Uzbek convention)
Tap:              Opens Material Date Picker (bottom sheet style)
Constraint:       Min date = today - back_date_window; Max date = today
Future dates:     Disabled and greyed out
```

---

### 9.5 PIN Input Field

Used for: Login PIN entry.

```
Display:          4 circles, 16dp diameter each
Spacing:          12px between circles
Filled State:     Primary color filled circle
Empty State:      Border-only circle (2px, Grey 300)
Keyboard:         Numeric keyboard (custom, large keys)
Key size:         Each digit key: 72dp × 72dp
Backspace:        Top right: backspace icon button
Security:         Circles fill immediately, then mask after 300ms
Shake Animation:  On wrong PIN (horizontal shake 4px amplitude)
```

---

## 10. Card Components

### 10.1 Standard Content Card

```
Background:       Surface (#1A1A28 dark / White light)
Border Radius:    radiusMD (12px)
Padding:          16px all sides
Shadow:           Level 1
Border:           1px solid Border color (dark mode only)
Margin:           0 (cards are spaced by the list/column gap)
```

---

### 10.2 Production Record Card (List Item)

The most frequently seen component — appears in every list.

```
Height:           Auto (min 80dp)
Layout:
  [Status indicator bar 4px wide] | [Content] | [Amount]

Left bar color:
  PENDING:  Warning amber (#FDCB6E)
  APPROVED: Success green (#00B894)
  REJECTED: Error red (#D63031)
  LINKED:   Violet (#A29BFE)

Content (left):
  Line 1: Operation name — body1, 16sp, bold
  Line 2: Record date — caption, 12sp, secondary text
  Line 3: "Tasdiqlandi" / "Kutilmoqda" — status label with icon

Amount (right):
  Line 1: Quantity — 20sp, 700 bold (tabular)
  Line 2: Unit — caption, 12sp, secondary
  Tap: Opens record detail screen

Swipe right (Foreman only):  Quick approve action (green reveal)
Swipe left (Foreman only):   Quick reject action (red reveal)
Long press (Foreman):        Enter multi-select mode
```

---

### 10.3 Stat Card (Dashboard)

Used in Director and Foreman dashboards.

```
Background:       Surface
Border Radius:    radiusLG (16px)
Padding:          20px
Shadow:           Level 1

Layout:
  [Icon 32dp, Primary color]
  [Display number — 32sp, 700 bold]
  [Label — body2, 14sp, secondary]
  [Delta indicator — caption, 12sp, success/error color]

Example:
  📊
  2,847
  Bugungi mahsulot (dona)
  ↑ +12% kechagiga nisbatan
```

---

### 10.4 Payroll Summary Card

Used in Worker payroll screen and Accountant review.

```
Background:       Linear gradient: Primary Dark → Primary
Border Radius:    radiusXL (24px)
Padding:          24px
Text:             White throughout

Layout:
  [Period name — body2, secondary opacity]
  [Amount — 32sp, 700 bold]
  [Status badge]
  [Breakdown row: Gross | Bonus | Deduction | Advance]
```

---

## 11. Navigation

### Bottom Navigation Bar

Used on all main screens after login. Each role sees different tabs.

```
Height:           72dp + bottom safe area
Background:       Surface (dark) / White (light)
Border Top:       1px solid Border color
Tab count:        Worker: 3 tabs · Foreman: 3 tabs · Accountant: 4 tabs · Director: 4 tabs

Tab Item:
  Icon:           24dp
  Label:          12sp, 400 Regular
  Active State:   Primary color icon + label, filled icon variant
  Inactive State: Grey 500 icon + label, outlined icon variant
  Indicator:      16dp wide pill above active icon (Primary, 3dp height)
  Tap animation:  Scale 1.0 → 1.1 → 1.0 (100ms)
```

**Tab structure per role:**

| Role | Tab 1 | Tab 2 | Tab 3 | Tab 4 |
|------|-------|-------|-------|-------|
| Worker | Bosh sahifa (home) | Kiritish (submit) | Tarix (history) | — |
| Foreman | Bosh sahifa | Kutmoqda (pending) | Jamoa (team) | — |
| Accountant | Bosh sahifa | Ishlab chiqarish | Ish haqi | Hisobot |
| Director | Bosh sahifa | Ishlab chiqarish | Ish haqi | Sozlamalar |

---

## 12. App Bar

```
Height:           56dp + top safe area
Background:       Background (transparent over page content) / Surface (sticky)
Elevation:        0 (flat); adds shadow on scroll
Title:            headline3, 18sp, 600 SemiBold, left-aligned
Leading:          Back arrow (arrow_back) for sub-screens; none for root tabs
Trailing:         Icon buttons (notification bell, more menu)
Notification badge:
  Position:       Top-right corner of bell icon
  Color:          Error red (#D63031)
  Size:           18dp circle
  Content:        Number if ≤ 9; "9+" if more
```

---

## 13. Bottom Sheet

Used for: Operation selection, rejection reason, bulk action confirmation, date picker.

```
Modal:            True — background dims to 40% black overlay
Handle:           Centered drag handle — 4dp × 32dp, Grey 400, 8px top margin
Background:       Surface Raised (#252538 dark / White light)
Border Radius:    24px top-left, 24px top-right; 0 bottom
Max Height:       90% of screen height
Min Height:       30% of screen height
Drag to dismiss:  Enabled (but confirmation dialogs are NOT draggable)
Padding:          16px horizontal, content-specific vertical
Animation:        Slide up 300ms ease-out
```

### Operation Selector Bottom Sheet

```
Header:
  Title: "Operatsiyani tanlang" — headline3
  Search field (always visible)
  [X] close button

Recently Used Section (if available):
  Label: "OXIRGI ISHLATIGANLAR" — overline, ALL CAPS
  Up to 3 recent operations

All Operations (alphabetical or by category):
  Grouped by OperationCategory if configured
  Each item: 56dp height, operation name (body1), price (body2 right)
  Selected: Primary background tint, check icon

Empty search: "Topilmadi" with clear search hint
```

---

## 14. Dialog & Alerts

### Confirmation Dialog

Used for: Reject action, Deactivate user, Finalize payroll, Cancel period.

```
Overlay:          Background dims to 50% black
Background:       Surface Raised
Border Radius:    radiusLG (16px)
Padding:          24px
Max Width:        320dp (centered)
Animation:        Scale 0.8 → 1.0, fade in 200ms

Structure:
  [Icon: 48dp, semantic color]
  [Title: headline3, 20sp bold, centered]
  [Body: body2, 14sp, centered, secondary text]
  [Action buttons: stacked vertically]
    Primary action: full-width (Danger or Primary button)
    Cancel: Ghost button

Cannot be dismissed by tapping background — user MUST choose an action.
```

### Rejection Reason Dialog

Special case — shown when foreman taps "Reject".

```
Extends base dialog with:
  Predefined reason chips (tap to select):
    "Noto'g'ri miqdor" | "Soxta yozuv" | "Noto'g'ri operatsiya" | "Boshqa"
  Free-text input (visible when "Boshqa" selected)
  Confirm button disabled until reason selected
```

---

## 15. Snackbar & Toast

### Snackbar

Used for: Action feedback (record submitted, approved, synced, error occurred).

```
Position:         Bottom of screen, above bottom navigation bar
Margin:           16px all sides
Border Radius:    radiusMD (12px)
Min Height:       48dp
Max Width:        Screen width - 32px
Padding:          12px horizontal, 14px vertical
Duration:         Success/Info: 3 seconds · Error: 5 seconds

Layout:
  [Leading icon 20dp] [Message text body2] [Optional action button]

Variants:
  Success:   Background #00B894 (Success green) / white text
  Error:     Background #D63031 (Error red) / white text
  Warning:   Background #FDCB6E (Warning amber) / Grey 900 text
  Info:      Background Surface Raised / Primary text

Stacking:   Show one at a time; queue if multiple arrive quickly
```

---

## 16. Status Badges

Small inline status indicators. Always color + icon + text.

```
Height:           24dp
Padding:          6px horizontal, 4px vertical
Border Radius:    radiusFull (pill shape)
Font:             caption, 11sp, 500 Medium

PENDING:
  Background: Warning amber at 15% opacity
  Text: Warning dark (#E17055)
  Icon: schedule, 14dp

APPROVED:
  Background: Success at 15% opacity
  Text: Success (#00B894)
  Icon: check_circle, 14dp

REJECTED:
  Background: Error at 15% opacity
  Text: Error (#D63031)
  Icon: cancel, 14dp

LINKED (Payroll locked):
  Background: Primary at 15% opacity
  Text: Primary Light (#A29BFE)
  Icon: lock, 14dp

SUSPICIOUS:
  Background: Orange at 15% opacity
  Text: Warning dark (#E17055)
  Icon: warning_amber, 14dp
```

---

## 17. Loading States

### Full Screen Loading

Used for: Initial data load, payroll calculation in progress.

```
Centered in screen:
  [CircularProgressIndicator, 48dp, Primary color]
  [Label below: "Yuklanmoqda..." — body2, secondary]

Background: Screen background (no overlay)
```

### Skeleton Loading

Used for: List screens while data loads (prevents layout shift).

```
Skeleton items mimic the shape of real content cards:
  Animated shimmer: left-to-right gradient sweep, 1.5s loop
  Colors: Grey 200 → Grey 100 (light) / Grey 800 → Grey 700 (dark)
  Border Radius: Same as real cards

Production record skeleton: mimics 3-4 record cards
Dashboard skeleton: mimics stat cards + partial list
```

### Inline Loading

Used for: Button loading state, search results loading.

```
Button loading: Replace text with SizedBox(20dp) CircularProgressIndicator
                Button remains disabled during load
List loading:   Small CircularProgressIndicator at bottom of list (pagination)
```

---

## 18. Empty States

Every list screen must have a defined empty state. No blank white screens.

### Structure

```
Centered vertically in the scrollable area:
  [Illustration: simple SVG or Lottie — 200dp wide]
  [Title: headline3, 18sp, centered]
  [Subtitle: body2, 14sp, secondary, centered, max 2 lines]
  [Action button: Primary or Secondary — only when an action is possible]
```

### Defined Empty States

| Screen | Title (uz) | Subtitle | Action |
|--------|-----------|---------|--------|
| Worker History (no records) | "Hali yozuv yo'q" | "Ishni kiritish uchun tugmani bosing" | FAB (submit) |
| Foreman Pending Queue (empty) | "Hammasi tasdiqlangan!" | "Hozircha yangi yozuv yo'q" | — |
| Notifications (none) | "Bildirishnomalar yo'q" | "Yangi voqealar bo'lganda shu yerda ko'rsatiladi" | — |
| Operation List (none) | "Operatsiyalar yo'q" | "Direktor operatsiya qo'shishi kerak" | — (worker) / Add button (director) |
| Workers List (no workers) | "Ishchilar yo'q" | "Ishchi qo'shing" | Add Worker button |
| Payroll Periods (none) | "Hisob davrlari yo'q" | "Yangi davr yarating" | Create Period |
| Search results (no match) | "Natija topilmadi" | "'[query]' bo'yicha hech narsa yo'q" | Clear search |

---

## 19. Error States

### Full Screen Error

Used for: Network failure preventing initial load, server 5xx errors.

```
Structure (same layout as empty state):
  [Error icon: cloud_off or error_outline, 64dp, Error red]
  [Title: "Xatolik yuz berdi" — headline3]
  [Subtitle: Human-readable error message — body2, secondary]
  [Retry button: Secondary button "Qayta urinish"]

Never show: Stack traces, HTTP status codes, technical error messages.
```

### Inline Error (Form Validation)

```
Position:         Below the input field
Color:            Error (#D63031)
Font:             caption, 12sp
Icon:             error_outline, 14dp, leading
Animation:        Slide down + fade in (200ms)
Input border:     Turns Error red simultaneously
```

### Error Banner

Used for: Partial failures (e.g., sync partially failed, some records could not be processed).

```
Position:         Below app bar
Background:       Error at 10% opacity
Border:           Left border 4px solid Error
Icon:             warning_amber, 20dp, Error
Text:             body2, Error text
Action:           Optional text button (Batafsil / Details)
Duration:         Persistent until dismissed or resolved
```

---

## 20. Offline State

The offline state is a **permanent system feature**, not an error. It must be visible but not alarming.

### Offline Banner

```
Position:         Sticky below the App Bar (always visible when offline)
Height:           40dp
Background:       Grey 800 / Grey 200
Icon:             cloud_off, 16dp
Text:             "Oflayn rejim — ma'lumotlar saqlanyapti" — caption, 14sp
Color:            Grey 400 text (neutral, not alarming)
Animation:        Slide down when connectivity lost; slide up when restored
```

### Sync In Progress Banner

```
Replaces offline banner when sync is running:
Background:       Primary at 10% opacity
Icon:             sync (spinning), 16dp, Primary
Text:             "Sinxronlanmoqda... (3/7)" — caption
Animation:        Icon rotates continuously while syncing
```

### Sync Complete Toast

```
Snackbar type: Success
Icon:          check_circle
Text:          "7 ta yozuv yuklandi ✓"
Duration:      3 seconds
```

### Offline Indicator on Records

Records created offline show a small sync indicator until confirmed synced:

```
Small icon:    cloud_upload, 14dp, Grey 400
Position:      Top-right corner of record card
Tooltip:       "Sinxronlanishi kutilmoqda"
After sync:    Icon disappears (no animation needed)
```

---

## 21. Dark Mode

### Strategy: Dark-First Design

TexERP is designed **dark-mode first**. The dark theme is the primary experience. Light mode is the secondary.

**Reason:** Factory floors often have bright overhead lighting. A dark app reduces glare and eye strain for workers staring at screens between physical work.

### Theme Toggle

- Default: System theme (follows device setting)
- User can override in Profile > Settings
- Preference stored locally; also synced to server

### Dark Mode Color Mapping

| Light Mode | Dark Mode |
|:----------:|:---------:|
| `#F8F9FA` background | `#0D0D14` background |
| `#FFFFFF` card | `#1A1A28` card |
| `#212529` primary text | `#F0F0F8` primary text |
| `#868E96` secondary text | `#9090B0` secondary text |
| `#DEE2E6` divider | `#2D2D44` divider |
| Shadow (elevation) | Border (1px) + subtle shadow |

---

## 22. Motion & Animation

### Principles

- **Purposeful:** Animations guide attention, not decorate
- **Fast:** Most transitions < 300ms; users should not wait for animations
- **Consistent:** Same action = same animation, every time

### Defined Animations

| Element | Animation | Duration | Easing |
|---------|-----------|:--------:|--------|
| Page transition | Slide left/right | 250ms | `easeInOut` |
| Bottom sheet open | Slide up | 300ms | `easeOut` |
| Bottom sheet close | Slide down | 250ms | `easeIn` |
| Dialog appear | Scale 0.9→1.0 + fade | 200ms | `easeOut` |
| Snackbar appear | Slide up + fade | 200ms | `easeOut` |
| Card tap | Scale 0.98 | 100ms | `linear` |
| Button press | Scale 0.97 | 80ms | `linear` |
| Status badge change | Fade cross-dissolve | 300ms | `easeInOut` |
| Skeleton shimmer | Left-right sweep | 1500ms | `linear` (loop) |
| PIN circle fill | Scale 0→1 | 150ms | `bounceOut` |
| Wrong PIN shake | Horizontal shake | 400ms | Custom |
| Sync icon rotate | 360° continuous | 1000ms | `linear` (loop) |
| FAB appearance | Scale 0→1 + fade | 200ms | `easeOut` |

### Page Transition Convention

```
Push (navigate deeper):    New page slides in from right
Pop (navigate back):       Current page slides out to right
Modal (bottom sheet):      Slides up from bottom
Dismiss modal:             Slides down to bottom
Tab switch:                Fade cross-dissolve (no slide — tabs are parallel)
```

---

## 23. Accessibility

### Minimum Requirements

| Requirement | Standard | TexERP Target |
|-------------|---------|:-------------:|
| Text contrast ratio | 4.5:1 (WCAG AA) | 7:1 (WCAG AAA) where possible |
| Touch target size | 44dp × 44dp | 48dp × 48dp |
| Focus indicators | Visible focus ring | 2dp Primary color ring |
| Screen reader labels | All interactive elements | All elements with `semanticsLabel` |
| Text scaling | Support up to 1.3× | Up to 1.5× without layout break |
| Color-blind safe | Color + icon + text | Enforced by icon rule |

### Uzbek/Russian Text Considerations

```
Uzbek (Latin):  Inter handles Uzbek Latin perfectly
Russian (Cyrillic): Inter has full Cyrillic coverage
Mixed content:  flutter_localizations + arb files handle switching
Long words:     Russian words can be very long — all text must support wrapping
RTL:            Not needed (Uzbek Latin and Russian are LTR)
```

---

## 24. Flutter Implementation Reference

### Color Constants

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  // Brand
  static const primary = Color(0xFF6C5CE7);
  static const primaryLight = Color(0xFFA29BFE);
  static const primaryDark = Color(0xFF4834D4);

  // Semantic
  static const success = Color(0xFF00B894);
  static const successLight = Color(0xFF55EFC4);
  static const warning = Color(0xFFFDCB6E);
  static const warningDark = Color(0xFFE17055);
  static const error = Color(0xFFD63031);
  static const errorLight = Color(0xFFFF7675);
  static const info = Color(0xFF0984E3);
  static const infoLight = Color(0xFF74B9FF);

  // Dark mode surfaces
  static const backgroundDark = Color(0xFF0D0D14);
  static const surfaceDark = Color(0xFF1A1A28);
  static const surfaceRaisedDark = Color(0xFF252538);
  static const borderDark = Color(0xFF2D2D44);
  static const textPrimaryDark = Color(0xFFF0F0F8);
  static const textSecondaryDark = Color(0xFF9090B0);

  // Status
  static statusColor(String status) => switch (status) {
    'PENDING'    => warning,
    'APPROVED'   => success,
    'REJECTED'   => error,
    'LINKED'     => primaryLight,
    'SUSPICIOUS' => warningDark,
    _            => Colors.grey,
  };
}
```

### Spacing Constants

```dart
// lib/core/theme/app_spacing.dart
class AppSpacing {
  static const xs   = 4.0;
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const xxl  = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  static const screenHorizontal = lg;
  static const cardPadding = lg;
  static const sectionGap = xxl;
}
```

### Typography

```dart
// lib/core/theme/app_typography.dart
class AppTypography {
  static const fontFamily = 'Inter';

  static const display   = TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700);
  static const headline1 = TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700);
  static const headline2 = TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600);
  static const headline3 = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600);
  static const body1     = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400);
  static const body2     = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400);
  static const label     = TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500);
  static const caption   = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400);
  static const overline  = TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.8);

  static const amountLarge  = TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  static const amountMedium = TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  static const quantity     = TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
}
```

### Border Radius

```dart
// lib/core/theme/app_radius.dart
class AppRadius {
  static const xs   = BorderRadius.all(Radius.circular(4));
  static const sm   = BorderRadius.all(Radius.circular(8));
  static const md   = BorderRadius.all(Radius.circular(12));
  static const lg   = BorderRadius.all(Radius.circular(16));
  static const xl   = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999));
}
```

---

*End of Design System — Version 1.0.0*  
*Every visual decision in the Flutter app must reference this document.*  
*Changes to this document affect every screen — update via pull request with Design Lead review.*
