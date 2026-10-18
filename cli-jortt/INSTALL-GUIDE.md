# cli-jortt Installation Guide

Set up the Jortt REST CLI for read-only migration work.

> **Package:** `jortt-cli` ships inside this skill. Nothing is downloaded from a package registry. | **Dependencies:** Bash 3.2 or newer, `curl` and `jq`.

**Version:** 1.0.0.0

---

## AI-FIRST INSTALL GUIDE

Copy this prompt to your AI assistant when you want guided setup:

```text
Set up cli-jortt for read-only Jortt extraction.
Check Bash, curl and jq. Explain each command before asking me to run it.
Copy the Moneybird Accountant .env.example to .env and ask me to fill the Jortt client ID and secret from app.jortt.nl API keys. Keep JORTT_SCOPES read-only.
Run the local CLI setup script and show me the printed symlink command. Do not create the symlink unless I request it.
Refresh the OpenAPI spec and run jortt-cli whoami only after I confirm network access and credentials are ready.
Run the offline doctor and CLI tests. Keep all extracts inside migration-workspace.
```

---

## 1. OVERVIEW

The skill uses `jortt-cli`, a local Bash client that reads the Jortt OpenAPI document and calls the REST API. Use the Jortt UI for exports that the API does not provide.

Run every command in this guide from the Moneybird Accountant root unless a step says otherwise. Saved output always lands in the gitignored `migration-workspace/` folder.

---

## 2. PREREQUISITES

The CLI needs Bash 3.2 or newer, `curl` and `jq`. It supports macOS Bash 3.2. The repository supplies the script and does not install it automatically.

```bash
bash --version
curl --version
jq --version
```

Expected: each command prints a version line. If a command is missing, install that prerequisite with the machine's approved package manager.

---

## 3. INSTALLATION

Run the setup check:

```bash
bash "cli-jortt/cli/jortt-cli/setup.sh"
```

Expected: `CLI file: ready`, one line per prerequisite and a `Manual symlink command:` line. The script ends with `No files changed. Run the symlink command yourself to install the link.` It never creates a link. The operator can run the printed command:

```bash
ln -s "/absolute/path/to/cli-jortt/cli/jortt-cli/jortt-cli" "$HOME/.local/bin/jortt-cli"
```

Then check the command:

```bash
jortt-cli --version
```

Expected: `jortt-cli 1.0.0`.

---

## 4. CONFIGURATION

### Credentials

Copy the template from the Accountant root:

```bash
cp ".env.example" ".env"
```

Fill `JORTT_CLIENT_ID` and `JORTT_CLIENT_SECRET` from the API keys area at `app.jortt.nl`. Keep the read-only `JORTT_SCOPES` value from the template for migration extraction. Do not add any `:write` scope. `.env` is gitignored. Never paste its values into terminal captures, tracked files or chat.

The CLI reads these three assignments from `.env` without sourcing it as shell code. Set `JORTT_ENV_FILE` if you keep the file elsewhere. The default scope list is read from `.env.example` when no scopes are configured.

### OpenAPI Spec

```bash
jortt-cli spec update
jortt-cli whoami
```

Expected: `OpenAPI cache updated:` followed by the cache path, then `HTTP status: 200` and a `Top-level field names:` line. `spec update` makes a network request. `whoami` calls the Jortt API.

### Optional Official Jortt MCP

Jortt provides an official MCP connection, but this system does not use it. To re-add it in the local project, run:

```bash
claude mcp add --transport http --scope local jortt https://mcp.jortt.nl/mcp
```

---

## 5. VERIFICATION

Run offline checks first:

```bash
bash "cli-jortt/scripts/doctor.sh"
JORTT_OPENAPI_FILE="/path/to/swagger.json" bash "cli-jortt/cli/jortt-cli/tests/run-tests.sh"
```

Expected: the doctor ends with `Mode: offline. No network calls were made.` and the CLI tests end with `Result: 22 passed, 0 failed`. The tests need a local Swagger file and use fake credentials. They do not make network calls.

For live verification, use `jortt-cli whoami` after credentials and network access are ready. It prints only HTTP status and top-level field names.

---

## 6. TROUBLESHOOTING

| What you see | Fix |
|---|---|
| `jq is required` or `curl is required` | Install the missing prerequisite, then rerun the setup check |
| `OpenAPI file not found` | Run `jortt-cli spec update` or set `JORTT_OPENAPI_FILE` |
| `JORTT_CLIENT_ID is unset` | Fill the client values in `.env` or point `JORTT_ENV_FILE` at the right file |
| Exit 6 on `whoami` | The token request failed. Check the client values and key scopes with the operator |

Full recovery steps are in [`references/troubleshooting.md`](references/troubleshooting.md).

---

## 7. UNINSTALLATION AND ROLLBACK

- Remove the CLI symlink if you created it: `rm "$HOME/.local/bin/jortt-cli"`.
- Clear the local bearer token cache with `jortt-cli token clear`.
- Remove the spec cache if you no longer need it. Its default path is `$HOME/.cache/jortt-cli/openapi.json` unless `XDG_CACHE_HOME` is set.
- Remove `.env` through the operator's credential handling process. Revoke the Jortt client credentials in Jortt if they should no longer work.

Rollback does not delete the migration workspace. Review its contents through the approved migration cleanup process.

---

## 8. RELATED RESOURCES

- [`ROUTER.md`](ROUTER.md) for routing and [`SKILL.md`](SKILL.md) for safety rules
- [`references/cli.md`](references/cli.md) for every command and exit code
