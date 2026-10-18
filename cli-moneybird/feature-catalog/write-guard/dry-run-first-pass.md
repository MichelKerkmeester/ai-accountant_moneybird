---
title: "Dry-run first pass"
description: "Every guarded API call first runs the official CLI with --dry-run and reads its first METHOD URL line to classify the request and its target administration."
trigger_phrases:
  - "dry-run first pass"
  - "moneybird guard dry-run"
  - "moneybird method url preview"
  - "moneybird-guard preview"
version: 1.0.0.0
---

# Dry-run first pass (moneybird-guard)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Every guarded API call first runs the official CLI with --dry-run and reads its first METHOD URL line to classify the request and its target administration.

The preview is what lets the guard reason about a request it did not build. The guard never parses API arguments itself, so its decisions follow whatever route the official CLI resolved.

---

## 2. HOW IT WORKS

Before the first pass the guard separates its own flags (`--confirm-write`, `--approval`, `--production`, `--out` and `--print-body`) from the CLI arguments. The local `administration list`, `current` and `use` commands skip the preview. `administration use <id>` is gated. Switching to the pilot administration passes. Switching to any other administration is treated as a production write and needs `--confirm-write`, the writer configuration, `--production` and `--approval`. The read-only lock blocks it with exit 6.

Every other call runs the CLI once with `--dry-run`. The guard keeps the first output line, requires it to be a single `METHOD URL` pair with a path under `/api/v2/` and reads the administration from the path. A failed preview returns the CLI status. A malformed first line exits 2. A GET then runs for real and every other method continues to the write gates.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Runs the preview and parses the METHOD URL line |
| [`references/cli.md`](../../references/cli.md) | Shared | Guard syntax and exit codes |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Every case runs through the preview against the stub |
| [`cli/moneybird-cli/tests/stub-moneybird-cli`](../../cli/moneybird-cli/tests/stub-moneybird-cli) | Fixture | Prints a deterministic METHOD URL line for each dry-run |
| [MBD-002](../../manual-testing-playbook/write-safety/unconfirmed-write-blocked.md) | Manual playbook | Shows the preview line for a blocked write |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/dry-run-first-pass.md`

Related references:
- [write-confirmation-lock.md](write-confirmation-lock.md) - The next gate for a non-GET request
- [pilot-administration-gate.md](pilot-administration-gate.md) - Uses the administration read from the preview
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
