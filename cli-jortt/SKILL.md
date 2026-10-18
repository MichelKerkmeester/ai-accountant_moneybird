---
name: cli-jortt
description: Routes Jortt bookkeeping through jortt-cli over REST for read-only migration extraction.
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
version: 1.0.0.0
nav_label: "Jortt CLI"
---

<!-- Keywords: jortt, jortt-cli, Jortt bookkeeping, Jortt extraction, Jortt REST API, Jortt invoices, Jortt expenses, Jortt receipts, Jortt bank transactions, Jortt XAF auditfile, accounting migration, Moneybird migration, source register -->

# Jortt Migration Skill

Read Jortt bookkeeping through its REST API and save repeatable extracts for a Moneybird migration. `jortt-cli` is the system's only API surface.

---

## 1. WHEN TO USE

### Activation Triggers

Use this skill when the user asks to:

- Extract Jortt customers, invoices, expenses, receipts, bank records or reports.
- Prepare source registers or evidence for a Jortt to Moneybird migration.
- Inspect a Jortt REST operation, download link or API response.
- Set up or diagnose `jortt-cli`.
- Check what the Jortt tooling can do or run its manual test scenarios.

### Keyword Triggers

- `jortt`, `jortt-cli` or Jortt bookkeeping
- Jortt invoices, expenses, receipts, bank transactions or VAT summaries
- Jortt extraction, auditfile, migration or source register
- `jortt-cli` operation slugs, scopes, paging or download links

### When NOT to Use

- Moneybird bookkeeping, imports or API calls belong to the sibling `cli-moneybird` skill.
- XAF auditfiles, annual accounts (jaarrekening) and filed VAT returns cannot come from the Jortt API. Ask the operator to use the Jortt UI.

---

## 2. SMART ROUTING

This skill is a packet of the repository hub. Its routing lives in [`ROUTER.md`](ROUTER.md) beside this file: the operation table, the resource domains and loading levels, the detection order and the router pseudocode. Read the hub [`SKILL.md`](../SKILL.md) first, then `ROUTER.md`, then this file.

---

## 3. HOW IT WORKS

### Surface Comparison

| Surface | Best use | Output and limits |
|---|---|---|
| `jortt-cli` | Repeatable API reads, paging, downloads and full OpenAPI operation coverage | Primary. Read-only. Non-GET calls are refused. |
| Jortt UI | XAF, annual accounts (jaarrekening) and filed VAT returns | Operator-only exports. XAF requires an administrator and is generated per year. |

### CLI Extraction Path

1. Run `jortt-cli spec info`. If no local spec exists, use `jortt-cli spec update` when network access is allowed.
2. Run `jortt-cli whoami`. A successful check reports HTTP 200 and top-level field names only.
3. Run `jortt-cli ops --tag TAG` to find an operation. Use `jortt-cli describe SLUG` to confirm its path, scope and parameters.
4. Extract with `jortt-cli call SLUG ... --all --out FILE`. The CLI follows next links and merges list data into one array.
5. Read the saved artifact only from `migration-workspace/`. Stdout reports the HTTP status and item count or top-level keys.

`jortt-cli` is the retry owner for its own 429 responses. Let it finish, and never add a second retry layer in a wrapper, script or calling agent.

### Output Location

All saved extracts and downloads belong under `AI Systems/Moneybird Accountant/migration-workspace/`. That directory is gitignored. Never write extracted records into this skill, tracked documentation or another service. This skill does not use Code Mode.

### Command Quick Reference

| Goal | Command |
|---|---|
| Check CLI | `jortt-cli --version` |
| Inspect spec | `jortt-cli spec info` |
| Refresh spec | `jortt-cli spec update` |
| Check organization | `jortt-cli whoami` |
| List expense operations | `jortt-cli ops --tag expenses` |
| Describe filters | `jortt-cli describe list-expenses` |
| Extract one VAT year | `jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json` |
| Check token metadata | `jortt-cli token status` |
| Diagnose offline | `bash scripts/doctor.sh` |

Use relative output names under `migration-workspace/`.

---

## 4. RULES

### ✅ ALWAYS

- Keep migration calls read-only and use only scopes required for the selected extraction.
- Use `--all` for paged list operations. Treat an empty array as a valid result.
- Save extracts with `--out` inside `migration-workspace/` and fetch signed links promptly.
- Run one `jortt-cli` process at a time. Its pacing keeps one process under 10 requests per second, and a list page holds at most 100 items.
- Treat every Jortt request as a read. If a task seems to need a write, stop and hand it to the Operator for the Jortt UI.
- Mark behavior absent from the local facts as `UNVERIFIED`.
- Ask the operator for XAF and other UI-only documents.

### ❌ NEVER

- Never add a `:write` scope or choose `Read and write` on consent. This holds even when the Operator asks, because Jortt writes happen only in the Jortt UI.
- Never write extracted data outside `migration-workspace/`.
- Never pass `--print-body`. The CLI refuses it with exit 2 in an agent session. Use `--out` and read the saved file.
- Never paste personal financial data into tracked files, commits or prompts to other services.
- Never touch `AI Systems/Moneybird Accountant/personal database`.
- Never treat a VAT summary as a filed return or another report as a general ledger (grootboek) export.

### ⚠️ ESCALATE IF

- A requested operation needs a scope that the key does not have.
- The user requests a write, a broad scope change or `Read and write` consent. Refuse it and point to the Jortt UI.
- An API response conflicts with the local spec or the migration plan.
- A 422, unexplained empty page or incomplete next-link chain could change the source register.
- The task needs an XAF auditfile, annual accounts (jaarrekening) or a filed VAT return (btw-aangifte).

### Tool-level wall

The CLI refuses every non-GET call with exit 3 and has no request-body option. The scope check still applies to reads, and `JORTT_SCOPES` holding read scopes only keeps the key itself read-only. An agent has no Jortt write path, with or without Operator permission.

---

## 5. REFERENCES

### Core References

- [`ROUTER.md`](ROUTER.md) holds the operation-to-surface table, the detection order and the router.
- [`references/cli.md`](references/cli.md) covers CLI installation, flags, scopes and exit codes.
- [`references/rest-api.md`](references/rest-api.md) contains all operation slugs, filters, paging notes and extraction recipes.
- [`references/exports-and-limits.md`](references/exports-and-limits.md) covers UI exports and API limits.
- [`references/troubleshooting.md`](references/troubleshooting.md) maps local and API errors to next steps.
- [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) gives setup and rollback steps.

### Inventory and Testing

- [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) lists every current CLI command, safety gate and surface with source anchors.
- [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) indexes operator scenarios and links each one to its catalog entry.

### Reference Loading Notes

Load only the reference that matches the current intent. Use the REST catalogue for operation selection. Use troubleshooting when a CLI command or API call fails. The UI export reference is required before answering XAF or filed-return requests. [`ROUTER.md`](ROUTER.md) section 2 stays the authority for loading rules.

---

## 6. SUCCESS CRITERIA

### Extraction Completion Checklist

A Jortt extraction is ready for migration review when:

- ✅ `bash scripts/doctor.sh` completes its offline checks.
- ✅ `jortt-cli whoami` returns HTTP 200 and only field names.
- ✅ A paged list finishes through `_links.next.href` and produces a valid JSON array inside `migration-workspace/`.
- ✅ The operator has supplied UI-only files when the migration phase requires them.

### Validation Success

- ✅ `cli/jortt-cli/tests/run-tests.sh` passes against its trimmed fixture.
- ✅ The manual testing playbook scenarios that apply to the change report `PASS`.

A successful local test does not prove a live account connection. Report live status only after current API evidence.

---

## 7. INTEGRATION POINTS

### Migration Plan

The migration plan index is [migration/README.md](../sk-moneybird-accountant/references/migration/README.md). The source CLI supports the inventory and source collection in Phases 0 to 2. Its records feed independent reconstruction, cross-reconciliation, anomaly review and mapping work in Phases 3 to 6. Pilot and historical writes begin later in the migration plan and belong to the Moneybird workflow. This skill does not authorize those writes.

### Sibling System

Use [`../cli-moneybird/`](../cli-moneybird/) for Moneybird API calls, imports and target-side verification. Jortt is the source system. Moneybird is the target system.

### Credentials and Outputs

The Operator copies `.env.example` to `.env` and fills the Jortt client values from `app.jortt.nl` API keys. Keep `JORTT_SCOPES` read-only for migration extraction. The CLI reads `.env` or the file selected by `JORTT_ENV_FILE`. An agent never reads `.env`, and the file is gitignored.

### External Tools

- **Bash, curl and jq:** required by `jortt-cli`. `cli/jortt-cli/setup.sh` checks them and prints a symlink command.

---

## 8. SCRIPTS

`scripts/doctor.sh` runs the offline doctor and `cli/jortt-cli/setup.sh` checks the CLI prerequisites.
