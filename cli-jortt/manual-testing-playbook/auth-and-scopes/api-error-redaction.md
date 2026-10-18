---
title: "JRT-015 -- API error redaction"
description: "This scenario validates API error redaction for `JRT-015`. Its objective is to confirm a failed request prints only the HTTP status and safe labels and appends the full response to a private workspace log."
version: 1.0.0.0
---

# JRT-015 -- API error redaction

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-015`.

---

## 1. OVERVIEW

This scenario validates API error redaction for `JRT-015`. Its objective is to confirm a failed request prints only the HTTP status and safe labels and appends the full response to a private workspace log.

### Why This Matters

A failed response can carry customer data. The terminal has to stay safe for a support transcript while the full text stays available for diagnosis.

This scenario makes a live read-only request that the API is expected to reject. Run it only with an operator-approved read-only key.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-015` and confirm the expected signals without contradictory evidence.

- Objective: Confirm a failed request prints only the HTTP status and safe labels and appends the full response to a private workspace log.
- Real user request: `Trigger one safe Jortt API error and show me that only the status and field names print.`
- Prompt: `Trigger one safe Jortt API error and show me that only the status and field names print.`
- Expected execution process: The agent confirms the operator approved a live read, sends one GET for a customer ID that does not exist, then reads the log tail and the log mode.
- Expected signals: Step 1: exit 1 and a stderr line of the form `jortt-cli: HTTP 4xx` with only safe field or code labels after it, naming `migration-workspace/logs/jortt-errors.log`. Step 2: the log tail holds the probe URL and the full response. Step 3: the mode prints as 600. No response free text and no record content appears on the terminal.
- Desired user-visible outcome: The operator sees a safe terminal line, the full response in the private log and a 600 mode on that log.
- Pass/fail: PASS if step 1 exits 1 with a status-only line, step 2 shows the full response in the log and step 3 prints 600, FAIL if response free text or record content prints on the terminal, the exit code is another value or the log is missing or has another mode.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Trigger one safe Jortt API error and show me that only the status and field names print.`

### Commands

1. `bash: jortt-cli call get-customer-by-id --customer_id playbook-error-probe`
2. `bash: tail -n 5 migration-workspace/logs/jortt-errors.log`
3. `bash: stat -c '%a' migration-workspace/logs/jortt-errors.log || stat -f '%Lp' migration-workspace/logs/jortt-errors.log`

### Expected

- Step 1: exit 1 with `jortt-cli: HTTP 4xx` and only safe field or code labels after the status, and a note that names `migration-workspace/logs/jortt-errors.log`.
- Step 2: the log tail holds `GET https://api.jortt.nl/customers/playbook-error-probe` and the full response body.
- Step 3: `600`. No response free text and no record content appears on the terminal.

### Evidence

The stderr line and exit code, the log tail and the printed mode. Do not copy record content.

### Pass / Fail

- **Pass**: Step 1 exits 1 with a status-only line, step 2 shows the full response in the log and step 3 prints 600.
- **Fail**: Response free text or record content prints on the terminal, the exit code is another value or the log is missing or has another mode.

### Failure Triage

1. Mark the scenario SKIP with the blocker named when live credentials are unavailable or not approved.
2. On exit 6, refresh the token per `references/troubleshooting.md`. On another status, confirm the probe call is the one written in step 1.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/transport/api-error-redaction.md`](../../feature-catalog/transport/api-error-redaction.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | `jortt_api_error_report` and `jortt_log_api_error` |
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Offline error-redaction case with the stub response |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-015
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/api-error-redaction.md`
- Feature catalog entry: [`feature-catalog/transport/api-error-redaction.md`](../../feature-catalog/transport/api-error-redaction.md)
