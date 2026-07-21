# TexERP Factory UAT & 30-Day Trial Onboarding Guide

This guide details the step-by-step procedure to onboard real textile factories to the TexERP platform for 30-day User Acceptance Testing (UAT).

---

## 1. Pre-Onboarding Preparation Checklist
- [ ] Obtain Factory Details: Legal Entity Name, Target Slug, Primary Director Phone Number, Currency (UZS/USD), Timezone.
- [ ] Determine Initial Scale: Expected number of workers, foremen, and departments.
- [ ] Collect Piecework Operation Catalog & Pricing Table (per piece rates).

---

## 2. Factory Provisioning Command
Execute the automated provisioning script using environment variables:

```bash
FACTORY_NAME="Samarkand Textile Group" \
FACTORY_SLUG="samarkand-textile" \
FACTORY_ADMIN_PHONE="+998901234567" \
FACTORY_ADMIN_NAME="Sherzod Alimov" \
INITIAL_WORKERS=50 \
npx ts-node scripts/onboard-factory-tenant.ts
```

---

## 3. Mobile App Provisioning for Factory Staff

### Director Setup
1. Download TexERP Flutter App on Director's mobile device or tablet.
2. Login with `+998901234567` and default PIN `1234`.
3. Set a new 4-digit PIN upon initial login.

### Foremen & Worker Provisioning
1. Director navigates to **User Management** -> **Add User**.
2. Register Foremen and assign them to respective Departments (e.g. Sewing Line 1, Cutting Workshop).
3. Register Workers with phone numbers or auto-generated worker codes (e.g., `WRK-001`).
4. Print QR codes or distribute credentials to workers.

---

## 4. 30-Day Trial Success Milestones

| Timeline | Objective | Success Metric |
| :--- | :--- | :--- |
| **Day 1 - 3** | Setup & Staff Registration | 100% of workers and foremen registered in TexERP. |
| **Day 4 - 7** | Daily Attendance & Operation Tracking | >90% daily worker clock-ins & live piecework logging. |
| **Day 8 - 14** | Foreman Batch Approvals | Daily foreman approval loop established with < 24h approval latency. |
| **Day 15 - 21** | Mid-Trial Payroll Run | Director executes test weekly payroll calculation with accurate piece rates. |
| **Day 22 - 30** | Full Production & Report Review | Export monthly payroll & production performance reports to Excel. |
