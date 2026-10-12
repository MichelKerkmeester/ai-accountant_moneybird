---
title: "cli-moneybird: Feature Catalog"
description: "Unified reference combining the complete feature inventory and current-reality reference for the cli-moneybird skill."
trigger_phrases:
  - "cli-moneybird feature catalog"
  - "moneybird capabilities"
  - "moneybird-guard features"
  - "feature catalog"
last_updated: "2026-10-10"
version: 1.0.0.0
---

# cli-moneybird: Feature Catalog

This document combines the current feature inventory for the `cli-moneybird` skill into a single reference. The root catalog acts as the skill-level directory: it summarizes each capability area, describes what the skill does today and points to the per-feature files that carry the deeper implementation and validation anchors.

---

## 1. OVERVIEW

Use this catalog as the canonical inventory for the live `cli-moneybird` feature surface. The numbered sections below group the skill by capability area so readers can move from a top-level summary into per-feature reference files without losing implementation or validation context.

The skill has two working layers. The official `moneybird-cli` owns REST routing. The local `moneybird-guard` wraps every API call with a dry-run preview, a read-only lock, a confirmation lock, a writer configuration check, a pilot administration gate, an approval gate, a payload digest binding, a write log and an output boundary. Bank file imports, tax rate creation, period locks and manual VAT filing stay with the operator in the Moneybird UI.

Every live write in this skill targets the pilot administration until the operator approves a production batch. The offline guard suite and the manual testing playbook are the validation anchors cited in each per-feature file.

---

## 2. OFFICIAL CLI AND SETUP

### Official CLI at a pinned commit

#### Description

The package adopts the official moneybird/moneybird-cli Shell project at one reviewed commit and wraps it instead of reimplementing the API surface.

#### Current Reality

The CLI reads the Moneybird OpenAPI spec at runtime and covers standard and custom actions through one route. The reviewed commit is stored once in `PINNED_COMMIT` inside `setup.sh`.

#### Source Files

See [`official-cli-and-setup/official-cli-pinned-commit.md`](official-cli-and-setup/official-cli-pinned-commit.md) for full implementation and test file listings.

---

### Setup script

#### Description

setup.sh prints the install plan by default and changes the machine only when an operator passes --install, with --check and --uninstall for state and removal.

#### Current Reality

`--install` checks its required commands, clones the official repository, checks out the pinned commit and links `moneybird-cli` into a bin folder. It refuses to replace an unrelated directory or symlink. `--check` reports source presence, commit match and PATH status. `--uninstall` prints the removal commands without running them.

#### Source Files

See [`official-cli-and-setup/setup-script.md`](official-cli-and-setup/setup-script.md) for full implementation and test file listings.

---

## 3. WRITE GUARD

### Dry-run first pass

#### Description

Every guarded API call first runs the official CLI with --dry-run and reads its first METHOD URL line to classify the request and its target administration.

#### Current Reality

Help, version and local administration commands pass straight through. `administration use <id>` is gated: switching to the pilot administration passes, and switching to any other administration is treated as a production write. Every other call is previewed first. A preview that does not start with a `METHOD URL` line under `/api/v2/` stops the guard with exit 2. A GET runs after the preview and any other method moves on to the write gates.

#### Source Files

See [`write-guard/dry-run-first-pass.md`](write-guard/dry-run-first-pass.md) for full implementation and test file listings.

---

### Write confirmation lock

#### Description

A non-GET request without --confirm-write prints its dry-run line and exits 3 before any real call.

#### Current Reality

The lock applies to every non-GET method, including deletes and custom actions. The printed dry-run line lets the operator review the method, path and administration before repeating the command with `--confirm-write`.

#### Source Files

See [`write-guard/write-confirmation-lock.md`](write-guard/write-confirmation-lock.md) for full implementation and test file listings.

### Read-only lock

#### Description

When `MONEYBIRD_GUARD_READ_ONLY=1`, the guard blocks every non-GET method before the real call and exits 6, even when `--confirm-write` or `--production` is present. GET calls still run.

#### Current Reality

The lock replaces the read-only boundary for read-only roles. Moneybird API tokens do not offer separate read and write scopes. Any environment value other than `1` leaves the lock off.

#### Source Files

See [`write-guard/read-only-lock.md`](write-guard/read-only-lock.md) for implementation and test file listings.

---

### Pilot administration gate

#### Description

A confirmed write must target the pilot administration unless the operator passes --production for an approved batch. Otherwise the guard exits 4.

#### Current Reality

The guard reads the pilot ID only from the Accountant folder `.env`. The environment variable of that name is ignored. A different target needs `--production`. A write with no pilot set needs it too. The guard repeats the dry-run with the writer session before the gate, so the gate checks the session that will write. A missing writer configuration stops the write with exit 7.

#### Source Files

See [`write-guard/pilot-administration-gate.md`](write-guard/pilot-administration-gate.md) for full implementation and test file listings.

---

### Write log

#### Description

Each confirmed write attempt appends one body-free JSON line with time, method, path, administration, exit status, approval reference, batch key and payload digest under the migration workspace.

#### Current Reality

The log lives at `migration-workspace/logs/moneybird-writes.jsonl` with owner-only permissions. Failed attempts are logged with their exit status. The approval reference, batch key and payload digest join the row back to its approved payload. A successful write also prints that an immediate GET may return cached data.

#### Source Files

See [`write-guard/write-log.md`](write-guard/write-log.md) for full implementation and test file listings.

---

### Payload-bound approval

#### Description

Each write runs only for the exact payload the Operator approved: the guard matches a keyed digest of the writer-session dry run with the `payload_digest` in the run journal and runs a reference and digest pair once.

#### Current Reality

The exit-3 preview prints the digest to copy into the `WRITE_INTENT`. A missing digest or a mismatch exits 9 (`PAYLOAD_MISMATCH`) before the real call, and a `--file` write also binds the file bytes to `attachment_digest`. A pair that already has a write-log row exits 8 as consumed.

#### Source Files

See [`write-guard/payload-bound-approval.md`](write-guard/payload-bound-approval.md) for full implementation and test file listings.

---

### Delete caution

#### Description

A successful DELETE prints a warning that 204 can mean nothing was deleted and asks for a separate read.

#### Current Reality

The warning is printed after the write succeeds and before the log line is appended. The guard does not perform the read-back itself. The operator confirms removal with a later GET or synchronization read.

#### Source Files

See [`write-guard/delete-caution.md`](write-guard/delete-caution.md) for full implementation and test file listings.

---

## 4. READS AND SAVED OUTPUT

### Period filter warning

#### Description

A list read without a period: filter still runs but warns that Moneybird defaults lists to period:this_year.

#### Current Reality

The warning goes to stderr and the read is not blocked. Passing `--filter period:YYYY` in either the spaced or the `=` form suppresses it.

#### Source Files

See [`reads-and-saved-output/period-filter-warning.md`](reads-and-saved-output/period-filter-warning.md) for full implementation and test file listings.

---

### Output guard

#### Description

--out saves the raw response only to a file inside migration-workspace and prints an item count or top-level keys instead of the records. Without --out the guard prints a one-line summary and no records. Any other path exits 5.

#### Current Reality

The path is checked before any CLI call. Parent traversal, a symlink on the way and a directory target are all refused. The response is written to a temporary file in the target folder and moved into place after the call succeeds.

#### Source Files

See [`reads-and-saved-output/output-guard.md`](reads-and-saved-output/output-guard.md) for full implementation and test file listings.

---

## 5. SESSIONS AND DIAGNOSTICS

### Reader and writer login

#### Description

login-from-env reads the token from .env or with --writer from .env.writer and passes it to the CLI through stdin with all CLI output suppressed.

#### Current Reality

The token never appears in the CLI argument list or in the guard's output. Writer login stores its session in a separate config folder, so reader and writer sessions do not overwrite each other.

#### Source Files

See [`sessions-and-diagnostics/reader-and-writer-login.md`](sessions-and-diagnostics/reader-and-writer-login.md) for full implementation and test file listings.

---

### Local doctor

#### Description

scripts/doctor.sh reports commands, the CLI pin, config folders and credential-file presence without opening credentials and calls the network only with --live.

#### Current Reality

The offline run prints yes or no lines and set or unset lines only. The `--live` run reports the administrations HTTP status, a count and whether configured administrations are present without printing their IDs.

#### Source Files

See [`sessions-and-diagnostics/local-doctor.md`](sessions-and-diagnostics/local-doctor.md) for full implementation and test file listings.

---

## 6. API KNOWLEDGE

### Documented API traps

#### Description

The references record the Moneybird API behaviors that make an incomplete read or write look complete, with the safe route for each.

#### Current Reality

The traps cover the default list period, response caching, the capped financial mutations list, synchronization batches, 204 deletes, rate limits, locked periods, the deprecated payment action and the operations that only the UI can perform.

#### Source Files

See [`api-knowledge/documented-api-traps.md`](api-knowledge/documented-api-traps.md) for full implementation and test file listings.
