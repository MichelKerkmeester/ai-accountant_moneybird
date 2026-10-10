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

> Get a repeatable record of Jortt bookkeeping for a Moneybird migration, with every saved extract kept in the ignored migration workspace.

Jortt API reads run through `jortt-cli`, which makes extraction repeatable and handles paging. Some records still need an operator to download them from the Jortt UI.

---

## 1. AT A GLANCE

| Aspect | What you get |
|---|---|
| **Use it for** | Read Jortt bookkeeping records and prepare migration source data |
| **Invoke with** | `jortt`, `jortt-cli`, Jortt API or migration requests |
| **Works on** | Jortt REST API and Jortt UI-only exports |
| **Produces** | Paged JSON extracts and downloaded files inside `migration-workspace/` |

---

## 2. OVERVIEW

### What It Does

This skill extracts Jortt records for a Moneybird migration through `jortt-cli`, which reads the OpenAPI spec, checks scopes and follows API paging. Use the Jortt UI for XAF, annual accounts and filed VAT returns.

Moneybird is the target system and has its own sibling skill. This skill handles Jortt as the source.

### The Source Data Layer

The REST API returns repeatable records and short-lived download links. Saving the result to the ignored migration workspace keeps the source set available for comparison without adding it to tracked files.

| Source | What it provides |
|---|---|
| **REST API** | Customers, invoices, expenses, receipts, banks, reports, labels and projects |
| **Jortt UI** | XAF auditfiles, annual accounts and filed VAT returns |

---

## 3. QUICK START

Load [`SKILL.md`](SKILL.md) when a request mentions Jortt. The steps below are the manual path.

**Step 1: Check the local setup.**

```bash
bash "AI Systems/Moneybird Accountant/cli-jortt/scripts/doctor.sh"
```

Expected: an offline diagnostic report. It does not make a network call.

**Step 2: Inspect the API spec and connection.**

```bash
jortt-cli spec info
jortt-cli whoami
```

Expected: path and operation counts followed by HTTP status and top-level field names. `whoami` requires an authenticated Jortt key.

**Step 3: Save a paged extract.**

```bash
jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json
```

Expected: an HTTP status and item count. The file is written below `migration-workspace/`.

---

## 4. HOW IT WORKS

The skill routes repeatable records through the OpenAPI-driven CLI. `ops` and `describe` show the operation scope and parameters. `call` validates every parameter before it requests a token. `--all` follows next links and combines pages. `--out` stores the result inside the workspace.

The UI remains the only source for XAF, annual accounts and filed VAT returns. Jortt has no general ledger export in the API or UI.

```text
Jortt request
   |
   v
SKILL.md routing (operation decides the surface)
   |
   +--> jortt-cli: ops, describe, call --all --out  -->  JSON extract in migration-workspace/
   |
   +--> Jortt UI (operator)                        -->  XAF, annual accounts, filed VAT returns
```

### Safety Gates

Every `call` passes three local checks before a token is requested. A non-GET operation needs `--allow-write`. The operation scope must appear in `JORTT_SCOPES`. Any `--out` path must resolve inside `migration-workspace/`. The [feature catalog](feature-catalog/feature-catalog.md) lists each gate with its source and test anchors.

---

## 5. INTEGRATION & NAVIGATION

### When To Use This Skill

Use `cli-jortt` for Jortt source records, source documents and Jortt API diagnostics. Load [`SKILL.md`](SKILL.md) for the routing and safety rules, then open the reference that matches the request.

### Related Skills

| Skill | Relationship |
|---|---|
| [`cli-moneybird`](../cli-moneybird/) | Handles target-side Moneybird API calls, imports and verification. This skill hands over once the Jortt source set is saved. |

---

## 6. TROUBLESHOOTING

| What you see | Why | Fix |
|---|---|---|
| `jortt-cli` not found | The CLI is not on `PATH` yet | Run `bash cli/jortt-cli/setup.sh` and apply the printed symlink command |
| Spec missing | No cached Swagger document exists | Run `jortt-cli spec update` when network access is allowed |
| Exit 3 | A write lacks `--allow-write` | Stop unless the operator asked for that one operation |
| Exit 4 | The configured key lacks the operation scope | Name the scope and ask the operator before changing key scopes |
| Exit 5 | The output path leaves `migration-workspace/` | Choose a relative name inside the workspace |

Full recovery steps are in [`references/troubleshooting.md`](references/troubleshooting.md).

---

## 7. VERIFICATION

The offline checks use the local OpenAPI file and never call Jortt. A live connection needs a separate `jortt-cli whoami` result with HTTP 200.

| Check | Result |
|---|---|
| CLI contract | `JORTT_OPENAPI_FILE=/path/to/swagger.json bash cli/jortt-cli/tests/run-tests.sh` ends with `Result: 11 passed, 0 failed` |
| Offline doctor | `bash scripts/doctor.sh` ends with `Mode: offline. No network calls were made.` |
| Operator scenarios | The [manual testing playbook](manual-testing-playbook/manual-testing-playbook.md) scenarios report `PASS` |
| README structure | `python3 .skilled/skills/sk-doc/scripts/validate_document.py README.md` reports zero issues |

---

## 8. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`SKILL.md`](SKILL.md) | Runtime routing, rules and success criteria |
| [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) | Credentials, CLI setup and rollback |
| [`references/rest-api.md`](references/rest-api.md) | All operations, scopes and extraction recipes |
| [`references/cli.md`](references/cli.md) | Command details and safety model |
| [`references/exports-and-limits.md`](references/exports-and-limits.md) | UI exports and known API limits |
| [`references/troubleshooting.md`](references/troubleshooting.md) | Error diagnosis and recovery |
| [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) | Current-state inventory of commands, gates and surfaces |
| [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) | Operator scenario index |
