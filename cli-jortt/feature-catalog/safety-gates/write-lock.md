---
title: "Write lock"
description: "Refuses every non-GET operation with exit 3, because Jortt is read-only for every agent."
trigger_phrases:
  - "Write lock"
  - "refuse Jortt writes"
  - "block Jortt writes"
  - "jortt-cli exit 3"
version: 1.0.0.0
---

# Write lock (non-GET refusal)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Refuses every non-GET operation with exit 3, because Jortt is read-only for every agent.

Migration extraction is read-only. The lock has no override, so no call can write to Jortt.

---

## 2. HOW IT WORKS

Any operation whose method is not GET counts as a write. `jortt-cli call` stops such an operation with exit 3 and a message that the operation is refused. The CLI has no flag that lifts the refusal and no option that sends a request body. The check runs before the scope check and before any token request, and it also applies to `--dry-run`.

All other API operations pass through the same scope check. A read whose scope is missing exits 4.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_check_read_gate` applies the lock and then the scope check. |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_error` exits with the gate's code. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that a write operation exits 3 with a refusal message and that a read without its scope exits 4. |
| [`manual-testing-playbook/auth-and-scopes/write-lock.md`](../../manual-testing-playbook/auth-and-scopes/write-lock.md) | Manual playbook | JRT-002 confirms the exit codes without a network request. |

---

## 4. SOURCE METADATA

- Group: Safety gates
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `safety-gates/write-lock.md`

Related references:
- [scope-check.md](scope-check.md) - Scope check
- [output-workspace-guard.md](output-workspace-guard.md) - Output workspace guard
