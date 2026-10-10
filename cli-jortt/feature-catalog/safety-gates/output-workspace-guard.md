---
title: "Output workspace guard"
description: "Keeps every saved extract and download inside the ignored migration-workspace folder and exits 5 otherwise."
trigger_phrases:
  - "Output workspace guard"
  - "jortt-cli --out"
  - "migration-workspace output path"
  - "jortt-cli exit 5"
version: 1.0.0.0
---

# Output workspace guard (--out)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Keeps every saved extract and download inside the ignored migration-workspace folder and exits 5 otherwise.

Extracted bookkeeping is personal financial data. The guard keeps it out of tracked files by construction rather than by convention.

---

## 2. HOW IT WORKS

### Core Behavior

The `--out` option of `call`, `get` and `fetch` resolves against `<Accountant root>/migration-workspace/`. A relative name such as `expenses.json` lands directly inside it, and a leading `migration-workspace/` prefix is accepted. An absolute path must already point inside the workspace. Anything else exits 5.

### Edge Cases

A `..` segment, a symlinked workspace, a symlink in any parent directory, a symlinked output file or a directory as the target all exit 5. A dry run checks the path without creating folders. A real write creates missing parent folders, writes through an owner-only temporary file and then moves it into place.

### Output Summary

With `--out` set, stdout shows only `HTTP` with the status and either `items:` with a count or `top-level keys:`. The records themselves stay in the file.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/workspace.sh`](../../cli/jortt-cli/lib/workspace.sh) | Shared | `jortt_resolve_output` and `jortt_write_output` enforce and perform the write. |
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_print_or_save` prints the summary line. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that outside paths exit 5 for `call` and `fetch` and that an inside path resolves. |
| [`manual-testing-playbook/extraction/paged-extract-to-workspace.md`](../../manual-testing-playbook/extraction/paged-extract-to-workspace.md) | Manual playbook | JRT-003 saves a paged extract inside the workspace. |

---

## 4. SOURCE METADATA

- Group: Safety gates
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `safety-gates/output-workspace-guard.md`

Related references:
- [write-lock.md](write-lock.md) - Write lock
- [scope-check.md](scope-check.md) - Scope check
