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
| `administration use ID` | Selects a local CLI administration. A switch to the pilot administration passes. Any other switch is gated like a production write |
| `administration current` | Prints the selected local CLI administration |
| `RESOURCE sync` | Reads synchronization IDs and versions when that resource supports synchronization |
| `RESOURCE sync_fetch --ids JSON` | Fetches a batch of synchronized records |

The CLI's normal success status is zero for an HTTP 2xx response. Its request, route, auth, dependency and non-2xx failures return a nonzero status. Help and version commands return zero. The guard passes through the CLI status except for its own safety exits.

### Login Without an Argument

The pinned CLI handles `moneybird-cli login` by prompting with `read` when no token argument is supplied. It reads that prompt from stdin. `moneybird-guard login-from-env` sends the token from `.env` through stdin. `moneybird-guard login-from-env --writer` reads `.env.writer` and selects the separate writer config directory. The guard suppresses CLI output so neither a token accidentally echoed by a future CLI nor administration details appear in its login message.

The CLI's default configuration is `${MONEYBIRD_CONFIG_DIR:-$HOME/.config/moneybird-cli}`. Session files contain tokens. The guard's writer login always uses the pinned writer configuration folder `$HOME/.config/moneybird-cli-writer`. `MONEYBIRD_WRITER_CONFIG_DIR` does not change it.

---

## 3. GUARD COMMAND

```text
moneybird-guard [--confirm-write] [--production] [--approval <ref>] [--out FILE] [--print-body] [--quiet] <moneybird-cli args...>
moneybird-guard login-from-env [--writer]
```

Guard flags are recognized anywhere before a literal `--`. Every other CLI argument is passed through. For API calls, the guard adds `--dry-run`, reads the first `METHOD URL` line and classifies the request.

The guard root is always the guard's own repository root, three folders above the script. The CLI binary is always `moneybird-cli` on `PATH`. The writer configuration folder is always `$HOME/.config/moneybird-cli-writer`. The pilot administration ID comes only from the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line in the root `.env` file.

`MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI`, `MONEYBIRD_WRITER_CONFIG_DIR`, `MONEYBIRD_HMAC_KEY_FILE` and the `MONEYBIRD_PILOT_ADMINISTRATION_ID` environment variable are honored only when `MONEYBIRD_GUARD_TEST=1` is set. That flag exists for the offline test suite only. Agents and Operators never set it in real use. Without the flag the guard prints a warning that the variable is ignored and carries on with the pinned value.

Set `MONEYBIRD_GUARD_READ_ONLY=1` to refuse every non-GET method before its real call. The guard prints the dry-run line, exits 6 and lets the read-only lock take precedence over `--confirm-write` and `--production`. GET calls still run. Values other than `1` leave the lock off. This lock is the boundary for read-only roles because Moneybird token scopes do not separate read from write.

A write passes these gates in order. First the read-only lock must be off, or the guard exits 6. Then `--confirm-write` is required, or the guard exits 3 after printing the preview and one `payload-digest:` line. Then the writer configuration folder must exist, or the write stops with exit 7. The guard never falls back to the reader session. Then the target must be the pilot administration, or `--production` after Operator approval, or the guard exits 4. Then `--approval <ref>` must match the `approval_reference` of a `WRITE_INTENT` event in `migration-workspace/RunJournal/run-journal.jsonl`. A missing flag, a missing journal or no matching entry stops the write with exit 8. Then the guard recomputes the payload digest of the writer-session dry run and compares it with the `payload_digest` of the matched entry. A missing digest or a mismatch exits 9 (`PAYLOAD_MISMATCH`). A write that forwards `--file` also binds the attachment bytes to the `attachment_digest` of the entry, with exit 9 on a mismatch or a missing digest. Then the reference and digest pair must not already have a write-log row, or the guard exits 8 with a consumed message. This applies to pilot writes and production writes alike.

The payload digest is a keyed HMAC-SHA256 over the canonical writer-session dry run: the method, the URL path without query or fragment and every dry-run line after the first, each line closed by one LF. The key is read by the guard process from the Operator-owned key file `migration-workspace/.secrets/alias-hmac.key`. A missing or unreadable key stops a write with exit 1 before the real call, and the key never appears in the journal, the write log, the preview or an argument. The exit-3 preview prints `payload-digest: <hex>` so the Operator can copy it into the `WRITE_INTENT`. A `--file` write also prints `attachment-digest: <hex>`, computed over the file bytes.

The write command shape is `moneybird-guard --confirm-write --approval "$APPROVAL_REF" <moneybird-cli args...>`, plus `--production` for a non-pilot administration.

`administration use <id>` is gated. Switching to the pilot administration passes. Switching to any other administration is blocked by the read-only lock with exit 6. Otherwise it needs `--confirm-write`, the writer configuration, `--production` and `--approval`, the same as a production write.

The table below is the one canonical exit-code table, the target of the gate ladder above, the TROUBLESHOOT keywords in `cli-moneybird/SKILL.md` and the rows in `references/troubleshooting.md`, and `scripts/exit-code-parity.sh` checks those surfaces against the guard.

| Exit | Meaning |
|---:|---|
| 0 | Success. The CLI call or a pass-through command completed |
| 1 | Tool or dependency failure |
| 2 | Usage error, including a malformed dry-run header |
| 3 | Write not confirmed with `--confirm-write` |
| 4 | Pilot gate. The target is not the pilot administration and `--production` was not passed |
| 5 | Output path or folder rejected |
| 6 | Read-only lock blocked a non-GET method |
| 7 | Writer configuration missing |
| 8 | Approval reference missing, not found or already consumed for this payload digest |
| 9 | Payload digest missing or mismatched (`PAYLOAD_MISMATCH`) |

Any other exit code is passed through from `moneybird-cli`.

A successful write prints the method and path, notes that an immediate GET may be cached and appends a JSONL record with the time, method, path, administration ID, exit status, approval reference, batch key and payload digest. It holds no request or response body. Confirmed write attempts also record their exit status.

Without `--out`, the guard captures the response body to a private temporary file under `migration-workspace/tmp/`. The folder uses mode 700 and the file uses mode 600. The guard prints one summary line and deletes the file. The summary line looks like `response: 2048 bytes, records: 12` for a list or `response: 512 bytes, fields: id,name` for an object. `--quiet` hides the summary. Record content does not reach the terminal by default.

`--out FILE` accepts only a file inside `<Accountant root>/migration-workspace/`. The CLI uses `--output raw`. The full body is saved to the file and stdout holds only an item count, the top-level keys or a no-body message, such as `items: 12`.

`--print-body` streams the full body to the terminal. It is for the Operator only. The guard refuses it with exit 2 when any agent session marker is set: `CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX`. The markers are a speed bump, not a boundary. Agents never use `--print-body`. `--print-body` with `--out` is refused with exit 2. It does not apply to `login-from-env`.

`--out` on a passthrough command (`help`, `--help`, `--version`, `administration list`, `administration current` and `administration use <id>`) is refused with exit 2.

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
