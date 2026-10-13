---
title: "MBD-016 -- Failure diagnosis and recovery"
description: "This scenario validates Failure diagnosis and recovery for `MBD-016`. It focuses on the need to confirm that a guard failure maps to the safe next step instead of a blind retry."
version: 1.0.0.0
---

# MBD-016 -- Failure diagnosis and recovery

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-016`.

---

## 1. OVERVIEW

This scenario validates Failure diagnosis and recovery for `MBD-016`. It focuses on the need to confirm that a guard failure maps to the safe next step instead of a blind retry.

### Why This Matters

A failed write retried against an unknown target can move a record twice or reach the wrong administration. The troubleshooting rows exist so a failure stops the batch and names its cause and fix.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-016` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a guard exit 7 on a write maps to the missing writer configuration and its login fix.
- Real user request: `My Moneybird write stopped with a guard exit code and I do not know whether I should retry it.`
- Prompt: `The guard stopped my write with exit 7. What is the safe next step?`
- Expected execution process: The agent answers from `references/troubleshooting.md` and `references/cli.md` without repeating the write, and the operator compares the answer with the rows the command block returns.
- Expected signals: The answer names the missing writer configuration folder `$HOME/.config/moneybird-cli-writer`, says to run `moneybird-guard login-from-env --writer` after the pilot gate and notes that the guard never falls back to the reader session. The source check lists the exit 7 row and the diagnostic order.
- Desired user-visible outcome: The operator gets the cause and the fix for the exit code and knows not to repeat the write with different flags.
- Pass/fail: PASS if the answer maps exit 7 to the writer configuration and the writer login and the sources agree. FAIL if the answer tells the operator to retry the write, to widen it with `--production` or to reuse the reader session.
- Feature catalog: [Failure diagnosis and recovery](../../feature-catalog/api-knowledge/failure-diagnosis-and-recovery.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Answer from the troubleshooting guide without repeating the failed write.
3. Execute the source check exactly as written.
4. Compare the answer with the expected signals.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-016 | Failure diagnosis and recovery | Confirm that a guard exit 7 on a write maps to the missing writer configuration and its login fix | `The guard stopped my write with exit 7. What is the safe next step?` | 1. `agent: answer the prompt` -> 2. `bash: rg -n "Guard exit 7\|Quick Diagnostics\|login-from-env --writer" references/troubleshooting.md` | Step 1: the answer names the writer configuration folder, the writer login command and the pilot gate. Step 2: the guide shows the exit 7 row, the diagnostic order and the login fix | The answer text and the matching source lines | PASS if the answer maps exit 7 to the writer configuration and the writer login and the sources agree. FAIL if the answer tells the operator to retry the write, to widen it with `--production` or to reuse the reader session. | 1. Re-read the guard rows in `references/troubleshooting.md`. 2. Re-read the canonical exit table in `references/cli.md` section 3. 3. Confirm no second write ran |

### Command Block

Run the source check from the `cli-moneybird/` package root. Do not repeat the write.

```bash
rg -n "Guard exit 7|Quick Diagnostics|login-from-env --writer" references/troubleshooting.md
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-knowledge/failure-diagnosis-and-recovery.md`](../../feature-catalog/api-knowledge/failure-diagnosis-and-recovery.md) | Feature-catalog entry for the troubleshooting guide |
| [`feature-catalog/sessions-and-diagnostics/local-doctor.md`](../../feature-catalog/sessions-and-diagnostics/local-doctor.md) | Feature-catalog entry for the first diagnostic step |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Owns the diagnostic order and the failure rows |
| [`references/cli.md`](../../references/cli.md) | Owns the canonical exit-code table |
| [`SKILL.md`](../../SKILL.md) | Routes a failed operation to the troubleshooting reference |

---

## 5. SOURCE METADATA

- Group: Setup and diagnostics
- Playbook ID: MBD-016
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `setup/failure-diagnosis-and-recovery.md`
