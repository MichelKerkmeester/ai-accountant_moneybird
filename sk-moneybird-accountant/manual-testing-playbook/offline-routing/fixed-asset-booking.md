---
title: LIVE-005 -- Fixed asset booking
description: This scenario validates Fixed asset booking for LIVE-005. It focuses on offline routing and policy.
id: LIVE-005
catalog_applicable: true
version: 1.0.0.0
---

# LIVE-005 -- Fixed asset booking

This document captures the offline prompt, the local read sequence, the expected signals and the evidence for LIVE-005.

---

## 1. OVERVIEW

This scenario validates Fixed asset booking. It focuses on routing a large purchase to the fixed asset reference, the cost-or-asset test and the depreciation steps.

### Why This Matters

Expensing an asset or depreciating it outside the yearly limit changes the profit and the VAT revision. A local-only check confirms the route and the depreciation boundary without touching accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route a large purchase to the fixed asset reference, the cost-or-asset test and the depreciation steps.
- Real user request: I bought a laptop for 1200 and want to depreciate it. Which steps and references apply? Keep this as an offline routing check.
- Prompt: I bought a laptop for 1200 and want to depreciate it. Which steps and references apply? Keep this as an offline routing check.
- Fixture rows: LIVE-005 (en) and LIVE-005-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects LIVE, names the fixed asset reference, states when a purchase is capitalised rather than expensed, names the aanschafwaarde, the gebruiksduur and the restwaarde on the bezitting, keeps the yearly depreciation within the limit, places the purchase VAT in the return for the invoice period and says a write needs a passed gate and Operator approval.
- Desired user-visible outcome: A concise route report with the selected mode, the reference path, the cost-or-asset outcome, the depreciation fields, the VAT treatment, the boundary result and no API activity.
- Pass/fail: PASS if The response routes to the fixed asset reference, applies the cost-or-asset test and keeps the write behind the gate. FAIL if The response expenses the purchase, skips the reference, invents a depreciation figure or calls a Moneybird API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| LIVE-005 | Fixed asset booking | Route a large purchase to the fixed asset reference, the cost-or-asset test and the depreciation steps. | I bought a laptop for 1200 and want to depreciate it. Which steps and references apply? Keep this as an offline routing check. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/fixed-assets.md -> 4. Report the selected mode, the cost-or-asset outcome, the depreciation fields, the VAT treatment and the write boundary without calling an API | Selects LIVE, names the fixed asset reference, states when a purchase is capitalised rather than expensed, names the aanschafwaarde, the gebruiksduur and the restwaarde on the bezitting, keeps the yearly depreciation within the limit, places the purchase VAT in the return for the invoice period and says a write needs a passed gate and Operator approval. | Capture the prompt, selected mode, reference path, cost-or-asset outcome, depreciation fields, VAT treatment and no-API confirmation. | PASS if The response routes to the fixed asset reference, applies the cost-or-asset test and keeps the write behind the gate. FAIL if The response expenses the purchase, skips the reference, invents a depreciation figure or calls a Moneybird API. | Check the T4 purchase invoice row of the Task-Type Table in the skill, the conditional fixed-asset read in that row and the decision table in the reference. Repeat without tool access. |

### Prompt

- Prompt: I bought a laptop for 1200 and want to depreciate it. Which steps and references apply? Keep this as an offline routing check.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/fixed-assets.md
4. Report the selected mode, the cost-or-asset outcome, the depreciation fields, the VAT treatment and the write boundary without calling an API

### Expected

Selects LIVE, names the fixed asset reference, states when a purchase is capitalised rather than expensed, names the aanschafwaarde, the gebruiksduur and the restwaarde on the bezitting, keeps the yearly depreciation within the limit, places the purchase VAT in the return for the invoice period and says a write needs a passed gate and Operator approval.

### Evidence

Capture the prompt, selected mode, reference path, cost-or-asset outcome, depreciation fields, VAT treatment and no-API confirmation.

### Pass / Fail

- **Pass**: The response routes to the fixed asset reference, applies the cost-or-asset test and keeps the write behind the gate.
- **Fail**: The response expenses the purchase, skips the reference, invents a depreciation figure or calls a Moneybird API.

### Failure Triage

Check the T4 purchase invoice row of the Task-Type Table in the skill, the conditional fixed-asset read in that row and the decision table in the reference. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/fixed-asset-booking.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| sk-moneybird-accountant/references/fixed-assets.md | Defines the cost-or-asset test, depreciation and the VAT revision |
| AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: LIVE-005
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/fixed-asset-booking.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/fixed-assets.md -> 4. Report the selected mode, the cost-or-asset outcome, the depreciation fields, the VAT treatment and the write boundary without calling an API

**Expected resources:** sk-moneybird-accountant/references/fixed-assets.md
