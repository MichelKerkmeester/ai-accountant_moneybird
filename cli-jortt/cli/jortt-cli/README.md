---
title: "jortt-cli"
description: "OpenAPI-driven Bash CLI for the Jortt REST API, with read-first migration extraction and gated writes."
trigger_phrases:
  - "jortt cli install"
  - "jortt-cli command"
  - "Jortt API operation"
  - "Jortt CLI output path"
version: 1.0.0.0
---

# jortt-cli

> OpenAPI-driven command line access to the Jortt REST API, built for repeatable migration reads.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | Find and call Jortt REST operations from a terminal or agent |
| **Invoke with** | `jortt-cli ops`, `describe`, `call`, `get`, `fetch`, `whoami` or `spec` |
| **Works on** | Bash 3.2 or newer with curl and jq |
| **Produces** | JSON output or files saved inside the ignored migration workspace |

---

## 2. OVERVIEW

### What It Does

`jortt-cli` loads the Jortt OpenAPI document and exposes its operations as stable kebab-case slugs. It validates path and query parameters, enforces required scopes and follows paged list links with `--all`.

The CLI supports the complete local API catalogue. Every non-GET operation is blocked until the call includes `--allow-write` and the configured key has the required scope.

---

## 3. QUICK START

```bash
bash setup.sh
```

Expected: prerequisite checks and a symlink command. The script writes nothing unless you pass `--link`.

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

## 4. COMMANDS

| Command | Purpose |
|---|---|
| `ops [--tag TAG] [--writes] [--json]` | List spec operations and required scopes |
| `describe SLUG` | Print method, path, scope, parameters, body schema and example |
| `call SLUG ...` | Call a spec operation with validated parameters |
| `get PATH [name=value ...]` | Make a raw API GET |
| `fetch URL --out FILE` | Fetch an HTTPS signed download link without a bearer token |
| `whoami` | Call organizations/me and print only status and top-level keys |
| `spec update` | Fetch and cache the Swagger document |
| `spec info` | Print path count, operation count and cache age without a network call |
| `token status` | Print token cache presence and remaining minutes |
| `token clear` | Delete the token cache entry for the configured client and scopes |

`call` accepts `--PARAM VALUE`, `--data JSON`, `--data-file FILE`, `--all`, `--out FILE`, `--raw`, `--dry-run` and `--allow-write`. See [`../../references/cli.md`](../../references/cli.md) for full details.

---

## 5. SAFETY MODEL

- Client credentials travel to curl through a private config stream, not process arguments.
- The token cache uses owner-only permissions and never prints the token.
- A write needs both `--allow-write` and its declared operation scope.
- `--dry-run` does not fetch a token or make a network call.
- `--all` follows next links and merges `data` arrays.
- `--out` and `fetch --out` reject paths outside migration-workspace.
- Signed downloads use HTTPS and do not receive the Jortt bearer token.

---

## 6. EXIT CODES

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | API or transport failure |
| 2 | Usage, input or spec error |
| 3 | Write blocked because `--allow-write` is missing |
| 4 | Required scope is missing |
| 5 | Output path is outside the workspace |
| 6 | Token or authentication failure |

---

## 7. RELATED FILES

| File | Purpose |
|---|---|
| [`setup.sh`](setup.sh) | Check prerequisites and print the symlink command |
| [`tests/run-tests.sh`](tests/run-tests.sh) | Offline contract tests using a local spec |
| [`../../references/cli.md`](../../references/cli.md) | Complete command and configuration guide |
| [`../../references/rest-api.md`](../../references/rest-api.md) | Endpoint catalogue and extraction recipes |
