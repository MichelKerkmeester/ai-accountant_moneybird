---
title: "List operations"
description: "Lists every operation in the local OpenAPI document with its stable slug, method, path and required scope."
trigger_phrases:
  - "List operations"
  - "jortt-cli ops"
  - "find a Jortt operation slug"
  - "list Jortt write operations"
version: 1.0.0.0
---

# List operations (jortt-cli ops)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Lists every operation in the local OpenAPI document with its stable slug, method, path and required scope.

Every other command addresses an operation by the slug this list shows, so `ops` is the first step when a request names a record type rather than an operation.

---

## 2. HOW IT WORKS

### Core Behavior

`jortt-cli ops` loads the OpenAPI document and prints a table with the columns `SLUG`, `METHOD`, `PATH` and `SCOPE`. The scope column is the OAuth scope the operation declares. `--tag TAG` keeps one API tag, `--writes` keeps every method other than GET and `--json` prints an array of objects that also carries the tag.

### Slug Rules

A slug is the operation ID in lowercase kebab-case. When two operations share a slug, the CLI keeps the bare slug for the preferred path and adds a version suffix to the others. The preference order is `v3`, then `v2`, then an unversioned path, then `v1`. A suffix such as `-v1` or `-legacy` names the path version of the operation that lost the tie. Slugs stay stable for one spec file, so a saved command keeps working until the spec changes.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_ops` parses the filters and prints the table or JSON. |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_operations_json` derives slugs, scopes and parameters from the spec. |
| [`cli/jortt-cli/jortt-cli`](../../cli/jortt-cli/jortt-cli) | Handler | Dispatches the `ops` command. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that every operation has a unique slug and that the unversioned path wins over `v1`. |
| [`manual-testing-playbook/operation-discovery/list-and-describe-operations.md`](../../manual-testing-playbook/operation-discovery/list-and-describe-operations.md) | Manual playbook | JRT-007 lists expense operations and describes one. |

---

## 4. SOURCE METADATA

- Group: Operation discovery
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `operation-discovery/list-operations.md`

Related references:
- [describe-operation.md](describe-operation.md) - Describe an operation
- [openapi-spec-cache.md](openapi-spec-cache.md) - OpenAPI spec cache
