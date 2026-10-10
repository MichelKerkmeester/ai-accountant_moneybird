---
title: Migration phases 0 to 2
description: Safety, setup, inventory, and source collection.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 0 to 2

Safety, setup, inventory, and source collection. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## Phase 0: Safety and system setup

### Goal

Build a controlled environment before anyone touches historical data.

### Actions

**0.1 Prepare the Moneybird administration [Operator].** Use the empty Moneybird trial administration as both the pilot and the mirror of the Jortt administration. No separate pilot administration is created. Book nothing historical yet. `MONEYBIRD_ADMINISTRATION_ID` and `MONEYBIRD_PILOT_ADMINISTRATION_ID` both hold its ID until the switch to live bookkeeping.

**0.2 Connect the tools [Operator + AI].**

- Fill `.env` from `.env.example`.
- Set `MONEYBIRD_GUARD_READ_ONLY=1` for read-only sessions and use guarded CLI reads with explicit period filters.
- Confirm the Moneybird CLI session and selected administration.
- Confirm that analysis sessions do not run Moneybird write operations.

**0.3 Verify access [AI].** Run read-only calls only:

- Fetch a Jortt token with the read scopes, then call `/v3/organizations/me`.
- Call Moneybird `GET /api/v2/administrations.json` to confirm the token and record the administration IDs.
- Set `MONEYBIRD_GUARD_READ_ONLY=1` and read one list through `moneybird-guard` with an explicit period filter.

Report status codes and field names only, never amounts or names.

**0.4 Protect the document archive [Operator + AI].** Confirm that `personal database/` is gitignored and that agents treat it as read-only. Build an index of the existing files. Do not reorganise them.

**0.5 Create the working folders [AI].** Create `migration-workspace/` with the subfolders from section 2.

**0.6 Record the migration rules.** During historical reconstruction:

- File no VAT returns.
- File no supplementary VAT returns (suppleties).
- File no IB returns.
- Initiate no historical tax payments.
- Invent no missing amounts.
- Never hide differences with arbitrary journal entries.
- Send no sales invoice. Historical sales invoices enter Moneybird as external sales invoices.

**0.7 Set up Moneybird foundations [Operator].**

- Create every tax rate the history needs in the Moneybird UI, including EU and non-EU reverse charge. The API cannot create tax rates.
- Decide the bookkeeping start date.

### Agents

- Orchestrator
- Evidence Archivist

### Output

`MIGRATION_CONFIG`, stored in `migration-workspace/`, containing:

- The Moneybird administration ID, used as both the production and the pilot ID.
- Suspected first business year.
- Document archive sources in use.
- Bookkeeping sources in use.
- Bank accounts in scope.
- Known tax sources.
- Confirmed materiality thresholds.
- The write-isolation decision (convention or hard boundary).

### Exit Gate 0

Continue only when all of these hold:

- Both Moneybird administrations exist.
- The Jortt CLI and the Moneybird CLI with `MONEYBIRD_GUARD_READ_ONLY=1` answer the explicit-period read.
- Moneybird writes use `moneybird-guard` and stay with the Migration Writer session.
- The original files are protected.
- The migration rules and thresholds are recorded.

Status: `PHASE 0 COMPLETE`

---

## Phase 1: Full source inventory

### Goal

Establish what data actually exists. Reconstruct nothing yet.

### Input

- The full document archive.
- Jortt, through the API.
- Bank archives.
- Mijn Belastingdienst [Operator].
- Documents from any accountant [Operator].

### Actions

**1.1 Archive scan [AI].** Find every candidate:

- Sales invoices, purchase invoices, receipts and credit notes.
- Annual accounts and XAF files.
- Bank exports.
- VAT returns, IB returns and tax assessments (aanslagen).
- Depreciation schedules.

**1.2 Build the invoice registry [AI].** Create `CLOUD_INVOICE_REGISTRY`. Record per document:

- Source ID, archive path, file name and SHA-256.
- Type, invoice number and invoice date.
- Supplier or customer, legal entity, country and VAT ID.
- Currency, net, VAT, gross and reverse-charge indicator.
- Confidence.

**1.3 Pull the Jortt inventory [AI].** Through the API, count per year the customers, sales invoices, expenses, receipts (including inbox items), bank accounts and bank transactions. Inbox receipts not linked to a booking are missing from Jortt's Dropbox export, so pull them from `GET /v3/receipts?scope=in_inbox` separately.

**1.4 Determine the business years [AI].** Find the first relevant business year from the earliest of:

- First sales invoice.
- First business purchase.
- First business bank transaction.
- First VAT return.
- First IB return with business income.
- First XAF.

**1.5 Build the year matrix [AI].** Mark each cell `COMPLETE`, `PARTIAL` or `MISSING`.

| Year | Documents | XAF | Bank | VAT | IB | Annual accounts | Assets |
|---|---|---|---|---|---|---|---|

### Agents

- **Evidence Archivist**: reads the document archive.
- **Document Extraction Agent**: extracts invoice data.

### Output

- `SOURCE_MANIFEST`
- `CLOUD_INVOICE_REGISTRY`
- `YEAR_SOURCE_MATRIX`
- `MISSING_SOURCE_REPORT`, which lists every export the operator still has to make

### Exit Gate 1

For every year it is known which sources exist, which are missing and what still needs exporting. No Moneybird writes yet.

Status: `PHASE 1 COMPLETE`

---

## Phase 2: Collect missing sources

### Goal

Make the evidence archive as complete as possible before reconstruction.

### Actions

The AI turns `MISSING_SOURCE_REPORT` into a concrete task list per year. The operator works through it.

**Jortt [Operator], per relevant year:**

- XAF 4.0.3 auditfile, via Boekhoudbot.
- Annual accounts.
- Filed VAT returns and any supplementary returns.

**Jortt [AI], per relevant year:**

- Sales invoice PDFs, via the invoice download endpoint.
- Purchase documents, via the expense and attachment endpoints.
- Inbox receipts, checked separately via `scope=in_inbox`.

**Bank [Operator], per business account and full year, in order of preference:**

1. CAMT.053
2. MT940
3. Official PDF bank statements
4. Other exports, for analysis only

**Mijn Belastingdienst [Operator]:**

- IB returns as filed.
- Final assessments.
- Amended assessments.
- Available VAT documents.
- Relevant correspondence.

**Accountant [Operator], if one was involved:**

- Annual figures.
- Tax profit calculation.
- Asset register.
- Correcting entries.
- Supplementary VAT returns.
- VAT reconciliations.

### Output

`SOURCE_MANIFEST_v2`

### Exit Gate 2

A year may move to reconstruction when it has at least:

- Original invoices meeting the document threshold in section 3.
- An XAF for that year.
- Bank history for every business account for the full year.
- Filed returns, or another reliable check source.

A year with too little evidence stays `SOURCE INCOMPLETE`.

**Choose the Moneybird start year here.** The start year is the earliest year from which every following year passes Gate 2. Years before it stay archive-only: their XAF, documents and filings remain in `personal database/` and Jortt's 7-year retention, and Moneybird starts with an opening balance. That opening balance is a journal entry dated the day before the start year. It comes from the closing balance in the last archive-only year's XAF and is checked against the bank and the filed returns. Record it as an exception with status `ACCEPTED HISTORICAL DIFFERENCE` if any line cannot be fully proven.

This rule replaces an open-ended wait. Without it, one incomplete middle year would block every later year under Phase 15.

Status: `PHASE 2 COMPLETE`

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
