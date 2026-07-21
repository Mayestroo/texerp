# TexERP 30-Day Trial Acceptance & Evaluation Checklist

This checklist tracks key feature verification and acceptance criteria during the 30-day factory trial.

---

## 1. System Setup & Configuration
- [ ] Tenant created with correct currency (`UZS`) and timezone (`Asia/Tashkent`).
- [ ] Factory departments and shift schedules configured.
- [ ] Piecework operation rates configured and verified against physical factory price catalog.

## 2. Worker & Foreman Mobile App Experience
- [ ] Workers can clock in/out using PIN or QR code.
- [ ] Workers can record completed piecework operations in real-time or offline mode.
- [ ] Foremen receive pending production submissions in real-time.
- [ ] Foremen can review, adjust, or approve production entries with one tap.

## 3. Director Operations & Payroll
- [ ] Director dashboard reflects active factory production velocity and worker count.
- [ ] Payroll calculation engine processes 30-day piecework earnings, bonuses, and deductions accurately.
- [ ] Exported payroll sheets (Excel/PDF) match factory accounting expectations without discrepancy.

## 4. Stability & Security Acceptance Criteria
- [ ] Zero data leaks between factory departments and strict multi-tenant isolation.
- [ ] Zero unhandled 5xx server crashes during peak morning clock-in window.
- [ ] Database backup confirmed active and verified via test restoration runbook.
