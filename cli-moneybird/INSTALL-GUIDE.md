# cli-moneybird Installation Guide

Set up the pinned official Moneybird CLI and the local write guard. The install script prints a plan by default. An operator must run its `--install` option to clone the reviewed CLI commit.

---

## 0. AI-FIRST INSTALL GUIDE

Copy this prompt to the operator who owns the Moneybird credentials:

```text
Set up the cli-moneybird skill from its package root.

1. Read INSTALL-GUIDE.md and cli/moneybird-cli/README.md.
2. Review the plan with:
   bash cli/moneybird-cli/setup.sh
3. After you approve the install, run:
   bash cli/moneybird-cli/setup.sh --install
4. Create the reader and writer credential files yourself. Do not paste either token into chat.
5. Run moneybird-guard login-from-env for the reader token.
6. Run moneybird-guard login-from-env --writer for the writer token only after the pilot gate.
7. Run bash scripts/doctor.sh and bash cli/moneybird-cli/tests/run-tests.sh.

Keep all migration records under migration-workspace. Do not run a production write until the operator approves that batch.
```

---

## 1. OVERVIEW

The skill uses the official `moneybird-cli` pinned to one reviewed commit and a local `moneybird-guard`. The guard wraps every CLI call with a dry-run preview, a write confirmation lock, a writer configuration check, a pilot administration gate, an approval reference check, a body-free write log and an output boundary.

| Component | Installed by | Location |
|---|---|---|
| Official CLI | `setup.sh --install`, run by the operator | `$HOME/.moneybird-cli` linked into `$HOME/.local/bin` |
| Write guard | Ships with this package, linked by `setup.sh --install` | `cli/moneybird-cli/moneybird-guard` linked into `$HOME/.local/bin` |

Setup links the guard onto `PATH` next to the CLI, so the skill can call `moneybird-guard` by name. The package path works too.

---

## 2. PREREQUISITES

- Bash 3.2 or newer, `curl`, `jq` and `git` for the CLI setup.
- `moneybird-cli` on `PATH` after installation.
- An operator who can create a Moneybird API token and select the correct administration for each CLI session.

The local doctor reports whether the required commands and config folders exist. It does not read credential files.

---

## 3. INSTALLATION

Run these commands from the `cli-moneybird/` folder.

```bash
bash cli/moneybird-cli/setup.sh
```

Expected: a plan with the official repository, the pinned commit and the symlink destination. This command installs nothing.

After reviewing the plan, the operator can run:

```bash
bash cli/moneybird-cli/setup.sh --install
bash cli/moneybird-cli/setup.sh --check
```

Expected: the first command checks dependencies, clones the official repository, checks out the pinned commit and creates the `moneybird-cli` symlink. The second reports whether the CLI is installed, whether its commit matches the pin and whether the command is on `PATH`.

The installer never pipes a remote script into a shell. It refuses to replace an unrelated existing CLI directory or symlink.

---

## 4. CONFIGURATION

The operator creates credentials locally. Do not put a token in a prompt, terminal command, tracked file or report.

- `.env` is the reader file. It holds `MONEYBIRD_API_TOKEN` and the Moneybird administration settings from `.env.example`.
- `.env.writer` is the separate writer file. From the pilot phase onward, put the write token there under `MONEYBIRD_API_TOKEN`.
- Set `MONEYBIRD_PILOT_ADMINISTRATION_ID` in the root `.env` file before the pilot write. The guard reads the pilot administration from that file only, not from the environment.
- Set `MONEYBIRD_ADMINISTRATION_ID` only when the migration plan needs a specific administration for a read.
- Set `MONEYBIRD_GUARD_READ_ONLY=1` for read-only sessions. The guard then blocks every non-GET call before the real call, even when write flags are present.

Both files are ignored by Git. The skill does not open or print them. The pinned CLI reads tokens only during `login-from-env`.

### Login

```bash
moneybird-guard login-from-env
moneybird-guard login-from-env --writer
```

Expected: a completion message with no token or administration details. The writer command reads `.env.writer` and stores its session under `$HOME/.config/moneybird-cli-writer`. The guard keeps that path fixed and ignores `MONEYBIRD_WRITER_CONFIG_DIR` in a real session. The reader command uses the CLI default config directory unless `MONEYBIRD_CONFIG_DIR` is already set.

The pinned CLI prompts for a token when `login` has no token argument. The guard sends the selected file value through stdin, so it does not put the token in the CLI argument list.

---

## 5. OPTIONAL OFFICIAL MONEYBIRD ENDPOINTS

Moneybird provides official read-only and read-write endpoints, but this system does not use them. The read-write endpoint bypasses `moneybird-guard`. To re-add both as local connections, run these commands from `AI Systems/Moneybird Accountant/`:

```bash
claude mcp add --transport http --scope local moneybird-readonly https://moneybird.com/mcp/v1/read_only
claude mcp add --transport http --scope local moneybird https://moneybird.com/mcp/v1/read_write
```

The read-write connection bypasses all `moneybird-guard` checks and write logs.

---

## 6. VERIFICATION

```bash
bash scripts/doctor.sh
bash cli/moneybird-cli/tests/run-tests.sh
```

Expected: doctor prints offline command, config and credential-file presence checks. It makes no network call without `--live`. The test script prints a pass and fail count. It sets `MONEYBIRD_GUARD_TEST=1` and uses a local stub under a temporary `MONEYBIRD_ENV_DIR`. That flag is for the offline test suite only.

An operator may run `bash scripts/doctor.sh --live` when live checks are needed. That option calls the administrations endpoint. This guide does not run it automatically.

---

## 7. TROUBLESHOOTING

| What you see | Why | Fix |
|---|---|---|
| `moneybird-cli` is not found | The bin folder is not on `PATH` | Add `$HOME/.local/bin` to `PATH` and rerun `setup.sh --check` |
| `Pinned commit matches: no` | The local source moved off the reviewed commit | Review the diff, then rerun `setup.sh --install` |
| Login fails | The selected credential file has no `MONEYBIRD_API_TOKEN` | The operator fixes the file. Do not print it |

See [`references/troubleshooting.md`](references/troubleshooting.md) for the full diagnostic order.

---

## 8. UNINSTALLATION AND ROLLBACK

### CLI

`bash cli/moneybird-cli/setup.sh --uninstall` prints removal commands without running them. Review the paths before the operator runs either command. Remove the reader and writer CLI session directories separately if the operator wants to remove local token copies.

### Credentials

The operator revokes each token in Moneybird, then removes the corresponding local `.env` or `.env.writer` file and its CLI session. Do not remove a credential file through an automated agent.

---

## 9. RELATED RESOURCES

| Document | Purpose |
|---|---|
| [`ROUTER.md`](ROUTER.md) | Runtime routing |
| [`SKILL.md`](SKILL.md) | Write rules |
| [`cli/moneybird-cli/README.md`](cli/moneybird-cli/README.md) | CLI adoption, pin and guard behavior |
| [`references/cli.md`](references/cli.md) | Guard usage and CLI command details |
| [`references/troubleshooting.md`](references/troubleshooting.md) | Failure diagnosis and recovery |
