---
title: "JRT-001 -- Offline doctor"
description: "This scenario validates Offline doctor for `JRT-001`. Its objective is to confirm the doctor checks local prerequisites and setup state without network access or printed secrets."
version: 1.0.0.0
---

# JRT-001 -- Offline doctor

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-001`.

---

## 1. OVERVIEW

This scenario validates Offline doctor for `JRT-001`. Its objective is to confirm the doctor checks local prerequisites and setup state without network access or printed secrets.

### Why This Matters

The doctor is the first check an operator runs. If it leaked a credential or called the API, every later diagnosis would start from an unsafe step.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-001` and confirm the expected signals without contradictory evidence.

- Objective: Confirm the doctor checks local prerequisites and setup state without network access or printed secrets.
- Real user request: `Run the cli-jortt doctor offline and tell me whether the CLI and prerequisites are present.`
- Prompt: `Run the cli-jortt doctor offline and tell me whether the CLI and prerequisites are present.`
- Expected execution process: The agent runs the doctor without `--live` and summarizes tool availability and setting presence.
- Expected signals: Step 1: the report lists `bash`, `curl` and `jq`, prints `set` or `unset` for each Jortt setting and ends with `Mode: offline. No network calls were made.`
- Desired user-visible outcome: The operator learns which prerequisites and settings are present without seeing any credential value.
- Pass/fail: PASS if the script exits 0, ends with the offline line and prints no credential value, FAIL if it starts a live API check or prints a credential value.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Run the cli-jortt doctor offline and tell me whether the CLI and prerequisites are present.`

### Commands

1. `bash: bash cli-jortt/scripts/doctor.sh`

### Expected

- Step 1: the report lists `bash`, `curl` and `jq`, prints `set` or `unset` for each Jortt setting and ends with `Mode: offline. No network calls were made.`

### Evidence

The doctor transcript with the absolute CLI path redacted, plus the exit code.

### Pass / Fail

- **Pass**: The script exits 0, ends with the offline line and prints no credential value.
- **Fail**: It starts a live API check or prints a credential value.

### Failure Triage

1. Run `bash scripts/doctor.sh` again and compare its last line with the expected offline line.
2. Inspect `scripts/doctor.sh` and the diagnostic order in `references/troubleshooting.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/diagnostics/offline-doctor.md`](../../feature-catalog/diagnostics/offline-doctor.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`scripts/doctor.sh`](../../scripts/doctor.sh) | Offline local diagnostics |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Diagnostic sequence |

---

## 5. SOURCE METADATA

- Group: Auth and scopes
- Playbook ID: JRT-001
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `auth-and-scopes/doctor-offline.md`
- Feature catalog entry: [`feature-catalog/diagnostics/offline-doctor.md`](../../feature-catalog/diagnostics/offline-doctor.md)
