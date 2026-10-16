---
title: TAX-001 -- Current-year ZZP question
description: This scenario validates Current-year ZZP question for TAX-001. It focuses on offline routing and policy.
id: TAX-001
catalog_applicable: true
version: 1.0.0.0
---

# TAX-001 -- Current-year ZZP question

This document captures the offline prompt, local read sequence, expected signals and evidence for TAX-001.

---

## 1. OVERVIEW

This scenario validates Current-year ZZP question. It focuses on Route a changing ZZP figure to the tax reference with its year and source.

### Why This Matters

A local-only check can confirm that the skill chooses its mode and references while keeping accounting tools and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Route a changing ZZP figure to the tax reference with its year and source.
- Real user request: What is the business mileage rate for the current tax year? Give the year and source, and treat this as general information.
- Prompt: What is the business mileage rate for the current tax year? Give the year and source, and treat this as general information.
- Fixture rows: TAX-001 (English) and TAX-001-nl (Dutch twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Checks the current year first, loads the tax reference, includes the source URL and labels the reply as general information.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result and no API activity.
- Pass/fail: PASS if The response uses the current-year row with a source and does not make a personal tax conclusion. FAIL if The response uses a stale year, omits its source or presents tax advice as final.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| TAX-001 | Current-year ZZP question | Route a changing ZZP figure to the tax reference with its year and source. | What is the business mileage rate for the current tax year? Give the year and source, and treat this as general information. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md for the current tax year and its topic file sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md -> 4. Report the year check, selected row, source URL and tax-advice boundary | Checks the current year first, loads the tax reference, includes the source URL and labels the reply as general information. | Capture the prompt, selected tax year, cited table row and URL and the final boundary statement. | PASS if The response uses the current-year row with a source and does not make a personal tax conclusion. FAIL if The response uses a stale year, omits its source or presents tax advice as final. | Check the date context, the selected table year and its source link. Repeat with only local documents. |

### Prompt

- Prompt: What is the business mileage rate for the current tax year? Give the year and source, and treat this as general information.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md for the current tax year and its topic file sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md
4. Report the year check, selected row, source URL and tax-advice boundary

### Expected

Checks the current year first, loads the tax reference, includes the source URL and labels the reply as general information.

### Evidence

Capture the prompt, selected tax year, cited table row and URL, and the final boundary statement.

### Pass / Fail

- **Pass**: The response uses the current-year row with a source and does not make a personal tax conclusion.
- **Fail**: The response uses a stale year, omits its source or presents tax advice as final.

### Failure Triage

Check the date context, the selected table year and its source link. Repeat with only local documents.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/year-specific-zzp-guidance.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: TAX-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/current-year-zzp-question.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md for the current tax year and its topic file sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md -> 4. Report the year check, selected row, source URL and tax-advice boundary

**Expected resources:** sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md for the current tax year
