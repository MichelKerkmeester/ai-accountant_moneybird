---
title: "OpenAPI spec cache"
description: "Fetches, validates and reports the cached Jortt Swagger 2.0 document that every command reads."
trigger_phrases:
  - "OpenAPI spec cache"
  - "jortt-cli spec info"
  - "jortt-cli spec update"
  - "refresh the Jortt swagger document"
version: 1.0.0.0
---

# OpenAPI spec cache (jortt-cli spec)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Fetches, validates and reports the cached Jortt Swagger 2.0 document that every command reads.

The spec decides which operations, parameters and scopes the CLI knows, so a stale or missing file changes what every other command can do.

---

## 2. HOW IT WORKS

### Core Behavior

`jortt-cli spec update` downloads `https://api.jortt.nl/swagger_doc` to a temporary file, checks that it is a Swagger 2.0 document with a `paths` object and then replaces the cache. The cache lives at `${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json`. A failed download or a failed check leaves the old cache in place and exits 1.

### Local Override

`JORTT_OPENAPI_FILE` points every command at a local file instead of the cache. With the override set, `spec update` only validates that file and never downloads. A missing override file stops a regular command with exit 2 rather than falling back to the network.

### Spec Info

`jortt-cli spec info` never makes a network call. It prints `OpenAPI file`, `Path count`, `Operation count` and `Cache age` in minutes. When no file exists it prints `OpenAPI file: missing` and `unavailable` for the other three fields. The offline doctor runs it when a spec is present.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_spec_update`, `jortt_ensure_spec` and `jortt_spec_info` own the cache. |
| [`cli/jortt-cli/jortt-cli`](../../cli/jortt-cli/jortt-cli) | Handler | Dispatches `spec update` and `spec info`. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Runs every check against a local file through `JORTT_OPENAPI_FILE`. |
| [`manual-testing-playbook/operation-discovery/spec-info-offline.md`](../../manual-testing-playbook/operation-discovery/spec-info-offline.md) | Manual playbook | JRT-008 reads the spec report without a network call. |

---

## 4. SOURCE METADATA

- Group: Operation discovery
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `operation-discovery/openapi-spec-cache.md`

Related references:
- [list-operations.md](list-operations.md) - List operations
- [describe-operation.md](describe-operation.md) - Describe an operation
