---
title: LIVE-004 -- Mixed-use cost booking
description: This scenario validates Mixed-use cost booking for LIVE-004. It focuses on offline routing and policy.
id: LIVE-004
catalog_applicable: true
version: 1.0.0.0
---

# LIVE-004 -- Mixed-use cost booking

This document captures the offline prompt, the local read sequence, the expected signals and the evidence for LIVE-004.

---

## 1. OVERVIEW

This scenario validates Mixed-use cost booking. It focuses on routing a partly private phone subscription to the mixed-use cost reference, its business share and its VAT split.

### Why This Matters

Deducting all the VAT or booking the private part as a business cost overstates the deduction and the profit. A local-only check confirms the route and the split without touching accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route a partly private phone subscription to the mixed-use cost reference, its business share and its VAT split.
- Real user request: How do I book my phone subscription that I use partly privately? Which booking steps and references apply? Keep this as an offline routing check.
- Prompt: How do I book my phone subscription that I use partly privately? Which booking steps and references apply? Keep this as an offline routing check.
- Fixture rows: LIVE-004 (en) and LIVE-004-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects LIVE, names the mixed-use cost reference, records the business share and its basis, splits the document in Moneybird with the private part on an equity category, deducts only the business share of the VAT with the private use settled in the last return of the year and says a write needs a passed gate and Operator approval.
- Desired user-visible outcome: A concise route report with the selected mode, the reference path, the business share, the VAT split, the private account, the boundary result and no API activity.
- Pass/fail: PASS if The response routes to the mixed-use cost reference, splits business and private and keeps the write behind the gate. FAIL if The response deducts all the VAT, books the private part as a business cost, skips the reference or calls a Moneybird API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| LIVE-004 | Mixed-use cost booking | Route a partly private phone subscription to the mixed-use cost reference, its business share and its VAT split. | How do I book my phone subscription that I use partly privately? Which booking steps and references apply? Keep this as an offline routing check. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/mixed-use-costs.md -> 4. Report the selected mode, the business share, the VAT split, the private account and the write boundary without calling an API | Selects LIVE, names the mixed-use cost reference, records the business share and its basis, splits the document in Moneybird with the private part on an equity category, deducts only the business share of the VAT with the private use settled in the last return of the year and says a write needs a passed gate and Operator approval. | Capture the prompt, selected mode, reference path, business share, VAT split, private account and no-API confirmation. | PASS if The response routes to the mixed-use cost reference, splits business and private and keeps the write behind the gate. FAIL if The response deducts all the VAT, books the private part as a business cost, skips the reference or calls a Moneybird API. | Check the T4 purchase invoice row of the Task-Type Table in the skill, the conditional mixed-use read in that row and the decision table in the reference. Repeat without tool access. |

### Prompt

- Prompt: How do I book my phone subscription that I use partly privately? Which booking steps and references apply? Keep this as an offline routing check.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/mixed-use-costs.md
4. Report the selected mode, the business share, the VAT split, the private account and the write boundary without calling an API

### Expected

Selects LIVE, names the mixed-use cost reference, records the business share and its basis, splits the document in Moneybird with the private part on an equity category, deducts only the business share of the VAT with the private use settled in the last return of the year and says a write needs a passed gate and Operator approval.

### Evidence

Capture the prompt, selected mode, reference path, business share, VAT split, private account and no-API confirmation.

### Pass / Fail

- **Pass**: The response routes to the mixed-use cost reference, splits business and private and keeps the write behind the gate.
- **Fail**: The response deducts all the VAT, books the private part as a business cost, skips the reference or calls a Moneybird API.

### Failure Triage

Check the T4 purchase invoice row of the Task-Type Table in the skill, the conditional mixed-use read in that row and the decision table in the reference. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/mixed-use-cost-booking.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/mixed-use-costs.md | Defines the business share, the VAT split and the booking steps |
| AI Systems/Moneybird Accountant/AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: LIVE-004
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/mixed-use-cost-booking.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/mixed-use-costs.md -> 4. Report the selected mode, the business share, the VAT split, the private account and the write boundary without calling an API

**Expected resources:** references/mixed-use-costs.md
