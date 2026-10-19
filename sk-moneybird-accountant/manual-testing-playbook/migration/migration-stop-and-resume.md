---
title: MIG-008 -- Migration stop and resume
description: This scenario validates stop classification and verified-state resume for MIG-008. It focuses on offline routing and policy.
id: MIG-008
catalog_applicable: true
version: 1.0.0.0
---

# MIG-008 -- Migration stop and resume

This document captures the offline prompt, local read sequence, expected signals and evidence for MIG-008.

---

## 1. OVERVIEW

This scenario validates the stop and resume rule. It focuses on classifying a stopped batch through the stop-state recovery matrix and naming its owner, evidence, retry rule and closure test before any resume.

### Why This Matters

A migration batch that resumes from the wrong place can double-write a record or accept an unverified write. The recovery matrix fixes who owns each stop, which evidence the journal needs and which closure test must pass before the batch continues.

---

## 2. SCENARIO CONTRACT

- Objective: Route a stopped batch through the stop-state recovery matrix and report its owner, evidence, retry rule and closure test.
- Real user request: A migration batch stopped after a guarded read was rate limited. Who owns the stop, what evidence does it record and when may the batch resume? Do not call an API.
- Prompt: A migration batch stopped after a guarded read was rate limited. Who owns the stop, what evidence does it record and when may the batch resume? Do not call an API.
- Fixture rows: none in routing-gold.json. The scenario reads the recovery matrix directly.
- Expected execution process: Read the project bootstrap and skill, load the control framework stop conditions and the shared mechanisms recovery matrix, classify the stop and report its row and the resume rule.
- Expected signals: Selects MIGRATION, names the HTTP_429 row with the Orchestrator as owner, names the request ledger, the response status, Retry-After and the affected batch as evidence, states the documented wait and the one authorized read reissue or guarded read-back with a new approved intent, names the closure test, keeps the journal append-only, resumes from the last verified journal state and makes no API call.
- Desired user-visible outcome: The named stop row, its four fields and the verified-state resume rule, with no record read and no API call.
- Pass/fail: PASS if the stop is classified on the HTTP_429 row, owner, evidence, retry rule and closure test are named, the journal stays append-only and the resume reads from the last verified journal state. FAIL if the same call is reissued unchanged, the batch resumes from the last attempted action, a wrong owner is named or an API is called.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Read the control framework stop conditions and its recovery table.
3. Read the M11 stop-state recovery matrix in the shared mechanisms file.
4. Classify the stop and name its owner, evidence, retry rule and closure test.
5. State the resume rule and the append-only journal requirement.
6. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-008 | Migration stop and resume | Route a stopped batch through the stop-state recovery matrix and report its owner, evidence, retry rule and closure test. | A migration batch stopped after a guarded read was rate limited. Who owns the stop, what evidence does it record and when may the batch resume? Do not call an API. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/control-framework.md at the stop conditions and recovery section -> 4. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md at the M11 stop-state recovery matrix -> 5. Classify the stop and report its owner, evidence, retry rule and closure test -> 6. State the resume rule and confirm no API activity | The HTTP_429 row is named with the Orchestrator owner, the ledger, status, Retry-After and batch evidence, the wait and authorized reissue rule, the closure test, the append-only journal and the last verified journal state, and the run makes no API call. | The matrix row with its four fields, the resume rule sentence and the no-call confirmation. | PASS if the stop is classified on the HTTP_429 row, owner, evidence, retry rule and closure test are named, the journal stays append-only and the resume reads from the last verified journal state. FAIL if the same call is reissued unchanged, the batch resumes from the last attempted action, a wrong owner is named or an API is called. | Check the stop conditions in control-framework.md and the M11 row fields in shared-mechanisms.md, then the journal states in the same file. Repeat offline. |

### Prompt

- Prompt: A migration batch stopped after a guarded read was rate limited. Who owns the stop, what evidence does it record and when may the batch resume? Do not call an API.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/control-framework.md at the stop conditions and recovery section
4. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md at the M11 stop-state recovery matrix
5. Classify the stop and report its owner, evidence, retry rule and closure test
6. State the resume rule and confirm the absence of API activity

### Expected

The HTTP_429 row is named with the Orchestrator owner, the ledger, status, Retry-After and batch evidence, the wait and authorized reissue rule, the closure test, the append-only journal and the last verified journal state, and the run makes no API call.

### Evidence

The matrix row with its four fields, the resume rule sentence and the no-call confirmation.

### Pass / Fail

- **Pass**: The stop is classified on the HTTP_429 row, owner, evidence, retry rule and closure test are named, the journal stays append-only and the resume reads from the last verified journal state.
- **Fail**: The same call is reissued unchanged, the batch resumes from the last attempted action, a wrong owner is named or an API is called.

### Failure Triage

Check the stop conditions in control-framework.md and the M11 row fields in shared-mechanisms.md, then the journal states in the same file. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-stop-and-resume.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Defines journal states and the complete stop-state recovery matrix |
| sk-moneybird-accountant/references/migration/control-framework.md | Defines stop conditions, recovery ownership and the resume rule |
| sk-moneybird-accountant/SKILL.md | Routes a stopped batch through the last verified checkpoint |

---

## 5. SOURCE METADATA

- Group: migration
- Playbook ID: MIG-008
- Canonical root source: manual-testing-playbook.md
- Feature file path: migration/migration-stop-and-resume.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/control-framework.md at the stop conditions and recovery section -> 4. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md at the M11 stop-state recovery matrix -> 5. Classify the stop and report its owner, evidence, retry rule and closure test -> 6. State the resume rule and confirm no API activity

**Expected resources:** sk-moneybird-accountant/references/migration/control-framework.md and sk-moneybird-accountant/references/migration/shared-mechanisms.md
