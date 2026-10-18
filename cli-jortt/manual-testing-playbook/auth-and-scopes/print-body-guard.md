---
title: "JRT-014 -- Print body guard"
description: "This scenario validates Print body guard for `JRT-014`. Its objective is to confirm `--print-body` is refused with exit 2 when an agent session marker is set and that the refusal points at `--out`."
version: 1.0.0.0
---

# JRT-014 -- Print body guard

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-014`.

---

## 1. OVERVIEW

This scenario validates Print body guard for `JRT-014`. Its objective is to confirm `--print-body` is refused with exit 2 when an agent session marker is set and that the refusal points at `--out`.

### Why This Matters

A full record body in a terminal transcript can leak customer data. The refusal has to fire before the spec is read and before a request is made.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-014` and confirm the expected signals without contradictory evidence.

- Objective: Confirm `--print-body` is refused with exit 2 when an agent session marker is set and that the refusal points at `--out`.
- Real user request: `Test jortt-cli with --print-body set to an agent marker and prove it refuses to print the record body.`
- Prompt: `Show that jortt-cli refuses --print-body in an agent session and points to --out instead.`
- Expected execution process: The agent sets one session marker at a time and reads the refusal on the first line of each command.
- Expected signals: Step 1: exit 2 and `jortt-cli: --print-body is refused because AI_SESSION_CHILD is set. Use --out and read the saved file instead.` Step 2: exit 2 with the same message naming `CLAUDECODE`. Neither step reads the spec or requests a token.
- Desired user-visible outcome: The operator sees a one-line refusal per marker and a safe alternative.
- Pass/fail: PASS if both steps exit 2 with a message that names the marker and points at `--out`, FAIL if either step prints a body, reads the spec or exits with another code.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Show that jortt-cli refuses --print-body in an agent session and points to --out instead.`

### Commands

1. `bash: env -u CLAUDECODE -u ACCOUNTANT_AGENT_SESSION -u CODEX_SANDBOX AI_SESSION_CHILD=1 jortt-cli call list-expenses --print-body`
2. `bash: env -u AI_SESSION_CHILD -u ACCOUNTANT_AGENT_SESSION -u CODEX_SANDBOX CLAUDECODE=1 jortt-cli call list-customers --print-body`

### Expected

- Step 1: exit 2 with `jortt-cli: --print-body is refused because AI_SESSION_CHILD is set. Use --out and read the saved file instead.`
- Step 2: exit 2 with the same message naming `CLAUDECODE`. Neither step reads the spec or requests a token.

### Evidence

Both stderr lines and their exit codes.

### Pass / Fail

- **Pass**: Both steps exit 2 with a message that names the marker and points at `--out`.
- **Fail**: Either step prints a body, reads the spec or exits with another code.

### Failure Triage

1. Confirm the marker is exported for the command and that no wrapper unsets it.
2. Inspect `jortt_check_print_body_allowed` in `cli/jortt-cli/lib/common.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/safety-gates/print-body-guard.md`](../../feature-catalog/safety-gates/print-body-guard.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Agent session markers and the refusal helper |
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | One refusal case per marker |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-014
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/print-body-guard.md`
- Feature catalog entry: [`feature-catalog/safety-gates/print-body-guard.md`](../../feature-catalog/safety-gates/print-body-guard.md)
