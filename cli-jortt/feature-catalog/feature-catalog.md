---
title: "cli-jortt: Feature Catalog"
description: "Current-state inventory for the cli-jortt skill, covering jortt-cli commands, local safety gates, transport behavior, diagnostics and UI routing."
trigger_phrases:
  - "cli-jortt feature catalog"
  - "jortt-cli capabilities"
  - "jortt-cli commands and safety gates"
  - "feature catalog"
last_updated: "2026-10-10"
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
| API calls | Read records through a validated operation call, a raw path or a signed download link. |
| Safety gates | Local checks that run before a token is requested and stop unsafe calls with a distinct exit code. |
| Transport | Paging, token handling, retries and request pacing between the CLI and the Jortt API. |
| Diagnostics | Local checks that confirm the setup without printing secrets. |
| Surfaces and routing | Where a request goes when the CLI is not the right surface. |

Manual validation for these features lives in the [manual testing playbook](../manual-testing-playbook/manual-testing-playbook.md).

---

## 2. OPERATION DISCOVERY

Find an operation and its contract in the local OpenAPI document before any request is made.

### List operations

#### Description

Lists every operation in the local OpenAPI document with its stable slug, method, path and required scope.

#### Current Reality

`ops` prints one row per operation. `--tag` narrows the list to one API tag, `--writes` keeps only non-GET operations and `--json` returns the same rows with the tag as JSON.

#### Source Files

See [`operation-discovery/list-operations.md`](operation-discovery/list-operations.md) for full implementation and test file listings.

---

### Describe an operation

#### Description

Prints one operation's method, path, scope, path and query parameters, body schema and an example call.

#### Current Reality

`describe SLUG` and `help SLUG` print the same contract. An unknown slug exits 2 and points at `jortt-cli ops`.

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

Read records through a validated operation call, a raw path or a signed download link.

### Call an operation

#### Description

Calls any spec operation by slug after validating parameter names, required values, types, enums and the JSON body.

#### Current Reality

`call SLUG` accepts `--PARAM VALUE`, `--data`, `--data-file`, `--all`, `--out`, `--raw`, `--dry-run` and `--allow-write`. Every input check runs before a token is requested.

#### Source Files

See [`api-calls/call-operation.md`](api-calls/call-operation.md) for full implementation and test file listings.

---

### Raw GET

#### Description

Sends a GET to an API path with name=value query pairs for endpoints that are easier to address by path.

#### Current Reality

`get PATH` builds the URL from a path and `name=value` pairs. It rejects full URLs, query strings, fragments and parent-directory segments with exit 2.

#### Source Files

See [`api-calls/raw-get.md`](api-calls/raw-get.md) for full implementation and test file listings.

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

`fetch URL --out FILE` resolves the output path first, accepts HTTPS links only and saves the file through a temporary copy. A failed download says the link may have expired.

#### Source Files

See [`api-calls/signed-download-fetch.md`](api-calls/signed-download-fetch.md) for full implementation and test file listings.

---

## 4. SAFETY GATES

Local checks that run before a token is requested and stop unsafe calls with a distinct exit code.

### Write lock

#### Description

Blocks every non-GET operation with exit 3 unless the call carries --allow-write.

#### Current Reality

The lock runs inside `call` before the scope check, before a token is requested and before a dry run prints. `ops --writes` lists every operation it guards.

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

## 5. TRANSPORT

Paging, token handling, retries and request pacing between the CLI and the Jortt API.

### Paged list merge

#### Description

Follows _links.next.href across pages and merges each page's data array into one JSON array.

#### Current Reality

`--all` works for GET operations and raw GETs. A page without a `data` array or a next link outside `https://api.jortt.nl` stops the run with exit 1.

#### Source Files

See [`transport/paged-list-merge.md`](transport/paged-list-merge.md) for full implementation and test file listings.

---

### Token cache and request retry

#### Description

Caches the client-credentials token privately, refreshes it near expiry and retries once after a 401 and up to three times after a 429.

#### Current Reality

`token status` prints whether a cached token exists and its remaining minutes. `token clear` removes the entry. Neither prints the token.

#### Source Files

See [`transport/token-cache-and-retry.md`](transport/token-cache-and-retry.md) for full implementation and test file listings.

---

## 6. DIAGNOSTICS

Local checks that confirm the setup without printing secrets.

### CLI setup check

#### Description

Checks the CLI file, Bash, curl and jq, then prints the symlink command without changing files.

#### Current Reality

`setup.sh` exits 1 when a prerequisite is missing. It creates the symlink only with `--link` and refuses to replace an existing path.

#### Source Files

See [`diagnostics/setup-check.md`](diagnostics/setup-check.md) for full implementation and test file listings.

---

### Offline doctor

#### Description

Reports tool availability, CLI location, credential presence and spec state without printing secrets or calling the network.

#### Current Reality

The doctor prints `set` or `unset` for each Jortt setting and whether the configured scopes contain a write scope. `--live` adds `whoami`.

#### Source Files

See [`diagnostics/offline-doctor.md`](diagnostics/offline-doctor.md) for full implementation and test file listings.

---

## 7. SURFACES AND ROUTING

Where a request goes when the CLI is not the right surface.

### Surface routing

#### Description

Sends each Jortt request to the CLI or the operator's UI export and hands Moneybird work to the sibling skill.

#### Current Reality

Record extraction and supported data questions go to `jortt-cli`. XAF auditfiles, annual accounts and filed VAT returns go to the operator. Moneybird work goes to `cli-moneybird`.

#### Source Files

See [`surfaces/surface-routing.md`](surfaces/surface-routing.md) for full implementation and test file listings.
