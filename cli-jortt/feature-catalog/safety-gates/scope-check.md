---
title: "Scope check"
description: "Stops a call with exit 4 when the operation's declared OAuth scope is missing from JORTT_SCOPES."
trigger_phrases:
  - "Scope check"
  - "JORTT_SCOPES"
  - "missing Jortt scope"
  - "jortt-cli exit 4"
version: 1.0.0.0
---

# Scope check (JORTT_SCOPES)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Stops a call with exit 4 when the operation's declared OAuth scope is missing from JORTT_SCOPES.

The check names the missing scope before a token request, so a read task never needs a broader key to find out what is wrong.

---

## 2. HOW IT WORKS

Every operation declares its OAuth scope in the spec. `call` and `whoami` compare that scope with the space-separated list in `JORTT_SCOPES` and exit 4 with the missing scope named when it is absent. The comparison is exact, so `expenses:read` never satisfies `expenses:write`.

The CLI reads `JORTT_SCOPES` from the environment first. When it is empty, it reads the named assignment from `.env` or the file set in `JORTT_ENV_FILE`. When that is empty too, it reads the default list from `.env.example`, which holds read scopes only. The same scope string is sent with the token request.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_load_config`, `jortt_has_scope` and `jortt_check_scope` resolve and compare scopes. |
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_check_read_gate` and `jortt_cmd_whoami` call the scope check. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that a read whose scope is missing exits 4 and names the missing scope. |
| [`manual-testing-playbook/auth-and-scopes/write-lock.md`](../../manual-testing-playbook/auth-and-scopes/write-lock.md) | Manual playbook | JRT-002 covers the missing scope step. |

---

## 4. SOURCE METADATA

- Group: Safety gates
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `safety-gates/scope-check.md`

Related references:
- [write-lock.md](write-lock.md) - Write lock
- [output-workspace-guard.md](output-workspace-guard.md) - Output workspace guard
