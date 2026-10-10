---
title: "MBD-008 -- Setup plan and pin check"
description: "This scenario validates Setup plan and pin check for `MBD-008`. It focuses on the need to confirm that the setup script prints its plan without installing and that the check reports the pin state."
version: 1.0.0.0
---

# MBD-008 -- Setup plan and pin check

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-008`.

---

## 1. OVERVIEW

This scenario validates Setup plan and pin check for `MBD-008`. It focuses on the need to confirm that the setup script prints its plan without installing and that the check reports the pin state.

### Why This Matters

The plan is what an operator reviews before installing third-party code. A plan that changes the machine would defeat that review. So would a check that misreports the pin.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-008` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that the setup script prints its plan without installing and that the check reports the pin state.
- Real user request: `Show me how the Moneybird CLI would be installed before anything is changed.`
- Prompt: `Show me the Moneybird CLI install plan and the pin check without installing anything.`
- Expected execution process: The agent runs the setup script with no option, with `--uninstall` and with `--check`, each pointed at a temporary install location so the real install is untouched.
- Expected signals: The plan names the official repository and a detached checkout of the pinned commit. The temporary location stays absent. The check prints three yes or no lines.
- Desired user-visible outcome: The operator sees the exact install and removal commands and the current pin state, with no change on disk.
- Pass/fail: PASS if the plan and uninstall modes exit 0 without creating the temporary install folder and the check prints `CLI source installed: no` for the empty location. FAIL if any mode creates files or the check reports an install that does not exist.
- Feature catalog: [Setup script](../../feature-catalog/official-cli-and-setup/setup-script.md)

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
| MBD-008 | Setup plan and pin check | Confirm that the setup script prints its plan without installing and that the check reports the pin state | `Show me the Moneybird CLI install plan and the pin check without installing anything.` | 1. `bash: setup.sh` -> 2. `bash: test ! -e cli-home` -> 3. `bash: setup.sh --uninstall` -> 4. `bash: setup.sh --check` | Step 1: plan with `git clone https://github.com/moneybird/moneybird-cli.git` and `checkout --detach`. Step 2: `plan changed nothing`. Step 3: two removal commands under the heading `Removal commands, not run:`. Step 4: `CLI source installed: no` and a nonzero exit | Captured output of all four steps | PASS if the plan and uninstall modes exit 0 without creating the temporary install folder and the check prints `CLI source installed: no` for the empty location. FAIL if any mode creates files or the check reports an install that does not exist. | 1. Confirm both `MONEYBIRD_CLI_HOME` and `MONEYBIRD_CLI_BIN` point at the temporary folder. 2. Read the mode dispatch in `setup.sh`. 3. Compare the plan with the install steps in `INSTALL-GUIDE.md` |

### Command Block

Run from the `cli-moneybird/` package root. The block points the script at a temporary install location and removes it on exit.

```bash
bash <<'SCENARIO'
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cli-moneybird.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export MONEYBIRD_CLI_HOME="$TEST_ROOT/cli-home" MONEYBIRD_CLI_BIN="$TEST_ROOT/bin"
bash cli/moneybird-cli/setup.sh
echo "plan exit=$?"
test ! -e "$TEST_ROOT/cli-home" && echo "plan changed nothing"
bash cli/moneybird-cli/setup.sh --uninstall
echo "uninstall exit=$?"
bash cli/moneybird-cli/setup.sh --check
echo "check exit=$?"
SCENARIO
```

### Optional Supplemental Checks

After the operator has installed the CLI, `bash cli/moneybird-cli/setup.sh --check` with no overrides should print `yes` for source and pin. A `no` on either PATH line, for `moneybird-cli` or `moneybird-guard`, means that link is missing or the bin folder is not on PATH.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/official-cli-and-setup/setup-script.md`](../../feature-catalog/official-cli-and-setup/setup-script.md) | Feature-catalog entry for Setup script |
| [`feature-catalog/official-cli-and-setup/official-cli-pinned-commit.md`](../../feature-catalog/official-cli-and-setup/official-cli-pinned-commit.md) | Feature-catalog entry for Official CLI at a pinned commit |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/setup.sh`](../../cli/moneybird-cli/setup.sh) | Setup implementation |
| [`INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Operator install steps |

---

## 5. SOURCE METADATA

- Group: Setup and diagnostics
- Playbook ID: MBD-008
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `setup/setup-plan-and-check.md`
