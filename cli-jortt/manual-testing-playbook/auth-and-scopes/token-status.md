---
title: "JRT-010 -- Token cache status"
description: "This scenario validates Token cache status for `JRT-010`. Its objective is to confirm token status and token clear report cache state without printing a token or calling the network."
version: 1.0.0.0
---

# JRT-010 -- Token cache status

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-010`.

---

## 1. OVERVIEW

This scenario validates Token cache status for `JRT-010`. Its objective is to confirm token status and token clear report cache state without printing a token or calling the network.

### Why This Matters

Operators check the token cache when a call fails with 401. The commands must stay safe to paste into a support thread.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-010` and confirm the expected signals without contradictory evidence.

- Objective: Confirm token status and token clear report cache state without printing a token or calling the network.
- Real user request: `Check whether jortt-cli has a cached token and clear it, without contacting Jortt.`
- Prompt: `Check whether jortt-cli has a cached token and clear it, without contacting Jortt.`
- Expected execution process: The agent uses a throwaway client ID so the real cache is untouched, then reads status, clears and reads status again.
- Expected signals: Step 1: `scope source: environment`, `Cached token: no` and `Remaining minutes: 0`. Step 2: `Cached token: cleared`. Step 3: `scope source: environment` and `Cached token: no`. No step prints a token or makes a request.
- Desired user-visible outcome: The operator sees cache state as yes or no with minutes, never the token itself.
- Pass/fail: PASS if all three steps exit 0 and print only the expected status lines, FAIL if any step prints a token string or makes a network request.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Check whether jortt-cli has a cached token and clear it, without contacting Jortt.`

### Commands

1. `bash: JORTT_ENV_FILE=/dev/null JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=playbook-client jortt-cli token status`
2. `bash: JORTT_ENV_FILE=/dev/null JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=playbook-client jortt-cli token clear`
3. `bash: JORTT_ENV_FILE=/dev/null JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=playbook-client jortt-cli token status`

### Expected

- Step 1: `scope source: environment`, `Cached token: no` and `Remaining minutes: 0`.
- Step 2: `Cached token: cleared`.
- Step 3: `scope source: environment` and `Cached token: no`. No step prints a token or makes a request.

### Evidence

The three output blocks and their exit codes.

### Pass / Fail

- **Pass**: All three steps exit 0 and print only the expected status lines.
- **Fail**: Any step prints a token string or makes a network request.

### Failure Triage

1. Confirm `JORTT_ENV_FILE=/dev/null` was set so no real credentials were read.
2. Inspect `jortt_token_status` and `jortt_token_clear` in `cli/jortt-cli/lib/api.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/transport/token-cache-and-retry.md`](../../feature-catalog/transport/token-cache-and-retry.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Token status and clear |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Private cache path |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-010
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/token-status.md`
- Feature catalog entry: [`feature-catalog/transport/token-cache-and-retry.md`](../../feature-catalog/transport/token-cache-and-retry.md)
