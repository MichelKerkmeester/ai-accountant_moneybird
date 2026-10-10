---
title: "Write lock"
description: "Blocks every non-GET operation with exit 3 unless the call carries --allow-write."
trigger_phrases:
  - "Write lock"
  - "--allow-write"
  - "block Jortt writes"
  - "jortt-cli exit 3"
version: 1.0.0.0
---

# Write lock (--allow-write)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Blocks every non-GET operation with exit 3 unless the call carries --allow-write.

Migration extraction is read-only. The lock makes a write a deliberate act that names one operation at a time.

---

## 2. HOW IT WORKS

Any operation whose method is not GET counts as a write. `jortt-cli call` stops such an operation with exit 3 and the message that it requires `--allow-write`. The check runs before the scope check and before any token request, and it also applies to `--dry-run`.

`jortt-cli get` only sends GET, so the lock never applies there. All other API operations pass through the same method and scope checks.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_check_write_gate` applies the lock and then the scope check. |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_error` exits with the gate's code. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that a write without the flag exits 3 and names `--allow-write`. |
| [`manual-testing-playbook/auth-and-scopes/write-lock.md`](../../manual-testing-playbook/auth-and-scopes/write-lock.md) | Manual playbook | JRT-002 confirms the exit codes without a network request. |

---

## 4. SOURCE METADATA

- Group: Safety gates
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `safety-gates/write-lock.md`

Related references:
- [scope-check.md](scope-check.md) - Scope check
- [output-workspace-guard.md](output-workspace-guard.md) - Output workspace guard
