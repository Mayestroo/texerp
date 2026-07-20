# UX Specification
# TexERP — Screen-by-Screen Interaction Guide

---

**Document Version:** 1.0.0  
**Status:** Approved  
**Created:** 2026-07-16  
**Depends On:** Core Specification, Design System, MVP Definition  
**Consumed By:** Flutter Architecture, Backend (API Contract)  

> **Rule:** Every screen in the Flutter app must conform to this document.  
> No screen, state, message, or interaction may be invented by the developer.  
> If it is not here, it does not ship in MVP.

---

## Conventions

```
Route:       GoRouter path
Access:      Which roles can reach this screen
Goal:        One sentence — what the user accomplishes
TAP:         User taps an element
SWIPE:       User swipes a list item
LONG PRESS:  User holds an element
SUBMIT:      Form submission
→            Navigates to
TOAST ✅:    Success snackbar (green, 3s)
TOAST ⚠️:    Warning snackbar (amber, 4s)
TOAST ❌:    Error snackbar (red, 5s)
DIALOG:      Confirmation modal (blocks until user acts)
```

---

## Table of Contents

### Auth Flow
- [A-01: Login Screen](#a-01-login-screen)
- [A-02: PIN Reset — Phone Entry](#a-02-pin-reset--phone-entry)
- [A-03: PIN Reset — OTP Verification](#a-03-pin-reset--otp-verification)
- [A-04: PIN Reset — New PIN](#a-04-pin-reset--new-pin)

### Worker Flow
- [W-01: Worker Home](#w-01-worker-home)
- [W-02: Submit Production](#w-02-submit-production)
- [W-03: Submit Confirmation](#w-03-submit-confirmation)
- [W-04: Worker History](#w-04-worker-history)
- [W-05: Record Detail (Worker View)](#w-05-record-detail-worker-view)
- [W-06: My Payroll](#w-06-my-payroll)

### Foreman Flow
- [F-01: Foreman Home](#f-01-foreman-home)
- [F-02: Pending Approval Queue](#f-02-pending-approval-queue)
- [F-03: Record Detail (Foreman View)](#f-03-record-detail-foreman-view)
- [F-04: Reject — Reason Selection](#f-04-reject--reason-selection)
- [F-05: Correct & Approve](#f-05-correct--approve)
- [F-06: Bulk Approve](#f-06-bulk-approve)
- [F-07: Team Performance](#f-07-team-performance)

### Accountant Flow
- [AC-01: Accountant Home](#ac-01-accountant-home)
- [AC-02: Payroll Periods List](#ac-02-payroll-periods-list)
- [AC-03: Create Payroll Period](#ac-03-create-payroll-period)
- [AC-04: Period Detail — Overview](#ac-04-period-detail--overview)
- [AC-05: Worker Payroll Breakdown](#ac-05-worker-payroll-breakdown)
- [AC-06: Add Adjustment](#ac-06-add-adjustment)
- [AC-07: Record Advance Payment](#ac-07-record-advance-payment)
- [AC-08: Finalize Period — Confirmation](#ac-08-finalize-period--confirmation)
- [AC-09: Production Records Review](#ac-09-production-records-review)

### Director Flow
- [D-01: Director Dashboard](#d-01-director-dashboard)
- [D-02: Workers List](#d-02-workers-list)
- [D-03: Create / Edit Worker](#d-03-create--edit-worker)
- [D-04: Worker Profile (Director View)](#d-04-worker-profile-director-view)
- [D-05: Operations Catalog](#d-05-operations-catalog)
- [D-06: Create / Edit Operation](#d-06-create--edit-operation)
- [D-07: Production Report](#d-07-production-report)

### Shared Screens
- [S-01: Notifications](#s-01-notifications)
- [S-02: My Profile](#s-02-my-profile)
- [S-03: Change PIN](#s-03-change-pin)
- [S-04: Settings (Director)](#s-04-settings-director)

---

## AUTH FLOW

---

### A-01: Login Screen

**Route:** `/login`  
**Access:** Public (unauthenticated)  
**Goal:** User authenticates with phone number and 4-digit PIN.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App logo | TexERP logo, 80dp, centered, top 20% of screen |
| 2 | Headline | "Kirish" (uz) / "Войти" (ru) — headline1, 24sp |
| 3 | Phone input | Label: "Telefon raqam" · Prefix: "+998" (fixed) · Keyboard: numeric · Placeholder: "__ ___ __ __" |
| 4 | PIN input | 4 circles · Appears after valid phone entered · Keyboard: numeric pad |
| 5 | Login button | Primary button · "Kirish" / "Войти" · Disabled until phone + 4 PIN digits |
| 6 | Forgot PIN link | Ghost button · "PIN kodini unutdingizmi?" · Below login button |
| 7 | Language toggle | Top-right corner · "UZ / RU" toggle |

#### States

| State | Trigger | Display |
|-------|---------|---------|
| Initial | Screen opens | Phone input focused, PIN hidden |
| Phone entered | 9 digits entered | PIN circles appear with animation (slide down, 200ms) |
| PIN entering | User taps digits | Circles fill one by one |
| Loading | Login button tapped | Button shows spinner; inputs disabled |
| Success | Auth successful | Navigate → role-based home screen (fade transition) |
| Wrong PIN | Server returns 401 | PIN circles shake animation · Circles clear · TOAST ❌ "Noto'g'ri PIN kod" |
| Account locked | 5 failed attempts | TOAST ❌ "Hisob 15 daqiqaga bloklandi" · Login button disabled with timer |
| Unregistered phone | Server returns 404 | TOAST ❌ "Bu raqam ro'yxatdan o'tmagan" · Phone field error border |

#### Actions

| Action | Result |
|--------|--------|
| TAP language toggle | Switch all UI text between Uzbek and Russian; persist choice |
| TAP "Forgot PIN" | → A-02 |
| SUBMIT (login button or last PIN digit) | Call `POST /auth/login`; handle states above |
| TAP screen background | Dismiss keyboard |

#### Validations

| Field | Rule | Error |
|-------|------|-------|
| Phone | Must be 9 digits (without +998 prefix) | Red border, no message (visual only) |
| PIN | Must be exactly 4 digits | Button stays disabled |

---

### A-02: PIN Reset — Phone Entry

**Route:** `/pin-reset/phone`  
**Access:** Public  
**Goal:** User enters phone number to receive OTP.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | Back button | arrow_back → A-01 |
| 2 | Title | "PIN kodni tiklash" — headline2 |
| 3 | Subtitle | "Raqamingizga SMS kod yuboramiz" — body2, secondary |
| 4 | Phone input | Same as A-01 |
| 5 | Send OTP button | Primary · "SMS kod yuborish" · Disabled until 9 digits |

#### States

| State | Display |
|-------|---------|
| Loading | Button spinner; "Yuborilmoqda..." |
| Success | → A-03 |
| Phone not found | TOAST ❌ "Bu raqam tizimda yo'q" |
| Rate limited | TOAST ⚠️ "Ko'p urinish. 2 daqiqadan keyin qaytaring" |

---

### A-03: PIN Reset — OTP Verification

**Route:** `/pin-reset/otp`  
**Access:** Public (has phone token from A-02)  
**Goal:** User enters the 6-digit SMS code.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | Back button | → A-02 |
| 2 | Title | "SMS kodni kiriting" — headline2 |
| 3 | Phone display | "+998 XX XXX XX XX" (masked) — body2, secondary |
| 4 | OTP input | 6 boxes, each 1 digit, auto-advance on entry |
| 5 | Confirm button | Primary · "Tasdiqlash" · Disabled until 6 digits |
| 6 | Resend OTP | Ghost button · "Kodni qayta yuborish (2:00)" · Countdown timer · Active after 2 min |
| 7 | Countdown timer | Shows remaining time in MM:SS format |

#### States

| State | Display |
|-------|---------|
| Loading | Button spinner |
| Success | → A-04 |
| Wrong OTP | Boxes shake + clear · TOAST ❌ "Noto'g'ri kod" |
| OTP expired | TOAST ❌ "Kod muddati o'tdi. Qayta yuboring" · All boxes clear |
| 3 wrong attempts | TOAST ❌ "Ko'p xato. Qaytadan boshlang" → A-02 |

---

### A-04: PIN Reset — New PIN

**Route:** `/pin-reset/new-pin`  
**Access:** Public (has verified OTP token)  
**Goal:** User sets a new 4-digit PIN.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | Title | "Yangi PIN kod" — headline2 |
| 2 | Subtitle | "4 xonali raqam kiriting" — body2, secondary |
| 3 | PIN input (new) | 4 circles · "Yangi PIN" label |
| 4 | PIN input (confirm) | 4 circles · "Tasdiqlash" label · Appears after 1st PIN complete |
| 5 | Set PIN button | Primary · "PIN kodini o'rnatish" · Disabled until both match |
| 6 | PIN mismatch indicator | Red text below confirm circles: "PIN kodlar mos emas" |

#### States

| State | Display |
|-------|---------|
| Loading | Button spinner |
| Success | TOAST ✅ "PIN kod muvaffaqiyatli o'zgartirildi" → Login screen |
| Server error | TOAST ❌ "Xatolik yuz berdi. Qaytadan urinib ko'ring" |

#### Validation

- Both PINs must match (real-time comparison as second PIN is typed)
- PIN cannot be "1111", "1234", "0000" (weak PIN block — TOAST ⚠️ "Oddiy PIN koddan foydalanmang")

---

## WORKER FLOW

---

### W-01: Worker Home

**Route:** `/worker/home`  
**Access:** WORKER role  
**Goal:** Worker sees today's submission summary and quick-access to submit more work.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Salom, [First Name] 👋" — headline3 · Notification bell (right) |
| 2 | Offline banner | Below app bar · Visible only when offline |
| 3 | Today's Summary Card | Large card · gradient background |
| 3a | | Total pieces today — display size, bold |
| 3b | | Estimated earnings today — amount style |
| 3c | | Record count: "X ta yozuv" — body2 |
| 4 | Status breakdown row | 3 chips: ✅ X Tasdiqlandi · ⏳ X Kutmoqda · ❌ X Rad etildi |
| 5 | Recent Records section | "Oxirgi yozuvlar" heading · Last 5 records as mini-cards |
| 5a | Mini-record card | Operation name · Date · Quantity · Status badge |
| 6 | FAB | Center-bottom · "Ishni kiritish" · add_circle icon |
| 7 | Bottom Navigation | Home (active) · Submit · History |

#### States

| State | Display |
|-------|---------|
| Loading | Skeleton for Summary Card + 3 mini-card skeletons |
| No records today | Summary Card shows "0 dona" · "Bugun hali ish kiritilmagan" caption |
| Has records | Full summary as described |
| Has pending notification | Bell icon shows red badge with count |
| Offline | Offline banner visible · Cached data shown with "Oxirgi yangilanish: HH:MM" caption |

#### Actions

| Action | Result |
|--------|--------|
| TAP FAB | → W-02 (Submit Production) |
| TAP notification bell | → S-01 (Notifications) |
| TAP mini-record card | → W-05 (Record Detail) |
| TAP "Barchasi" (view all) | → W-04 (Worker History) |
| TAP History tab | → W-04 |

---

### W-02: Submit Production

**Route:** `/worker/submit`  
**Access:** WORKER role  
**Goal:** Worker records completed work (operation + quantity + date).

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Ish kiritish" — headline3 · Back arrow |
| 2 | Offline banner | If offline: "Oflayn — saqlangandan keyin yuboriladi" |
| 3 | Operation selector | Dropdown field · "Operatsiyani tanlang" placeholder |
| 3a | | Shows recently used (last 3) at top, separated by divider |
| 3b | | Opens Operation Selector Bottom Sheet on tap |
| 4 | Quantity input | Special large input · "Miqdor" label · Unit suffix ("dona") · [−] [+] buttons |
| 5 | Date field | Date picker field · Default: today · Label: "Ish sanasi" |
| 6 | Price preview | Auto-calculated, read-only: "Narx: 450 so'm × 85 = 38,250 so'm" — body2, secondary |
| 7 | Bundle code field | Optional text field · "Partiya kodi (ixtiyoriy)" · Collapsed by default |
| 8 | Submit button | Primary · "Yuborish" · Disabled until operation + quantity (≥1) selected |

#### States

| State | Display |
|-------|---------|
| Loading (initial) | Operations list loading skeleton while catalog fetches |
| Ready | All fields ready for input |
| Duplicate warning | Before submit: DIALOG "Bu operatsiya bugun allaqachon kiritilgan. Baribir yuborishni xohlaysizmi?" [Yuborish / Bekor qilish] |
| Submitting | Button shows "Yuborilmoqda..." spinner |
| Success (online) | → W-03 (Confirmation) |
| Success (offline) | → W-03 (Confirmation — offline variant) |
| Validation error | Field-level errors appear inline |
| Server error | TOAST ❌ "Xatolik yuz berdi. Qaytadan urinib ko'ring" |

#### Validations

| Field | Rule | Inline Error |
|-------|------|-------------|
| Operation | Must be selected | Field border turns red on submit attempt |
| Quantity | Between 1 and 9999 | "Miqdor 1 dan 9999 gacha bo'lishi kerak" |
| Date | Within back-date window | "Sana [X] kundan eski bo'lishi mumkin emas" |

#### Operation Selector Bottom Sheet

```
Header: "Operatsiyani tanlang" + search bar
Recently used section (max 3): labeled "OXIRGI ISHLATIGANLAR"
All operations: grouped by category (if configured)
Each row: [Operation name — body1] [Price — body2, right, secondary]
Search: filters in real-time as user types
Empty search: "Topilmadi" with "Qidiruvni tozalash" ghost button
Tap on operation: closes sheet, populates field, focuses quantity input
```

#### Actions

| Action | Result |
|--------|--------|
| TAP [−] button | Quantity decreases by 1 (min: 1) |
| TAP [+] button | Quantity increases by 1 (max: 9999) |
| HOLD [−] or [+] | Rapid increment/decrement (10/sec after 500ms hold) |
| TAP date field | Opens date picker bottom sheet |
| TAP "Partiya kodi" expand | Reveals bundle code text field |
| TAP Submit | Validate → check duplicate → submit |

---

### W-03: Submit Confirmation

**Route:** `/worker/submit/confirmation` (or modal over W-02)  
**Access:** WORKER role  
**Goal:** Confirm submission was received; encourage next submission.

#### Layout

```
[Full-screen success overlay — fades in over W-02]

Center of screen:
  [check_circle icon — 80dp — Success green — scale animation 0→1.2→1.0]
  [Title: "Yuborildi!" — headline1, Success green]
  [Subtitle: "85 dona Yoqa tikish" — body1, secondary]
  [Amount: "38,250 so'm" — amountLarge]
  [Date: "16 iyul 2026" — caption, secondary]

Status chip:
  [⏳ Tasdiqlash kutilmoqda] — Warning amber chip

Bottom buttons:
  [Primary: "Yana kiritish"] — goes back to W-02, resets form
  [Ghost: "Bosh sahifaga"] — → W-01

[Offline variant — same but:]
  [cloud_upload icon instead of check_circle — Blue]
  [Title: "Saqlandi!"]
  [Subtitle: "Internet aloqasi tiklanganda yuboriladi"]
  [No amount shown — "Narx internet aloqasida ko'rinadi"]
```

#### Auto-dismiss

Screen auto-navigates to W-01 after 5 seconds if user takes no action (countdown shown: "5 soniyada yopiladi").

---

### W-04: Worker History

**Route:** `/worker/history`  
**Access:** WORKER role  
**Goal:** Worker reviews all their production records with status.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Tarixim" — headline3 |
| 2 | Filter bar | Horizontal scroll · Date filter chips: "Bugun" · "Bu hafta" · "Bu oy" · "Barchasi" |
| 3 | Status filter | Horizontal chips: "Barchasi" · "Kutmoqda" · "Tasdiqlandi" · "Rad etildi" |
| 4 | Summary row | Total: "X dona · X,XXX,XXX so'm" — small stat below filters |
| 5 | Records list | Sorted: newest first · Production Record Cards (see Design System 10.2) |
| 6 | Load more | Pagination: auto-load on scroll to bottom (25 items per page) |

#### States

| State | Display |
|-------|---------|
| Loading | 5 skeleton record cards |
| Empty (no records) | Empty state: "Yozuvlar yo'q" · "Ish kiriting!" · FAB |
| Empty (filtered) | "Bu filtr bo'yicha yozuv yo'q" · "Filtrni tozalash" ghost button |
| Loaded | List with records |
| Offline | Offline banner · Cached records shown |

#### Record Card Content (in list)

```
Left status bar (4dp wide, colored by status)
Content:
  Row 1: [Operation name — body1, bold] [Quantity — 20sp, bold, right]
  Row 2: [Date — caption, secondary] [Unit — caption, secondary, right]
  Row 3: [Status badge] [Amount — body2, right, primary color if approved]
```

#### Actions

| Action | Result |
|--------|--------|
| TAP filter chip | Apply filter; list refreshes |
| TAP record card | → W-05 (Record Detail) |
| SWIPE down | Pull-to-refresh |

---

### W-05: Record Detail (Worker View)

**Route:** `/worker/history/:recordId`  
**Access:** WORKER role (own records only)  
**Goal:** Worker sees full details of one record and its approval history.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Yozuv tafsiloti" · Back arrow |
| 2 | Status hero | Large status badge (40dp height pill) centered at top |
| 3 | Operation card | Operation name · Date · Quantity · Unit Price (snapshot) · Total = quantity × price |
| 4 | Price note | "Narx yuborilgan vaqtdagi: 450 so'm" — caption, secondary |
| 5 | Timeline section | "Tarix" heading · Vertical timeline of all events |
| 5a | Timeline items | Each: [Icon] [Action label] [Actor name + role] [Timestamp] |
| 6 | Rejection reason | Shown in red callout box if status = REJECTED: "Rad etish sababi: [reason]" |
| 7 | Correction note | Shown in amber box if quantity was corrected: "Miqdor [X] → [Y] o'zgartirildi: [comment]" |
| 8 | Bundle code | Shown if present: "Partiya kodi: [code]" |

#### Timeline Items Examples

```
🟢 CREATED    "Siz yubordin"                           "16 iyul, 10:30"
⏳ PENDING    "Tasdiqlash kutilmoqda"                  —
✅ APPROVED   "Akbar Toshmatov (Brigadir) tasdiqladi"  "16 iyul, 11:15"

or:

🟢 CREATED    "Siz yubordin"                           "16 iyul, 10:30"
✏️ CORRECTED  "Akbar Toshmatov miqdorni o'zgartirdi"   "16 iyul, 11:15"
              "85 → 72 | Izoh: Ikkinchi smenada kiriterilgan"
✅ APPROVED   "Tasdiqlandi"                            "16 iyul, 11:15"
```

#### States

| State | Display |
|-------|---------|
| Loading | Skeleton loader |
| PENDING | Amber hero status · Timeline shows only CREATED |
| APPROVED | Green hero · Full timeline |
| REJECTED | Red hero · Red rejection reason box · Full timeline |

---

### W-06: My Payroll

**Route:** `/worker/payroll`  
**Access:** WORKER role  
**Goal:** Worker views their finalized payroll for each period.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Ish haqim" |
| 2 | Period selector | Horizontal scroll list of period name chips · Most recent first |
| 3 | Payroll Summary Card | Gradient card · Period name · Final pay amount (large) · Status badge |
| 4 | Breakdown section | Row items: Gross earnings · Bonus · Deduction · Advance · Final |
| 5 | Record count | "X ta tasdiqlangan yozuv asosida" — caption, secondary |

#### States

| State | Display |
|-------|---------|
| No finalized periods | Empty state: "Hisob-kitob hali yakunlanmagan" · "Hisobingiz tayyor bo'lganda bu yerda ko'rinadi" |
| Period not yet finalized | "Bu davr hali yakunlanmagan" chip |
| Finalized | Full breakdown visible |

---

## FOREMAN FLOW

---

### F-01: Foreman Home

**Route:** `/foreman/home`  
**Access:** FOREMAN role  
**Goal:** Foreman sees team's current state and pending actions at a glance.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Salom, [First Name]" · Notification bell |
| 2 | Offline banner | |
| 3 | Pending count card | Large emphasis card · "⏳ [N] ta yozuv kutilmoqda" · Primary-tinted background · TAP → F-02 |
| 4 | Today's team summary | "Bugun jamoam:" · Total pieces · Worker count active today |
| 5 | Top performers row | Horizontal scroll · Up to 5 worker mini-cards showing name + today's quantity |
| 6 | Recent approvals | Last 5 approval actions taken by this foreman (with timestamp) |
| 7 | Bottom Nav | Home · Kutmoqda · Jamoa |

#### States

| State | Display |
|-------|---------|
| Loading | Skeleton |
| 0 pending | Pending card shows "✅ Hammasi tasdiqlangan!" — green tint |
| N > 0 pending | Pending card pulses subtly (gentle opacity animation) |
| Offline | Offline banner · Cached counts with stale indicator |

#### Actions

| Action | Result |
|--------|--------|
| TAP pending count card | → F-02 |
| TAP worker mini-card | → Worker profile (read-only foreman view) |
| TAP notification bell | → S-01 |

---

### F-02: Pending Approval Queue

**Route:** `/foreman/pending`  
**Access:** FOREMAN role  
**Goal:** Foreman reviews and approves/rejects pending production records from their team.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Tasdiqlash navbati ([N])" · "Barchasi" action right |
| 2 | Sort bar | Sort chips: "Yangi avval" (default) · "Eski avval" · "Ishchi bo'yicha" |
| 3 | Records list | Production Record Cards (Design System 10.2) in PENDING state |
| 4 | Select All button | Appears in multi-select mode: "Barchasini tanlash" |
| 5 | Bulk action bar | Bottom bar in multi-select: "[N] tanlandi · [✅ Barchasini tasdiqlash]" |
| 6 | Multi-select FAB | Replaced by bulk action bar in multi-select mode |

#### States

| State | Display |
|-------|---------|
| Loading | 4 skeleton record cards |
| Empty queue | Empty state: "Hammasi tasdiqlangan! 🎉" · Secondary text: "Yangi yozuvlar tushganda bu yerda ko'rsatiladi" |
| Has records | Full list |
| Multi-select active | Checkboxes appear on all cards · Bulk action bar slides up from bottom |

#### Actions on Record Cards

| Action | Result |
|--------|--------|
| TAP record card | → F-03 (Record Detail) |
| SWIPE RIGHT on card | Quick approve: green reveal with ✅ icon · DIALOG "Tasdiqlaysizmi?" [Ha / Bekor] |
| SWIPE LEFT on card | Quick reject: red reveal with ❌ icon → F-04 (reason selection) |
| LONG PRESS card | Enter multi-select mode; card becomes selected |
| TAP checkbox (multi-select) | Toggle selection |

#### Toasts

| Event | Toast |
|-------|-------|
| Single approve success | TOAST ✅ "[Worker name]ning yozuvi tasdiqlandi" |
| Single reject success | TOAST ✅ "Yozuv rad etildi" |
| Bulk approve success | TOAST ✅ "[N] ta yozuv tasdiqlandi" |
| Network error | TOAST ❌ "Xatolik. Qaytadan urinib ko'ring" |

---

### F-03: Record Detail (Foreman View)

**Route:** `/foreman/records/:recordId`  
**Access:** FOREMAN role (own team records only)  
**Goal:** Foreman reviews one record in detail before deciding to approve, reject, or correct.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Yozuv tafsiloti" · Back |
| 2 | Worker info card | Avatar initial · Worker name · Worker code · Department |
| 3 | Record details | Operation name · Date · Quantity submitted · Price snapshot |
| 4 | Calculated amount | quantity × price — prominent display |
| 5 | Bundle code | If present |
| 6 | Suspicious flag | If `is_suspicious = true`: amber warning banner "⚠️ Shubhali miqdor aniqlanди" |
| 7 | Action section | Three buttons at bottom (sticky) |
| 7a | | [✅ Tasdiqlash] — Success green primary button |
| 7b | | [✏️ To'g'irlab tasdiqlash] — Secondary button |
| 7c | | [❌ Rad etish] — Danger outlined button |
| 8 | Timeline | Same as W-05 — shows previous state changes |

#### Actions

| Action | Result |
|--------|--------|
| TAP Tasdiqlash | DIALOG "Tasdiqlaysizmi? [Quantity] dona" [Ha / Bekor] → approve |
| TAP To'g'irlab tasdiqlash | → F-05 |
| TAP Rad etish | → F-04 |

#### After Approve

```
Record card animates out (slide right)
TOAST ✅ "Tasdiqlandi: [quantity] dona"
Navigate back to F-02; list updates
```

---

### F-04: Reject — Reason Selection

**Route:** Bottom sheet over F-03  
**Access:** FOREMAN role  
**Goal:** Foreman selects or enters a rejection reason (mandatory).

#### Components

```
Bottom Sheet (non-dismissible — user must choose):
  Handle bar
  Title: "Rad etish sababi" — headline3
  
  Reason chips (select one):
    [Noto'g'ri miqdor]  [Soxta yozuv]
    [Noto'g'ri operatsiya]  [Ikki marta kiritilgan]
    [Boshqa sabab ↓]
  
  "Boshqa sabab" selected → shows free text input field
    Placeholder: "Sababni yozing..."
    Min 10 characters required
  
  [❌ Rad etish] — Danger primary button (enabled only when reason selected)
  [Bekor qilish] — Ghost button
```

#### Actions

| Action | Result |
|--------|--------|
| TAP reason chip | Chip selects (single-select); button enables |
| TAP "Boshqa sabab" | Free text field appears |
| TAP Rad etish | Call API; on success: dismiss sheet + record slides away from F-02 list + TOAST ✅ "Rad etildi" |

---

### F-05: Correct & Approve

**Route:** Bottom sheet over F-03  
**Access:** FOREMAN role  
**Goal:** Foreman changes the quantity and approves with a mandatory explanation.

#### Components

```
Bottom Sheet (non-dismissible):
  Handle bar
  Title: "To'g'irlab tasdiqlash" — headline3
  
  Original quantity display:
    "Ishchi kiritgan: [N] dona" — body2, secondary, strikethrough
  
  New quantity input:
    Large quantity input (Design System 9.2)
    Label: "To'g'ri miqdor"
    Pre-filled with original quantity
    [−] [+] buttons
  
  Comment input (mandatory):
    Multi-line text field
    Label: "Izoh (majburiy)"
    Placeholder: "Nima uchun miqdor o'zgartirildi?"
    Min 10 characters
    Character counter: "0/200"
  
  Calculated amount preview:
    "Yangi miqdor: [N] dona × 450 so'm = X,XXX so'm"
  
  [✅ Tasdiqlash] — Primary button (disabled until: new qty valid + comment ≥ 10 chars)
  [Bekor qilish] — Ghost button
```

#### Validations

| Field | Rule | Error |
|-------|------|-------|
| New quantity | 1–9999 and different from original (if same, just use approve) | "Miqdor o'zgarmagan. Oddiy tasdiqlashdan foydalaning" |
| Comment | Min 10 characters | Character counter turns red below 10 |

#### Actions

| Action | Result |
|--------|--------|
| TAP Tasdiqlash | Call correct-and-approve API; on success: sheet closes + record gone from list + TOAST ✅ "To'g'irlandi va tasdiqlandi" |

---

### F-06: Bulk Approve

**Route:** Multi-select mode in F-02  
**Access:** FOREMAN role  
**Goal:** Foreman approves multiple records in one action.

#### Flow

```
1. Foreman long-presses any record → multi-select mode activates
2. Top app bar changes to: "← [N] tanlandi · Barchasini tanlash (right)"
3. Checkboxes appear on all cards
4. Bottom bulk action bar slides up:
   [✅ Barchasini tasdiqlash ([N] ta)]
5. Foreman selects more records (or taps "Barchasini tanlash" for all)
6. TAP bulk approve button →

DIALOG:
  "Tasdiqlaysizmi?"
  "[N] ta yozuv tasdiqlanadi"
  [Ha, barchasini tasdiqlash] (Primary)
  [Bekor qilish] (Ghost)

7. On confirm: Spinner in dialog; "Tasdiqlanmoqda..."
8. Success: Dialog closes; cards animate out; TOAST ✅ "[N] ta yozuv tasdiqlandi"
9. Multi-select mode exits automatically
```

#### Limits

- Maximum 50 records per bulk approve (enforced by UI — "Barchasini tanlash" caps at 50)
- If >50 in queue, a notice appears: "Ko'pi bilan 50 ta tanlash mumkin"

---

### F-07: Team Performance

**Route:** `/foreman/team`  
**Access:** FOREMAN role  
**Goal:** Foreman sees each worker's production totals for today and the current period.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Mening jamoam" |
| 2 | Period selector | "Bugun" / "Bu hafta" / "Bu oy" filter |
| 3 | Team total row | "Jami: [N] dona · [N] ishchi faol" — stat row |
| 4 | Worker list | Sorted by production quantity (highest first) |
| 4a | Worker row | Rank # · Avatar initial · Name · Total quantity · Total earnings estimate |
| 4b | | Progress bar (relative to top performer = 100%) |
| 5 | TAP worker row | → Worker production history (read-only foreman view) |

---

## ACCOUNTANT FLOW

---

### AC-01: Accountant Home

**Route:** `/accountant/home`  
**Access:** ACCOUNTANT role  
**Goal:** Accountant sees current period status and production summary.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Buxgalteriya" · notification bell |
| 2 | Active period card | "Joriy davr: [Period name]" · Status badge · Days remaining |
| 3 | Records summary | "Tasdiqlangan: [N] · Kutilmoqda: [N]" — warning if pending > 0 |
| 4 | Quick actions | [📊 Hisobot] [💰 Hisob-kitob] [📥 Eksport] |
| 5 | Bottom Nav | Bosh sahifa · Ishlab chiqarish · Ish haqi · Hisobot |

---

### AC-02: Payroll Periods List

**Route:** `/accountant/payroll`  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** View all payroll periods; create new one.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Hisob davrlari" · [+ Create] button (right) |
| 2 | Active period banner | If exists: highlighted card at top — current period with status |
| 3 | Periods list | Sorted newest first · Period cards |
| 4 | Period card | Period name · Date range · Status badge · Worker count · Total amount |

#### Period Card Status Badges

```
DRAFT:       ⚪ "Tayyorlanmoqda"
CALCULATING: 🔄 "Hisoblanmoqda..." (spinner on badge)
CALCULATED:  🟡 "Ko'rib chiqilsin"
FINALIZED:   🔒 "Yakunlangan" (lock icon)
CANCELLED:   ✖️ "Bekor qilingan"
```

#### Actions

| Action | Result |
|--------|--------|
| TAP [+] Create | → AC-03 |
| TAP period card | → AC-04 |

#### States

| State | Display |
|-------|---------|
| Empty | "Hisob davrlari yo'q" · [+ Yangi davr yaratish] primary button |
| Loading | 3 skeleton period cards |

---

### AC-03: Create Payroll Period

**Route:** `/accountant/payroll/create`  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Define a new payroll period's name and date range.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Yangi davr" · Back |
| 2 | Period name field | Text input · Placeholder: "Masalan: Iyul 2026 — 1-yarm" · Auto-suggested based on today's date |
| 3 | Start date | Date picker · Default: 1st of current month or 16th (alternating) |
| 4 | End date | Date picker · Default: 15th or last day of month |
| 5 | Preview | "Bu davr uchun X ta tasdiqlangan yozuv mavjud" — real-time count |
| 6 | Overlap warning | If dates overlap existing period: red warning banner |
| 7 | Create button | Primary · "Davr yaratish" |

#### Validations

| Field | Rule | Error |
|-------|------|-------|
| Name | Non-empty | "Davr nomini kiriting" |
| Date range | End > Start | "Tugash sanasi boshlanish sanasidan keyin bo'lishi kerak" |
| Overlap | No overlap with existing periods | Red banner: "Bu sanalar [Period name] bilan to'qnashadi" · Button disabled |

---

### AC-04: Period Detail — Overview

**Route:** `/accountant/payroll/:periodId`  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Central hub for one payroll period — review, adjust, finalize.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "[Period name]" · Back · More menu (Cancel period — DRAFT only) |
| 2 | Status card | Large status banner · Period dates · Worker count · Total amount (if calculated) |
| 3 | Pending warning | If pending records exist: amber banner "⚠️ [N] ta yozuv hali tasdiqlanmagan" |
| 4 | Action buttons | Context-sensitive — see below |
| 5 | Workers list | Each worker row: Name · Pieces · Gross earnings · Adjustments indicator |
| 6 | Totals footer | Sticky at bottom: Total gross · Total final |

#### Action Buttons by Status

| Period Status | Buttons Shown |
|:------------:|---------------|
| DRAFT | [▶️ Hisob-kitobni boshlash] (Primary) |
| CALCULATING | [⏳ Hisoblanmoqda...] (disabled, spinner) |
| CALCULATED | [✅ Yakunlash] (Primary) · [🔄 Qayta hisoblash] (Secondary) |
| FINALIZED | [📥 Excel yuklab olish] (Primary) · [🔒 Yakunlangan] (disabled badge) |

#### Actions

| Action | Result |
|--------|--------|
| TAP Start Calculation | DIALOG confirm → queue job → status → CALCULATING → poll every 3s for CALCULATED |
| TAP worker row | → AC-05 (Worker Breakdown) |
| TAP Finalize | → AC-08 (Finalize confirmation) |
| TAP Download Excel | Queue export job → TOAST ✅ "Excel tayyorlanmoqda..." → notification when ready |

#### Calculation Progress

While status = CALCULATING:
```
Progress bar shown (indeterminate)
Text: "Hisoblanmoqda... [Aziz: 45/100]"
Auto-polls every 3 seconds
Cannot navigate away (or warning dialog if back pressed)
```

---

### AC-05: Worker Payroll Breakdown

**Route:** `/accountant/payroll/:periodId/workers/:workerId`  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Review one worker's complete payroll breakdown; add adjustments.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "[Worker name]" · Back |
| 2 | Worker info | Avatar · Name · Code · Department |
| 3 | Summary card | Gradient card · Final pay amount (large) · Period name |
| 4 | Breakdown list | Line items: |
| 4a | | Gross earnings: "X dona × avg narx = X,XXX,XXX so'm" |
| 4b | | Per-operation breakdown (expandable): Operation name · Quantity · Price · Subtotal |
| 4c | | Bonuses: each bonus as a line (reason + amount) |
| 4d | | Deductions: each deduction (reason + amount, negative) |
| 4e | | Advances: each advance (date + amount, negative) |
| 4f | | Carry-forward: if any (amount, labeled "Oldingi qarz") |
| 4g | | **Final pay: large, bold** |
| 5 | Add adjustment button | Secondary · "Bonus/Chegirma qo'shish" |
| 6 | Add advance button | Secondary · "Avans qo'shish" |
| 7 | Records tab | Switch to see individual production records for this worker this period |

#### States

| State | Display |
|-------|---------|
| DRAFT period | Calculations not run yet — "Hisob-kitob hali amalga oshirilmagan" |
| FINALIZED | All amounts shown; add buttons hidden; "🔒 Yakunlangan" banner |

---

### AC-06: Add Adjustment

**Route:** Bottom sheet over AC-05  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Add a bonus or deduction with a mandatory reason.

#### Components

```
Bottom Sheet (non-dismissible):
  Title: "Bonus / Chegirma qo'shish"
  
  Type selector (segmented control):
    [+ Bonus] [- Chegirma]
    Active: green (bonus) / red (deduction)
  
  Amount input:
    Label: "Miqdor (so'm)"
    Keyboard: numeric
    Placeholder: "0"
    Max: 10,000,000
  
  Reason field (mandatory):
    Label: "Sabab"
    Placeholder: "Nega? (masalan: Rejim uchun bonus)"
    Min: 5 characters
    Max: 200 characters
  
  Amount preview:
    "Yakuniy ish haqi: [old] → [new]" (updates live)
  
  [Saqlash] — Primary button (enabled when amount > 0 AND reason filled)
  [Bekor qilish] — Ghost
```

---

### AC-07: Record Advance Payment

**Route:** Bottom sheet over AC-05 or AC-04  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Record cash advance given to a worker.

#### Components

```
Bottom Sheet:
  Title: "Avans qo'shish"
  
  Worker (if from AC-04): Dropdown to select worker
  Worker (if from AC-05): Fixed — shows worker name
  
  Amount: Same as AC-06 amount input
  
  Date: Date picker (default: today, within current period)
  
  Note (optional):
    Placeholder: "Izoh (ixtiyoriy)"
  
  Preview:
    "Bu avans [worker name]ning ish haqidan chiqariladi"
  
  [Saqlash] — Primary
  [Bekor qilish] — Ghost
```

---

### AC-08: Finalize Period — Confirmation

**Route:** Full-screen modal over AC-04  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Final check before locking the payroll period forever.

#### Layout

```
[Full-screen overlay — dark background]

Center card:
  🔒 icon (48dp, Primary violet)
  
  Title: "Davrni yakunlash"
  
  Warning message (amber callout box):
    "⚠️ Bu amalni qaytarib bo'lmaydi. Yakunlangandan so'ng
     hech qanday o'zgarish kiritib bo'lmaydi."
  
  Summary:
    Period: [Period name]
    Workers: [N] ta ishchi
    Total final pay: [X,XXX,XXX so'm]
    Records locked: [N] ta yozuv
  
  Pending records warning (if any):
    Red callout: "⛔ [N] ta yozuv hali tasdiqlanmagan va
    hisobga kirmaydi. Davom etasizmi?"
  
  Confirm checkbox:
    ☐ "Men barcha ma'lumotlarni tekshirdim va davr yakunlashga tayyorman"
  
  [🔒 Ha, yakunlash] — Danger primary button (enabled ONLY when checkbox checked)
  [Bekor qilish] — Ghost button
```

#### After Confirm

```
Loading overlay: "Yakunlanmoqda..."
On success:
  - Period status → FINALIZED
  - All workers notified via push notification
  - TOAST ✅ "Davr yakunlandi. [N] ta ishchiga bildirishnoma yuborildi"
  - Navigate back to AC-04 (now shows FINALIZED state)
```

---

### AC-09: Production Records Review

**Route:** `/accountant/production`  
**Access:** ACCOUNTANT, DIRECTOR  
**Goal:** Accountant reviews all production records with filters.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Ishlab chiqarish" |
| 2 | Filter row | Date range · Worker filter · Status filter · Operation filter |
| 3 | Summary bar | "X ta yozuv · X dona · X,XXX,XXX so'm" |
| 4 | Records list | Same Production Record Cards but with worker name visible |
| 5 | Export button | Top right: download icon → queue Excel export |

---

## DIRECTOR FLOW

---

### D-01: Director Dashboard

**Route:** `/director/home`  
**Access:** DIRECTOR role  
**Goal:** Real-time factory performance overview.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Bugungi kun" · Date · Notification bell |
| 2 | Offline banner | |
| 3 | Stat cards row | Horizontal scroll — 4 stat cards (Design System 10.3): |
| 3a | | Bugungi mahsulot: [N] dona |
| 3b | | Tasdiqlash navbati: [N] ta |
| 3c | | Faol ishchilar: [N] / [Total] |
| 3d | | Joriy davr holati: [status badge] |
| 4 | Top performers | "Eng yaxshi ishchilar — bugun" · Horizontal scroll mini-cards |
| 5 | Pending alert | If pending > 10: amber banner "⚠️ [N] ta yozuv kutilmoqda" |
| 6 | Quick links | [👥 Ishchilar] [⚙️ Operatsiyalar] [📊 Hisobot] |
| 7 | Bottom Nav | Bosh sahifa · Ishlab chiqarish · Ish haqi · Sozlamalar |

---

### D-02: Workers List

**Route:** `/director/workers`  
**Access:** DIRECTOR role  
**Goal:** Manage all workers and foremen in the factory.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Ishchilar ([N])" · [+ Add] right button |
| 2 | Search bar | Always visible · "Ism yoki koddan qidiring" |
| 3 | Role filter | Chips: "Barchasi" · "Ishchi" · "Brigadir" · "Buxgalter" |
| 4 | Status filter | Chips: "Faol" (default) · "Nofaol" |
| 5 | Worker list | Sorted alphabetically |
| 5a | Worker row | Avatar initial · Name · Code · Role badge · Department · Status indicator |
| 6 | TAP worker | → D-04 |

#### States

| State | Display |
|-------|---------|
| Empty | "Ishchilar yo'q" · [+ Ishchi qo'shish] primary button |
| Search no match | "Topilmadi: '[query]'" |

---

### D-03: Create / Edit Worker

**Route:** `/director/workers/create` or `/director/workers/:id/edit`  
**Access:** DIRECTOR role  
**Goal:** Register a new worker or update an existing one.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Ishchi qo'shish" / "Tahrirlash" · Back · Save (right, text button) |
| 2 | Avatar section | Large avatar placeholder · Camera icon overlay for photo upload |
| 3 | Full name | Text input · "To'liq ism" |
| 4 | Phone number | Phone input · "+998 XX XXX XX XX" |
| 5 | Worker code | Text input · "W-XXXX" format suggestion · "Ishchi kodi" |
| 6 | Role selector | Segmented: Ishchi · Brigadir · Buxgalter |
| 7 | Department (if Worker/Foreman) | Dropdown → select from department list |
| 8 | Foreman assignment (if Worker) | Dropdown → select foreman (filtered by same department) |
| 9 | Initial PIN | 4-digit PIN input · "Boshlang'ich PIN kod" · "Worker birinchi kirishda o'zgartirishi kerak" note |
| 10 | Save button | Primary · Full width at bottom |

#### Validations

| Field | Rule | Error |
|-------|------|-------|
| Full name | Non-empty, min 2 chars | "Ism kiritilmadi" |
| Phone | Valid format, unique in tenant | "Bu raqam allaqachon ro'yxatda bor" |
| Worker code | Unique in tenant | "Bu kod allaqachon ishlatilgan" |
| Initial PIN | 4 digits | "4 xonali PIN kiriting" |

#### After Save (Create)

```
TOAST ✅ "[Worker name] muvaffaqiyatli qo'shildi"
Navigate back to D-02
```

---

### D-04: Worker Profile (Director View)

**Route:** `/director/workers/:workerId`  
**Access:** DIRECTOR role  
**Goal:** View worker details; take management actions.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "[Worker name]" · Back · Edit (pencil icon) |
| 2 | Profile header | Large avatar · Name · Worker code · Role badge · Status |
| 3 | Details card | Phone · Department · Foreman · Join date |
| 4 | This month summary | Total pieces · Estimated earnings this period |
| 5 | Production history tab | List of recent records (read-only) |
| 6 | Actions (bottom, Director only) | |
| 6a | | [Tayinlashni o'zgartirish] — reassign foreman |
| 6b | | [Nofaol qilish] — Danger button (if ACTIVE) |
| 6c | | [Faollashtirish] — Success button (if DEACTIVATED) |

#### Deactivate Flow

```
TAP [Nofaol qilish] →
DIALOG:
  "⚠️ [Name]ni nofaol qilish"
  "[Name]ning barcha sessiyalari yopiladi va
   u tizimga kira olmaydi. Yozuvlari saqlanib qoladi."
  [Ha, nofaol qilish] (Danger)
  [Bekor qilish] (Ghost)

On confirm:
  TOAST ✅ "[Name] nofaol qilindi"
  Worker's status badge turns grey
  All their sessions revoked immediately
```

---

### D-05: Operations Catalog

**Route:** `/director/operations`  
**Access:** DIRECTOR role  
**Goal:** Manage all operations and their prices.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Operatsiyalar ([N])" · [+ Qo'shish] |
| 2 | Status filter | "Faol" (default) · "Nofaol" · "Barchasi" |
| 3 | Search | "Operatsiya nomidan qidiring" |
| 4 | Operations list | Grouped by category (if configured) |
| 4a | Operation row | Name · Code · Price · Unit · Status dot · Edit icon |

#### Operation Row Actions

| Action | Result |
|--------|--------|
| TAP row | → D-06 (Edit) |
| TAP edit icon | → D-06 (Edit) |
| SWIPE LEFT | Reveal: [Nofaol qilish] (red) |
| SWIPE RIGHT (inactive op) | Reveal: [Faollashtirish] (green) |

---

### D-06: Create / Edit Operation

**Route:** `/director/operations/create` or `/director/operations/:id/edit`  
**Access:** DIRECTOR role  
**Goal:** Add or modify an operation in the catalog.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Operatsiya qo'shish" / "Tahrirlash" · Back · Save |
| 2 | Operation name | Text input · "Masalan: Yoqa tikish" |
| 3 | Operation code | Text input · Optional · "OP-001" |
| 4 | Category | Dropdown · Optional · "Kategoriya tanlang" · [+ Yangi kategoriya] link |
| 5 | Unit | Segmented: [Dona] [Metr] [Juft] (default: Dona) |
| 6 | Unit price | Currency input · "Narx (so'm)" · Keyboard: numeric with decimal |
| 7 | Price change warning | If editing price on existing operation: amber box "⚠️ Bu narx faqat yangi yozuvlarga tatbiq etiladi. Avvalgi yozuvlar o'zgarmaydi." |
| 8 | Sort order | Number input · Optional · "Ro'yxatdagi tartib" |
| 9 | Save button | Primary |

#### Validations

| Field | Rule | Error |
|-------|------|-------|
| Name | Non-empty, unique in tenant | "Bu nom allaqachon mavjud" |
| Price | > 0 | "Narx 0 dan katta bo'lishi kerak" |

---

### D-07: Production Report

**Route:** `/director/reports`  
**Access:** DIRECTOR, ACCOUNTANT  
**Goal:** View and export production data by date range, worker, or operation.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Hisobot" |
| 2 | Date range | Two date pickers: "Dan" — "Gacha" · Default: this month |
| 3 | Grouping selector | Chips: "Ishchi bo'yicha" (default) · "Operatsiya bo'yicha" · "Kun bo'yicha" |
| 4 | Worker filter | Optional dropdown (All workers default) |
| 5 | Generate button | Secondary · "Hisoblash" |
| 6 | Results table | Scrollable data table |
| 7 | Export button | [📥 Excel yuklab olish] — Primary — enabled after results generated |

#### Table Columns (Worker grouping)

| Column | Data |
|--------|------|
| Ishchi | Name + code |
| Dona | Total approved pieces |
| Operatsiyalar | Distinct operation count |
| Jami (so'm) | Gross earnings estimate |

---

## SHARED SCREENS

---

### S-01: Notifications

**Route:** `/notifications`  
**Access:** All roles  
**Goal:** View all notifications; mark as read.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Bildirishnomalar" · "Barchasini o'qilgan deb belgilash" (text right, if unread exist) |
| 2 | Filter | "Barchasi" · "O'qilmagan" chips |
| 3 | Notifications list | Grouped by "Bugun" · "Kecha" · "Oldingi" |
| 3a | Notification row | Icon (type-specific) · Title · Body preview · Timestamp · Unread dot |

#### Notification Row Types

| Type | Icon | Color |
|------|------|-------|
| ENTRY_SUBMITTED | assignment | Primary |
| ENTRY_APPROVED | check_circle | Success green |
| ENTRY_REJECTED | cancel | Error red |
| PAYROLL_FINALIZED | payments | Primary |
| PAYROLL_CALCULATED | calculate | Info blue |
| SUSPICIOUS_ENTRY | warning_amber | Warning amber |

#### Actions

| Action | Result |
|--------|--------|
| TAP notification | Mark as read → navigate to related screen (record detail, period detail, etc.) |
| TAP "Barchasini o'qilgan" | All marked read; unread dots disappear |
| SWIPE LEFT on row | Mark as read (without navigating) |

#### States

| State | Display |
|-------|---------|
| Empty | Empty state: "Bildirishnomalar yo'q" · "Yangi voqealar bu yerda ko'rsatiladi" |
| Empty filter | "O'qilmagan bildirishnomalar yo'q ✓" |

---

### S-02: My Profile

**Route:** `/profile`  
**Access:** All roles  
**Goal:** View own account info; manage PIN; change language.

#### Components

| # | Component | Details |
|---|-----------|---------|
| 1 | App Bar | "Profilim" |
| 2 | Avatar section | Large avatar (initial or photo) · TAP to upload photo |
| 3 | Info card | Full name · Phone · Worker code · Role badge |
| 4 | Department card | Department · Foreman (if Worker) |
| 5 | Settings section | |
| 5a | | Language toggle: "UZ / RU" |
| 5b | | Dark mode toggle |
| 5c | | Notification preferences |
| 6 | Security section | |
| 6a | | [🔑 PIN kodni o'zgartirish] → S-03 |
| 7 | App info | Version number · App name |
| 8 | Logout button | Danger outlined · "Chiqish" |

#### Logout Flow

```
TAP Chiqish →
DIALOG:
  "Chiqasizmi?"
  "Hisobingizdan chiqasiz. Oflayn saqlangan yozuvlar yo'qolmaydi."
  [Ha, chiqish] (Danger)
  [Bekor qilish] (Ghost)

On confirm:
  Revoke session
  Clear local tokens
  Navigate to A-01 (Login)
```

---

### S-03: Change PIN

**Route:** `/profile/change-pin`  
**Access:** All roles  
**Goal:** User changes their own PIN.

#### Components

```
App Bar: "PIN kodni o'zgartirish" · Back

Step 1: Current PIN
  "Joriy PIN kodingizni kiriting" — body2
  PIN circles (4)

Step 2 (after correct current PIN): New PIN
  "Yangi PIN kodni kiriting" — body2
  PIN circles (4)
  Then confirm PIN entry

Save button: "Saqlash" (enabled after both match)
```

#### States / Validations

| Scenario | Behavior |
|---------|---------|
| Wrong current PIN | Shake + clear · "Noto'g'ri PIN" |
| New PINs don't match | Shake confirm circles · "PIN kodlar mos emas" |
| Weak PIN (1111, 1234, 0000) | TOAST ⚠️ "Oddiy PIN ishlatmang" |
| Success | TOAST ✅ "PIN kod o'zgartirildi" · Navigate back |

---

### S-04: Settings (Director)

**Route:** `/director/settings`  
**Access:** DIRECTOR role  
**Goal:** Configure factory-level settings.

#### Components

| # | Setting | Type | Description |
|---|---------|------|-------------|
| 1 | Factory name | Text input | Display name |
| 2 | Back-date window | Number input (1–7) | "Ishchi necha kun oldingi sanaga yozuv kirita oladi?" |
| 3 | Suspicious threshold | Number input | "X barobardан ortiq miqdor shubhali hisoblanadi" |
| 4 | Language | Dropdown: UZ / RU / UZ+RU | Factory default language |
| 5 | Departments section | List of departments + [+ Add dept] | Create/rename/deactivate departments |

#### Save behavior

Changes save on blur (each field individually) with a small "Saqlandi ✓" checkmark appearing next to the field.

---

## GLOBAL BEHAVIORS (All Screens)

### Pull-to-Refresh
All list screens support pull-to-refresh. Spinner appears at top. No toast on success (silent refresh).

### Deep Links from Push Notifications

| Notification Type | Deep Link Target |
|:----------------:|:----------------:|
| ENTRY_SUBMITTED | F-02 (Foreman Pending Queue) |
| ENTRY_APPROVED | W-05 (Record Detail, worker's own record) |
| ENTRY_REJECTED | W-05 (Record Detail, shows reason) |
| PAYROLL_FINALIZED | W-06 (My Payroll) |
| PAYROLL_CALCULATED | AC-04 (Period Detail) |

### Back Navigation

- All screens reached via push navigation show back arrow
- Root tab screens (Home, Queue, etc.) show no back arrow
- Physical Android back button follows Flutter Navigator stack
- On Login screen: back press = exit app (with "Chiqasizmi?" prompt on first press, exit on second)

### Session Expiry

If JWT expires mid-session:
```
Next API call returns 401 →
App shows full-screen modal:
  "Sessiya muddati tugadi"
  "Iltimos, qaytadan kiring"
  [Kirish] Primary button → A-01
  (Cannot dismiss — must re-login)
```

### Connectivity Change

```
Goes offline:
  Offline banner slides down (below app bar)
  Toast ⚠️ "Internet aloqasi uzildi"

Comes online:
  Offline banner slides up (disappears)
  Sync manager starts
  Sync banner briefly appears: "Sinxronlanmoqda..."
  After sync: TOAST ✅ "[N] ta yozuv yuborildi" (only if queue had items)
  Sync banner slides up
```

---

*End of UX Specification — Version 1.0.0*  
*Total screens specified: 30 screens + global behaviors*  
*Every interaction, state, message, and navigation path is defined.*  
*Flutter developer must not invent any behavior not documented here.*
