---
title: GATE-001 -- English first check
description: This scenario validates the English first wording gate for GATE-001. It focuses on offline checks and policy.
id: GATE-001
catalog_applicable: true
version: 1.0.0.0
---

# GATE-001 -- English first check

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-001.

---

## 1. OVERVIEW

This scenario validates the English first gate. It focuses on running the checker over the skill family and reporting the problem count and the problem kinds it can name.

### Why This Matters

The skill family writes English first and keeps Dutch only as a labelled term or as data. The checker enforces that rule, so a new unlabelled Dutch term or a dropped Dutch label fails the run instead of slipping into the corpus.

---

## 2. SCENARIO CONTRACT

- Objective: Run the English first check on the skill family and report the problem count and the problem kinds it reports.
- Real user request: Run the English first check on the skill family and report what it found. Keep this as an offline check.
- Prompt: Run the English first check on the skill family and report what it found. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The checker runs on the real corpus.
- Expected execution process: Read the project bootstrap and skill, run the checker over the skill family, report the count line and the problem kinds and confirm no network call.
- Expected signals: The checker prints `0 problems`, the report names the problem kinds residual, first-use, doubled, reversed, unglossed, duplicate and stale-exception, names the glossary term index and the exceptions file and the run makes no network call.
- Desired user-visible outcome: The count line, the six problem kinds plus the stale exception kind and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker exits 0 and prints `0 problems` and the report names the problem kinds and the exceptions file. FAIL if the checker reports a problem, exits nonzero or the response downloads anything.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the checker over the real corpus.
3. Read the count line and any reported problem lines.
4. Report the problem kinds the checker can name and the exceptions file.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-001 | English first check | Run the English first check on the skill family and report the problem count and the problem kinds it reports. | Run the English first check on the skill family and report what it found. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-english-first.py -> 4. Report the count line and the problem kinds and confirm no network activity | The checker prints `0 problems`, the report names the problem kinds and the exceptions file and the run makes no network call. | The checker count line, the named problem kinds and the pass or fail verdict. | PASS if the checker exits 0 and prints `0 problems` and the report names the problem kinds and the exceptions file. FAIL if the checker reports a problem, exits nonzero or the response downloads anything. | Check the glossary category files and the exceptions file, then rerun the checker. Repeat offline. |

### Prompt

- Prompt: Run the English first check on the skill family and report what it found. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-english-first.py
4. Report the count line and the problem kinds and confirm the absence of network activity

### Expected

The checker prints `0 problems`, the report names the problem kinds and the exceptions file and the run makes no network call.

### Evidence

The checker count line, the named problem kinds and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker exits 0 and prints `0 problems` and the report names the problem kinds and the exceptions file.
- **Fail**: The checker reports a problem, exits nonzero or the response downloads anything.

### Failure Triage

Check the glossary category files and the exceptions file, then rerun the checker. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/english-first-check.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/check-english-first.py | Masks the data regions, applies the six rules and the exceptions and prints the sorted problem lines |
| sk-moneybird-accountant/references/glossary/ | Holds the English and Dutch term pairs the rules read |
| sk-moneybird-accountant/assets/english-first-exceptions.json | Lists each kept Dutch term with its file, check, rule and reason |
| sk-moneybird-accountant/scripts/check-english-first-test.sh | Proves each rule and mask on fixtures and runs the checker on the real corpus |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/english-first-check.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-english-first.py -> 4. Report the count line and the problem kinds and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/check-english-first.py, sk-moneybird-accountant/references/glossary/ and sk-moneybird-accountant/assets/english-first-exceptions.json
