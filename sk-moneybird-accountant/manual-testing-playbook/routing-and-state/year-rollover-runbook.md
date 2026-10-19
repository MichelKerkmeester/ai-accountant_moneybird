---
title: "STATE-002 -- Year rollover runbook"
description: "This scenario validates the year rollover runbook and the offline calendar check for STATE-002."
id: STATE-002
catalog_applicable: true
version: 1.0.0.0
---

# STATE-002 -- Year rollover runbook

This document captures the offline prompt, local read sequence, expected signals and evidence for STATE-002.

---

## 1. OVERVIEW

This scenario validates the year rollover runbook. It focuses on the 1 January steps, the release calendar and the offline calendar check that keeps the year files current.

### Why This Matters

A year file that still holds last year's figures, or a checked date that lags a passed checkpoint, presents a stale figure as settled. The runbook is the Operator's route through the rollover and the calendar check is the falsifiable end of it. A local-only check confirms both without fetching a page.

---

## 2. SCENARIO CONTRACT

- Objective: Walk the year rollover runbook and run the offline calendar check.
- Real user request: It is time for the year rollover. Walk me through the runbook for the newest year folder and tell me what the calendar check verifies. Do not fetch any page.
- Prompt: It is time for the year rollover. Walk me through the runbook for the newest year folder and tell me what the calendar check verifies. Do not fetch any page.
- Fixture rows: none in routing-gold.json. The calendar check reads the tracked year files.
- Expected execution process: Read the project bootstrap and skill, then the rollover runbook and the watchlist, then run the offline calendar check. Do not use network access, accounting APIs or private finance data.
- Expected signals: Names the Operator as the runbook owner. Lists the eight runbook steps from the new year folder through the changelog. Names the five release checkpoints as check-by dates and says the Operator moves them each cycle. States that the calendar check reads the checked_on dates from the year READMEs and the rules file and fails when a current or future year predates the latest passed checkpoint. The offline run reports the current year files current at the latest passed checkpoint.
- Desired user-visible outcome: A concise rollover report with the owner, the runbook steps, the checkpoints and the calendar check result.
- Pass/fail: PASS if the owner, the runbook steps, the checkpoint names and the offline calendar result are correct and no page is fetched. FAIL if a step or checkpoint is missing, a stale year is reported current or the run fetches a page.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Read the rollover runbook and the watchlist.
3. Run the offline calendar check.
4. Compare the steps, the checkpoints and the result with the expected signals.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| STATE-002 | Year rollover runbook | Walk the year rollover runbook and run the offline calendar check. | It is time for the year rollover. Walk me through the runbook for the newest year folder and tell me what the calendar check verifies. Do not fetch any page. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/year-rollover.md -> 4. Read sk-moneybird-accountant/assets/source-watchlist.json -> 5. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar -> 6. Report the runbook steps, the release checkpoints and the calendar check result | Names the Operator as owner, lists the eight runbook steps and the five checkpoints, states the checked_on rule and the stale-year failure. The offline run reports the current year files current at the latest passed checkpoint. | Capture the prompt, the owner, the steps, the checkpoint names, the calendar output and the no-network status. | PASS if the owner, the runbook steps, the checkpoint names and the offline calendar result are correct and no page is fetched. FAIL if a step or checkpoint is missing, a stale year is reported current or the run fetches a page. | Check sections 2 and 3 of the runbook reference, then rerun the calendar check. Repeat offline. |

### Prompt

- Prompt: It is time for the year rollover. Walk me through the runbook for the newest year folder and tell me what the calendar check verifies. Do not fetch any page.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/tax-rules/year-rollover.md
4. Read sk-moneybird-accountant/assets/source-watchlist.json
5. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar
6. Report the runbook steps, the release checkpoints and the calendar check result

### Expected

Names the Operator as owner, lists the eight runbook steps and the five checkpoints, states the checked_on rule and the stale-year failure. The offline run reports the current year files current at the latest passed checkpoint.

### Evidence

Capture the prompt, the owner, the steps, the checkpoint names, the calendar output and the no-network status.

### Pass / Fail

- **Pass**: The owner, the runbook steps, the checkpoint names and the offline calendar result are correct and no page is fetched.
- **Fail**: A step or checkpoint is missing, a stale year is reported current or the run fetches a page.

### Failure Triage

Check sections 2 and 3 of the runbook reference, then rerun the calendar check. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/reference-and-state/year-rollover-runbook.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/references/tax-rules/year-rollover.md | Owns the runbook, the release calendar and the owner of both. |
| sk-moneybird-accountant/assets/source-watchlist.json | Lists the publication series the monthly watch checks. |
| sk-moneybird-accountant/scripts/build-source-library.py | Implements the watch and the calendar check modes. |
| sk-moneybird-accountant/scripts/source-library-test.sh | Proves the watch, its state and the calendar check on fixtures and the real corpus. |

---

## 5. SOURCE METADATA

- Group: routing-and-state
- Playbook ID: STATE-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: routing-and-state/year-rollover-runbook.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/year-rollover.md -> 4. Read sk-moneybird-accountant/assets/source-watchlist.json -> 5. Run python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar -> 6. Report the runbook steps, the release checkpoints and the calendar check result

**Expected resources:** sk-moneybird-accountant/references/tax-rules/year-rollover.md, sk-moneybird-accountant/assets/source-watchlist.json, sk-moneybird-accountant/scripts/build-source-library.py
