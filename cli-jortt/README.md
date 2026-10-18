---
title: "cli-jortt"
description: "Reads Jortt bookkeeping into a repeatable source set for a Moneybird migration, with the REST API as the working path."
trigger_phrases:
  - "Jortt bookkeeping"
  - "Jortt migration"
  - "jortt-cli"
  - "Jortt REST API"
  - "Jortt receipts and expenses"
version: 1.0.0.0
---

# cli-jortt

> Reads your Jortt bookkeeping into a repeatable source set for a Moneybird migration, with every saved extract kept in the ignored migration workspace.

`jortt-cli` pulls records from the Jortt REST API, follows the paging for you and saves the result as JSON. A few records exist only in the Jortt UI. You download those yourself.

The commands below assume the repository root is your current directory.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | Reading Jortt records and preparing migration source data |
| **Invoke with** | `jortt`, `jortt-cli`, Jortt API or migration requests |
| **Works on** | The Jortt REST API, plus UI-only exports you download yourself |
| **Produces** | Paged JSON extracts and downloaded files inside `migration-workspace/` |

---

## 2. OVERVIEW

### What It Does

`jortt-cli` reads the Jortt OpenAPI description at runtime, checks each call against its scope and follows the API's paging. Use the Jortt UI for XAF auditfiles, annual accounts (jaarrekening) and filed VAT returns.

Jortt is the source system here. Moneybird is the target and the sibling `cli-moneybird` skill owns it.

### Where Each Record Comes From

The REST API returns repeatable records and short-lived download links. Saving them to the ignored migration workspace gives you a source set to compare against later, without adding private data to tracked files.

| Source | What it provides |
|---|---|
| **REST API** | Customers, invoices, expenses, receipts, banks, reports, labels and projects |
| **Jortt UI** | XAF auditfiles, annual accounts and filed VAT returns |

Jortt has no general ledger (grootboek) export, in the API or in the UI.

---

## 3. QUICK START

Load [`ROUTER.md`](ROUTER.md) and [`SKILL.md`](SKILL.md) when a request mentions Jortt. The steps below are the manual path.

**Step 1: Install the CLI and check the setup.**

```bash
bash cli-jortt/cli/jortt-cli/setup.sh
bash cli-jortt/scripts/doctor.sh
```

Expected: the setup script prints a symlink command. Run it to put `jortt-cli` on your `PATH`. The doctor prints an offline report and makes no network call.

**Step 2: Inspect the API description and the connection.**

```bash
jortt-cli spec info
jortt-cli whoami
```

Expected: `spec info` prints the path and operation counts. `whoami` prints an HTTP status and top-level field names and it needs a working Jortt key in `.env`. If the API description is missing, run `jortt-cli spec update` first.

**Step 3: Save a paged extract.**

```bash
jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json
```

Expected: an HTTP status and an item count. The file lands inside `migration-workspace/`.

---

## 4. HOW IT WORKS

`ops` lists the operations and `describe` shows one operation's scope and parameters. `call` checks parameter names, required parameters and basic types before it makes any request. `--all` follows the next links and merges every page into one JSON array. `call` prints a short summary by default, for example `HTTP 200, items: 25`. Record content stays out of the terminal by default. `--out` saves the full body inside the workspace and prints the same summary. `--print-body` prints the full body and is refused with exit 2 when an agent session marker is set. Agents never use `--print-body`.

The UI stays the only source for XAF, annual accounts (jaarrekening) and filed VAT returns.

```text
Jortt request
   |
   v
ROUTER.md routing (the operation decides the surface)
   |
   +--> jortt-cli: ops, describe, call --all --out  -->  JSON extract in migration-workspace/
   |
   +--> Jortt UI (Operator)                         -->  XAF, annual accounts, filed VAT returns
```

### Safety Gates

Every `call` passes three local checks before the CLI asks for a token.

- A call that is not a GET is refused with exit 3.
- The operation's scope must appear in `JORTT_SCOPES`.
- Any `--out` path must resolve inside `migration-workspace/`.

The [feature catalog](feature-catalog/feature-catalog.md) lists each gate with its source and test anchors.

---

## 5. INTEGRATION & NAVIGATION

### When To Use This Skill

Use `cli-jortt` for Jortt source records, source documents and Jortt API diagnostics. Load [`ROUTER.md`](ROUTER.md) for the routing and [`SKILL.md`](SKILL.md) for the safety rules, then open the reference that fits the request.

### Related Skills

| Skill | Relationship |
|---|---|
| [`cli-moneybird`](../cli-moneybird/) | Owns the Moneybird side: API calls, imports and verification. Work passes to it once the Jortt source set is saved. |

---

## 6. TROUBLESHOOTING

| What you see | Why | Fix |
|---|---|---|
| `jortt-cli` not found | The CLI is not on your `PATH` yet | Run `bash cli-jortt/cli/jortt-cli/setup.sh` and apply the symlink command it prints |
| The API description is missing | No cached copy exists | Run `jortt-cli spec update` when you have network access |
| Exit 3 | A non-GET operation was refused | Stop. Jortt is read-only and no write path exists for an agent |
| Exit 4 | The key lacks the operation's scope | Name the scope and ask the Operator before changing key scopes |
| Exit 5 | The output path leaves `migration-workspace/` | Use a relative name inside the workspace |

[`references/troubleshooting.md`](references/troubleshooting.md) has the full recovery steps.

---

## 7. FAQ

**Q: Can an agent write to Jortt?**

No. Jortt is read-only and no write path exists for an agent. Every non-GET call exits 3.

**Q: Do the offline checks call Jortt?**

No. They use a local copy of the API description and never call Jortt.

**Q: Does a passing suite prove a live connection?**

No. A live connection needs a separate `jortt-cli whoami` result with HTTP 200.

---

## 8. VERIFICATION

The offline checks use a local copy of the API description and never call Jortt. The suite defaults to the trimmed fixture under `cli-jortt/cli/jortt-cli/tests/fixtures/` and reads another file only when `JORTT_OPENAPI_FILE` names one. A live connection needs a separate `jortt-cli whoami` result with HTTP 200.

| Check | Result |
|---|---|
| CLI contract | `bash cli-jortt/cli/jortt-cli/tests/run-tests.sh` ends with `Result: 22 passed, 0 failed`, including fault cases for Jortt exit codes 1, 2 and 6 |
| Offline doctor | `bash cli-jortt/scripts/doctor.sh` ends with `Mode: offline. No network calls were made.` |
| Operator scenarios | The [manual testing playbook](manual-testing-playbook/manual-testing-playbook.md) holds the scenario contract. A recorded run lands under `benchmark/reports/` |

---

## 9. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`ROUTER.md`](ROUTER.md) | Runtime routing |
| [`SKILL.md`](SKILL.md) | Rules and success criteria |
| [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) | Credentials, CLI setup and rollback |
| [`references/rest-api.md`](references/rest-api.md) | Every operation, its scope and extraction recipes |
| [`references/cli.md`](references/cli.md) | Command details and the safety model |
| [`references/exports-and-limits.md`](references/exports-and-limits.md) | UI exports and known API limits |
| [`references/troubleshooting.md`](references/troubleshooting.md) | Error diagnosis and recovery |
| [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) | Commands, gates and surfaces as they work today |
| [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) | Operator scenario index |
