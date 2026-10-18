---
title: "moneybird-cli"
description: "Adopted official Moneybird CLI and local guard for guarded REST API v2 reads and writes."
trigger_phrases:
  - "moneybird cli setup"
  - "moneybird guard command"
  - "moneybird cli pin"
  - "moneybird login from env"
version: 1.0.0.0
---

# moneybird-cli: pinned official CLI and guard

---

## 1. OVERVIEW

`cli/moneybird-cli/` holds the adopted official Moneybird CLI, the local `moneybird-guard` wrapper, the installer and the offline test suite. It provides REST API v2 reads, writes, custom actions, attachments and synchronization. Invoke it with `moneybird-guard` for API calls or `setup.sh` for installation. It works with the official `moneybird/moneybird-cli` at a pinned commit and needs Bash, curl, jq and git. It produces CLI responses and guarded JSON output under `migration-workspace/`.

This package adopts `moneybird/moneybird-cli` and does not rewrite it. The official Shell CLI reads Moneybird's OpenAPI spec at runtime, so endpoint routing and custom actions follow the spec. The pin is `2e34e5190f6e918b6f8a60d4f583452c7d0828aa`, the reviewed commit recorded for this package.

Current state:

- Every API call goes through `moneybird-guard`, which previews the request first and holds non-GET calls behind the confirmation, pilot and approval gates.
- `setup.sh` prints a plan by default and changes the machine only when an Operator passes `--install`.
- The offline suite in `tests/` runs against a local stub and never touches the real CLI session, `.env` or `.env.writer`.

### Pin Updates

Review the official CLI diff before changing the pin. Check the routing, request building, authentication, multipart handling and exit behavior. Then update the single `PINNED_COMMIT` variable in `setup.sh`, review the new `--check` result and update this README and [`../../references/cli.md`](../../references/cli.md) together.

---

## 2. DIRECTORY TREE

```text
cli/moneybird-cli/
+-- README.md              # This guide
+-- moneybird-guard        # Guarded wrapper around the official CLI
+-- setup.sh               # Plan, install, check and uninstall the pinned CLI
`-- tests/
    +-- run-tests.sh       # Offline guard tests against the local stub
    `-- stub-moneybird-cli # Stub that stands in for the official CLI
```

---

## 3. KEY FILES

| File | Responsibility |
|---|---|
| `moneybird-guard` | Previews every API call and holds writes behind the confirmation, pilot and approval gates |
| `setup.sh` | Prints the install plan, installs the pinned CLI, checks the install and prints removal commands |
| `tests/run-tests.sh` | Runs the offline guard tests against the local stub |
| `tests/stub-moneybird-cli` | Provides deterministic CLI responses for the offline tests |

---

## 4. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Guard root | Always the guard's own repository root, three folders above the script |
| CLI binary | Always `moneybird-cli` on `PATH` |
| Writer configuration | Always `$HOME/.config/moneybird-cli-writer`, never the reader session |
| Pilot ID | Read only from the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line in the root `.env` file |
| Test overrides | `MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI`, `MONEYBIRD_WRITER_CONFIG_DIR`, `MONEYBIRD_HMAC_KEY_FILE` and the `MONEYBIRD_PILOT_ADMINISTRATION_ID` environment variable are honored only when `MONEYBIRD_GUARD_TEST=1` is set. That flag exists for the offline test suite only, and agents and Operators never set it in real use |
| Output | `--out` must resolve to a file inside `migration-workspace/` and outside its `.secrets/`, `RunJournal/` and `logs/` folders, otherwise the guard exits 5 |

For an API call, the guard first adds `--dry-run`. It blocks non-GET calls without `--confirm-write`. A write also needs an existing writer configuration folder, or the guard exits 7 and never falls back to the reader session. The target must be the pilot administration, or `--production` after Operator approval. `--approval <ref>` must match the `approval_reference` of a `WRITE_INTENT` event in `migration-workspace/RunJournal/run-journal.jsonl`, or the guard exits 8. The matched event must also carry a `payload_digest` equal to the keyed HMAC-SHA256 digest of the writer-session dry run, or the guard exits 9, and a `--file` write binds the file bytes to the event's `attachment_digest` the same way. The exit-3 preview prints the digest to copy into the event. A reference and digest pair that already has a write-log row is refused with exit 8 as consumed. This applies to pilot writes and production writes alike.

Without `--out`, the guard prints one summary line and keeps the response body in a private temporary file under `migration-workspace/tmp/`. `--print-body` is for the Operator only and the guard refuses it in an agent session.

Set `MONEYBIRD_GUARD_READ_ONLY=1` to block every non-GET method before the real CLI call. GET calls still run. This lock takes precedence over `--confirm-write` and `--production`, exits 6 and prints the dry-run line with a clear message. Any other value leaves the lock off.

`administration use <id>` is gated. Switching to the pilot administration passes. Switching to any other administration is blocked by the read-only lock. Otherwise it needs `--confirm-write`, the writer configuration, `--production` and `--approval`, the same as a production write.

Main write flow:

```text
moneybird-guard
      |
      v
--dry-run preview
      |
      v
read-only lock (exit 6) --> confirmation (exit 3)
      |
      v
writer configuration (exit 7) --> pilot gate (exit 4)
      |
      v
approval journal (exit 8) --> payload and attachment digests (exit 9)
      |
      v
official CLI call --> output and write log in migration-workspace/
```

---

## 5. ENTRYPOINTS

| Entrypoint | Type | Purpose |
|---|---|---|
| `bash setup.sh` | CLI | Prints the install plan and exits without changing files |
| `bash setup.sh --install` | CLI | Checks Bash, curl, jq and git, then clones and checks out the pin |
| `bash setup.sh --check` | CLI | Reports whether the local source is installed, pinned and on PATH |
| `bash setup.sh --uninstall` | CLI | Prints removal commands and does not run them |
| `moneybird-guard ...` | CLI | Previews and runs API calls under the guard gates |
| `moneybird-guard login-from-env [--writer]` | CLI | Logs in from the selected credential file without printing the token |

The source directory defaults to `$HOME/.moneybird-cli`. Override it with `MONEYBIRD_CLI_HOME`. The symlink directory defaults to `$HOME/.local/bin`. Override it with `MONEYBIRD_CLI_BIN`.

The official CLI stores configuration under `${MONEYBIRD_CONFIG_DIR:-$HOME/.config/moneybird-cli}`. Its session files hold tokens. `moneybird-guard login-from-env --writer` always uses the pinned folder `$HOME/.config/moneybird-cli-writer` to keep the writer session apart from the reader session.

The pinned CLI accepts a token as a `login` argument or prompts when no token argument is given. The guard sends the file value through stdin and suppresses CLI output. The token does not appear in CLI arguments or guard output.

---

## 6. VALIDATION

Run from the `cli-moneybird/` package root.

```bash
bash cli/moneybird-cli/setup.sh --check
bash cli/moneybird-cli/tests/run-tests.sh
```

Expected: the check reports source presence, the pin match and the PATH status. The stub suite ends with `Pass: 58  Fail: 0`.

---

## 7. RELATED

| Document | Purpose |
|---|---|
| [`moneybird-guard`](moneybird-guard) | Executable write and output guard |
| [`setup.sh`](setup.sh) | Pinned official CLI installer |
| [`tests/run-tests.sh`](tests/run-tests.sh) | Offline guard tests using a local stub |
| [`../../INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Setup, credentials, verification and rollback |
| [`../../references/cli.md`](../../references/cli.md) | CLI flags, exit behavior and project survey |
| [`../../references/troubleshooting.md`](../../references/troubleshooting.md) | Guard, API and setup recovery |
