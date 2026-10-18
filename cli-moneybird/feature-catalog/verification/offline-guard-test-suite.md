---
title: "Offline guard test suite"
description: "cli/moneybird-cli/tests/run-tests.sh exercises the guard against a local CLI stub in a temporary workspace and reports one pass or fail line per case."
trigger_phrases:
  - "offline guard test suite"
  - "moneybird guard tests"
  - "tests/run-tests.sh"
  - "moneybird guard stub"
version: 1.0.0.0
---

# Offline guard test suite (run-tests.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

`cli/moneybird-cli/tests/run-tests.sh` exercises the guard against a local CLI stub in a temporary workspace and reports one pass or fail line per case.

The suite is the offline proof for the write gates, the output boundary and both logins. It needs no token and makes no network call, so an agent can run it before a migration session.

---

## 2. HOW IT WORKS

### Isolation

The suite creates a temporary Accountant root, points `MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI` and `MONEYBIRD_WRITER_CONFIG_DIR` at it, sets `MONEYBIRD_GUARD_TEST=1` and unsets the agent session markers. Every CLI call goes to the stub, which prints deterministic dry-run lines and injects the upstream failures. The temporary root is removed on exit.

### Coverage

The cases cover the period warning, the confirmation lock, the read-only lock and its synchronization fetch exception, the writer configuration and pilot gates, the approval reference, the payload and attachment digests, the single-use rule, the write log, the DELETE caution, the output guard with its state-folder and trailing-slash refusals, the summary output, the `--print-body` refusal under an agent marker and its place before the write gates, the `--out` refusal on a passthrough command, the ignored environment overrides without the test flag, the `administration use` gate, both logins, a quoted token, the doctor's pinned writer folder and two injected stub faults.

### Reporting

Each case prints a `PASS:` or `FAIL:` line with its name. The run ends with a `Pass:` and `Fail:` count and exits nonzero when any case fails. The manual playbook maps the offline cases to their operator scenarios.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Test | Creates the temporary root and runs every guard case |
| [`cli/moneybird-cli/tests/stub-moneybird-cli`](../../cli/moneybird-cli/tests/stub-moneybird-cli) | Test | Prints deterministic dry-run output and the injected failures |
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | The guard under test |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Integration | Runs the suite on every push and pull request |
| [`cli/moneybird-cli/README.md`](../../cli/moneybird-cli/README.md) | Reference | Documents the offline suite and the stub |

---

## 4. SOURCE METADATA

- Group: Verification
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `verification/offline-guard-test-suite.md`

Related references:
- [exit-code-parity-check.md](exit-code-parity-check.md) - Checks the guard exit codes against every documented surface
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
