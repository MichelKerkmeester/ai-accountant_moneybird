---
title: "Raw GET"
description: "Sends a GET to an API path with name=value query pairs for endpoints that are easier to address by path."
trigger_phrases:
  - "Raw GET"
  - "jortt-cli get"
  - "Jortt API path request"
  - "name=value query pairs"
version: 1.0.0.0
---

# Raw GET (jortt-cli get)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Sends a GET to an API path with name=value query pairs for endpoints that are easier to address by path.

`get` skips the operation lookup, so it suits a quick read of a known path. `call` stays the preferred route because it validates parameters against the spec.

---

## 2. HOW IT WORKS

`jortt-cli get /v3/expenses vat_date_from=YYYY-01-01` sends a GET to `https://api.jortt.nl/v3/expenses` with the encoded query pairs. The path must not carry a host, a query string, a fragment or a `..` segment. Each extra argument must use `name=value`. A violation exits 2 before any request.

The command always uses GET, so the write lock never applies. It does not map the path to an operation, so it runs no local scope check and the API decides whether the key may read the path. `--all`, `--out` and `--raw` behave as they do for `call`.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_get` validates the path and builds the query string. |
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_request` sends the GET. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/extraction/raw-get-path-guard.md`](../../manual-testing-playbook/extraction/raw-get-path-guard.md) | Manual playbook | JRT-009 confirms the path guards reject unsafe input offline. |
| [`references/cli.md`](../../references/cli.md) | Reference | Documents the raw GET contract. |

---

## 4. SOURCE METADATA

- Group: API calls
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-calls/raw-get.md`

Related references:
- [call-operation.md](call-operation.md) - Call an operation
- [organization-check.md](organization-check.md) - Organization check
- [signed-download-fetch.md](signed-download-fetch.md) - Signed download fetch
