---
title: "JRT-012 -- Organization check prints field names only"
description: "This scenario validates Organization check prints field names only for `JRT-012`. Its objective is to confirm whoami proves the live connection while printing only the HTTP status and top-level field names."
version: 1.0.0.0
---

# JRT-012 -- Organization check prints field names only

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-012`.

---

## 1. OVERVIEW

This scenario validates Organization check prints field names only for `JRT-012`. Its objective is to confirm whoami proves the live connection while printing only the HTTP status and top-level field names.

### Why This Matters

The live connection check is the one command that touches real organization data. Its output has to be safe evidence.

This scenario makes a live read-only request. Run it only with an operator-approved read-only key.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-012` and confirm the expected signals without contradictory evidence.

- Objective: Confirm whoami proves the live connection while printing only the HTTP status and top-level field names.
- Real user request: `Check that my Jortt API key works, but do not show me any organization details.`
- Prompt: `Check that my Jortt API key works, but do not show me any organization details.`
- Expected execution process: The agent confirms the operator approved a live read, runs `whoami` once and reports the status line.
- Expected signals: Step 1: `HTTP status: 200` followed by `Top-level field names:` and a comma-separated list of key names with no values.
- Desired user-visible outcome: The operator learns the key works and sees no organization value.
- Pass/fail: PASS if the status is 200 and the second line lists key names only, FAIL if any field value prints or the command exits with another code.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Check that my Jortt API key works, but do not show me any organization details.`

### Commands

1. `bash: jortt-cli whoami`

### Expected

- Step 1: `HTTP status: 200` followed by `Top-level field names:` and a comma-separated list of key names with no values.

### Evidence

The two output lines. Do not capture anything beyond them.

### Pass / Fail

- **Pass**: The status is 200 and the second line lists key names only.
- **Fail**: Any field value prints or the command exits with another code.

### Failure Triage

1. Mark the scenario SKIP with the blocker named when live credentials are unavailable or not approved.
2. On exit 4 or 6, follow the scope and token steps in `references/troubleshooting.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-calls/organization-check.md`](../../feature-catalog/api-calls/organization-check.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | `whoami` handler |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Token and scope recovery |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-012
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/whoami-field-names.md`
- Feature catalog entry: [`api-calls/organization-check.md`](../../feature-catalog/api-calls/organization-check.md)
