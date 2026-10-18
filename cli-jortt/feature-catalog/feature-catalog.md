---
title: "cli-jortt: Feature Catalog"
description: "Current-state inventory for the cli-jortt skill, covering jortt-cli commands, local safety gates, transport behavior, diagnostics and UI routing."
trigger_phrases:
  - "cli-jortt feature catalog"
  - "jortt-cli capabilities"
  - "jortt-cli commands and safety gates"
  - "feature catalog"
last_updated: "2026-10-13"
version: 1.0.0.0
---

# cli-jortt: Feature Catalog

This catalog inventories what the `cli-jortt` skill does today. It summarizes each capability area and points to the per-feature files that carry the implementation and validation anchors for `jortt-cli`, its helper scripts and UI routing.

---

## 1. OVERVIEW

Use this catalog as the current-state inventory for the Jortt extraction skill. The sections below group the features by capability area. Each entry links to a per-feature file with the source files and the tests or playbook scenarios that back it.

| Area | What it covers |
|---|---|
| Operation discovery | Find an operation and its contract in the local OpenAPI document before any request is made. |
| API calls | Read records through a validated operation call or a signed download link. |
| Safety gates | Local checks that run before a token is requested and stop unsafe calls with a distinct exit code. |
| Transport | Paging, token handling, retries, request pacing and error reporting between the CLI and the Jortt API. |
| Diagnostics | Local checks that confirm the setup without printing secrets. |
| Surfaces and routing | Where a request goes when the CLI is not the right surface. |
| Reference guides | The references the router loads for commands, operations, exports and recovery. |
| Testing and CI | The offline CLI suite and the workflow that runs it. |

Manual validation for these features lives in the [manual testing playbook](../manual-testing-playbook/manual-testing-playbook.md).

---

## 2. OPERATION DISCOVERY

Find an operation and its contract in the local OpenAPI document before any request is made.

### List operations

#### Description

Lists every operation in the local OpenAPI document with its stable slug, method, path and required scope.

#### Current Reality

`ops` prints one row per operation. `--tag` narrows the list to one API tag and `--json` returns the same rows with the tag as JSON.

#### Source Files

See [`operation-discovery/list-operations.md`](operation-discovery/list-operations.md) for full implementation and test file listings.

---

### Describe an operation

#### Description

Prints one operation's method, path, scope, path and query parameters and an example call.

#### Current Reality

`describe SLUG` prints the contract. An unknown slug exits 2 and points at `jortt-cli ops`.

#### Source Files

See [`operation-discovery/describe-operation.md`](operation-discovery/describe-operation.md) for full implementation and test file listings.

---

### OpenAPI spec cache

#### Description

Fetches, validates and reports the cached Jortt Swagger 2.0 document that every command reads.

#### Current Reality

`spec update` downloads and validates the document. `spec info` reports the file, path count, operation count and cache age without a network call. Other commands fetch the document once when no cache exists.

#### Source Files

See [`operation-discovery/openapi-spec-cache.md`](operation-discovery/openapi-spec-cache.md) for full implementation and test file listings.

---

## 3. API CALLS

Read records through a validated operation call or a signed download link.

### Call an operation

#### Description

Calls any spec GET operation by slug after validating parameter names, required values, types and enums.

#### Current Reality

`call SLUG` accepts `--PARAM VALUE`, `--all`, `--out`, `--print-body` and `--dry-run`. It prints a short summary by default and keeps record content out of the terminal. `--print-body` is refused when an agent session marker is set. Every input check runs before a token is requested.

#### Source Files

See [`api-calls/call-operation.md`](api-calls/call-operation.md) for full implementation and test file listings.

---

### Organization check

#### Description

Confirms the configured key reaches the API and prints only the HTTP status and top-level field names.

#### Current Reality

`whoami` checks the scope of the organization operation, requests a token and reads `/organizations/me`. It never prints a field value.

#### Source Files

See [`api-calls/organization-check.md`](api-calls/organization-check.md) for full implementation and test file listings.

---

### Signed download fetch

#### Description

Saves a short-lived signed download link into the migration workspace without sending the Jortt bearer token.

#### Current Reality

`fetch URL --out FILE` resolves the output path first, accepts HTTPS links only, follows redirects to HTTPS only and saves the file through a temporary copy. A failed download says the link may have expired.

#### Source Files

See [`api-calls/signed-download-fetch.md`](api-calls/signed-download-fetch.md) for full implementation and test file listings.

---

## 4. SAFETY GATES

Local checks that run before a token is requested and stop unsafe calls with a distinct exit code.

### Write lock

#### Description

Refuses every non-GET operation with exit 3, because Jortt is read-only for every agent.

#### Current Reality

The lock runs inside `call` before the scope check, before a token is requested and before a dry run prints. The CLI has no flag that lifts it.

#### Source Files

See [`safety-gates/write-lock.md`](safety-gates/write-lock.md) for full implementation and test file listings.

---

### Scope check

#### Description

Stops a call with exit 4 when the operation's declared OAuth scope is missing from JORTT_SCOPES.

#### Current Reality

The configured scopes come from the environment, then `.env` or `JORTT_ENV_FILE`, then the read-only default list in `.env.example`. The check is an exact string match.

#### Source Files

See [`safety-gates/scope-check.md`](safety-gates/scope-check.md) for full implementation and test file listings.

---

### Output workspace guard

#### Description

Keeps every saved extract and download inside the ignored migration-workspace folder and exits 5 otherwise.

#### Current Reality

Relative names resolve under the workspace and absolute paths must already sit inside it. Parent traversal, a symlinked workspace, symlinked parents and a symlinked target file all exit 5.

#### Source Files

See [`safety-gates/output-workspace-guard.md`](safety-gates/output-workspace-guard.md) for full implementation and test file listings.

---

### Print body guard

#### Description

Refuses --print-body with exit 2 when an agent session marker is set, so a full record body never reaches a terminal transcript.

#### Current Reality

`call` refuses `--print-body` with exit 2 when `CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX` is set, and the refusal points at `--out` for a supported record read.

#### Source Files

See [`safety-gates/print-body-guard.md`](safety-gates/print-body-guard.md) for full implementation and test file listings.

---

## 5. TRANSPORT

Paging, token handling, retries, request pacing and error reporting between the CLI and the Jortt API.

### Paged list merge

#### Description

Follows _links.next.href across pages and merges each page's data array into one JSON array.

#### Current Reality

`--all` works for GET operations. A page without a `data` array or a next link outside `https://api.jortt.nl` stops the run with exit 1.

#### Source Files

See [`transport/paged-list-merge.md`](transport/paged-list-merge.md) for full implementation and test file listings.

---

### Token cache and request retry

#### Description

Caches the client-credentials token privately, refreshes it near expiry and applies bounded 401 and 429 retries.

#### Current Reality

`token status` prints whether a cached token exists, its remaining minutes and where `JORTT_SCOPES` came from. `token clear` removes the entry. Neither prints the token.

#### Source Files

See [`transport/token-cache-and-retry.md`](transport/token-cache-and-retry.md) for full implementation and test file listings.

---

### API error redaction

#### Description

Prints only the HTTP status and safe field or code labels for a failed request and appends the full response to a private workspace log.

#### Current Reality

A non-2xx response prints the status and safe field or code labels only and appends the full body to `migration-workspace/logs/jortt-errors.log` with owner-only permissions.

#### Source Files

See [`transport/api-error-redaction.md`](transport/api-error-redaction.md) for full implementation and test file listings.

---

## 6. DIAGNOSTICS

Local checks that confirm the setup without printing secrets.

### CLI setup check

#### Description

Checks the CLI file, Bash, curl and jq, then prints the symlink command without changing files.

#### Current Reality

`setup.sh` exits 1 when a prerequisite is missing. It prints the symlink command and never creates the link.

#### Source Files

See [`diagnostics/setup-check.md`](diagnostics/setup-check.md) for full implementation and test file listings.

---

### Offline doctor

#### Description

Reports tool availability, CLI location, credential presence and spec state without printing secrets or calling the network.

#### Current Reality

The doctor prints `set` or `unset` for each Jortt setting and whether the configured scopes contain a write scope. It makes no network call.

#### Source Files

See [`diagnostics/offline-doctor.md`](diagnostics/offline-doctor.md) for full implementation and test file listings.

---

## 7. SURFACES AND ROUTING

Where a request goes when the CLI is not the right surface.

### Surface routing

#### Description

Sends each Jortt request to the CLI or the operator's UI export and hands Moneybird work to the sibling skill.

#### Current Reality

Record extraction and supported data questions go to `jortt-cli`. XAF auditfiles, annual accounts (jaarrekening) and filed VAT returns go to the operator. Moneybird work goes to `cli-moneybird`.

#### Source Files

See [`surfaces/surface-routing.md`](surfaces/surface-routing.md) for full implementation and test file listings.

---

## 8. REFERENCE GUIDES

The references the skill router loads for commands, operations, exports and recovery.

### CLI command reference

#### Description

Documents every jortt-cli command, its configuration, its safety checks and its exit codes.

#### Current Reality

The guide covers every command, the Jortt settings and their precedence, the token and output rules and the exit code for each failure class.

#### Source Files

See [`reference-guides/cli-command-reference.md`](reference-guides/cli-command-reference.md) for full implementation and test file listings.

---

### REST API catalogue

#### Description

Records the scope map, endpoint catalogue, filters, paging rules and extraction recipes for the local Jortt OpenAPI document.

#### Current Reality

The guide maps each scope and operation, names the filters and paging behavior and carries the extraction recipes for the migration registers.

#### Source Files

See [`reference-guides/rest-api-catalogue.md`](reference-guides/rest-api-catalogue.md) for full implementation and test file listings.

---

### Exports and limits

#### Description

States which records only the Jortt UI can export and owns the API rate, page and retention limits the extraction path respects.

#### Current Reality

XAF auditfiles, annual accounts (jaarrekening) and filed VAT returns come from the Jortt UI, and no general ledger (grootboek) export exists. The guide owns the rate, page, retention and history statements.

#### Source Files

See [`reference-guides/exports-and-limits.md`](reference-guides/exports-and-limits.md) for full implementation and test file listings.

---

### Troubleshooting guide

#### Description

Maps jortt-cli exit codes and API responses to ordered read-only recovery checks.

#### Current Reality

The guide runs read-only diagnostics in order and maps the common exit codes and API statuses to a meaning and an action.

#### Source Files

See [`reference-guides/troubleshooting-guide.md`](reference-guides/troubleshooting-guide.md) for full implementation and test file listings.

---

## 9. TESTING AND CI

The offline suite and the workflow that runs it with the sibling checks.

### Offline CLI test suite

#### Description

Runs the jortt-cli contract against a local OpenAPI file with fake credentials and no network call.

#### Current Reality

The suite runs each case with a local Swagger file and fake credentials against a stub network, checks every gate and injects faults for the upstream, spec and token exit codes.

#### Source Files

See [`testing/offline-cli-test-suite.md`](testing/offline-cli-test-suite.md) for full implementation and test file listings.

---

### Skill health CI

#### Description

Runs the Jortt offline suite and the sibling repository checks on every push and pull request in the skill-health workflow.

#### Current Reality

The workflow runs the Jortt suite and the sibling checks on push and pull request and keeps the link job on a schedule.

#### Source Files

See [`testing/skill-health-ci.md`](testing/skill-health-ci.md) for full implementation and test file listings.
