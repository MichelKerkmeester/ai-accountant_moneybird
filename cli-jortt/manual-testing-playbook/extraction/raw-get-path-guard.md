---
title: "JRT-009 -- Raw GET path guard"
description: "This scenario validates Raw GET path guard for `JRT-009`. Its objective is to confirm the raw GET command rejects a full URL, a parent-directory segment and a malformed query pair before any request."
version: 1.0.0.0
---

# JRT-009 -- Raw GET path guard

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-009`.

---

## 1. OVERVIEW

This scenario validates Raw GET path guard for `JRT-009`. Its objective is to confirm the raw GET command rejects a full URL, a parent-directory segment and a malformed query pair before any request.

### Why This Matters

`get` skips the operation lookup, so its own input checks are the only thing between a typo and an unexpected request.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-009` and confirm the expected signals without contradictory evidence.

- Objective: Confirm the raw GET command rejects a full URL, a parent-directory segment and a malformed query pair before any request.
- Real user request: `Try a few unsafe raw Jortt GET requests and show me that jortt-cli refuses them.`
- Prompt: `Try a few unsafe raw Jortt GET requests and show me that jortt-cli refuses them.`
- Expected execution process: The agent runs three invalid `get` commands and reads each refusal and exit code.
- Expected signals: Step 1: exit 2 with `get accepts an API path without a host, query string or fragment.` Step 2: exit 2 with `get path must not contain parent-directory segments.` Step 3: exit 2 with `GET parameters must use name=value.` No step requests a token.
- Desired user-visible outcome: The operator sees three clear refusals and no request.
- Pass/fail: PASS if all three steps exit 2 with the expected messages, FAIL if any step sends a request or exits with another code.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Try a few unsafe raw Jortt GET requests and show me that jortt-cli refuses them.`

### Commands

1. `bash: jortt-cli get https://api.jortt.nl/v3/expenses`
2. `bash: jortt-cli get /v3/../organizations/me`
3. `bash: jortt-cli get /v3/expenses vat_date_from`

### Expected

- Step 1: exit 2 with `get accepts an API path without a host, query string or fragment.`
- Step 2: exit 2 with `get path must not contain parent-directory segments.`
- Step 3: exit 2 with `GET parameters must use name=value.` No step requests a token.

### Evidence

The three messages and exit codes.

### Pass / Fail

- **Pass**: All three steps exit 2 with the expected messages.
- **Fail**: Any step sends a request or exits with another code.

### Failure Triage

1. Confirm the commands were copied exactly, including the bare `vat_date_from` argument.
2. Inspect `jortt_cmd_get` in `lib/commands.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-calls/raw-get.md`](../../feature-catalog/api-calls/raw-get.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Raw GET input checks |
| [`references/cli.md`](../../references/cli.md) | Raw GET contract |

---

## 5. SOURCE METADATA

- Group: Extraction
- Playbook ID: JRT-009
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `extraction/raw-get-path-guard.md`
- Feature catalog entry: [`api-calls/raw-get.md`](../../feature-catalog/api-calls/raw-get.md)
