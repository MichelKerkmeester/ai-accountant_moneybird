---
title: Jortt to Moneybird concept mapping
description: Conceptual mapping for Jortt bookkeeping data to Moneybird categories, records, assets, VAT and opening balances.
nav_label: "Jortt to Moneybird concept mapping"
trigger_phrases:
  - Jortt to Moneybird mapping
  - migrate a Jortt auditfile
  - Jortt migration trap
  - reconcile source bookkeeping
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Jortt to Moneybird concept mapping

Map each record by accounting purpose and evidence. Product behavior is per Jortt or Moneybird help reviewed on 2026-10-10.

---

## 1. OVERVIEW

This reference describes conceptual matches and common migration traps. It does not duplicate CLI mechanics. Use jortt-cli for Jortt reads, following [cli-jortt](../../../cli-jortt/SKILL.md), and moneybird-guard for Moneybird reads or writes, following [cli-moneybird](../../../cli-moneybird/SKILL.md). Set MONEYBIRD_GUARD_READ_ONLY=1 for read-only Moneybird sessions.

---

## 2. CONCEPT MAPPING

| Jortt source concept | Moneybird accounting concept | Migration trap |
|---|---|---|
| Sales and income | Sales invoices for invoices issued in Moneybird, or external sales for historic or outside invoices | A bank receipt that settles an existing invoice is not new revenue. Do not duplicate the sale. |
| Costs | Moneybird categories and processed purchase documents | Matching category names can have different ledger or VAT treatment. Map by purpose and tax treatment. |
| Receipts and purchase invoices | Incoming documents that become booked documents after processing | An uploaded but unprocessed document is not booked and is not included in the VAT return (btw-aangifte). |
| Private withdrawals and deposits | Private or equity postings | They are not operating expenses or sales. Keep proprietor cash flows separate. |
| Categories and ledger accounts | Moneybird category mapped to a ledger account and RGS code | Do not assume the source account list imports one-to-one. Review the target category and VAT mapping. |
| VAT returns and corrections | Moneybird VAT workflow for eligible periods, with the tax authority route for earlier returns filed elsewhere | Moneybird's comparison depends on returns it filed. Preserve evidence of historical filed returns. The operator files all returns. |
| Assets and depreciation | Target fixed assets (vaste activa) with original cost, date in use, useful life (gebruiksduur), residual value (restwaarde) and prior depreciation | Do not post accumulated depreciation twice. Confirm building WOZ floor and tax treatment separately. |
| Business mileage | Mileage expense supported by travel-year rate and trip log | The reviewed Jortt help pages did not confirm a direct mileage migration workflow. Status: unverified. Preserve evidence and verify before closing. |
| Bank entries | Bank transaction matched to an invoice, receipt, category or private account | A matched invoice receipt must not be treated as a second sale. |

---

## 3. SOURCE-SYSTEM EXPORT TRAPS

### Attachments

Per Jortt help reviewed on 2026-10-10, uploaded document attachments are not included in the Jortt auditfile. Reconcile the auditfile against the original documents and attachment register as distinct items.

Source: [Jortt export options](https://www.jortt.nl/uitleg/faq/exportmogelijkheden-in-jortt/).
CLI route for source reads: [cli-jortt](../../../cli-jortt/SKILL.md).

### Asset list

Per Jortt help reviewed on 2026-10-10, the asset list is not a separate export, although asset data appear in the auditfile or annual report. Reconcile asset evidence and the source balance sheet independently.

Source: [Jortt export options](https://www.jortt.nl/uitleg/faq/exportmogelijkheden-in-jortt/).
CLI route for source reads: [cli-jortt](../../../cli-jortt/SKILL.md).

### Categories and opening balance

Jortt groups categories as income, costs and balance items. Private withdrawals and deposits are balance items, per [Jortt category guidance](https://www.jortt.nl/boekhouden/boekhouden-uitleg/op-de-juiste-categorie-boeken/). Compare the source trial balance with the target category and ledger mappings before any approved write.

CLI route for target review or write work: [cli-moneybird](../../../cli-moneybird/SKILL.md).

---

## 4. MIGRATION CHECKS

- Reconcile documents, booked records, bank transactions, assets and filed returns as separate evidence streams.
- Keep the original source evidence unchanged.
- Keep migration data and output only in migration-workspace/.
- Record missing attachments and uncertain classifications as exceptions.
- Pass the applicable phase gate before a Moneybird write.
- Preserve the source and target record relationship in the migration register.
- Do not treat a Moneybird CLI read-back as proof until the owning tool skill's verification process is followed.

---

## 5. RELATED RESOURCES

- [Migration phase index](./README.md) contains phase routing and gates.
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) describes target accounting treatment.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) explains the tax rules and routes to the year folders with the values per year.
