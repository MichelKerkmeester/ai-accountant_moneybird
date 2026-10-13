---
title: "Exit code parity check"
description: "scripts/exit-code-parity.sh compares the guard's own exit codes with every documented surface and the fault-injection self-test proves the check reports drift."
trigger_phrases:
  - "exit code parity check"
  - "moneybird guard exit codes"
  - "scripts/exit-code-parity.sh"
  - "exit code drift"
version: 1.0.0.0
---

# Exit code parity check (exit-code-parity.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

`scripts/exit-code-parity.sh` compares the guard's own exit codes with every documented surface and the fault-injection self-test proves the check reports drift.

The guard is the source of truth for its exit codes. A documented surface that drifts from the guard sends an agent down the wrong recovery path, so the check compares the code sets in both directions before a release.

---

## 2. HOW IT WORKS

### Core Behavior

The check derives the guard's exit codes from the guard script rather than a hardcoded list. It extracts the guard codes and the codes named by each surface. The check fails when a surface misses a guard code or names a code the guard never emits. Generic shell results are excluded from the extra-code test. A `--root DIR` argument points the check at another repository copy, which is what the self-test uses. The check reads files only. It never calls the CLI and never opens a credential file.

### Coverage Surfaces

The compared surfaces are the canonical exit table in `references/cli.md`, the guard exit rows in `references/troubleshooting.md`, the TROUBLESHOOT keyword line in `SKILL.md` and the gate ladder in `SKILL.md` section 3. The check also requires the `--print-body` keyword and the `references/cli.md` pointer in that ladder. `references/cli.md` owns the canonical table, so the check points there rather than restating the numbers.

### Self-Test

`scripts/exit-code-parity-test.sh` copies the files the check reads and mutates one surface per case. A clean copy must pass and every mutant must fail with a report line that names the drift. The self-test is the fault-injection anchor for the check.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`scripts/exit-code-parity.sh`](../../scripts/exit-code-parity.sh) | Script | Compares the guard exit codes with every documented surface |
| [`scripts/exit-code-parity-test.sh`](../../scripts/exit-code-parity-test.sh) | Script | Runs the check on a clean copy and on mutated copies |
| [`references/cli.md`](../../references/cli.md) | Shared | Owns the canonical exit-code table the check compares |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`scripts/exit-code-parity-test.sh`](../../scripts/exit-code-parity-test.sh) | Test harness | Proves a clean copy passes and each mutated surface fails with a named gap |
| [`.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Integration | Runs the parity check and its self-test on every push and pull request |

---

## 4. SOURCE METADATA

- Group: Verification
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `verification/exit-code-parity-check.md`

Related references:
- [offline-guard-test-suite.md](offline-guard-test-suite.md) - Exercises the guard the exit codes come from
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
