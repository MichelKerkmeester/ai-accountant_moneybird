---
title: REF-003 -- Tax knowledge base
description: This scenario validates the tax knowledge base for REF-003. It focuses on offline checks and policy.
id: REF-003
catalog_applicable: true
version: 1.0.0.0
---

# REF-003 -- Tax knowledge base

This document captures the offline prompt, local read sequence, expected signals and evidence for REF-003.

---

## 1. OVERVIEW

This scenario validates the tax knowledge base. It focuses on the read path of a figure question through the tree index and the year README to the one topic part, with the fragment check proving every link into the tree.

### Why This Matters

Every figure lives in one topic file of one year folder, so a figure answer is only as good as the resolution that found it. Resolving the year first and reading only the named part keeps the answer on a settled, sourced figure instead of a remembered one.

---

## 2. SCENARIO CONTRACT

- Objective: Read a figure question through the tree index and the year README and run the fragment check over the tree.
- Real user request: A question asks for the business mileage rate of the current tax year. Show how the tax knowledge base tree is read for a figure and run the fragment check over the tree. Keep this offline.
- Prompt: A question asks for the business mileage rate of the current tax year. Show how the tax knowledge base tree is read for a figure and run the fragment check over the tree. Keep this offline.
- Fixture rows: none in routing-gold.json. The scenario reads the tree index and runs the fragment check.
- Expected execution process: Read the project bootstrap and skill, read the tree index, resolve the current year first, read the year README and the one topic part it names from its key figures section, run the fragment check and confirm no network call.
- Expected signals: Names the eight year folders, the twelve topic folders with their four part files, the general topic files and the five cross-year files, resolves the year before any figure, reads the year README and the one named part, the fragment check reports 0 problems and the run makes no network call.
- Desired user-visible outcome: The read path from index to year README to topic part, the fragment summary and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the year is resolved before the figure, the year README names the one read part, the fragment check reports 0 problems and no API is called. FAIL if a figure is used before the year resolves, an unneeded part is read, the check reports a problem or the response makes a network or accounting API call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Read the tree index for the year folders and the cross-year files.
3. Resolve the current tax year first.
4. Read the year README and the one topic part it names, starting at its key figures section.
5. Run the fragment check over the tree.
6. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| REF-003 | Tax knowledge base | Read a figure question through the tree index and the year README and run the fragment check over the tree. | A question asks for the business mileage rate of the current tax year. Show how the tax knowledge base tree is read for a figure and run the fragment check over the tree. Keep this offline. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/README.md -> 4. Resolve the current tax year and read its year README -> 5. Read the one topic part the README names at its key figures section -> 6. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py -> 7. Report the read path and the fragment summary and confirm no network activity | The year resolves before any figure, the year README names the one read part, the fragment check reports 0 problems and the run makes no network call. | The read path with the named part, the fragment summary line and the pass or fail verdict. | PASS if the year is resolved before the figure, the year README names the one read part, the fragment check reports 0 problems and no API is called. FAIL if a figure is used before the year resolves, an unneeded part is read, the check reports a problem or the response makes a network or accounting API call. | Check the year resolution in the year and state resolver and the topic table in the year README, then rerun the fragment check. Repeat offline. |

### Prompt

- Prompt: A question asks for the business mileage rate of the current tax year. Show how the tax knowledge base tree is read for a figure and run the fragment check over the tree. Keep this offline.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/tax-rules/README.md
4. Resolve the current tax year and read its year README
5. Read the one topic part the README names at its key figures section
6. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py
7. Report the read path and the fragment summary and confirm the absence of network activity

### Expected

The year resolves before any figure, the year README names the one read part, the fragment check reports 0 problems and the run makes no network call.

### Evidence

The read path with the named part, the fragment summary line and the pass or fail verdict.

### Pass / Fail

- **Pass**: The year is resolved before the figure, the year README names the one read part, the fragment check reports 0 problems and no API is called.
- **Fail**: A figure is used before the year resolves, an unneeded part is read, the check reports a problem or the response makes a network or accounting API call.

### Failure Triage

Check the year resolution in the year and state resolver and the topic table in the year README, then rerun the fragment check. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/reference-and-state/tax-knowledge-base.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/references/tax-rules/README.md | The tree index with the eight year folder rows and the five cross-year file rows |
| sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md | The general rules and the pointer table to the general topic files |
| sk-moneybird-accountant/references/tax-rules/year-and-state.md | Fixes the tax year and the state of a value before it is used |
| sk-moneybird-accountant/references/tax-rules/general/ | The general topic files one cross-year question is routed through |
| sk-moneybird-accountant/scripts/check-fragments.py | Resolves every relative link and fragment into and inside the tree |

---

## 5. SOURCE METADATA

- Group: routing-and-state
- Playbook ID: REF-003
- Canonical root source: manual-testing-playbook.md
- Feature file path: routing-and-state/tax-knowledge-base.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/README.md -> 4. Resolve the current tax year and read its year README -> 5. Read the one topic part the README names at its key figures section -> 6. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py -> 7. Report the read path and the fragment summary and confirm no network activity

**Expected resources:** sk-moneybird-accountant/references/tax-rules/README.md, sk-moneybird-accountant/references/tax-rules/year-and-state.md and sk-moneybird-accountant/scripts/check-fragments.py
