---
title: Migration phases 10 to 16
description: Year-end, income-tax cross-check, continuity, review, locking, and current-year parallel work.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 10 to 16

Year-end, income-tax cross-check, continuity, review, locking, and current-year parallel work. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## Phase 10: Year-end check

After Q1 to Q4, run a full year check. Request each report for one year only.

**10.1 Bank.** Per account, the Moneybird closing balance must equal the real bank balance. Target: €0.00 difference.

**10.2 Revenue.** Compare document sales, XAF, annual accounts and Moneybird.

**10.3 Costs.** Compare per main group.

**10.4 VAT.** All quarters must be verified.

**10.5 Fixed assets.** Compare:

- The original purchase.
- The historical processing.
- The depreciation.
- The book value.

**10.6 Private items.** Check:

- Private deposits.
- Private withdrawals.
- Business costs paid privately.

**10.7 Profit.** Compare Moneybird, XAF, annual accounts and the filed return.

**10.8 Balance sheet.** Check at least:

- Bank.
- Receivables and payables.
- VAT.
- Assets and depreciation.
- Debts.
- Equity.

**10.9 Auditfile comparison.** Export Moneybird's XAF 4.0 for the year through `POST /reports/export/auditfile`. Compare it with Jortt's XAF at ledger-account level through `CATEGORY_MAPPING`. Any account total that differs needs an explanation.

---

## Phase 11: IB cross-verification

### Goal

Establish whether Moneybird matches the historical business figures.

| Item | Moneybird | Annual accounts | Filed IB |
|---|---:|---:|---:|

Jortt's API has no IB report, so the IB column comes from the filed return and the assessment.

Accounting profit is not always the same as tax profit. Record tax adjustments separately.

Never make Moneybird match the IB return by adding unknown items.

---

## Phase 12: Continuity between years

Before migrating year N+1, check that the closing balance of year N equals the opening position of year N+1 for:

- Bank.
- Receivables and payables.
- VAT.
- Assets and cumulative depreciation.
- Loans.
- Equity.

Do not enter a separate new opening balance while the full history is built in the same Moneybird administration. The only opening balance is the one at the start year chosen at Gate 2.

---

## Phase 13: Year Red Team

An independent agent now actively tries to prove that the year is wrong. It works in its own session, with guarded CLI reads set to `MONEYBIRD_GUARD_READ_ONLY=1`, explicit period filters and the original sources.

Checkpoints:

- Missing or duplicate invoices.
- Duplicate bank transactions.
- Wrong year, including the December to January cut-off.
- Missing credit notes.
- Unusual suppliers.
- Reverse charge.
- Private items.
- Assets and depreciation.
- Tax payments.
- Internal transfers.
- Unexplained journal entries.
- Profit differences and balance differences.

Output: `RED_TEAM_YEAR_REPORT`

---

## Phase 14: Year lock

A year may be locked only when all of these hold:

- Document completeness meets the threshold.
- All invoices are processed.
- All material ledger entries are explained.
- The bank matches exactly.
- All VAT periods are verified.
- The balance sheet and the profit match.
- The IB cross-check is done.
- The Red Team found no material unexplained errors.

**Lock it [Operator].** Lock the period in the Moneybird settings. The lock blocks edits and deletes in that period.

**Verify the lock [AI].** Read `period_locked_until` from `GET /api/v2/administrations.json` and confirm it covers the year.

Status: `YEAR VERIFIED & LOCKED`

Create a snapshot in `Snapshots/` containing:

- Source manifest and invoice registry.
- Canonical dataset and exception ledger.
- Moneybird auditfile, balance sheet and profit and loss.
- General ledger export.
- VAT reconciliation and IB reconciliation.
- Red Team report and the final verification report.
- The write journal.

Only then start the next year.

---

## Phase 15: Repeat from oldest to newest year

For each year, starting at the start year:

```
reconstruction -> quarterly migrations -> VAT verification -> year check -> IB -> Red Team -> LOCK
```

Then move to the next year. Never migrate several historical years in parallel.

---

## Phase 16: Current-year parallel mirror (2026)

The current year is handled differently, because the existing administration still leads.

During reconstruction:

- Jortt, or the accountant, is the official administration.
- Moneybird is a shadow ledger.

Per quarter:

1. Process the new documents.
2. Compare with the XAF.
3. Import and check the bank.
4. Reconstruct in Moneybird.
5. Compare the VAT overview.
6. File nothing again.

After 2026 closes, all of these must hold:

- Q1, Q2, Q3 and Q4 are verified.
- The bank is exact.
- Profit is exact or explained.
- The balance sheet is exact or explained.
- The annual accounts and IB are checked.

Then: `2026 VERIFIED`.

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
