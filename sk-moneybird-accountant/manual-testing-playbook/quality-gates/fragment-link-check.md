---
title: GATE-003 -- Fragment link check
description: This scenario validates the fragment link check for GATE-003. It focuses on offline checks and policy.
id: GATE-003
catalog_applicable: true
version: 1.0.0.0
---

# GATE-003 -- Fragment link check

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-003.

---

## 1. OVERVIEW

This scenario validates the fragment link check. It focuses on running the checker over the skill family and reporting the summary line and the rules it enforces.

### Why This Matters

A renamed heading or a moved file silently breaks every relative link and fragment that names it. The checker resolves each link path and each fragment against an anchor line or a heading slug and enforces the fixed section ids of the year topic files, so link drift fails the run instead of reaching a reader.

---

## 2. SCENARIO CONTRACT

- Objective: Run the fragment link check over the skill family and report the summary line and the rules it enforces.
- Real user request: Run the fragment link check over the skill family and report the summary line. Keep this as an offline check.
- Prompt: Run the fragment link check over the skill family and report the summary line. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The checker runs on the real corpus.
- Expected execution process: Read the project bootstrap and skill, run the checker over the bootstrap, the README and the skill markdown, read the last output line and confirm no network call.
- Expected signals: The last output line counts the links, the fragment links and 0 problems, the report names the duplicate-suffix rejection, the anchor and slug matching and the year section id rule and the run makes no network call.
- Desired user-visible outcome: The summary line with its counts, the named rules and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker exits 0 and its last line reports 0 problems and the report names the fragment and section id rules. FAIL if the checker reports a problem, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the checker over the skill family.
3. Read the last output line for the link, fragment and problem counts.
4. Report the rules the checker enforces.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-003 | Fragment link check | Run the fragment link check over the skill family and report the summary line and the rules it enforces. | Run the fragment link check over the skill family and report the summary line. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py -> 4. Report the summary line and the enforced rules and confirm no network activity | The last output line reports 0 problems with the link and fragment counts, the report names the duplicate-suffix rejection and the year section id rule and the run makes no network call. | The checker summary line, the named rules and the pass or fail verdict. | PASS if the checker exits 0 and its last line reports 0 problems and the report names the fragment and section id rules. FAIL if the checker reports a problem, exits nonzero or the response makes a network call. | Check the named link or fragment in the file the checker reports, then rerun the checker. Repeat offline. |

### Prompt

- Prompt: Run the fragment link check over the skill family and report the summary line. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py
4. Report the summary line and the enforced rules and confirm the absence of network activity

### Expected

The last output line reports 0 problems with the link and fragment counts, the report names the duplicate-suffix rejection and the year section id rule and the run makes no network call.

### Evidence

The checker summary line, the named rules and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker exits 0 and its last line reports 0 problems and the report names the fragment and section id rules.
- **Fail**: The checker reports a problem, exits nonzero or the response makes a network call.

### Failure Triage

Check the named link or fragment in the file the checker reports, then rerun the checker. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/fragment-link-check.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/check-fragments.py | Resolves link paths and fragments across the bootstrap, the README and the skill markdown |
| sk-moneybird-accountant/ROUTER.md | Links the routed references the check resolves |
| sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md | Holds the pointer table to the general topic files a cross-year question is routed through |
| sk-moneybird-accountant/scripts/fragment-check-test.sh | Proves the seeded link, slug and section id failures on fixtures and on a copy of the real tree |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-003
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/fragment-link-check.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-fragments.py -> 4. Report the summary line and the enforced rules and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/check-fragments.py and sk-moneybird-accountant/ROUTER.md
