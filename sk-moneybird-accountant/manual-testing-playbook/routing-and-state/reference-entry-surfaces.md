---
title: REF-001 -- Reference entry surfaces
description: This scenario validates the reference entry surfaces for REF-001. It focuses on offline checks and policy.
id: REF-001
catalog_applicable: true
version: 1.0.0.0
---

# REF-001 -- Reference entry surfaces

This document captures the offline prompt, local read sequence, expected signals and evidence for REF-001.

---

## 1. OVERVIEW

This scenario validates the reference entry surfaces. It focuses on running the two offline checks that prove the generated landing page, the key figure item index, the answer surface fields and the sourced term map stay in step with the reference tree.

### Why This Matters

The surfaces exist so a reader reaches a figure row, a section or a file without reading a whole section. A surface that drifts from its owning file promises an entry the tree does not hold, so both checks verify the surfaces instead of asserting them.

---

## 2. SCENARIO CONTRACT

- Objective: Run the reference index check and the source library check and report whether the entry surfaces are in step.
- Real user request: Run the reference index check and the source library check and tell me whether the landing page, the item index, the answer surface fields and the term map are in step. Keep this offline.
- Prompt: Run the reference index check and the source library check and tell me whether the landing page, the item index, the answer surface fields and the term map are in step. Keep this offline.
- Fixture rows: none in routing-gold.json. The checks run on the real corpus.
- Expected execution process: Read the project bootstrap and skill, run the reference index check and the source library check, read both result lines, name the surfaces and confirm no network call.
- Expected signals: The index check prints `reference-index: ok`, the source check prints its matching sources line, the report names the three landing page blocks, the item index, the `answerSurface` keys section, rows and tokens, the `nav_label` field and the term map and the run makes no network call.
- Desired user-visible outcome: Both result lines, the named surfaces and a clear PASS or FAIL verdict.
- Pass/fail: PASS if both checks exit 0 and print their ok lines and the report names the surfaces. FAIL if either check reports drift or a missing field, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the reference index check over the landing page, the item index and the `answerSurface` records.
3. Run the source library check over the frontmatter field set and the term map.
4. Read both result lines.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| REF-001 | Reference entry surfaces | Run the reference index check and the source library check and report whether the entry surfaces are in step. | Run the reference index check and the source library check and tell me whether the landing page, the item index, the answer surface fields and the term map are in step. Keep this offline. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check -> 4. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check -> 5. Report both result lines and the named surfaces and confirm no network activity | The index check prints `reference-index: ok`, the source check prints its matching sources line, the report names the surfaces and the run makes no network call. | Both result lines, the named surfaces and the pass or fail verdict. | PASS if both checks exit 0 and print their ok lines and the report names the surfaces. FAIL if either check reports drift or a missing field, exits nonzero or the response makes a network call. | Check the named surface row in references/README.md, index.json or the term map, then rerun both checks. Repeat offline. |

### Prompt

- Prompt: Run the reference index check and the source library check and tell me whether the landing page, the item index, the answer surface fields and the term map are in step. Keep this offline.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
4. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check
5. Report both result lines and the named surfaces and confirm the absence of network activity

### Expected

The index check prints `reference-index: ok`, the source check prints its matching sources line, the report names the surfaces and the run makes no network call.

### Evidence

Both result lines, the named surfaces and the pass or fail verdict.

### Pass / Fail

- **Pass**: Both checks exit 0 and print their ok lines and the report names the surfaces.
- **Fail**: Either check reports drift or a missing field, exits nonzero or the response makes a network call.

### Failure Triage

Check the named surface row in references/README.md, index.json or the term map, then rerun both checks. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/reference-and-state/reference-entry-surfaces.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/build-reference-index.py | Writes and checks the landing page, the item index, the `answerSurface` records and the `nav_label` field |
| sk-moneybird-accountant/references/README.md | The generated landing page with the three per-group blocks |
| sk-moneybird-accountant/references/index.json | Holds one record per reference file with its `answerSurface` object |
| sk-moneybird-accountant/assets/term-map.json | One row per Dutch term with its English gloss and the source the owning year file cites |
| sk-moneybird-accountant/scripts/build-source-library.py | Checks the frontmatter field set and the sourced term map entries |
| sk-moneybird-accountant/scripts/reference-index-test.sh | Proves the item index and the `answerSurface` schema on fixtures |
| sk-moneybird-accountant/scripts/source-library-test.sh | Proves the frontmatter field set and the term map checks on fixtures |

---

## 5. SOURCE METADATA

- Group: routing-and-state
- Playbook ID: REF-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: routing-and-state/reference-entry-surfaces.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check -> 4. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check -> 5. Report both result lines and the named surfaces and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/build-reference-index.py, sk-moneybird-accountant/references/index.json, sk-moneybird-accountant/assets/term-map.json and sk-moneybird-accountant/scripts/build-source-library.py
