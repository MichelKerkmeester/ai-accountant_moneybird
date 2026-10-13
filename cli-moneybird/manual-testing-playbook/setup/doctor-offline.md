---
title: "MBD-001 -- Doctor runs offline"
description: "This scenario validates Doctor runs offline for `MBD-001`. It focuses on the need to confirm that the doctor reports local state without a network call or a credential value."
version: 1.0.0.0
---

# MBD-001 -- Doctor runs offline

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-001`.

---

## 1. OVERVIEW

This scenario validates Doctor runs offline for `MBD-001`. It focuses on the need to confirm that the doctor reports local state without a network call or a credential value.

### Why This Matters

The doctor is the first diagnostic an agent runs. It must stay safe to run without operator approval, which means no network call and no credential read.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-001` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that the doctor reports local state without a network call or a credential value.
- Real user request: `Check my Moneybird setup without contacting any service.`
- Prompt: `Run the Moneybird doctor offline and tell me whether it read or printed any credential.`
- Expected execution process: The agent runs `bash scripts/doctor.sh` with no option and reads the report. It does not pass `--live`.
- Expected signals: The report ends with the read-only line and shows only yes or no and set or unset values.
- Desired user-visible outcome: A local diagnostic summary with no token, no administration ID and no network result.
- Pass/fail: PASS if the doctor exits 0, prints `Doctor is read-only` and shows no credential value. FAIL if it calls the network, prints a token or prints an administration ID.
- Feature catalog: [Local doctor](../../feature-catalog/sessions-and-diagnostics/local-doctor.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Decide whether the scenario stays local or needs the operator for a live step.
3. Execute the deterministic steps exactly as written.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-001 | Doctor runs offline | Confirm that the doctor reports local state without a network call or a credential value | `Run the Moneybird doctor offline and tell me whether it read or printed any credential.` | 1. `bash: bash scripts/doctor.sh` -> 2. `bash: bash scripts/doctor.sh \| grep -E "read-only"` | Step 1: exit 0 with yes or no lines and set or unset lines. Step 2: `Doctor is read-only` is printed | Full doctor output reviewed locally with any path that names a person replaced by a placeholder | PASS if the doctor exits 0, prints `Doctor is read-only` and shows no credential value. FAIL if it calls the network, prints a token or prints an administration ID. | 1. Confirm no `--live` argument was passed. 2. Check `scripts/doctor.sh` for a changed offline branch. 3. Compare with the troubleshooting order in `references/troubleshooting.md` |

### Command Block

Run from the `cli-moneybird/` package root. The doctor checks the real local setup for presence only.

```bash
bash scripts/doctor.sh
echo "exit=$?"
bash scripts/doctor.sh | grep -E "read-only"
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/sessions-and-diagnostics/local-doctor.md`](../../feature-catalog/sessions-and-diagnostics/local-doctor.md) | Feature-catalog entry for Local doctor |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`scripts/doctor.sh`](../../scripts/doctor.sh) | Doctor implementation |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Diagnostic order |

---

## 5. SOURCE METADATA

- Group: Setup and diagnostics
- Playbook ID: MBD-001
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `setup/doctor-offline.md`
