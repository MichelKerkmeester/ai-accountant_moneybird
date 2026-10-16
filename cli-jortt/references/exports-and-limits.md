---
title: "Jortt Exports and API Limits"
description: "Confirmed export routes and limits for source records used in an accounting migration."
trigger_phrases:
  - "Jortt XAF auditfile"
  - "Jortt annual accounts"
  - "Jortt Dropbox export limits"
  - "Jortt no general ledger export"
importance_tier: important
contextType: research
version: 1.0.0.0
---

# Jortt Exports and API Limits

This reference separates API extraction from records that only the operator can download in Jortt.

---

## 1. OVERVIEW

### When to Use

- A request names an XAF auditfile, annual accounts or a filed VAT return
- A migration step depends on API rate limits, page size or history depth
- A download link expired or a record looks archived

### Core Principle

Say plainly when a record needs the Jortt UI. Never present another report as the requested export.

---

## 2. UI-ONLY EXPORTS

### XAF auditfile

The API has no XAF or auditfile endpoint. In the Jortt UI, an administrator (Beheerder) can open `Boekhoudbot`, choose `Maak voor mij een auditfile`, select a year and generate one XAF 4.0.3 file for that year. Uploaded receipts and invoices are not part of that XAF file. Ask the operator to perform this step.

### Annual accounts and filed VAT returns

Annual accounts are under `Rapporten > Jaarrekening`, one year at a time. Filed VAT returns must also be downloaded through the Jortt UI. The API has no filed VAT return endpoint and its VAT summary is not a filed return. The supplied facts identify no IB report endpoint.

### No general ledger export

There is no general ledger export in the API or in the UI. Do not promise one or label a report as a general ledger. The API also has no general journal entries apart from payroll journal entries.

---

## 3. DROPBOX EXPORT

Jortt's Dropbox export includes sales invoices plus purchase invoices and receipts linked to a booking. Files are renamed by booking number per year. It leaves unlinked inbox files out. Use the receipt and attachment download endpoints to recover API-accessible originals, including unlinked inbox items.

---

## 4. RETENTION AND DOWNLOADS

Jortt keeps an administration for seven years after a subscription ends. Keep an independent migration archive. Do not rely on continued account access as the only copy.

Receipt, invoice and attachment download operations return short-lived signed links. The link lasts only a few minutes. Fetch it promptly with `jortt-cli fetch`. A signed link can expire before a later retry, so request a fresh link from the API.

---

## 5. API LIMITS

The Jortt API allows at most 10 requests per second. List pages contain at most 100 items. Report operations accept a year parameter. The real historic depth of list endpoints is UNCONFIRMED. The CLI sleeps between requests and follows `_links.next.href` when `--all` is set.

Writes to a closed financial year fail with HTTP 422. Payment-matching sources are limited to the last 24 months and are unavailable inside a closed year. The migration route is read-only, so a 422 on a read needs investigation rather than a write retry.

Archived customers can behave like deleted records and return `deleted: true`. Projects and bank accounts have an `archived` flag. The API catalogue has no `include_deleted` filter. Preserve record state when building the source register.

---

## 6. UNCONFIRMED ITEMS

Whether Moneybird accepts Jortt's XAF 4.0.3 format needs a separate check before the migration plan relies on import. The API facts do not establish an import result. A search summary mentioned an 18 month history limit, but no primary source confirmed it.

The oldest available records through list endpoints are UNCONFIRMED. Do not treat any capability absent from the supplied spec and research as confirmed. Mark it `UNVERIFIED` until an operator or source document confirms it.

---

## 7. RELATED RESOURCES

- [`rest-api.md`](rest-api.md) - API operations and paging
- [`cli.md`](cli.md) - Signed download fetch
- [`troubleshooting.md`](troubleshooting.md) - Expired links and 422 responses
