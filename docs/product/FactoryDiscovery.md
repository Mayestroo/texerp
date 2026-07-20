# Factory Discovery Document
# TexERP — Pre-Design Field Interview Guide

---

**Document Version:** 1.0.0  
**Status:** Template — Fill During Factory Visit  
**Purpose:** Discover real factory workflows before designing any UI or writing any code  
**Interview Duration:** 2–3 hours  
**Interviewer:** Product Manager / CTO / Lead Engineer  
**Interviewees:** Factory Director, Foreman (at least 2), Accountant, 2–3 Workers

---

> **Why this document exists:**  
> Every assumption baked into UI or backend that does NOT match how this specific factory actually works will cost 2–5 days of rework. A 3-hour interview prevents 3 weeks of wrong software.  
>
> **Rule:** Do not generalize. Ask, then write the exact answer. "It depends" is not an answer — ask what it depends on.

---

## Interview Protocol

### Before the Interview
- [ ] Print this document or open on tablet
- [ ] Bring voice recorder (with permission)
- [ ] Bring camera (with permission) — photograph actual paper forms, Excel files
- [ ] Ask for 2–3 real paper submission forms to take away
- [ ] Ask for their current payroll Excel file (anonymized is fine)

### During the Interview
- Start with the Director (big picture)
- Then interview a Foreman (operational detail)
- Then sit with 2–3 workers on the production floor (real behavior)
- Then interview the Accountant (payroll detail)
- Walk the factory floor — see what is ACTUALLY happening, not what is described

### After the Interview
- Complete all blank fields within 24 hours while memory is fresh
- Highlight any answers that contradict the existing Business Analysis Document
- Create a "Gaps & Updates" section at the bottom
- Share with the team before any UI design begins

---

## Section 1: Factory Overview

| Question | Answer |
|----------|--------|
| Factory full name | |
| Factory location (city, region) | |
| Factory working hours | |
| How many shifts per day? | |
| Shift times (e.g., 08:00–17:00) | |
| Total number of workers | |
| Number of sewing lines | |
| Number of foremen | |
| Number of accountants | |
| Has the factory used any digital system before? | |
| If yes — what system? Why did they stop? | |
| What phone brands/models do most workers have? | |
| What Android version do most workers use? | |
| Is there Wi-Fi in the factory? | |
| Wi-Fi coverage: everywhere / partial / none | |
| Do workers use mobile data? | |
| Average worker age | |
| Workers' comfort with smartphones (1–5) | |
| Primary language used in factory (uz / ru / mix) | |

---

## Section 2: Departments & Sections

**Draw or describe the factory floor layout:**

```
[Space for sketch / photograph]
```

| Question | Answer |
|----------|--------|
| What are the main sections/departments? | |
| Is production organized by lines, sections, or both? | |
| How many sewing lines are there? | |
| Does each line specialize in specific operations? | |
| Who manages each line — a dedicated foreman? | |
| Can a worker work on multiple lines in a day? | |
| Are there other sections besides sewing? (cutting, finishing, QC?) | |
| Does the app need to know which section a record came from? | |

**Department/Section List:**

| Department Name | Workers Count | Foreman Name | Notes |
|----------------|:------------:|:------------:|-------|
| | | | |
| | | | |
| | | | |
| | | | |
| | | | |

---

## Section 3: Workers & Roles

**3.1 Worker Reality**

| Question | Answer |
|----------|--------|
| How do workers currently record their work? (paper form / verbal?) | |
| What exactly is written on the paper? | |
| Who hands out the paper forms? | |
| Where do workers put the completed forms? | |
| At what time during the day do workers submit? (once/multiple times?) | |
| Do workers submit at the end of their shift? Or mid-shift? | |
| Do workers submit for today's work only, or sometimes yesterday's? | |
| Maximum how many days back can a worker submit? | |
| Do workers ever submit for more than they actually did? (honest answer) | |
| How is this caught currently? | |
| Do workers know their piece rate for each operation? | |
| Can a worker do multiple different operations in one day? | |
| What is the maximum number of operations a worker does per day? | |
| Do workers work on bundles or on continuous flow? | |

**3.2 Worker Literacy**

| Question | Answer |
|----------|--------|
| Can all workers read Uzbek? | |
| Can all workers read Russian? | |
| Which language do workers prefer for the app? | |
| Are there workers who cannot read at all? | |
| How do those workers currently fill in paper forms? | |
| Are there workers over 50 who might struggle with smartphones? | |
| Have workers ever used a mobile app for work before? | |

**3.3 Worker Phone Reality**

| Question | Answer |
|----------|--------|
| Do all workers own a personal smartphone? | |
| What percentage have Android vs iPhone? | |
| Cheapest/oldest phone model you've seen workers use? | |
| Do workers have mobile internet (SIM data)? | |
| Will the factory provide phones to workers who don't have one? | |
| Are phones allowed on the production floor? | |
| Where do workers keep their phones during work? | |

---

## Section 4: Operations Catalog

> **This is the most critical section.** The operation catalog is the foundation of the entire system.

**4.1 Operation Basics**

| Question | Answer |
|----------|--------|
| How many total operations exist in this factory? | |
| Do operations change per season / per order / or are they fixed? | |
| Who decides the operation names? | |
| Who decides the piece rate (price per unit)? | |
| How often do prices change? | |
| When prices change, do old records keep the old price? | |
| What is the unit of measurement? (pieces / meters / other?) | |
| Is it always "pieces" or are some operations measured differently? | |

**4.2 Complete Operation List**

> Ask the factory to provide their current list. Copy it here or attach as photo.

| Operation Code | Operation Name | Unit | Current Price (UZS) | Section/Line | Notes |
|:-------------:|---------------|:----:|:------------------:|:------------:|-------|
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |

*(Continue on separate sheet if needed)*

**4.3 Operation Edge Cases**

| Question | Answer |
|----------|--------|
| Can a worker submit for an operation they are NOT assigned to? | |
| Are some operations only done by specific workers? | |
| Are there operations that are always done in pairs (two workers together)? | |
| Are there operations with a daily maximum quantity? | |
| What is the typical maximum quantity per operation per day per worker? | |
| What is the highest quantity you've ever seen in one day? | |
| What is a "suspicious" quantity that should be questioned? | |
| Are there operations that take a full shift (so only 1 submission per day)? | |

---

## Section 5: Bundle (Partiya) System

| Question | Answer |
|----------|--------|
| Does this factory use bundles/partiyas? | |
| What is a bundle? How many pieces per bundle? | |
| Who creates and tags bundles? | |
| What information is on a bundle tag? | |
| Can a worker split a bundle (do partial qty and pass it on)? | |
| Do workers submit per bundle or per day total? | |
| If per bundle: does the app need to track bundle numbers? | |
| Can the same bundle go through multiple workers? | |
| What happens if a bundle is lost? | |
| Are bundles tied to specific orders/styles/colors? | |
| Does the foreman currently check bundle numbers against paper? | |

---

## Section 6: Approval Flow

> Walk through a REAL example from yesterday. Ask to see the actual paper from yesterday.

**6.1 Current Paper Flow**

| Question | Answer |
|----------|--------|
| Show me exactly what happens from when a worker finishes work to when it's recorded. | |
| Who physically carries the paper? | |
| Where does the paper go? (who collects it?) | |
| When does the foreman see it? | |
| What does the foreman check? | |
| Does the foreman ever change the quantity? | |
| How often does the foreman reject/correct? (% estimate) | |
| What are the most common reasons for rejection/correction? | |
| What happens to the paper after the foreman checks it? | |
| Who gives it to the accountant? | |
| When? (same day / next day / weekly?) | |

**6.2 Common Rejection Reasons (ask for real examples)**

| Reason | How Often | Example |
|--------|:--------:|---------|
| | | |
| | | |
| | | |
| | | |

**6.3 Foreman Reality**

| Question | Answer |
|----------|--------|
| How many workers does each foreman supervise? | |
| Is the foreman on the floor all day or in an office? | |
| Does the foreman have a smartphone? | |
| Is the foreman comfortable with apps? | |
| How many records does a foreman approve per day on average? | |
| Does the foreman approve in real time or end-of-day? | |
| Can a foreman have a deputy (assistant foreman)? | |
| What happens if the foreman is sick/absent? Who approves? | |
| Does the foreman ever approve records for workers not in their team? | |

---

## Section 7: Payroll System

> **Most critical section for backend design.** Get exact formulas, not descriptions.

**7.1 Payroll Basics**

| Question | Answer |
|----------|--------|
| How often is payroll calculated? (weekly / bi-weekly / monthly?) | |
| What are the exact payroll period dates? (e.g., 1–15, 16–31?) | |
| Who calculates payroll? (Accountant / Director / both?) | |
| How long does payroll calculation take currently? | |
| What software/tool is currently used? (Excel / 1C / manual?) | |

**7.2 Payroll Formula**

> Ask them to show you the actual Excel formula. Write it exactly.

**Current formula:**
```
[Write the exact formula here]

Example:
  Worker earnings = SUM(quantity × operation_rate for each operation)
  + Bonus (if any)
  - Deductions (if any)  
  - Advances (already given)
  = Final pay

But what is the ACTUAL formula used in this factory?
```

| Variable | Description | Example Value |
|----------|-------------|:-------------:|
| | | |
| | | |
| | | |
| | | |

**7.3 Payroll Edge Cases**

| Question | Answer |
|----------|--------|
| What happens if a worker works only 3 days in a month? | |
| What if a worker's earnings are less than their advance? | |
| Is there a minimum guaranteed salary? | |
| Is there overtime? How is it calculated? | |
| Are there productivity bonuses? What is the formula? | |
| Are there attendance bonuses? | |
| Are there quality-based bonuses? | |
| What deductions are common? (advance / fine / uniform / other?) | |
| Is there a legal minimum wage that must be met? | |
| Do different operations have different calculation methods? | |
| Are there workers on fixed salary (not piece rate)? | |
| How are advances tracked currently? (notebook / Excel / mental?) | |
| How many advances per month on average? | |
| What is the maximum advance a worker can take? | |

**7.4 Payroll Output**

| Question | Answer |
|----------|--------|
| What does the Director see from payroll? | |
| What does the accountant prepare as final output? | |
| Is there a payslip given to each worker? | |
| How is payment made? (cash / bank transfer / mixed?) | |
| Who signs the payroll document? | |
| Where is the payroll document stored? | |
| How long does the factory keep payroll records? | |
| Is there a government reporting requirement for payroll? | |

---

## Section 8: Current Tools & Documents

**8.1 Current Paper Forms**

> Ask to see and photograph every paper form currently used.

| Form Name | Purpose | Fields on Form | Who Fills It | Who Receives It |
|-----------|---------|---------------|:------------:|:---------------:|
| | | | | |
| | | | | |
| | | | | |
| | | | | |

**8.2 Current Excel Files**

> Ask for copies (anonymized). This is gold — your Excel must replace these exactly.

| Excel File Name | Purpose | Who Creates It | Who Uses It | Columns (list all) |
|----------------|---------|:-------------:|:-----------:|-------------------|
| | | | | |
| | | | | |
| | | | | |

**8.3 Other Tools**

| Question | Answer |
|----------|--------|
| Does the factory use 1C (1С:Предприятие)? | |
| Does the factory use any HR software? | |
| Does the factory use WhatsApp for work communication? | |
| Does the factory use any messaging for approvals or notifications? | |
| Are there any other digital tools? | |

---

## Section 9: Pain Points

> Let them talk. Do not suggest answers. Just listen and write.

**"Tell me about the biggest problems with your current process."**

| Pain Point | Who Suffers | How Often | Estimated Cost/Impact |
|-----------|:-----------:|:---------:|:---------------------:|
| | | | |
| | | | |
| | | | |
| | | | |
| | | | |

**9.1 Specific Pain Point Probes**

| Question | Answer |
|----------|--------|
| How often do workers submit incorrect quantities? | |
| How are incorrect quantities discovered? | |
| Has a worker ever been paid for work they didn't do? | |
| Has a worker ever NOT been paid for work they did do? | |
| How often does payroll calculation have errors? | |
| What is the biggest error you've ever found in payroll? | |
| How long does the Director spend reviewing paper records per day? | |
| How long does the accountant spend on payroll per month? | |
| Has there ever been a dispute about quantities with a worker? | |
| How was it resolved? | |
| Is there a problem with workers not submitting on time? | |
| Is there a problem with foremen not approving on time? | |
| Are there trust issues between workers and management about quantities? | |

---

## Section 10: Reporting & KPIs

**10.1 What the Director Wants to Know**

| Question | Answer |
|----------|--------|
| What do you check first thing in the morning? | |
| What number tells you if today is a good or bad day? | |
| Do you track production against a daily target? | |
| What is the daily target for this factory? (total units) | |
| Do you track efficiency per worker? Per line? | |
| Who is your best worker right now? How do you know? | |
| Who is underperforming? How do you currently know? | |
| Do you track production by operation? By style? | |
| Do you need to report to anyone outside the factory? (investor / brand?) | |
| What report would make your life significantly easier? | |

**10.2 Key Metrics the System Must Track**

| Metric | Current Method | Frequency Needed |
|--------|:-------------:|:----------------:|
| Total daily production (units) | | |
| Production per worker per day | | |
| Pending approvals count | | |
| Payroll total per period | | |
| Earnings per worker per period | | |
| | | |
| | | |

---

## Section 11: Terminology

> Every factory uses slightly different words. These are the exact words to use in the UI.

| Our Term (English) | Factory's Actual Word (Uzbek) | Factory's Actual Word (Russian) | Notes |
|:------------------:|:-----------------------------:|:-------------------------------:|-------|
| Worker | | | |
| Foreman | | | |
| Operation | | | |
| Quantity / Count | | | |
| Bundle | | | |
| Approve | | | |
| Reject | | | |
| Payroll | | | |
| Salary / Earnings | | | |
| Advance | | | |
| Bonus | | | |
| Deduction | | | |
| Payroll Period | | | |
| Production Line | | | |
| Section | | | |
| Submit (a record) | | | |
| Pending | | | |
| History | | | |
| Dashboard | | | |
| Settings | | | |
| Piece rate | | | |

---

## Section 12: Organizational Structure

**Draw or describe the reporting structure:**

```
[Space for org chart sketch]

Example:
  Director
    └── Accountant
    └── Foreman 1 (Line 1)
          └── Worker 1–1
          └── Worker 1–2
          ...
    └── Foreman 2 (Line 2)
          └── Worker 2–1
          ...
```

| Question | Answer |
|----------|--------|
| Who has the final authority in the factory? | |
| Does the Director approve anything in the current process? | |
| Is there a production manager between Director and Foreman? | |
| Does the accountant report to the Director? | |
| Who has access to payroll information? | |
| Can foremen see each other's workers' records? | |
| Can workers see their colleagues' records? | |
| Who can change an operation price? | |
| Who can create a new worker account? | |

---

## Section 13: Special Scenarios

> These are the questions that reveal unexpected requirements.

| Question | Answer |
|----------|--------|
| What happens if a worker is sick for a week? | |
| What happens if a worker quits mid-month? | |
| What if a worker is on maternity leave? | |
| Do seasonal workers exist? (hired for peak season only) | |
| Are there contract workers from agencies? | |
| What happens if the foreman is away — who approves? | |
| What if there's a power outage for a full day? | |
| What if a worker loses their phone? | |
| Has there ever been a situation where records were falsified? | |
| How was it discovered? | |
| Are there workers who share a phone? | |
| Is there a case where one worker submits on behalf of another? | |
| What happens if the internet is down for a whole day? | |
| What is the factory's plan for the first week of using the app? | |

---

## Section 14: Adoption & Change Management

| Question | Answer |
|----------|--------|
| Who in the factory is MOST excited about this system? | |
| Who is MOST resistant? Why? | |
| Have workers been told about the new system? | |
| What is the Director's plan to ensure workers actually use it? | |
| What happens to a worker who refuses to use the app? | |
| Is there a champion (person) who will help other workers? | |
| What training is the factory willing to provide? | |
| How much time can be dedicated to training? | |
| What is the switch-over date? (when paper stops) | |
| Will paper run in parallel with the app for a period? | |

---

## Section 15: Technical Reality Check

| Question | Answer |
|----------|--------|
| What is the Wi-Fi router brand/model in the factory? | |
| Is Wi-Fi password shared with workers? | |
| Is there a separate workers' network? | |
| Internet provider and speed (approximate) | |
| Is the internet connection reliable? Outages per week? | |
| Who manages the IT/tech in the factory? | |
| Is there anyone who can install the app on workers' phones? | |
| Is there a Google Play account workers can use? | |
| Can the factory install APK files directly (without Play Store)? | |
| Are there any parental controls or MDM on worker devices? | |

---

## Section 16: Questions the Factory Has for Us

> Let them ask questions. Their questions reveal their real concerns.

| Their Question | Our Answer |
|----------------|-----------|
| | |
| | |
| | |
| | |
| | |

---

## Post-Interview: Gaps & Contradictions

> Fill this section within 24 hours of the interview. Compare findings against existing documents.

### Contradictions with Business Analysis Document

| BAD Assumption | Reality Found | Impact | Action Required |
|:-------------:|:-------------:|:------:|:---------------:|
| | | | |
| | | | |
| | | | |

### New Requirements Not in PRD

| Discovery | Module Affected | Priority | Add to MVP? |
|-----------|:--------------:|:--------:|:-----------:|
| | | | |
| | | | |
| | | | |

### UI/Design Implications

> Discoveries that directly affect screen design decisions.

| Discovery | Screen Affected | Design Change Needed |
|-----------|:--------------:|:-------------------:|
| Workers submit once at end of shift (not real-time) | Submit screen | Time picker not needed; default to today |
| Workers don't know operation codes, only names | Operation selector | Show name only, no codes |
| | | |
| | | |
| | | |

### Terminology Corrections

> Words that must change in the app based on what the factory actually says.

| Our Term | Correct Factory Term | Where It Appears |
|:--------:|:-------------------:|:----------------:|
| | | |
| | | |
| | | |

### Payroll Formula (Final Confirmed)

```
After the interview, write the CONFIRMED payroll formula:

Worker Monthly Pay = 
  Σ (quantity_approved × operation_unit_price)
  [+ or -] [adjustments specific to this factory]
  - Advances
  = Final Pay

Special rules for THIS factory:
  1. [Rule 1]
  2. [Rule 2]
  ...
```

---

## Interview Sign-Off

| Role | Name | Signature | Date |
|------|------|:---------:|:----:|
| Factory Director | | | |
| Foreman (1) | | | |
| Foreman (2) | | | |
| Accountant | | | |
| Interviewer | | | |

**Documents collected:**
- [ ] Sample paper submission form
- [ ] Current payroll Excel file (anonymized)
- [ ] Operations list with prices
- [ ] Org chart or org description
- [ ] Photos of factory floor

**Status after interview:**
- [ ] All sections completed
- [ ] Contradictions with BAD identified
- [ ] New requirements identified
- [ ] Team briefed on discoveries
- [ ] UI/UX design can begin ✅

---

*End of Factory Discovery Document — Version 1.0.0*  
*This document must be completed BEFORE any UI design or backend code is written.*  
*Archive the completed version alongside all factory-provided documents.*
