---
title: "JRT-007 -- List and describe operations"
description: "This scenario validates List and describe operations for `JRT-007`. Its objective is to confirm ops filters by tag and describe prints the full contract of one operation from the local spec."
version: 1.0.0.0
---

# JRT-007 -- List and describe operations

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-007`.

---

## 1. OVERVIEW

This scenario validates List and describe operations for `JRT-007`. Its objective is to confirm ops filters by tag and describe prints the full contract of one operation from the local spec.

### Why This Matters

Every extraction starts by naming the right operation. A wrong slug or a missing scope is cheaper to catch here than after a token request.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-007` and confirm the expected signals without contradictory evidence.

- Objective: Confirm ops filters by tag and describe prints the full contract of one operation from the local spec.
- Real user request: `Which Jortt operations handle expenses, and what does the receipt download operation need?`
- Prompt: `Which Jortt operations handle expenses, and what does the receipt download operation need?`
- Expected execution process: The agent lists the expense operations, then describes the receipt download operation and names its scope and parameter.
- Expected signals: Step 1: a table with the columns `SLUG`, `METHOD`, `PATH` and `SCOPE` that lists expense operations only. Step 2: `Path: /v3/receipts/id/{id}/download`, `Scope: receipts:read`, `Path params: id` and an example call.
- Desired user-visible outcome: The operator gets the expense operation list and the exact call shape for a receipt download.
- Pass/fail: PASS if both steps exit 0 and step 2 names the receipt scope and the `id` parameter, FAIL if the table mixes in other tags or the description misses the scope or parameter.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Which Jortt operations handle expenses, and what does the receipt download operation need?`

### Commands

1. `bash: jortt-cli ops --tag expenses`
2. `bash: jortt-cli describe download-url-for-a-receipt`

### Expected

- Step 1: a table with the columns `SLUG`, `METHOD`, `PATH` and `SCOPE` that lists expense operations only.
- Step 2: `Path: /v3/receipts/id/{id}/download`, `Scope: receipts:read`, `Path params: id` and an example call.

### Evidence

Both outputs and their exit codes.

### Pass / Fail

- **Pass**: Both steps exit 0 and step 2 names the receipt scope and the `id` parameter.
- **Fail**: The table mixes in other tags or the description misses the scope or parameter.

### Failure Triage

1. Run `jortt-cli spec info` to confirm a spec is loaded.
2. Run `cli/jortt-cli/tests/run-tests.sh` and check the slug and describe tests.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/operation-discovery/list-operations.md`](../../feature-catalog/operation-discovery/list-operations.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | `ops` and `describe` handlers |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Slug derivation |

---

## 5. SOURCE METADATA

- Group: Operation discovery
- Playbook ID: JRT-007
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `operation-discovery/list-and-describe-operations.md`
- Feature catalog entry: [`feature-catalog/operation-discovery/list-operations.md`](../../feature-catalog/operation-discovery/list-operations.md)
