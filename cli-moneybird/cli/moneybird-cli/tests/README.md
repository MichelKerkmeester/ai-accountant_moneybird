---
title: "moneybird-cli tests: Offline guard test suite"
description: "Runs the moneybird-guard safety gates against a stub CLI inside a temporary workspace, with no network and no real credentials."
trigger_phrases:
  - "moneybird guard tests"
  - "moneybird-cli stub suite"
version: 1.0.0.0
---

# moneybird-cli tests: Offline guard test suite

---

## 1. OVERVIEW

`tests/` owns the offline verification of `../moneybird-guard`. The suite replaces the real `moneybird-cli` binary with a local stub and replaces the repository root with a temporary workspace, so every read, write and refusal gate runs without touching the network, a credential file or real migration data.

Current state:

- Covers read paths, write gates, the read-only lock, approval and payload digests, `--out` checks, `--print-body` refusal, passthrough commands and fault injection.
- Each case records PASS or FAIL and the run exits non-zero when any case fails.
- The harness sets `MONEYBIRD_GUARD_TEST=1` internally so the guard accepts its environment overrides. Nothing else may set it.

---

## 2. FILES

| File | Role |
|---|---|
| `run-tests.sh` | Test harness. Builds the temporary workspace, runs all guard cases and prints the pass and fail totals |
| `stub-moneybird-cli` | Stub CLI. Implements `--dry-run` output, records each real invocation in `MONEYBIRD_TEST_LOG` and injects failures through `MONEYBIRD_TEST_FAULT` |

---

## 3. BOUNDARIES

- The stub may only record invocations and emit canned responses. It never performs a real API call.
- Cases must stay inside the temporary workspace that the harness builds and cleans up with a trap.
- New gates in `../moneybird-guard` need a matching case here before they are relied on.

---

## 4. VALIDATION

```bash
TMPDIR=<scratch> bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
```

Expected tail: `Pass: 62  Fail: 0` and exit code 0.

---

## 5. RELATED

- [cli-moneybird README](../../../README.md)
- [moneybird-guard](../moneybird-guard)
- [setup.sh](../setup.sh)
