# Vision Document
# TexERP — Digital Production Management Platform

---

**Document Version:** 1.0.0  
**Status:** Draft  
**Created:** 2026-07-16  
**Owner:** Product Team  

---

## 1. Problem We Are Solving

Textile and garment factories across Central Asia run their production tracking and payroll on paper. Every day, thousands of workers write their completed work on paper slips. Foremen manually verify these slips. Accountants manually type this data into Excel. Payroll is computed by hand. The entire cycle takes days, contains errors, and produces disputes.

This is not a technology gap — smartphones are everywhere. This is a **product gap**: there is no affordable, simple, mobile-first, locally-adapted tool built for this exact job.

**TexERP closes that gap.**

---

## 2. Vision Statement

> **"Every garment factory, regardless of size, can track every unit of production, pay every worker accurately, and give every manager real-time visibility — all from a mobile phone."**

We are not building another generic ERP. We are building the **operating system of the factory floor** — a focused, fast, simple tool that eliminates paper from the production tracking and payroll cycle entirely.

---

## 3. Core Beliefs

| Belief | What It Means For Us |
|--------|---------------------|
| Mobile is the only viable interface on the factory floor | We build Flutter-first; no desktop app for factory users |
| Simplicity is a feature | A sewing operator with basic smartphone skills must succeed on first use |
| Trust is earned through accuracy | Workers must be able to verify their own pay; disputes must have evidence |
| Data isolation is non-negotiable | Every factory's data is theirs alone; multi-tenancy must be airtight |
| Speed matters more than perfection | Ship a working MVP; iterate fast based on real factory feedback |

---

## 4. Target Market

### Primary (V1)
- **Geography:** Uzbekistan (Tashkent region + industrial cities)
- **Factory size:** 10-500 workers
- **Factory type:** Cut-Make-Trim (CMT) garment factories, sportswear, workwear
- **Payment model:** Piece-rate (workers paid per operation completed)

### Expansion (V2)
- **Geography:** Kazakhstan, Kyrgyzstan
- **Factory size:** Up to 1,000 workers
- **Factory type:** Knitwear, denim, textile weaving

### Long-term (V3)
- **Geography:** South Asia (Bangladesh, Pakistan, India) — requires localization
- **Factory type:** Large-scale export factories

---

## 5. Strategic Differentiation

| Differentiator | Why It Matters |
|---------------|---------------|
| Mobile-first, works on cheap Android phones | Factories cannot afford or don't need PCs on the floor |
| Uzbek-language native | Competitors offer Russian-only or English-only interfaces |
| Offline-capable | Factory floors often have poor WiFi; offline submission is essential |
| Purpose-built for piece-rate | Generic ERP systems don't understand piece-rate payroll natively |
| Fast onboarding (1 day) | Factories will not tolerate multi-week implementation projects |
| Affordable SaaS | No large upfront license; monthly subscription fits factory budgets |
| Local support | Phone/WhatsApp support in Uzbek is a competitive moat |

---

## 6. What We Are NOT Building

- We are not building a full ERP (no finance, no procurement, no CRM in V1)
- We are not building a desktop application for factory workers
- We are not building a generic HR system
- We are not replacing accounting software (we export to it)
- We are not building IoT infrastructure in V1

---

## 7. Product Pillars

### Pillar 1 — Production Accuracy
Every unit of work is captured, verified, and immutably recorded. No more fake records, no more duplicates, no more disputes without evidence.

### Pillar 2 — Payroll Speed
Payroll calculation that took 3-7 days now takes under 4 hours. From verified production records to signed payslip in one workflow.

### Pillar 3 — Real-Time Visibility
Directors and foremen see production performance live on their phones. No more end-of-day verbal reports.

### Pillar 4 — Worker Trust
Workers can see their own work history, their approved records, their calculated pay. Transparency builds trust and reduces disputes.

### Pillar 5 — Multi-Tenant Scale
One platform, hundreds of isolated factories. The economics of SaaS applied to factory management.

---

## 8. 5-Year North Star

By 2031, TexERP will be:
- Used by 500+ factories across 5+ countries
- Processing 10M+ production records per month
- Trusted by 100,000+ factory workers to verify their own pay
- Generating $500K+ ARR
- Extended with AI-powered planning, quality control, and machine management modules
- The reference platform for garment factory digitization in Central and South Asia

---

## 9. Guiding Principles for Product Decisions

1. **Factory Floor First** — If a sewing operator cannot use it without training, we redesign it
2. **Data Integrity Over Speed** — It is better to block an action than to allow corrupted data
3. **Audit Everything** — Every change to every record must have a traceable reason and actor
4. **Local First** — Language, currency, regulations, and support must be local by default
5. **Iterate in Weeks, Not Months** — Ship working software; let real factories teach us what to build next

---

*End of Vision Document — Version 1.0.0*
