---
title: Live workflows, phases 17 to 20
description: The transition to live work and the monthly, quarterly, and yearly workflows.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Live workflows, phases 17 to 20

The transition to live work and the monthly, quarterly, and yearly workflows. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## Phase 17: Switch to live bookkeeping

From the agreed start date:

| Role | System |
|---|---|
| Primary ledger | Moneybird |
| Primary document archive | `personal database/` |
| Cash truth | Bank |
| Filing truth | Belastingdienst |
| Archive and verification source | Historical Jortt data and XAF files |

Cancel Jortt only after downloading everything in Phase 2. Jortt keeps the administration for 7 years after cancellation, but do not rely on that as the only copy.

---

## Phase 18: Live monthly workflow

Every month:

1. Detect new documents in the archive.
2. Compare them with Moneybird.
3. Classify new suppliers.
4. Check bank transactions.
5. Look for:
   - Documents without a Moneybird record.
   - Moneybird records without a document.
   - Bank transactions without an explanation.
   - Unpaid or open invoices.
   - Duplicates.
6. Have the VAT Agent check every high-risk invoice.
7. Write the exception report. Target: `UNEXPLAINED = 0`.

---

## Phase 19: Live quarterly workflow

Before every VAT return:

1. Check document completeness.
2. Check Moneybird completeness.
3. Reconcile the bank.
4. Check revenue.
5. Check costs.
6. Review reverse charge.
7. Review foreign suppliers.
8. Recalculate VAT independently.
9. Compare with Moneybird.
10. Process corrections from previous periods.
11. Review the exception ledger.
12. Only then file the VAT return [Operator].

---

## Phase 20: Live yearly workflow

Before the annual IB return:

1. All months are closed.
2. The bank is exact.
3. Receivables are checked.
4. Payables are checked.
5. VAT is checked.
6. Assets are checked.
7. Depreciation is checked.
8. Private items are checked.
9. Profit is checked.
10. The balance sheet is checked.
11. Tax differences are recorded.
12. The year is closed.
13. The IB return is prepared.
14. The final year audit is done.

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
