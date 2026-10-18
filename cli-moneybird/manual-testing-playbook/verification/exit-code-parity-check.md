---
title: "MBD-018 -- Exit code parity check"
description: "This scenario validates the Exit code parity check for `MBD-018`. It focuses on the need to confirm that every documented guard exit code still matches the guard and that the self-test catches drift."
version: 1.0.0.0
---

# MBD-018 -- Exit code parity check

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-018`.

---

## 1. OVERVIEW

This scenario validates the Exit code parity check for `MBD-018`. It focuses on the need to confirm that every documented guard exit code still matches the guard and that the self-test catches drift.

### Why This Matters

The guard is the source of truth for its exit codes. A documented surface that drifts from the guard sends an agent down the wrong recovery path, so both directions of the comparison must hold and the check must be able to fail.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-018` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that the parity check prints `ok` against the current tree and that the self-test reports zero failures across the clean copy and the mutated copies.
- Real user request: `Make sure the documented Moneybird guard exit codes still match the guard before we rely on the troubleshooting rows.`
- Prompt: `Check that every documented Moneybird guard exit code still matches the guard and prove the check catches drift.`
- Expected execution process: The agent runs the parity check and its self-test from the `cli-moneybird/` package root and reads the report lines and the two exit statuses.
- Expected signals: The parity check prints an `exit-code-parity: ok` line with the guard code set and exits 0. The self-test runs the check on a clean copy and on mutated copies, prints a `Result: <passed> passed, 0 failed` line and exits 0. Neither script calls the CLI and neither opens a credential file.
- Desired user-visible outcome: The operator sees that the documented exit codes match the guard and that a mutated surface is caught by the self-test.
- Pass/fail: PASS if the parity check prints `ok` and exits 0 and the self-test reports zero failures and exits 0. FAIL if either script exits nonzero or the self-test reports a failed case.
- Feature catalog: [Exit code parity check](../../feature-catalog/verification/exit-code-parity-check.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Run the parity check exactly as written against the current tree.
3. Run the self-test exactly as written and read its result line.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-018 | Exit code parity check | Confirm that the parity check prints `ok` and that the self-test reports zero failures across the clean copy and the mutated copies | `Check that every documented Moneybird guard exit code still matches the guard and prove the check catches drift.` | 1. `bash: bash scripts/exit-code-parity.sh` -> 2. `bash: bash scripts/exit-code-parity-test.sh` -> 3. `bash: read both exit statuses` | Step 1: an `exit-code-parity: ok` line with the guard code set and exit status 0. Step 2: a `Result: <passed> passed, 0 failed` line and exit status 0. Step 3: both statuses read 0 | The parity report line, the self-test result line and the two exit statuses | PASS if the parity check prints `ok` and exits 0 and the self-test reports zero failures and exits 0. FAIL if either script exits nonzero or the self-test reports a failed case. | 1. Confirm both scripts ran from the `cli-moneybird/` package root. 2. Re-read the named gap line the failing mutant prints and compare it with the mutated surface. 3. Correct the named surface, then re-run `bash scripts/exit-code-parity.sh` and confirm the gap line is gone |

### Command Block

Run from the `cli-moneybird/` package root. Both scripts read files only. They never call the CLI and never open a credential file.

```bash
bash scripts/exit-code-parity.sh
echo "parity exit=$?"
bash scripts/exit-code-parity-test.sh
echo "self-test exit=$?"
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/verification/exit-code-parity-check.md`](../../feature-catalog/verification/exit-code-parity-check.md) | Feature-catalog entry for the parity check and its self-test |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`scripts/exit-code-parity.sh`](../../scripts/exit-code-parity.sh) | Compares the guard exit codes with every documented surface |
| [`scripts/exit-code-parity-test.sh`](../../scripts/exit-code-parity-test.sh) | Runs the check on a clean copy and on mutated copies |
| [`references/cli.md`](../../references/cli.md) | Owns the canonical exit-code table the check compares |
| [`.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Runs the parity check and its self-test on every push and pull request |

---

## 5. SOURCE METADATA

- Group: Verification
- Playbook ID: MBD-018
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `verification/exit-code-parity-check.md`
