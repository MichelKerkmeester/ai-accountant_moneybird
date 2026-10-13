---
title: "MBD-017 -- Offline guard test suite"
description: "This scenario validates the Offline guard test suite for `MBD-017`. It focuses on the need to confirm that every guard case passes against the packaged stub without a token or a network call."
version: 1.0.0.0
---

# MBD-017 -- Offline guard test suite

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-017`.

---

## 1. OVERVIEW

This scenario validates the Offline guard test suite for `MBD-017`. It focuses on the need to confirm that every guard case passes against the packaged stub without a token or a network call.

### Why This Matters

The suite is the offline proof for the write gates, the output boundary and both logins. An operator needs to trust the same run before a migration session, and the run must not need a credential.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-017` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that the offline guard suite runs against the packaged stub, reports one `PASS:` line per case, zero failures and exit status 0.
- Real user request: `Check the Moneybird guard before we start, without a token and without touching Moneybird.`
- Prompt: `Run the offline Moneybird guard suite and tell me whether every case passes.`
- Expected execution process: The agent runs the suite from the `cli-moneybird/` package root and reads the `PASS:` lines, the final count line and the exit status.
- Expected signals: Every case prints a `PASS:` line, no `FAIL:` line appears, the final line reports `Fail: 0` with a nonzero pass count and the suite exits 0. Every CLI call goes to the packaged stub and the temporary root is removed on exit.
- Desired user-visible outcome: The operator sees that the guard gates pass offline and that no token or network call was needed.
- Pass/fail: PASS if the suite exits 0 and its final line reports zero failures with a nonzero pass count. FAIL if any case fails, the suite exits nonzero or the run needs a real token or network access.
- Feature catalog: [Offline guard test suite](../../feature-catalog/verification/offline-guard-test-suite.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Run the suite exactly as written against the packaged stub.
3. Read the case lines, the final count line and the exit status.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-017 | Offline guard test suite | Confirm that the suite reports one `PASS:` line per case, zero failures and exit status 0 | `Run the offline Moneybird guard suite and tell me whether every case passes.` | 1. `bash: bash cli/moneybird-cli/tests/run-tests.sh` -> 2. `bash: read the final count line and the exit status` | Step 1: every case prints a `PASS:` line and no `FAIL:` line appears. Step 2: the final line reports `Fail: 0` with a nonzero pass count and the suite exit status is 0 | The full case list, the final count line and the exit status | PASS if the suite exits 0 and its final line reports zero failures with a nonzero pass count. FAIL if any case fails, the suite exits nonzero or the run needs a real token or network access. | 1. Confirm the run started from the `cli-moneybird/` package root. 2. Confirm no real `.env` was used and the stub path in the suite still resolves. 3. Re-run one failing case name with `bash -x` and read the assertion |

### Command Block

Run from the `cli-moneybird/` package root. The suite uses only the packaged stub and a temporary folder that it removes on exit. It never touches the real CLI session, `.env` or `.env.writer`.

```bash
bash cli/moneybird-cli/tests/run-tests.sh
echo "suite exit=$?"
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/verification/offline-guard-test-suite.md`](../../feature-catalog/verification/offline-guard-test-suite.md) | Feature-catalog entry for the offline suite |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Creates the temporary root and runs every guard case |
| [`cli/moneybird-cli/tests/stub-moneybird-cli`](../../cli/moneybird-cli/tests/stub-moneybird-cli) | Deterministic CLI stand-in behind every case |
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | The guard under test |
| [`.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Runs the suite on every push and pull request |

---

## 5. SOURCE METADATA

- Group: Verification
- Playbook ID: MBD-017
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `verification/offline-guard-test-suite.md`
