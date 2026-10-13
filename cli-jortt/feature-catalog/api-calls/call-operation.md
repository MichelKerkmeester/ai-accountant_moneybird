---
title: "Call an operation"
description: "Calls any spec operation by slug after validating parameter names, required values, types, enums and the JSON body."
trigger_phrases:
  - "Call an operation"
  - "jortt-cli call"
  - "validated Jortt API call"
  - "jortt-cli dry-run"
version: 1.0.0.0
---

# Call an operation (jortt-cli call)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Calls any spec operation by slug after validating parameter names, required values, types, enums and the JSON body.

This is the main extraction command. The safety gates and the paging loop are separate catalog entries because they apply across commands.

---

## 2. HOW IT WORKS

### Parameters

Each `--NAME VALUE` pair must match a path or query parameter of the operation. An unknown name exits 2 and lists the valid names. A missing required parameter exits 2. Integer, number and boolean values are checked against the spec, and a value outside a declared enum is rejected. Path values are URL-encoded into the path and query values are appended in the order given.

### Body

`--data JSON` or `--data-file FILE` supplies a request body. Only one of them is allowed and the body must parse as JSON. An operation that requires a body exits 2 when neither is given.

### Dry Run

`--dry-run` prints the method, the full URL and the body, then stops. It requests no token and makes no API call. The spec load runs first, so a first run without a cache can still download the OpenAPI document. The write lock and the scope check also run before the output, so a dry run of a blocked write fails the same way a real call would.

### Output

Without `--out` the command prints a summary line by default: `HTTP 200, items: 25` for a list, or `HTTP 200, data items: 25, top-level keys: data, meta` for an object. Record content does not reach the terminal by default. `--print-body` prints the full body as formatted JSON, or unformatted with `--raw`. `--raw` alone only changes the form of `--print-body` output. The command refuses `--print-body` with exit 2 when any agent session marker is set (`CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX`). The refusal message says to use `--out` and read the saved file instead. Agents never use `--print-body`. With `--out` the response is saved inside the migration workspace and stdout shows the same summary.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_call` parses options and runs the validation chain. |
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_validate_params`, `jortt_validate_param_value` and `jortt_build_url` check and assemble the request. |
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_request` sends the validated request. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks the dry-run URL, the unknown-parameter message and the integer type check. |
| [`manual-testing-playbook/extraction/paged-extract-to-workspace.md`](../../manual-testing-playbook/extraction/paged-extract-to-workspace.md) | Manual playbook | JRT-003 runs a paged read-only extract. |

---

## 4. SOURCE METADATA

- Group: API calls
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-calls/call-operation.md`

Related references:
- [raw-get.md](raw-get.md) - Raw GET
- [organization-check.md](organization-check.md) - Organization check
- [signed-download-fetch.md](signed-download-fetch.md) - Signed download fetch
