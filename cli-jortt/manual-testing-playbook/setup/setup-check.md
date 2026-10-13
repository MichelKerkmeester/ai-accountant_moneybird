---
title: "JRT-013 -- CLI setup check"
description: "This scenario validates CLI setup check for `JRT-013`. Its objective is to confirm the setup script checks prerequisites and prints the symlink command without changing any file."
version: 1.0.0.0
---

# JRT-013 -- CLI setup check

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-013`.

---

## 1. OVERVIEW

This scenario validates CLI setup check for `JRT-013`. Its objective is to confirm the setup script checks prerequisites and prints the symlink command without changing any file.

### Why This Matters

Setup is the first command a new operator runs. It must never change the machine unless the operator asks.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-013` and confirm the expected signals without contradictory evidence.

- Objective: Confirm the setup script checks prerequisites and prints the symlink command without changing any file.
- Real user request: `Check whether this machine is ready for jortt-cli and show me how to install it, but do not change anything.`
- Prompt: `Check whether this machine is ready for jortt-cli and show me how to install it, but do not change anything.`
- Expected execution process: The agent runs the setup script without `--link` and relays the printed symlink command.
- Expected signals: Step 1: `CLI file: ready`, a Bash version, `curl: available`, `jq: available`, a `Manual symlink command:` line and `No files changed. Pass --link to create this symlink.`
- Desired user-visible outcome: The operator gets a readiness report and an install command to review.
- Pass/fail: PASS if the script exits 0 and ends with the no-change line, FAIL if a symlink is created or a prerequisite line is missing.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Check whether this machine is ready for jortt-cli and show me how to install it, but do not change anything.`

### Commands

1. `bash: bash cli-jortt/cli/jortt-cli/setup.sh`

### Expected

- Step 1: `CLI file: ready`, a Bash version, `curl: available`, `jq: available`, a `Manual symlink command:` line and `No files changed. Pass --link to create this symlink.`

### Evidence

The transcript with the absolute path redacted and the exit code.

### Pass / Fail

- **Pass**: The script exits 0 and ends with the no-change line.
- **Fail**: A symlink is created or a prerequisite line is missing.

### Failure Triage

1. Check that `--link` was not passed.
2. Inspect `cli/jortt-cli/setup.sh` and the install order in `INSTALL-GUIDE.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/diagnostics/setup-check.md`](../../feature-catalog/diagnostics/setup-check.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/setup.sh`](../../cli/jortt-cli/setup.sh) | Prerequisite check and symlink command |
| [`INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Install sequence |

---

## 5. SOURCE METADATA

- Group: Setup
- Playbook ID: JRT-013
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `setup/setup-check.md`
- Feature catalog entry: [`feature-catalog/diagnostics/setup-check.md`](../../feature-catalog/diagnostics/setup-check.md)
