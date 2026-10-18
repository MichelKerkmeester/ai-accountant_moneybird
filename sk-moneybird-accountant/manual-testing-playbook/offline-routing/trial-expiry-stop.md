---
title: MIG-004 -- Trial expiry before write batch
description: Offline routing scenario for trial expiry before write batch.
id: MIG-004
catalog_applicable: true
version: 1.0.0.0
---

# MIG-004 -- Trial expiry before write batch

This document captures the offline prompt, local read sequence, expected signals and evidence for MIG-004.

---

## 1. OVERVIEW

This scenario validates stop a moneybird write batch when trial or package access may expire before verification completes.

### Why This Matters

A local-only check verifies gate routing while keeping accounting tools, network calls and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Stop a Moneybird write batch when trial or package access may expire before verification completes.
- Real user request: The trial expires before the next Moneybird write batch and read-back can finish. Should the batch proceed? Do not call an API.
- Prompt: The trial expires before the next Moneybird write batch and read-back can finish. Should the batch proceed? Do not call an API.
- Fixture rows: MIG-004 (English) and MIG-004-nl (Dutch twin).
- Expected execution process: Read only the listed local public references. Do not use a network connection or accounting API.
- Expected signals: Stops the batch because the access window does not cover the write, synchronization, read-back and verification. Requires the Operator to confirm valid access and evidence before resuming. No API is called.
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
| MIG-004 | Trial expiry before write batch | Stop a Moneybird write batch when trial or package access may expire before verification completes. | The trial expires before the next Moneybird write batch and read-back can finish. Should the batch proceed? Do not call an API. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md -> 4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md -> 5. Report the stop and required access evidence without calling an API | Stops the batch because the access window does not cover the write, synchronization, read-back and verification. Requires the Operator to confirm valid access and evidence before resuming. No API is called. | Capture the prompt, selected route, required gate, evidence rule and confirmation that no API was called. | PASS if all expected signals appear and no API call occurs. FAIL if the request is executed, a required gate or evidence item is omitted or the global read-only boundary is weakened. | Check whether access covers the complete write and verification window. If expiry is uncertain, keep the batch stopped. Repeat offline. |

### Prompt

- Prompt: The trial expires before the next Moneybird write batch and read-back can finish. Should the batch proceed? Do not call an API.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md
4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md
5. Report the stop and required access evidence without calling an API

### Expected

Stops the batch because the access window does not cover the write, synchronization, read-back and verification. Requires the Operator to confirm valid access and evidence before resuming. No API is called.

### Evidence

Capture the prompt, selected route, required gate, evidence rule and confirmation that no API was called.

### Pass / Fail

- **Pass**: All expected signals appear and no API call occurs.
- **Fail**: The request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened.

### Failure Triage

Check whether access covers the complete write and verification window. If expiry is uncertain, keep the batch stopped. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-trial-and-package-expiry.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Defines access-window checks before writes and verification. |
| sk-moneybird-accountant/references/migration/overview-and-setup.md | Defines expiry, evidence, renewal owner and alert config fields. |
| sk-moneybird-accountant/SKILL.md | Requires a current expiry check before every non-GET batch. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-004
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/trial-expiry-stop.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md -> 4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md -> 5. Report the stop and required access evidence without calling an API

**Expected resources:** AGENTS.md, sk-moneybird-accountant/SKILL.md, sk-moneybird-accountant/references/migration/shared-mechanisms.md, sk-moneybird-accountant/references/migration/overview-and-setup.md
