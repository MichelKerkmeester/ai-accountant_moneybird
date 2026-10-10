---
title: "Moneybird CLI and Guard Reference"
description: "Adoption notes, command flags, guard behavior, exit codes and the Moneybird CLI project survey."
trigger_phrases:
  - "moneybird cli flags"
  - "moneybird guard exit codes"
  - "moneybird cli login"
  - "moneybird cli pin update"
  - "moneybird cli project survey"
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Moneybird CLI and Guard Reference

Use this reference to install the adopted CLI, inspect a route and understand the guard's write boundary. The CLI owns API endpoint coverage and the guard owns local safety checks.

---

## 1. OVERVIEW

### Adoption

The package adopts the official `moneybird/moneybird-cli` Shell project. It reads the Moneybird OpenAPI spec at runtime and routes standard actions and custom actions from that spec. The guard wraps the CLI instead of reimplementing its API surface.

The reviewed commit is `2e34e5190f6e918b6f8a60d4f583452c7d0828aa`, dated 2026-04-21 in the supplied source survey. The project has no tagged releases. The setup script stores this pin once in `PINNED_COMMIT` and checks out a detached commit.

### Install Commands

| Command | Result |
|---|---|
| `bash setup.sh` | Prints the plan and changes nothing |
| `bash setup.sh --install` | Checks Bash, curl, jq and git, then clones and checks out the pin |
| `bash setup.sh --check` | Reports source presence, commit match and PATH status |
| `bash setup.sh --uninstall` | Prints removal commands without running them |

The install path defaults to `$HOME/.moneybird-cli`. The symlink defaults to `$HOME/.local/bin/moneybird-cli`. Use `MONEYBIRD_CLI_HOME` and `MONEYBIRD_CLI_BIN` to change those locations.

---

## 2. OFFICIAL CLI COMMANDS

The CLI supports `list`, `get`, `create`, `update` and `delete` where the spec exposes those routes. It also supports custom actions. Run the pinned CLI help before relying on an endpoint-specific action or field.

| Flag or command | Meaning |
|---|---|
| `--administration ID` | Selects an administration for the API request |
| `--dry-run` | Prints `METHOD URL` first, then JSON body or multipart fields, without sending the request |
| `--output raw` | Emits raw JSON for a guarded `--out` file |
| `--output pretty` | Emits formatted JSON |
| `--output table` | Emits a table when supported |
| `--fields field1,field2` | Selects response fields |
| `--select JQ` | Filters a response with a jq expression |
| `--page NUMBER` | Selects a page |
| `--per_page NUMBER` | Sets page size within the API limit |
| `--file PATH` | Supplies a file to a multipart field when the endpoint declares it |
| `login [token]` | Logs in with a token argument or prompts for a token when omitted |
| `administration list` | Lists administrations available in the local CLI session |
| `administration use ID` | Selects a local CLI administration |
| `administration current` | Prints the selected local CLI administration |
| `RESOURCE sync` | Reads synchronization IDs and versions when that resource supports synchronization |
| `RESOURCE sync_fetch --ids JSON` | Fetches a batch of synchronized records |

The CLI's normal success status is zero for an HTTP 2xx response. Its request, route, auth, dependency and non-2xx failures return a nonzero status. Help and version commands return zero. The guard passes through the CLI status except for its own safety exits.

### Login Without an Argument

The pinned CLI handles `moneybird-cli login` by prompting with `read` when no token argument is supplied. It reads that prompt from stdin. `moneybird-guard login-from-env` sends the token from `.env` through stdin. `moneybird-guard login-from-env --writer` reads `.env.writer` and selects the separate writer config directory. The guard suppresses CLI output so neither a token accidentally echoed by a future CLI nor administration details appear in its login message.

The CLI's default configuration is `${MONEYBIRD_CONFIG_DIR:-$HOME/.config/moneybird-cli}`. Session files contain tokens. Writer login uses `${MONEYBIRD_WRITER_CONFIG_DIR:-$HOME/.config/moneybird-cli-writer}`.

---

## 3. GUARD COMMAND

```text
moneybird-guard [--confirm-write] [--production] [--out FILE] [--quiet] <moneybird-cli args...>
moneybird-guard login-from-env [--writer]
```

Guard flags are recognized anywhere before a literal `--`. Every other CLI argument is passed through. For API calls, the guard adds `--dry-run`, reads the first `METHOD URL` line and classifies the request.

Set `MONEYBIRD_GUARD_READ_ONLY=1` to refuse every non-GET method before its real call. The guard prints the dry-run line, exits 6 and lets the read-only lock take precedence over `--confirm-write` and `--production`. GET calls still run. Values other than `1` leave the lock off. This lock is the boundary for read-only roles because Moneybird token scopes do not separate read from write.

| Exit | Meaning |
|---:|---|
| 0 | CLI call succeeded or a pass-through command completed |
| 1 | CLI, login, required dependency or local logging error |
| 2 | Invalid guard usage or malformed dry-run header |
| 3 | Non-GET call lacks `--confirm-write` |
| 4 | Target is outside the pilot or no pilot is configured and production was not enabled |
| 5 | `--out` escapes `migration-workspace/` or crosses a symlink |
| 6 | `MONEYBIRD_GUARD_READ_ONLY=1` blocked a non-GET method |

For writes, an existing writer config directory is selected before the actual call. Without it, the guard warns and uses the current reader session. A successful write prints the method and path, notes that an immediate GET may be cached and appends a JSONL record without a request or response body. Confirmed write attempts also record their exit status.

`--out FILE` accepts only a file inside `<Accountant root>/migration-workspace/`. The CLI uses `--output raw`. The response body is saved to the file and stdout contains only an item count, top-level keys or a no-body message. `--quiet` suppresses guard summaries. It does not hide warnings, safety messages or the normal CLI response when no `--out` path is set.

---

## 4. PROJECT SURVEY

| Project | Type | Decision |
|---|---|---|
| `moneybird/moneybird-cli` | Official Shell CLI | Adopted. It is official, reads the OpenAPI spec at runtime and covers standard and custom endpoints through one route |
| `ondergetekende/moneybird-cli` | Independent Python CLI | Not used. It is a separate implementation |
| `dutch-and-bold/moneybird-cli` | .NET technology demo | Not used. It is a demo project from 2021 |
| `lwestenberg/moneybird-time-cli` | Time-entry CLI | Not used. It covers only time entries |
| `picqer/moneybird-php-client`, `ArjanCodes/moneysnake`, `dannyvankooten/moneybird` and `maartenvanvliet/moneybird` | Community SDKs | Not used. The skill uses the official CLI as its REST client |
| `moneybird/openapi` | Official API schema | Source consumed by the CLI at runtime |

The official CLI is adopted because it covers the documented REST surface without adding a second endpoint implementation to this skill. The commit pin makes upgrades reviewable. Review the source diff before changing the pin because the CLI reads its spec at runtime.

---

## 5. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`../cli/moneybird-cli/README.md`](../cli/moneybird-cli/README.md) | Install and guard usage |
| [`rest-api.md`](rest-api.md) | API limits and verification traps |
| [`migration-recipes.md`](migration-recipes.md) | Guarded command sequences |
| [`troubleshooting.md`](troubleshooting.md) | Failure diagnosis |
