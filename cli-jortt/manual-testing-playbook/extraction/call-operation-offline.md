---
title: "JRT-011 -- Call an operation offline"
description: "This scenario validates Call an operation offline for `JRT-011`. Its objective is to confirm `call` validates parameter names, required values and types and prints the dry-run request without a token or a network call."
version: 1.0.0.0
---

# JRT-011 -- Call an operation offline

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-011`.

---

## 1. OVERVIEW

This scenario validates Call an operation offline for `JRT-011`. Its objective is to confirm `call` validates parameter names, required values and types and prints the dry-run request without a token or a network call.

### Why This Matters

`call` is the main extraction command. A bad parameter caught locally keeps the request count down and keeps a typo out of the API log.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-011` and confirm the expected signals without contradictory evidence.

- Objective: Confirm `call` validates parameter names, required values and types and prints the dry-run request without a token or a network call.
- Real user request: `Show me how jortt-cli would call the expense list and stop invalid parameters before sending anything.`
- Prompt: `Show me how jortt-cli would call the expense list and stop invalid parameters before sending anything.`
- Expected execution process: The agent runs one valid dry run and three invalid calls, then names the check that stopped each invalid call.
- Expected signals: Step 1: the printed `GET` URL carries both `vat_date_from` and `vat_date_till`, followed by `Body: none`. Steps 2 to 4: exit 2 with the unknown-parameter, integer-type and missing-required-parameter messages. No step requests a token.
- Desired user-visible outcome: The operator sees the exact request shape and a clear local refusal for each bad input.
- Pass/fail: PASS if step 1 exits 0 with the dry-run URL and `Body: none`, steps 2 to 4 exit 2 with the expected messages and no step reaches the network, FAIL if a step exits with another code, prints another message or sends a request.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Show me how jortt-cli would call the expense list and stop invalid parameters before sending anything.`

### Commands

1. `bash: JORTT_SCOPES=expenses:read jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --dry-run`
2. `bash: jortt-cli call list-expenses --unknown_filter value --dry-run`
3. `bash: jortt-cli call list-expenses --page invalid --dry-run`
4. `bash: jortt-cli call get-expense-by-id --dry-run`

### Expected

- Step 1: `GET https://api.jortt.nl/v3/expenses?vat_date_from=YYYY-01-01&vat_date_till=YYYY-12-31` followed by `Body: none`.
- Step 2: exit 2 with `Unknown parameter 'unknown_filter'.` and the valid parameter list.
- Step 3: exit 2 with `Parameter 'page' must be an integer.`
- Step 4: exit 2 with `Required parameter 'id' is missing.` No step requests a token.

### Evidence

The four output blocks and their exit codes.

### Pass / Fail

- **Pass**: Step 1 exits 0 with the dry-run URL and `Body: none`, steps 2 to 4 exit 2 with the expected messages and no step reaches the network.
- **Fail**: A step exits with another code, prints another message or sends a request.

### Failure Triage

1. Confirm the local OpenAPI file is present and run `jortt-cli spec info`.
2. Inspect `jortt_validate_params` and `jortt_check_required_params` in `cli/jortt-cli/lib/commands.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-calls/call-operation.md`](../../feature-catalog/api-calls/call-operation.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Parameter validation, URL build and dry-run output |
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Offline coverage for the dry-run URL and the input checks |

---

## 5. SOURCE METADATA

- Group: Extraction
- Playbook ID: JRT-011
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `extraction/call-operation-offline.md`
- Feature catalog entry: [`feature-catalog/api-calls/call-operation.md`](../../feature-catalog/api-calls/call-operation.md)
