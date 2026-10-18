---
title: "jortt-cli: Jortt REST API CLI"
description: "OpenAPI-driven Bash CLI for the Jortt REST API, built for read-only migration extraction. Every non-GET operation is refused."
trigger_phrases:
  - "jortt cli install"
  - "jortt-cli command"
  - "Jortt API operation"
  - "Jortt CLI output path"
version: 1.0.0.0
---

# jortt-cli: Jortt REST API CLI

---

## 1. OVERVIEW

`cli/jortt-cli/` holds the OpenAPI-driven command line client for the Jortt REST API, built for repeatable migration reads. `jortt-cli` loads the Jortt OpenAPI document and exposes its operations as stable kebab-case slugs. It validates path and query parameters, enforces required scopes and follows paged list links with `--all`.

Current state:

- The CLI supports the complete local API catalogue. Every non-GET operation is refused with exit 3, and every read needs its scope in `JORTT_SCOPES`.
- Response summaries stay on by default. The full body goes to the terminal only with `--print-body`, or to a file inside the ignored migration workspace with `--out`.
- The CLI runs on Bash 3.2 or newer with curl and jq.

---

## 2. QUICK START

Run from this directory:

```bash
bash setup.sh
```

Expected: prerequisite checks and a symlink command. The script writes nothing.

Review the printed path, then create the link yourself:

```bash
ln -s "/absolute/path/to/cli-jortt/cli/jortt-cli/jortt-cli" "$HOME/.local/bin/jortt-cli"
```

```bash
jortt-cli spec info
jortt-cli whoami
jortt-cli ops --tag expenses
jortt-cli describe list-expenses
jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses.json
```

Expected: local spec details, an HTTP status with field names, the expense operation list, parameter details and an output summary. The extract is stored under `migration-workspace/`.

---

## 3. DIRECTORY TREE

```text
cli/jortt-cli/
+-- README.md
+-- jortt-cli                     # Executable entry point and command dispatch
+-- setup.sh                      # Prerequisite check and symlink command
+-- lib/                          # Sourced helpers
|   +-- api.sh                    # Token cache, requests, retries and downloads
|   +-- commands.sh               # Command handlers and parameter validation
|   +-- common.sh                 # Spec parsing, config, scopes and error output
|   `-- workspace.sh              # Output path guard for migration-workspace/
`-- tests/                        # Offline contract suite
    +-- run-tests.sh
    `-- fixtures/
        `-- openapi-trimmed.json
```

---

## 4. KEY FILES

| File | Responsibility |
|---|---|
| `jortt-cli` | Parses the command line, loads the spec and dispatches every command |
| `lib/common.sh` | Loads configuration, parses the spec into slugs, checks scopes and prints errors |
| `lib/commands.sh` | Implements `ops`, `describe`, `call`, `whoami` and `fetch` and validates parameters and required values |
| `lib/api.sh` | Fetches and caches the OAuth token, sends authenticated requests, retries a 401 once and a 429 up to three times and downloads signed links |
| `lib/workspace.sh` | Resolves every `--out` path inside `migration-workspace/` and rejects escapes and symlinks |
| `setup.sh` | Checks Bash, curl and jq, then prints the symlink command and never creates the link |
| `tests/run-tests.sh` | Runs the offline contract suite against the trimmed OpenAPI fixture |
| `tests/fixtures/openapi-trimmed.json` | The trimmed Swagger 2.0 fixture the suite reads by default |

---

## 5. ENTRYPOINTS

| Command | Purpose |
|---|---|
| `ops [--tag TAG] [--json]` | List spec operations and required scopes |
| `describe SLUG` | Print method, path, scope, parameters and example |
| `call SLUG ...` | Call a spec operation with validated parameters |
| `fetch URL --out FILE` | Fetch an HTTPS signed download link without a bearer token |
| `whoami` | Call organizations/me and print only status and top-level keys |
| `spec update` | Fetch and cache the Swagger document |
| `spec info` | Print path count, operation count and cache age without a network call |
| `token status` | Print token cache presence and remaining minutes |
| `token clear` | Delete the token cache entry for the configured client and scopes |

`call` accepts `--PARAM VALUE`, `--all`, `--out FILE`, `--print-body` and `--dry-run`. See [`../../references/cli.md`](../../references/cli.md) for full details.

---

## 6. BOUNDARIES AND SAFETY

- Client credentials travel to curl through a private config stream, not process arguments.
- The token cache uses owner-only permissions and never prints the token.
- Every non-GET operation is refused with exit 3, and a read needs its declared operation scope.
- `--dry-run` prints the method and URL without fetching a token or calling a Jortt operation.
- `--all` follows next links and merges `data` arrays.
- A 429 waits for `Retry-After` or backs off 1, 2 and 4 seconds, for at most three retries. The CLI is the only retry layer.
- `--out` and `fetch --out` reject paths outside migration-workspace.
- `--print-body` prints the full body but is refused with exit 2 when any agent session marker is set, and the message says to use `--out` and read the saved file.
- Signed downloads use HTTPS and do not receive the Jortt bearer token.

### Exit Codes

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | API or transport failure |
| 2 | Usage, input or spec error |
| 3 | Non-GET operation refused because Jortt is read-only |
| 4 | Required scope is missing |
| 5 | Output path is outside the workspace |
| 6 | Token or authentication failure |

---

## 7. VALIDATION

Run from the repository root. The suite is offline and reads the trimmed fixture unless `JORTT_OPENAPI_FILE` names another file.

```bash
bash cli-jortt/cli/jortt-cli/tests/run-tests.sh
```

Expected result: `Result: 28 passed, 0 failed`, including fault cases for Jortt exit codes 1, 2 and 6, plus the 401 and 429 retries and paging.

---

## 8. RELATED

| File | Purpose |
|---|---|
| [`setup.sh`](setup.sh) | Check prerequisites and print the symlink command |
| [`tests/run-tests.sh`](tests/run-tests.sh) | Offline contract tests using a local spec |
| [`../../references/cli.md`](../../references/cli.md) | Complete command and configuration guide |
| [`../../references/rest-api.md`](../../references/rest-api.md) | Endpoint catalogue and extraction recipes |
