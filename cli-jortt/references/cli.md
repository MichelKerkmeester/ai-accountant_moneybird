---
title: "jortt-cli Reference"
description: "Full command, configuration and safety reference for the OpenAPI-driven Jortt CLI."
trigger_phrases:
  - "jortt-cli command reference"
  - "jortt-cli setup"
  - "jortt-cli write lock"
  - "jortt-cli output workspace"
importance_tier: important
contextType: research
version: 1.0.0.0
---

# jortt-cli Reference

Use this reference when installing the CLI, selecting an operation or diagnosing its local safety checks.

---

## 1. OVERVIEW

`jortt-cli` is a Bash 3.2 command line client that reads Jortt OpenAPI 2.0 metadata at runtime. It exposes every operation in the supplied spec through a stable slug. It needs `curl` and `jq`.

The CLI is designed for repeatable migration reads. It can call the full REST API, but every non-GET method needs `--allow-write` and every operation needs its documented scope in `JORTT_SCOPES`.

---

## 2. INSTALL

From the `cli-jortt` directory, run:

```bash
bash cli/jortt-cli/setup.sh
```

The script checks Bash, `curl` and `jq`, then prints a symlink command. It does not create the link unless you pass `--link`.

```bash
ln -s "/absolute/path/to/cli/jortt-cli/jortt-cli" "$HOME/.local/bin/jortt-cli"
jortt-cli --version
```

Expected version output: `jortt-cli 1.0.0`.

---

## 3. SPEC SOURCE

The CLI uses `JORTT_OPENAPI_FILE` when it points to a file. Otherwise it reads `${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json`.

```bash
jortt-cli spec info
jortt-cli spec update
```

`spec info` reports path count, operation count and cache age without a network call. `spec update` fetches `https://api.jortt.nl/swagger_doc`. A normal command fetches that document once when no cache exists. The CLI accepts Swagger 2.0 documents only.

The 2026-10-10 local snapshot has 118 paths and 158 operations. `references/rest-api.md` lists the snapshot catalogue.

---

## 4. AUTHENTICATION AND SCOPES

Set `JORTT_CLIENT_ID`, `JORTT_CLIENT_SECRET` and `JORTT_SCOPES` in the environment or in the Accountant root `.env`. Set `JORTT_ENV_FILE` to select a different file. The CLI reads only those three named assignments and never sources the file as shell code.

When `JORTT_SCOPES` is empty, the CLI reads the read-only scope list from `.env.example`. Token requests use the client credentials grant at `https://app.jortt.nl/oauth-provider/oauth/token`. Credentials travel through a private curl config stream. They do not appear in curl arguments or CLI output.

The bearer token is cached under `${TMPDIR:-/tmp}/jortt-cli-$(id -u)/` with mode `0600`. The cache key uses the client ID and configured scopes. The CLI refreshes a token when it is within sixty seconds of expiry. A 401 clears the cache and retries once.

```bash
jortt-cli token status
jortt-cli token clear
```

These commands show token presence and remaining minutes or clear the current cache entry. They never print the token.

---

## 5. COMMANDS

### List operations

```bash
jortt-cli ops
jortt-cli ops --tag expenses
jortt-cli ops --writes
jortt-cli ops --json
```

Each row shows the slug, method, path and required scope. The JSON output also includes the tag. `--writes` lists methods other than GET.

### Describe an operation

```bash
jortt-cli describe list-expenses
jortt-cli help list-expenses
```

The output shows its method, path, scope, path parameters, query parameters, body schema name and an example command.

### Call an operation

```bash
jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses.json
jortt-cli call get-customer-by-id --customer_id CUSTOMER_ID --dry-run
```

`--PARAM VALUE` names must match path or query parameters in the spec. Unknown names fail with the valid parameter list. Required parameters and basic integer, number, boolean and enum values are checked before a request. Pass request bodies with `--data JSON` or `--data-file FILE`.

`--all` follows `_links.next.href` and merges each page's `data` array into one JSON array. The API page size is at most 100 items. `--raw` prints the response without `jq` formatting. `--dry-run` prints the method, URL and JSON body without requesting a token or making a network call.

### Raw GET

```bash
jortt-cli get /v3/expenses vat_date_from=YYYY-01-01 --all
```

`get` accepts an API path and `name=value` query values. It always uses GET. It rejects full URLs and path traversal segments.

### Identify the organization

```bash
jortt-cli whoami
```

This calls the organizations/me operation and prints only the HTTP status and top-level field names.

### Fetch a signed download

```bash
jortt-cli call download-url-for-a-receipt --id RECEIPT_ID --raw
jortt-cli fetch SIGNED_HTTPS_URL --out receipt.pdf
```

The API returns a short-lived link. `fetch` requires HTTPS and does not send an authorization header to the signed URL.

---

## 6. OUTPUT AND WRITE SAFETY

Every `--out` and `fetch --out` destination must resolve inside `<Accountant root>/migration-workspace/`. Relative names resolve under that directory. Absolute paths must already be inside it. The CLI creates parent directories for a real write and rejects parent traversal, symlink parents and symlink output files.

The migration workspace is gitignored. With `--out`, stdout contains only the HTTP status and an item count or top-level keys.

A non-GET operation is a write. The CLI exits 3 unless that call includes `--allow-write`. It exits 4 when the operation's scope is missing from `JORTT_SCOPES`. Both checks run before the network call. A dry-run write still requires the flag and scope.

---

## 7. EXIT CODES

| Code | Meaning |
|---:|---|
| 0 | Command completed |
| 1 | API, HTTP or transport failure |
| 2 | Invalid command, parameter or OpenAPI document |
| 3 | Write blocked because `--allow-write` is missing |
| 4 | Required scope is absent from `JORTT_SCOPES` |
| 5 | Output path is outside migration-workspace or crosses a symlink |
| 6 | Token request or authentication failure |

---

## 8. CLI SURVEY

The repository survey completed on 2026-10-10 found no Jortt CLI. Jortt publishes `jorttbv/jortt-ruby`, a Ruby API client library rather than a command line tool. Community projects include `iotta/jortt-client-rs` and `floris-xlx/jortt-rs`, both Rust clients. `dkapitan/jortt-report` is a timesheet reporting TUI. `te-con/jorttconnector` is deprecated and uses older API keys.

No official Jortt CLI or SDK was found in the local survey. Listings in Glama, npm and PyPI are UNCONFIRMED. This `jortt-cli` is new work for the migration workflow. The skill does not install community clients.

---

## 9. RELATED RESOURCES

- [`rest-api.md`](rest-api.md) - Operation catalogue and extraction recipes
- [`troubleshooting.md`](troubleshooting.md) - Exit code and API error recovery
- [`../feature-catalog/feature-catalog.md`](../feature-catalog/feature-catalog.md) - Command inventory with source and test anchors
