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

# moneybird-cli

> Use the official Moneybird CLI through a local guard that previews each API call and blocks unconfirmed writes.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | REST API v2 reads, writes, custom actions, attachments and synchronization |
| **Invoke with** | `moneybird-guard` for API calls or `setup.sh` for installation |
| **Works on** | The official `moneybird/moneybird-cli` at a pinned commit with Bash, curl and jq |
| **Produces** | CLI responses and guarded JSON output under `migration-workspace/` |

---

## 2. OVERVIEW

### What Is Adopted

This package adopts `moneybird/moneybird-cli` and does not rewrite it. The official Shell CLI reads Moneybird's OpenAPI spec at runtime, so endpoint routing and custom actions follow the spec. The pin is `2e34e5190f6e918b6f8a60d4f583452c7d0828aa`, the reviewed commit recorded for this package.

The `moneybird-guard` wrapper previews API calls, requires explicit confirmation and a recorded approval reference for non-GET methods, keeps writes on the pilot administration and restricts saved output to `migration-workspace/`. The project survey and reason for this choice are in [`../../references/cli.md`](../../references/cli.md).

### Pin Updates

Review the official CLI diff before changing the pin. Check the routing, request building, authentication, multipart handling and exit behavior. Then update the single `PINNED_COMMIT` variable in `setup.sh`, review the new `--check` result and update this README and `references/cli.md` together.

---

## 3. QUICK START

**Step 1: Preview the install plan.**

```bash
bash setup.sh
```

Expected: clone, detached checkout and symlink commands are printed. Nothing is installed.

**Step 2: Install after operator approval.**

```bash
bash setup.sh --install
```

Expected: dependency checks pass, the official repository is cloned at the pin and `moneybird-cli` is linked under the selected bin directory.

**Step 3: Check the installation.**

```bash
bash setup.sh --check
moneybird-guard login-from-env
```

Expected: the check reports source presence, pin match and PATH status. Login reports completion without showing the token.

---

## 4. SETUP AND SAFETY

| Option | Behavior |
|---|---|
| `setup.sh` | Prints the install plan and exits without changing files |
| `setup.sh --install` | Checks Bash, curl, jq and git, then clones and checks out the pin |
| `setup.sh --check` | Reports whether the local source is installed, pinned and on PATH |
| `setup.sh --uninstall` | Prints removal commands and does not run them |

The source directory defaults to `$HOME/.moneybird-cli`. Override it with `MONEYBIRD_CLI_HOME`. The symlink directory defaults to `$HOME/.local/bin`. Override it with `MONEYBIRD_CLI_BIN`.

The official CLI stores configuration under `${MONEYBIRD_CONFIG_DIR:-$HOME/.config/moneybird-cli}`. Its session files hold tokens. `moneybird-guard login-from-env --writer` always uses the pinned folder `$HOME/.config/moneybird-cli-writer` to keep the writer session apart from the reader session.

The guard root is always the guard's own repository root. The CLI binary is always `moneybird-cli` on `PATH`. The writer configuration folder is always `$HOME/.config/moneybird-cli-writer`. The pilot administration ID comes only from the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line in the root `.env` file. `MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI`, `MONEYBIRD_WRITER_CONFIG_DIR` and the `MONEYBIRD_PILOT_ADMINISTRATION_ID` environment variable are honored only when `MONEYBIRD_GUARD_TEST=1` is set. That flag exists for the offline test suite only. Agents and Operators never set it in real use.

The pinned CLI accepts a token as a `login` argument or prompts when no token argument is given. The guard sends the file value through stdin and suppresses CLI output. The token does not appear in CLI arguments or guard output.

For an API call, the guard first adds `--dry-run`. It blocks non-GET calls without `--confirm-write`. A write also needs an existing writer configuration folder, or the guard exits 7 and never falls back to the reader session. The target must be the pilot administration, or `--production` after Operator approval. `--approval <ref>` must match the `approval_reference` of a `WRITE_INTENT` event in `migration-workspace/RunJournal/run-journal.jsonl`, or the guard exits 8. This applies to pilot writes and production writes alike. Use `--out FILE` only for a path inside `migration-workspace/`.

Without `--out`, the guard prints one summary line and keeps the response body in a private temporary file under `migration-workspace/tmp/`. `--print-body` is for the Operator only and the guard refuses it in an agent session.

Set `MONEYBIRD_GUARD_READ_ONLY=1` to block every non-GET method before the real CLI call. GET calls still run. This lock takes precedence over `--confirm-write` and `--production`, exits 6 and prints the dry-run line with a clear message. Any other value leaves the lock off.

`administration use <id>` is gated. Switching to the pilot administration passes. Switching to any other administration is blocked by the read-only lock. Otherwise it needs `--confirm-write`, the writer configuration, `--production` and `--approval`, the same as a production write.

---

## 5. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`moneybird-guard`](moneybird-guard) | Executable write and output guard |
| [`setup.sh`](setup.sh) | Pinned official CLI installer |
| [`tests/run-tests.sh`](tests/run-tests.sh) | Offline guard tests using a local stub |
| [`../../references/cli.md`](../../references/cli.md) | CLI flags, exit behavior and project survey |
| [`../../references/troubleshooting.md`](../../references/troubleshooting.md) | Guard, API and setup recovery |
