---
title: MIG-002 -- Write journal crash resume
description: Offline routing scenario for write journal crash resume.
id: MIG-002
catalog_applicable: true
version: 1.0.0.0
---

# MIG-002 -- Write journal crash resume

This document captures the offline prompt, local read sequence, expected signals, and evidence for MIG-002.

---

## 1. OVERVIEW

This scenario validates resume an interrupted write batch from its journal and read back uncertain outcomes without blind retry.

### Why This Matters

A local-only check verifies gate routing while keeping accounting tools, network calls, and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Resume an interrupted write batch from its journal and read back uncertain outcomes without blind retry.
- Real user request: A Moneybird write batch crashed after WRITE_INTENT and the response was lost. Show how to resume from the journal. Do not call an API or blindly retry.
- Prompt: A Moneybird write batch crashed after WRITE_INTENT and the response was lost. Show how to resume from the journal. Do not call an API or blindly retry.
- Expected execution process: Read only the listed local public references. Do not use a network connection or accounting API.
- Expected signals: Routes through the append-only run journal and stable local write key. Resumes from the last verified state, checks source reference and every planned payload field using a synchronized read or documented cache wait, stops on ambiguity, and does not blindly retry. No API is called.
- Desired user-visible outcome: A concise route report with the required gate, owner action, stop or recovery rule, and no API activity.
- Pass/fail: PASS if all expected signals appear and no API call occurs. FAIL if the request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the skill and the listed local references.
2. Apply the prompt without accessing external services or private finance data.
3. Compare the response with the expected signals.
4. Record a concise verdict and evidence.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-002 | Write journal crash resume | Resume an interrupted write batch from its journal and read back uncertain outcomes without blind retry. | A Moneybird write batch crashed after WRITE_INTENT and the response was lost. Show how to resume from the journal. Do not call an API or blindly retry. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/shared-mechanisms.md -> 4. Read references/migration/control-framework.md -> 5. Report journal states, read-back conditions, and retry rule without calling an API | Routes through the append-only run journal and stable local write key. Resumes from the last verified state, checks source reference and every planned payload field using a synchronized read or documented cache wait, stops on ambiguity, and does not blindly retry. No API is called. | Capture the prompt, selected route, required gate, evidence rule, and confirmation that no API was called. | PASS if all expected signals appear and no API call occurs. FAIL if the request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened. | Check that the response loss is treated as WRITE_UNKNOWN, then verify the read-back and exact-match requirement. Repeat offline. |

### Prompt

- Prompt: A Moneybird write batch crashed after WRITE_INTENT and the response was lost. Show how to resume from the journal. Do not call an API or blindly retry.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/migration/shared-mechanisms.md
4. Read references/migration/control-framework.md
5. Report journal states, read-back conditions, and retry rule without calling an API

### Expected

Routes through the append-only run journal and stable local write key. Resumes from the last verified state, checks source reference and every planned payload field using a synchronized read or documented cache wait, stops on ambiguity, and does not blindly retry. No API is called.

### Evidence

Capture the prompt, selected route, required gate, evidence rule, and confirmation that no API was called.

### Pass / Fail

- **Pass**: All expected signals appear and no API call occurs.
- **Fail**: The request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened.

### Failure Triage

Check that the response loss is treated as WRITE_UNKNOWN, then verify the read-back and exact-match requirement. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-write-keys-and-run-journal.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/shared-mechanisms.md | Defines stable keys, WRITE_INTENT, journal states, and uncertain-write recovery. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/control-framework.md | Defines stop conditions and resume from verified state. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Routes writes through the approval and journal controls. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/write-journal-crash-resume.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/shared-mechanisms.md -> 4. Read references/migration/control-framework.md -> 5. Report journal states, read-back conditions, and retry rule without calling an API

**Expected resources:** AI Systems/Moneybird Accountant/AGENTS.md, SKILL.md, references/migration/shared-mechanisms.md, references/migration/control-framework.md
