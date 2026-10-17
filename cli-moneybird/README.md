---
title: cli-moneybird
description: Rebuild historical bookkeeping in Moneybird with guarded API access and a clear pilot path for migration work.
trigger_phrases:
  - Moneybird bookkeeping migration
  - Moneybird REST API
  - guarded Moneybird CLI
  - Moneybird read-only lock
version: 1.0.0.0
---

# cli-moneybird

> Rebuilds your historical bookkeeping in Moneybird, with a guard on every API read, write and verification step.

The commands below assume `cli-moneybird/` is your current directory.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | Rebuilding historical records in Moneybird during a Jortt migration |
| **Invoke with** | Moneybird, moneybird-cli, moneybird-guard or accounting migration |
| **Works on** | The Moneybird REST API v2, plus UI-only steps the Operator performs |
| **Produces** | Guarded API changes, migration evidence and explicit verification reads |

---

## 2. OVERVIEW

### What It Does

This skill guides an agent through rebuilding historical bookkeeping in Moneybird. Every write stays visible and tied to an approved pilot. The `moneybird-guard` command wraps the official Moneybird CLI for REST reads, writes, files and synchronization. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before they read. The sibling `cli-jortt` skill owns the Jortt source reads.

### Why Use It

- **Every write has a checkpoint.** The guard previews each API request and a write needs explicit confirmation.
- **Writes stay on the pilot.** The guard blocks writes outside the pilot administration until the Operator approves a production batch.
- **Checks cover the right years.** An explicit period and synchronization reads catch older records that a default list would miss.

### What The API Handles

The API covers repeatable reads and migration writes. The Operator keeps bank file import, tax rate setup, period locks and historical VAT filing in the Moneybird UI.

| Capability | What the skill can do |
|---|---|
| REST v2 | Read and write supported resources through the pinned official CLI |
| Guarded changes | Preview requests, require confirmation and enforce the pilot gate |
| Migration verification | Check explicit periods, use synchronization for bulk pulls and keep outputs in the workspace |

---

## 3. QUICK START

**Step 1: Review the install plan.**

```bash
bash cli/moneybird-cli/setup.sh
```

Expected: the official repository, the pinned commit and the install locations are printed. Nothing is installed. When the plan looks right, run `bash cli/moneybird-cli/setup.sh --install`.

**Step 2: Log in with the reader token and check the setup.**

```bash
moneybird-guard login-from-env
bash cli/moneybird-cli/setup.sh --check
```

Expected: the login finishes without showing the token. The check reports the source, the pin match and the `PATH` status.

**Step 3: Run the offline checks.**

```bash
bash scripts/doctor.sh
bash cli/moneybird-cli/tests/run-tests.sh
```

Expected: the doctor reports your local state without a network call. The stub suite ends with `Pass: 58  Fail: 0`.

**Step 4: Read the rules before any write.**

Open `SKILL.md` and `references/migration-recipes.md`. Use the pilot administration and review the dry-run output before you confirm a write.

---

## 4. HOW IT WORKS

### Guard Routing

The skill routes each request by operation. REST work goes through the official CLI behind `moneybird-guard`. The guard asks the CLI for a dry run, reads the method and URL and then decides:

- A GET call runs.
- A non-GET call is blocked when `MONEYBIRD_GUARD_READ_ONLY=1` is set.
- Otherwise a non-GET call needs `--confirm-write`, an existing writer configuration folder and the pilot administration as its target. It also needs `--approval <ref>` matching the `approval_reference` of a `WRITE_INTENT` entry in `migration-workspace/RunJournal/run-journal.jsonl` whose `payload_digest` equals the keyed digest of the writer-session dry run. The reference and digest pair must not be consumed yet.
- A production batch needs the same checks plus `--production`, after the Operator approves that batch.

UI-only tasks stay with the Operator.

```text
Request
   |
   v
Operation router
   |
   +--> moneybird-guard --> official CLI --> Moneybird API --> period read-back
   |         |
   |         +--> output and logs in migration-workspace/
   |
   +--> Moneybird UI (Operator): bank imports, tax rates, period locks, VAT filing
```

### Cached Reads

A GET right after a write can return cached data. Check the write's own response status first, then verify in a later read. For bulk verification, use the synchronization endpoints and fetch IDs in batches within the API limit.

---

## 5. INTEGRATION & NAVIGATION

### When To Use This Skill

Use this skill for Moneybird API reads, a pilot migration write, document attachments and period verification. Use the Moneybird UI for bank file imports, tax rate creation, period locks and historical VAT filing. Do not use this skill for Jortt source exports.

### Package Layout

```text
cli-moneybird/
+-- README.md                  # This guide
+-- ROUTER.md                  # Operation routing
+-- SKILL.md                   # Safety rules, gates and the exit ladder
+-- INSTALL-GUIDE.md           # CLI setup, credentials, verification and rollback
+-- references/                # API, CLI, recipe and troubleshooting guides
+-- feature-catalog/           # Current features with source and test anchors
+-- manual-testing-playbook/   # Operator scenarios that validate the catalog
+-- benchmark/                 # Benchmark inputs and run reports
+-- scripts/                   # Offline diagnostics for the package
`-- cli/moneybird-cli/         # Pinned official CLI, guard and installer
```

| Path | Purpose |
|---|---|
| `ROUTER.md` | Operation routing |
| `SKILL.md` | Safety rules, gates and the exit ladder |
| `INSTALL-GUIDE.md` | CLI setup, credentials, verification and rollback |
| `references/` | The API, CLI, recipe and troubleshooting guides |
| `feature-catalog/` | What the package does today, with source and test anchors for each feature |
| `manual-testing-playbook/` | The Operator scenarios that validate the catalog. One live scenario writes to the pilot administration and runs only with Operator approval |
| `benchmark/` | Benchmark inputs and run reports |
| `scripts/` | Offline diagnostics for the package |
| `cli/moneybird-cli/` | The pinned official CLI, the guard wrapper, the installer and the offline tests |

### Related Skills

| Skill | Relationship | Use When |
|---|---|---|
| [`cli-jortt`](../cli-jortt/SKILL.md) | Sibling skill | A migration needs Jortt source records |

---

## 6. TROUBLESHOOTING

| What you see | Why | Next step |
|---|---|---|
| Guard exits 3 | The write lacks confirmation | Review the preview. Repeat with `--confirm-write` only after approval |
| Guard exits 4 | The target is not the pilot or no pilot is configured | Check the target and the pilot ID in the root `.env` file. Use `--production` only after the Operator approves that batch |
| Guard exits 5 | The `--out` path leaves `migration-workspace/` | Choose a path inside the workspace |
| Guard exits 6 | The read-only lock blocks a non-GET call | Keep the lock for read-only work. Use a write session only when the approved migration gate requires a write |
| Guard exits 7 | The writer configuration folder is missing | Run `moneybird-guard login-from-env --writer` after the pilot gate |
| Guard exits 8 | The write lacks `--approval`, the reference is not in the run journal or the reference and digest pair is consumed | Check the `WRITE_INTENT` entry and repeat with `--approval "$APPROVAL_REF"`. A consumed pair needs a new entry |
| Guard exits 9 | The payload or the attachment bytes do not match the approved digest | Re-run the preview, copy the `payload-digest` line into a new `WRITE_INTENT` entry and retry with the new reference |
| A list leaves out older records | The API defaults to the current year | Add an explicit period filter such as `--filter period:YYYY` and read again |

[`references/troubleshooting.md`](references/troubleshooting.md) has the full diagnostic sequence.

---

## 7. FAQ

**Q: Can the guard write to production?**

Only after the Operator approves that batch. A write targets the pilot by default and needs `--production` for anything else.

**Q: Does a write run without confirmation?**

No. The guard exits 3 when a write lacks `--confirm-write`, and exits 8 when it lacks an approved `--approval` reference from the run journal.

**Q: Do the local checks prove live access?**

No. They do not prove live access, production access or a reconciled ledger.

---

## 8. VERIFICATION

| Check | How to run it |
|---|---|
| Offline diagnostics | `bash scripts/doctor.sh` reports local checks and does not call the API |
| Guard behavior | `bash cli/moneybird-cli/tests/run-tests.sh` ends with `Pass: 58  Fail: 0` |
| Guard exit codes | `bash scripts/exit-code-parity.sh` checks the guard exit codes against the exit table, the troubleshooting rows and the skill keywords |
| Migration evidence | Rehearse a pilot write and its undo, then check later synchronization reads |

The local checks do not prove live access, production access or a reconciled ledger.

---

## 9. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`ROUTER.md`](ROUTER.md) | Runtime routing |
| [`SKILL.md`](SKILL.md) | Safety rules |
| [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) | Setup, credentials, verification and rollback |
| [`references/cli.md`](references/cli.md) | The official CLI and how to use the guard |
| [`references/rest-api.md`](references/rest-api.md) | API limits, caching and verification behavior |
| [`references/migration-recipes.md`](references/migration-recipes.md) | Guarded migration command sequences |
| [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) | What the package does today |
| [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) | Operator scenario index |
