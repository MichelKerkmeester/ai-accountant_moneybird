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

> Rebuild historical bookkeeping in Moneybird with a guarded path for each API read, write and verification step.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | Reconstruct historical records in Moneybird during a Jortt migration |
| **Invoke with** | Moneybird, moneybird-cli, moneybird-guard or accounting migration |
| **Works on** | Moneybird REST API v2 and operator-only UI steps |
| **Produces** | Guarded API changes, migration evidence and explicit verification reads |

---

## 2. OVERVIEW

### What It Does

This skill guides an agent through rebuilding historical bookkeeping in Moneybird while keeping writes visible and tied to an approved pilot. The `moneybird-guard` command wraps the official CLI for REST reads, writes, files and synchronization. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before CLI reads. The sibling `cli-jortt` skill owns Jortt source reads.

### Why It Matters

- **Writes have a visible checkpoint:** every API request is previewed and a write requires explicit confirmation.
- **Pilot scope stays clear:** the guard blocks writes outside the pilot until the operator approves a production batch.
- **Verification covers the intended time:** explicit periods and synchronization reads help catch missing older records.

### Moneybird Operation Layer

The API surface handles repeatable reads and migration writes. The operator retains bank file import, tax rate setup, period locks and historical VAT filing in the Moneybird UI.

| Capability | What the skill knows how to operate |
|---|---|
| REST v2 | Read and write supported resources through the pinned official CLI |
| Guarded changes | Preview requests, require confirmation and enforce the pilot gate |
| Migration verification | Check explicit periods, use synchronization for bulk pulls and keep outputs in the workspace |

---

## 3. QUICK START

**Step 1: Review the installation plan.**

```bash
bash cli/moneybird-cli/setup.sh
```

Expected: the official source, reviewed commit and install locations are printed. Nothing is installed.

**Step 2: Check local setup and the offline guard suite.**

```bash
bash scripts/doctor.sh
bash cli/moneybird-cli/tests/run-tests.sh
```

Expected: doctor reports local state without network calls. The stub suite ends with `Fail: 0`.

**Step 3: Read the runtime rules before an API write.**

Open `SKILL.md` and `references/migration-recipes.md`. Use the pilot administration and review the dry-run before confirming a write.

---

## 4. HOW IT WORKS

The skill routes each request by operation. REST work goes through the official CLI behind `moneybird-guard`. The guard checks the dry-run method and URL, then allows GET calls to pass through. It blocks non-GET calls when `MONEYBIRD_GUARD_READ_ONLY=1` and otherwise requires `--confirm-write` and checks that the target matches the pilot. An operator must approve each production batch before `--production` is used. UI-only tasks stay with the operator.

```text
[request]
   |
   v
[operation router]
   |                 |                 |
   v                 v                 v
[guarded CLI] -------------------- [Moneybird UI]
   |
   v
[migration workspace]
   |
   v
[period read-back]
```

### Cached Reads

An immediate GET may return cached data after a write. Check the write's own response status first, then verify in a later read. For bulk verification use the synchronization endpoints and batch their IDs within the API limit.

---

## 5. INTEGRATION & NAVIGATION

### When To Use This Skill

Use it for Moneybird API reads, a pilot migration write, document attachment work or period verification. Use the Moneybird UI for bank file imports, tax rate creation, period locks and historical VAT filing. Do not use this skill for Jortt source exports.

### Related Skills

| Skill | Relationship |
|---|---|
| `cli-jortt` | Reads Jortt source data for the migration |
| `cli-moneybird` | Writes approved records into the Moneybird target and verifies them |

### Navigation

- `SKILL.md` contains operation routing and safety rules.
- `INSTALL-GUIDE.md` covers CLI setup, credentials and rollback.
- `references/` contains API, CLI, recipe and troubleshooting details.
- `feature-catalog/` lists what the package does today, with source and test anchors per feature.
- `manual-testing-playbook/` holds the operator scenarios that validate the catalog, including two live scenarios that run only with operator approval.

---

## 6. TROUBLESHOOTING

| What you see | Why | Next step |
|---|---|---|
| Guard exits 3 | The write lacks confirmation | Review the preview and repeat with `--confirm-write` only after approval |
| Guard exits 4 | Target differs from the pilot or no pilot is configured | Check the target and pilot configuration. Use `--production` only after operator approval |
| List misses older records | The API defaults to the current year | Add an explicit `period:` filter and repeat the read |
| Guard exits 6 | The read-only lock blocks a non-GET method | Keep the lock set for read-only work. Use a write role only when the approved migration gate requires a write |

See [`references/troubleshooting.md`](references/troubleshooting.md) for the full diagnostic sequence.

---

## 7. VERIFICATION

| Check | How to run it |
|---|---|
| Offline diagnostics | `bash scripts/doctor.sh` reports local checks and does not call the API |
| Guard behavior | `bash cli/moneybird-cli/tests/run-tests.sh` ends with `Fail: 0` |
| Package structure | Run `validate_skill_package.py` against this folder and require exit code 0 |
| Catalog and playbook | Run the sk-doc catalog and playbook package validators and require a PASS line with zero violations |
| Migration evidence | Rehearse a pilot write and its undo, then check later synchronization reads |

The local checks do not prove live OAuth, production access or accounting reconciliation.

---

## 8. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`SKILL.md`](SKILL.md) | Runtime routing and safety rules |
| [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) | Setup, credentials, verification and rollback |
| [`references/cli.md`](references/cli.md) | Official CLI adoption and guard usage |
| [`references/rest-api.md`](references/rest-api.md) | API limits, caching and verification behavior |
| [`references/migration-recipes.md`](references/migration-recipes.md) | Guarded migration command sequences |
| [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) | Current-state feature inventory |
| [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) | Operator scenario index |

