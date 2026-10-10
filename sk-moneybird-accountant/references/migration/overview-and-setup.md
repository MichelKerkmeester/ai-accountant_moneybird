---
title: Migration overview and setup
description: Opening sections 0 to 3 of the migration plan.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration overview and setup

Opening sections 0 to 3 of the migration plan. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## AI Accounting Migration & Verification System

### Executable workflow: historical sole-trader (ZZP) bookkeeping into Moneybird

This plan rebuilds a complete Dutch sole-trader administration in Moneybird, from the first business year to today. AI agents do the reading, matching and checking. A human operator owns every credential, every export from a web UI and every approval to write.

The plan holds no personal or financial data. Figures, names and identifiers live only in the gitignored `personal database/` link, the gitignored `migration-workspace/` folder and the gitignored `.env` files.

---

## 0. GOAL

Rebuild the full administration in Moneybird and prove it against four independent sources of evidence:

1. **Document Truth**: original invoices and receipts in the document archive (`personal database/`).
2. **Ledger Truth**: the historical bookkeeping in Jortt, exported as XAF auditfiles.
3. **Cash Truth**: bank transactions from official bank exports.
4. **Filing Truth**: the VAT (btw) and income tax (IB) returns that were actually filed.

Moneybird becomes the authoritative historical record only once these four sources agree within the thresholds in section 3.

The workflow runs in separate phases. Each phase states its input, actions, owner, agents, output, verification and exit gate. No phase starts before the previous one has passed its exit gate.

#### Task owners

Every step carries one of these tags:

- **[Operator]**: only a human can do it. Examples: logging in to Mijn Belastingdienst, generating an XAF in Jortt, approving OAuth, uploading a bank file in the Moneybird web app.
- **[AI]**: an agent does it with the tools in section 1.
- **[Operator + AI]**: an agent prepares it and the operator approves or executes it.

---

## 1. TOOLS AND ACCESS

This section records what each service actually supports, checked against the vendors' documentation on 2026-10-10. Anything marked **unverified** must be tested before a phase relies on it.

### 1.1 Jortt (source system, read only)

**REST API.** The base URL is `https://api.jortt.nl` (v3). Authentication uses the OAuth2 client credentials grant. The client ID and secret go to `https://app.jortt.nl/oauth-provider/oauth/token` through HTTP Basic auth, and the returned bearer token lasts 2 hours. The rate limit is 10 requests per second. Lists are paged at most 100 items per page.

Use only read scopes: `organizations:read customers:read invoices:read expenses:read receipts:read financing:read reconciling:read reports:read`. Never request a `:write` scope for this migration.

What the API gives you:

- Customers, sales invoices (with PDF download), expenses (purchase invoices, with VAT-date filters) and receipts (with `scope=in_inbox|all` and PDF download).
- Bank accounts and their bank transactions.
- Profit and loss and balance reports per year, quarter or month, back to 2006.
- VAT period summaries (`/reports/summaries/btw`). These are summaries, not the filed returns.
- Attachment downloads through short-lived signed links. Download each file at once.

What the API does not give you:

- **No XAF export.** The auditfile exists only in the Jortt UI.
- **No general ledger export** of any kind, in the API or the UI.
- **No general journal entries** (memoriaal) apart from payroll entries.
- **No filed VAT returns and no IB report.**
- **No date filter on sales invoices.** Fetch all pages and filter locally.

**UI exports [Operator].** The account owner (Beheerder role) generates one XAF 4.0.3 auditfile per year via Boekhoudbot, "Maak voor mij een auditfile". The XAF does not contain uploaded documents. Download the annual accounts (jaarrekening) under Rapporten and download the filed VAT returns. Jortt keeps an administration for 7 years after a subscription ends.

**CLI access.** This system reaches Jortt through `jortt-cli` only. Build the registers from the REST API because the calls are repeatable and their output can be hashed.

**CLI.** Jortt publishes no official CLI or SDK, only an OpenAPI 2.0 spec at `https://api.jortt.nl/swagger_doc`. This system's `jortt-cli` uses that specification.

### 1.2 Moneybird (target system)

**REST API v2.** Requests go to `https://moneybird.com/api/v2/{administration_id}/{resource}.json` with `Authorization: Bearer <token>`. Treat every ID as a string, because the IDs are larger than many JSON parsers handle. The rate limit is 150 requests per 5 minutes per IP, and 50 per 5 minutes on `/reports/`. A `429` response carries `Retry-After`.

**CLI access.** This system reaches Moneybird through `moneybird-cli` behind `moneybird-guard` only. Read-only sessions set `MONEYBIRD_GUARD_READ_ONLY=1`.

**CLI.** Moneybird's official CLI is `moneybird/moneybird-cli`, a shell tool that needs curl and jq and reads the OpenAPI spec at runtime. It supports `--dry-run` and `--administration`. It has no tagged releases, so pin a commit.

**What each surface can do for this migration:**

| Need | Guarded CLI | UI |
|---|---|---|
| Historical sales invoices, original numbers kept | `external_sales_invoices` + PDF attachment | Yes |
| Purchase invoices and receipts with PDF | `documents/purchase_invoices`, `documents/receipts` + `attachments` | Yes |
| Journal entries (memoriaal) | `documents/general_journal_documents` | Yes |
| Bank history | `financial_statements` (JSON mutations only) | CAMT.053 / MT940 file import **[Operator]** |
| Link payments to documents | `financial_mutations/{id}/link_booking` | Yes |
| Ledger accounts | Create and update (`rgs_code` required) | Yes |
| Tax rates, including reverse charge | Read only | Create **[Operator]** |
| Fixed assets and depreciation | `assets` + value changes | Yes |
| Profit and loss, balance, general ledger | `reports/*`, at most 12 months per call | Yes |
| XAF auditfile export | `reports/export/auditfile` (3.2 or 4.0) | Yes |
| Mark a historical VAT return as filed | No | "Handmatig indienen" **[Operator]** |
| Lock a period | Read `period_locked_until` only | Settings **[Operator]** |
| Delete a wrong record | Yes (`DELETE`) | Yes |

**API traps that break verification:**

- **List endpoints default to `period:this_year`.** Any filter you pass replaces that default. Every verification query must set the period explicitly, or it silently skips older years.
- **`GET /financial_mutations` caps at 100 results.** Use the synchronization endpoints (`GET .../synchronization` for IDs and versions, then `POST` with up to 100 IDs) for complete pulls.
- **API responses are cached.** An immediate GET after a write can return stale data. Trust the status code and body of the write response first. Run the full read-back through the synchronization endpoints in a later pass.
- **`DELETE /ledger_accounts` returns 204 even when nothing was deleted.** Confirm every delete with a separate read.
- **Reports cover at most 12 months per request.** Request one year at a time.
- **Moneybird cannot import old bookkeeping in one go.** History is rebuilt record by record, or replaced by an opening balance.
- **VAT returns must be marked in order.** You cannot file an earlier period after a later one.

### 1.3 Credentials and connections

| Item | Where it lives | Who may use it |
|---|---|---|
| Jortt client ID and secret | `.env` (gitignored) | Every analysis agent, read scopes only |
| Moneybird API token (can write) | `.env.writer` (gitignored), from Phase 7 onward | Migration Writer session only |
| Read-only Moneybird CLI session | Process environment with `MONEYBIRD_GUARD_READ_ONLY=1` | Analysis, audit and red team sessions |
| Moneybird writer token | `.env.writer`, from Phase 7 onward | Migration Writer through `moneybird-guard` only |
| Pilot administration ID | `.env` | Same value as the administration ID until Phase 17. Clear it at the switch to live bookkeeping, so writes need `--production` again |

Copy `.env.example` to `.env` and fill it in. Never print a credential in a log, report or chat.

Set `MONEYBIRD_GUARD_READ_ONLY=1` in every analysis, audit and red team session. It blocks every non-GET Moneybird CLI call before the real call.

**Write isolation is a convention, not a hard boundary.** The token in `.env.writer` is reachable from any session started in this folder. Two rules close most of that gap:

- Analysis, audit and red team sessions use guarded CLI reads with `MONEYBIRD_GUARD_READ_ONLY=1` and explicit period filters.
- The Writer acts only on a pre-write report that the operator approved, and it logs every created or changed ID in the write journal.

A hard boundary would need a separate OS user or keychain item. The operator decides in Phase 0 whether that is worth it.

---

## 2. WORKING FOLDERS

Never rename, move, overwrite or delete the original files behind `personal database/`. Agents read from it and write nowhere inside it.

All migration output goes to `migration-workspace/`, which is gitignored:

- `migration-workspace/Registers/`: one register per source and agent.
- `migration-workspace/Mappings/`: category, ledger and VAT mappings.
- `migration-workspace/Exceptions/`: the exception ledger.
- `migration-workspace/Reports/`: pre-write, pilot, quarter and year reports.
- `migration-workspace/Snapshots/`: frozen inputs and year-lock snapshots.
- `migration-workspace/Inputs/<agent>/`: the only files each independent agent may read (see Phase 3).
- `migration-workspace/WriteJournal/`: every Moneybird write with its returned ID.

---

## 3. MATERIALITY THRESHOLDS

The gates below use these numbers. They are proposed defaults. The operator confirms or changes them in `MIGRATION_CONFIG` during Phase 0, ideally with an accountant. This plan is not tax advice.

| Check | Threshold | Applies at |
|---|---|---|
| Bank balance per account at period end | €0.00 difference | Phases 8, 10 |
| VAT per return box per quarter | at most €1.00, classed `ROUNDING` | Phase 9 |
| Revenue and costs per main group per year | at most €5.00 unexplained | Phase 10 |
| Profit versus annual accounts and filed IB | €0.00 unexplained, every difference explained | Phases 10, 11 |
| Balance sheet line per year | €0.00 unexplained | Phase 10 |
| Ledger entries backed by an original document | 100% above €50, at least 98% overall by count | Gate 2 |
| Missing original document | Always an exception, never ignored | All phases |

"Unexplained" means no exception record with a cause and evidence. A threshold never permits a balancing entry. It only decides whether a difference blocks the gate.

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
