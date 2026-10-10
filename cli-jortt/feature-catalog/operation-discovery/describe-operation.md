---
title: "Describe an operation"
description: "Prints one operation's method, path, scope, path and query parameters, body schema and an example call."
trigger_phrases:
  - "Describe an operation"
  - "jortt-cli describe"
  - "jortt-cli help slug"
  - "Jortt operation parameters"
version: 1.0.0.0
---

# Describe an operation (jortt-cli describe)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Prints one operation's method, path, scope, path and query parameters, body schema and an example call.

Use it before a call to confirm the exact parameter names the CLI will accept and the scope the key needs.

---

## 2. HOW IT WORKS

`jortt-cli describe SLUG` prints `Slug`, `Method`, `Path`, `Scope`, `Path params`, `Query params`, `Body schema` and `Example`. An empty list prints `none`. The example names every required path and query parameter as `--NAME VALUE` and adds `--data '{}'` when the operation takes a body.

`jortt-cli help SLUG` is an alias. An unknown slug stops with exit 2 and the message `Unknown operation slug`, so a typo never reaches the network.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_describe` builds the description and example call. |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_operation` resolves one slug from the derived operation list. |
| [`cli/jortt-cli/jortt-cli`](../../cli/jortt-cli/jortt-cli) | Handler | Routes `describe` and `help SLUG` to the same handler. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that the expense list description includes its path, a filter and an empty body schema. |
| [`manual-testing-playbook/operation-discovery/list-and-describe-operations.md`](../../manual-testing-playbook/operation-discovery/list-and-describe-operations.md) | Manual playbook | JRT-007 describes a receipt download operation. |

---

## 4. SOURCE METADATA

- Group: Operation discovery
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `operation-discovery/describe-operation.md`

Related references:
- [list-operations.md](list-operations.md) - List operations
- [openapi-spec-cache.md](openapi-spec-cache.md) - OpenAPI spec cache
