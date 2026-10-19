---
title: "Output guard"
description: "--out saves the raw response only to a file inside migration-workspace, outside the guard's .secrets, RunJournal and logs folders, and prints an item count or top-level keys instead of the records. Without --out the guard prints a one-line summary and no records. Any other path exits 5."
trigger_phrases:
  - "output guard"
  - "moneybird output guard"
  - "moneybird-guard --out"
  - "moneybird guard exit 5"
version: 1.0.0.0
---

# Output guard (--out)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

--out saves the raw response only to a file inside migration-workspace, outside the guard's .secrets, RunJournal and logs folders, and prints an item count or top-level keys instead of the records. Without --out the guard prints a one-line summary and no records. Any other path exits 5.

Saved Moneybird data stays inside the ignored migration workspace and out of the chat. The terminal only shows the shape of what was saved.

---

## 2. HOW IT WORKS

`--out FILE` accepts an absolute path or a relative path that resolves against the Accountant folder. The resolved file must sit below `migration-workspace/`. The guard checks this before any CLI call and exits 5 for a path outside the workspace, a `..` segment, a symlink anywhere on the way, a file used as a folder, a directory target or a trailing slash. It also exits 5 for any path into `migration-workspace/.secrets/`, `RunJournal/` or `logs/` in any letter case, because those folders hold the guard's key, approval journal and write log. The guard refuses `--out` on a passthrough command (`administration list`, `administration current` or `administration use <id>`) with exit 2.

On a valid path the guard adds `--output raw`, writes the response to a temporary file in the target folder and moves it into place when the call succeeds. Stdout then shows only `items: N` for an array, `keys:` with the top-level keys for an object or a short no-body message. Without `--out` the guard captures the body to a private temporary file under `migration-workspace/tmp/`, with private folder and file permissions the guard sets, prints the summary and deletes the file. The summary is one line. It shows the byte size and then a record count for a list or the top-level field names for an object. `references/cli.md` shows the line format. Record content does not reach the terminal by default. A failed call removes the temporary file.

`--print-body` streams the full body to the terminal. It is for the Operator only and agents never use it. The guard refuses it with exit 2, before the dry-run, when any agent session marker is set (`CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX`) or when `--out` is present. The markers are a speed bump, not a boundary. `--print-body` does not apply to `login-from-env`.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Validates the path and saves the raw response |
| [`references/cli.md`](../../references/cli.md) | Shared | Documents --out and exit 5 |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Outside path exits 5 and inside path prints only the item count |
| [MBD-010](../../manual-testing-playbook/reads/output-guard-confines-saves.md) | Manual playbook | Operator check of both paths in a temporary workspace |

---

## 4. SOURCE METADATA

- Group: Reads And Saved Output
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reads-and-saved-output/output-guard.md`

Related references:
- [period-filter-warning.md](period-filter-warning.md) - The read that usually feeds a saved file
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
