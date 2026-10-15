---
title: LIVE-002 -- Quarterly and yearly bookkeeping
description: This scenario validates Quarterly and yearly bookkeeping for LIVE-002. It focuses on offline routing and policy.
id: LIVE-002
catalog_applicable: true
version: 1.0.0.0
---

# LIVE-002 -- Quarterly and yearly bookkeeping

This document captures the offline prompt, local read sequence, expected signals and evidence for LIVE-002.

---

## 1. OVERVIEW

This scenario validates Quarterly and yearly bookkeeping. It focuses on Route VAT review and annual close work to the period workflow and current-year guidance.

### Why This Matters

A local-only check can confirm that the skill chooses its mode and references while keeping accounting tools and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Route VAT review and annual close work to the period workflow and current-year guidance.
- Real user request: Help me prepare my quarterly VAT review and year-end close. Do not submit a return and do not call an API.
- Prompt: Help me prepare my quarterly VAT review and year-end close. Do not submit a return and do not call an API.
- Fixture rows: LIVE-002 (en) and LIVE-002-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects LIVE, separates quarterly VAT from yearly close, requires a year check, and says the operator files the return.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result, and no API activity.
- Pass/fail: PASS if Both cadences are covered, current-year figures are checked, and return filing remains operator-only. FAIL if The response merges the periods, gives an unsourced figure, submits a return, or calls an API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| LIVE-002 | Quarterly and yearly bookkeeping | Route VAT review and annual close work to the period workflow and current-year guidance. | Help me prepare my quarterly VAT review and year-end close. Do not submit a return and do not call an API. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md -> 4. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/vat/figures.md for the period's tax year -> 5. Report quarterly and yearly checks, the current-year rule and the return-filing boundary | Selects LIVE, separates quarterly VAT from yearly close, requires a year check and says the operator files the return. | Capture the requested period tasks, selected references, tax-year note, filing boundary and no-API confirmation. | PASS if Both cadences are covered, current-year figures are checked and return filing remains operator-only. FAIL if The response merges the periods, gives an unsourced figure, submits a return or calls an API. | Check the selected cadence, then the tax reference, then the filing rule. Repeat offline. |

### Prompt

- Prompt: Help me prepare my quarterly VAT review and year-end close. Do not submit a return and do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md
4. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/vat/figures.md for the period's tax year
5. Report quarterly and yearly checks, the current-year rule, and the return-filing boundary

### Expected

Selects LIVE, separates quarterly VAT from yearly close, requires a year check, and says the operator files the return.

### Evidence

Capture the requested period tasks, selected references, tax-year note, filing boundary, and no-API confirmation.

### Pass / Fail

- **Pass**: Both cadences are covered, current-year figures are checked, and return filing remains operator-only.
- **Fail**: The response merges the periods, gives an unsourced figure, submits a return, or calls an API.

### Failure Triage

Check the selected cadence, then the tax reference, then the filing rule. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: LIVE-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/quarterly-yearly-bookkeeping.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md -> 4. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/vat/figures.md for the period's tax year -> 5. Report quarterly and yearly checks, the current-year rule and the return-filing boundary

**Expected resources:** sk-moneybird-accountant/references/moneybird-bookkeeping.md, sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/vat/figures.md for the period's tax year
