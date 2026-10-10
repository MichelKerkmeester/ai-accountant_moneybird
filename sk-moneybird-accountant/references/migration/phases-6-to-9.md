---
title: Migration phases 6 to 9
description: Mapping, pilot work, historical quarterly migration, and VAT verification.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 6 to 9

Mapping, pilot work, historical quarterly migration, and VAT verification. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## Phase 6: Design the Moneybird mapping

### Goal

Decide how historical bookings translate into Moneybird.

### Mapping Agent

Create `CATEGORY_MAPPING`. Every new Moneybird ledger account needs an RGS code (`rgs_code`), because the API rejects ledger accounts without one.

| Old category | Moneybird ledger account | RGS code | Type | VAT rate | Confidence |
|---|---|---|---|---|---|

Also create `VENDOR_TAX_MATRIX`:

| Legal entity | Period | Country | VAT ID | Type | Moneybird tax rate |
|---|---|---|---|---|---|

Every Moneybird tax rate in this matrix must already exist. The operator created them in step 0.7.

### Document type mapping

| Historical item | Moneybird record |
|---|---|
| Sales invoice issued in Jortt | External sales invoice, original number and date kept, original PDF attached |
| Purchase invoice | Purchase invoice document with PDF attached |
| Receipt | Receipt document with PDF attached |
| Journal entry, private item, correction | General journal document |
| Asset | Asset with its historical value changes |
| Bank transaction | Financial statement imported from CAMT.053 or MT940 |

Unverified: does Moneybird's VAT report count external sales invoices the same way as its own sales invoices? Test this in the pilot before relying on it.

### Vendor versioning

When a supplier later invoices from another country or legal entity, add a new validity period. Never use one permanent VAT rule per brand.

---

## Phase 7: Pilot migration

### Goal

Test the whole process on a small, controlled dataset in the **trial administration**, which is also the future mirror. Each pilot record is either kept as a verified first record or removed in the undo rehearsal, so nothing unverified stays in the mirror.

### Selection

Choose one representative month from the oldest usable year. Ideally it contains:

- A sales invoice.
- A Dutch purchase.
- An EU SaaS purchase.
- A non-EU SaaS purchase.
- A normal bank payment.
- A private payment, if one exists.

### Steps

**7.1 Pre-write report [AI].** Generate `PILOT PRE-WRITE REPORT` with every record, its Moneybird destination, ledger account, tax rate, risk class and the expected totals.

**7.2 Resolve blockers [Operator + AI].** Resolve every `RED` and `BLACK` record first.

**7.3 Approve [Operator].** Approve the pre-write report. Move the Moneybird API token into `.env.writer` and give it only to the Writer session.

**7.4 Write [AI].** The Migration Writer writes only approved records through `moneybird-guard` for every write, using the Writer token after the plan gate. It appends every returned ID to `WriteJournal/`.

**7.5 Import the bank file [Operator].** Import the pilot month's CAMT.053 or MT940 file in the Moneybird web app. Then the Writer links payments through `financial_mutations/{id}/link_booking`.

**7.6 Read back [AI].** Compare `PLANNED` with `ACTUAL` in two passes:

- From the write responses, immediately.
- Through the synchronization endpoints, in a later session. This guards against cached GET responses.

**7.7 Independent audit [AI].** The Independent Auditor checks Moneybird again, starting from the original sources. It uses guarded CLI reads with `MONEYBIRD_GUARD_READ_ONLY=1` and explicit period filters.

**7.8 Red Team [AI].** The Red Team runs a second check.

**7.9 Rehearse the undo [Operator + AI].** Delete one pilot record through the REST API, confirm the delete with a separate read and log it. This proves the correction path before production needs it.

### Exit Gate 7

The pilot passes only when all of these hold:

- Documents are correct and have their PDFs.
- VAT is correct.
- The bank reconciles logically.
- There are no duplicates.
- There are no unexplained differences.
- The undo rehearsal worked.

Status: `PILOT PASSED`, otherwise `PILOT FAILED`.

Bulk processing is forbidden until the pilot passes. After it passes, replay the same approved records in the production administration through Phase 8.

---

## Phase 8: Historical migration per quarter

### Goal

Reconstruct the oldest year in Moneybird under control. Work on at most one quarter at a time.

### Per quarter

**8.1 Freeze input [AI].** Record which source files belong to the batch, with their hashes, in `Snapshots/`.

**8.2 Pre-write reconciliation [AI].** Check all records again.

**8.3 Pre-write report [AI].** Report:

- Number of documents and number of transactions.
- Green, Amber, Red and Black counts.
- Expected revenue, costs and VAT.
- Expected bank movement.

**8.4 Approve [Operator].** Approve the report.

**8.5 Write [AI].** Write approved records only. Throttle to stay under 150 requests per 5 minutes.

**8.6 Import bank files [Operator].** Import the quarter's bank files. Then the Writer links payments.

**8.7 Read-after-write [AI].** Check every written record through the synchronization endpoints.

**8.8 Document reconciliation [AI].** Compare Moneybird with the originals.

**8.9 Bank reconciliation [AI].** Compare transactions and closing balances per account.

**8.10 VAT reconciliation [AI].** Run Phase 9.

**8.11 Red Team [AI].** Run an adversarial review on the batch.

**8.12 Batch lock.** Only then set `YYYY-QX VERIFIED`.

### Correcting a wrong write

Corrections go through `moneybird-guard` or the Moneybird UI:

1. Log the wrong record as an exception.
2. Delete or update it by its ID from `WriteJournal/`.
3. Confirm the change with a separate read.
4. Rewrite it from an approved record.

Never correct inside a locked period without first opening an exception and unlocking deliberately.

---

## Phase 9: VAT verification loop per quarter

Use four independent values:

- **A, Document VAT**: calculated from the original invoices.
- **B, Ledger VAT**: calculated from the XAF.
- **C, Filed VAT**: what was actually filed.
- **D, Moneybird VAT**: the new reconstruction, from `GET /reports/tax` with an explicit period.

| Return box | Documents | Ledger | Filed | Moneybird | Difference |
|---|---:|---:|---:|---:|---:|

Classify each difference as one of:

- `EXACT`
- `ROUNDING`
- `EXPLAINED`
- `SOURCE DIFFERENCE`
- `FILING DIFFERENCE`
- `MONEYBIRD DIFFERENCE`
- `UNEXPLAINED`

Exit for the quarter: `UNEXPLAINED = 0`.

**After the exit [Operator].** Mark the quarter's VAT return in Moneybird as filed with "Handmatig indienen", in chronological order, so Moneybird never offers to file it.

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
