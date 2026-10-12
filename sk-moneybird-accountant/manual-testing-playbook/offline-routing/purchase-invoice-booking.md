---
title: LIVE-003 -- Purchase invoice booking
description: This scenario validates Purchase invoice booking for LIVE-003. It focuses on offline routing and policy.
id: LIVE-003
catalog_applicable: true
version: 1.0.0.0
---

# LIVE-003 -- Purchase invoice booking

This document captures the offline prompt, local read sequence, expected signals, and evidence for LIVE-003.

---

## 1. OVERVIEW

This scenario validates Purchase invoice booking. It focuses on routing a reverse-charged foreign purchase invoice to the purchase invoice reference and its VAT case.

### Why This Matters

A wrong VAT rate on a reverse-charged invoice drops VAT that is owed or claims a deduction a KOR business may not take. A local-only check confirms the route without touching accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route a reverse-charged EU purchase invoice to the purchase invoice reference and its VAT case.
- Real user request: Book this purchase invoice from an EU software supplier. It shows 0% VAT and says reverse charge. Which steps, VAT rate and references apply? Keep this as an offline routing check.
- Prompt: Book this purchase invoice from an EU software supplier. It shows 0% VAT and says reverse charge. Which steps, VAT rate and references apply? Keep this as an offline routing check.
- Fixture rows: LIVE-003 (en) and LIVE-003-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects LIVE, names the purchase invoice reference, classifies the invoice as EU reverse charge, picks the Binnen EU rate, reports rubriek 4b with the deduction in 5b, flags a KOR or exempt business as different, and says a write needs a passed gate and Operator approval.
- Desired user-visible outcome: A concise route report with selected mode, reference path, VAT case, rate, rubrieken, boundary result, and no API activity.
- Pass/fail: PASS if The response routes to the purchase invoice reference, picks the EU reverse-charge case and keeps the write behind the gate. FAIL if The response books the invoice with Geen btw or a Dutch rate, skips the reference, or calls a Moneybird API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| LIVE-003 | Purchase invoice booking | Route a reverse-charged EU purchase invoice to the purchase invoice reference and its VAT case. | Book this purchase invoice from an EU software supplier. It shows 0% VAT and says reverse charge. Which steps, VAT rate and references apply? Keep this as an offline routing check. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/purchase-invoices.md -> 4. Report the selected mode, the case, the VAT rate, the return rubrieken and the write boundary without calling an API | Selects LIVE, names the purchase invoice reference, classifies the invoice as EU reverse charge, picks the Binnen EU rate, reports rubriek 4b with the deduction in 5b, flags a KOR or exempt business as different, and says a write needs a passed gate and Operator approval. | Capture the prompt, selected mode, reference path, case, rate, rubrieken and no-API confirmation. | PASS if The response routes to the purchase invoice reference, picks the EU reverse-charge case and keeps the write behind the gate. FAIL if The response books the invoice with Geen btw or a Dutch rate, skips the reference, or calls a Moneybird API. | Check the T4 purchase invoice row of the Task-Type Table in the skill, the routing line in the bootstrap and the decision table in the reference. Repeat without tool access. |

### Prompt

- Prompt: Book this purchase invoice from an EU software supplier. It shows 0% VAT and says reverse charge. Which steps, VAT rate and references apply? Keep this as an offline routing check.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/purchase-invoices.md
4. Report the selected mode, the case, the VAT rate, the return rubrieken and the write boundary without calling an API

### Expected

Selects LIVE, names the purchase invoice reference, classifies the invoice as EU reverse charge, picks the Binnen EU rate, reports rubriek 4b with the deduction in 5b, flags a KOR or exempt business as different, and says a write needs a passed gate and Operator approval.

### Evidence

Capture the prompt, selected mode, reference path, case, rate, rubrieken and no-API confirmation.

### Pass / Fail

- **Pass**: The response routes to the purchase invoice reference, picks the EU reverse-charge case and keeps the write behind the gate.
- **Fail**: The response books the invoice with Geen btw or a Dutch rate, skips the reference, or calls a Moneybird API.

### Failure Triage

Check the T4 purchase invoice row of the Task-Type Table in the skill, the routing line in the bootstrap and the decision table in the reference. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/purchase-invoice-booking.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/purchase-invoices.md | Defines the booking flow and the VAT case table |
| AI Systems/Moneybird Accountant/AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: LIVE-003
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/purchase-invoice-booking.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/purchase-invoices.md -> 4. Report the selected mode, the case, the VAT rate, the return rubrieken and the write boundary without calling an API

**Expected resources:** references/purchase-invoices.md
