---
title: "JRT-002 -- Write lock and missing scope"
description: "This scenario validates Write lock and missing scope for `JRT-002`. Its objective is to confirm a write without its explicit flag exits 3 and a write with the flag but a missing scope exits 4 before any network request."
version: 1.0.0.0
---

# JRT-002 -- Write lock and missing scope

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-002`.

---

## 1. OVERVIEW

This scenario validates Write lock and missing scope for `JRT-002`. Its objective is to confirm a write without its explicit flag exits 3 and a write with the flag but a missing scope exits 4 before any network request.

### Why This Matters

Migration extraction must never write to Jortt by accident. Both gates have to stop the call locally, before a token exists.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-002` and confirm the expected signals without contradictory evidence.

- Objective: Confirm a write without its explicit flag exits 3 and a write with the flag but a missing scope exits 4 before any network request.
- Real user request: `Show the dry-run for a Jortt expense creation without sending a request.`
- Prompt: `Show the dry-run for a Jortt expense creation without sending a request.`
- Expected execution process: The agent runs both dry-run commands, reads each exit code and explains which gate stopped the call.
- Expected signals: Step 1: exit 3 with a message that names `--allow-write`. Step 2: exit 4 with a message that names `expenses:write`. Neither step requests a token.
- Desired user-visible outcome: The operator sees that the write flag is checked first and the scope second, with no request sent.
- Pass/fail: PASS if the exit codes are 3 and 4 in that order and neither call reaches the network, FAIL if either command makes a request or returns another code.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Show the dry-run for a Jortt expense creation without sending a request.`

### Commands

1. `bash: JORTT_SCOPES=expenses:write jortt-cli call create-an-expense --dry-run`
2. `bash: JORTT_SCOPES=expenses:read jortt-cli call create-an-expense --allow-write --dry-run`

### Expected

- Step 1: exit 3 with a message that names `--allow-write`.
- Step 2: exit 4 with a message that names `expenses:write`. Neither step requests a token.

### Evidence

Both terminal messages and exit codes.

### Pass / Fail

- **Pass**: The exit codes are 3 and 4 in that order and neither call reaches the network.
- **Fail**: Either command makes a request or returns another code.

### Failure Triage

1. Run `cli/jortt-cli/tests/run-tests.sh` and check the two gate tests.
2. Review the write and scope gates in `references/cli.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/safety-gates/write-lock.md`](../../feature-catalog/safety-gates/write-lock.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Write gate and scope check |
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Offline gate tests |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-002
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/write-lock.md`
- Feature catalog entry: [`feature-catalog/safety-gates/write-lock.md`](../../feature-catalog/safety-gates/write-lock.md)
