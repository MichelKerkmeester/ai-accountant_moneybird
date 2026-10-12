---
title: Moneybird bookkeeping for a Dutch sole trader
description: Accounting treatment for common ZZP sales, costs, private use, assets, opening balances, bank reconciliation, and VAT events in Moneybird.
trigger_phrases:
  - Moneybird ZZP bookkeeping
  - book a business expense
  - match a Moneybird bank transaction
  - Moneybird asset depreciation
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Moneybird bookkeeping for a Dutch sole trader

Use accounting purpose and tax treatment to choose a posting. Product behaviors below are per Moneybird help reviewed on 2026-10-10.

---

## 1. OVERVIEW

This reference explains how common sole-trader events map to accounting categories in Moneybird. It does not repeat CLI mechanics. Use moneybird-guard for every Moneybird CLI read or write, following [cli-moneybird](../../cli-moneybird/SKILL.md). Set MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions.

---

## 2. SALES AND RECEIPTS

### New sales and historical external sales

Use a Moneybird sales invoice for an invoice created and sent in Moneybird. Use external sales for an invoice issued outside Moneybird or a historical invoice entered from its source document. Per Moneybird help, an external sale supports outside or historic sales records. Review the invoice date, customer, net amount, VAT treatment, and source document.

- Product reference: [external sales](https://helpcenter.moneybird.nl/nl/articles/223885-externe-omzet-verwerken-in-je-administratie).
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

### Bank receipt for an existing invoice

Match a receipt to the existing sales invoice. Do not record the receipt as another sale. A cash receipt settles the debtor balance and must not duplicate revenue.

- Product reference: [Jortt category guidance](https://www.jortt.nl/boekhouden/boekhouden-uitleg/op-de-juiste-categorie-boeken/) describes the same matching principle.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 3. PURCHASES AND COSTS

### Purchase invoices and receipts

Add the source invoice or receipt as an incoming document, then process it into the accounts. The [purchase invoice reference](./purchase-invoices.md) gives the full booking flow and the VAT rate for a Dutch invoice, a reverse-charged foreign invoice and an invoice with foreign VAT. Per Moneybird help, a document in the incoming inbox is not booked and is not included in VAT until processed. Check the supplier, date, invoice number, amount, VAT, and accounting category before saving.

- Product references: [add a purchase invoice or receipt](https://helpcenter.moneybird.nl/nl/articles/207118-inkoopfactuur-of-bon-toevoegen) and [process incoming documents](https://helpcenter.moneybird.nl/nl/articles/207134-verwerk-inkoopfacturen-en-bonnen).
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

### Category choice

Moneybird categories map to ledger accounts and RGS codes. Select the category by accounting purpose and VAT treatment, not by a label that happens to match a Jortt category. The category list is product behavior per Moneybird help reviewed on 2026-10-10.

- Product reference: [add a category](https://helpcenter.moneybird.nl/nl/articles/207276-categorie-toevoegen).
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

### Mixed private and business costs

Keep the business and private parts separate. Use a product split only after the eligible business portion and VAT allocation have been checked. Private costs paid from the business account are not operating expenses.

- Product reference: [automatic private-cost split](https://helpcenter.moneybird.nl/nl/articles/639653-prive-kosten-automatisch-verdelen), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 4. PRIVATE USE AND MILEAGE

### Private withdrawals and contributions

Post proprietor contributions and withdrawals against private or equity accounts. They are not sales or operating expenses. Record private use of a business product or service as the supported private-use adjustment after the underlying tax treatment has been decided.

- Product references: [business and private](https://helpcenter.moneybird.nl/nl/articles/207322-zakelijk-en-prive) and [private use of business products or services](https://helpcenter.moneybird.nl/nl/articles/207324-privegebruik-van-zakelijke-producten-of-diensten-voor-eenmanszaken), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

### Business kilometres in a private vehicle

Record the supported business distance with the rate for the travel year and a trip purpose. Keep the trip log. Do not separately deduct fuel, insurance, repairs, or parking that the kilometre allowance already covers. The amount changes by year, so first check `kosten-en-auto.md` in the folder for the travel year, routed from [the Dutch tax rules](./dutch-tax-rules.md).

- Product reference: [business kilometres](https://helpcenter.moneybird.nl/nl/articles/207993-zakelijke-gereden-kilometers-verwerken), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 5. ASSETS AND OPENING BALANCE

### Fixed assets and depreciation

A qualifying asset is recorded with its original cost, in-use date, useful life, residual value, and prior depreciation when it already existed. Moneybird supports straight-line depreciation and existing-asset opening data. Its product activation threshold is €450 excluding VAT, per Moneybird help reviewed on 2026-10-10. Tax classification and depreciation limits still need a year-specific check. Building depreciation needs a separate WOZ floor decision and is not fully automated by the product.

- Product references: [add an asset](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen), [straight-line depreciation](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven), and [move existing assets](https://helpcenter.moneybird.nl/nl/articles/223936-bestaande-vaste-activa-overzetten-naar-bezittingen).
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

### Opening balance

Use the final closing balance sheet from the previous system. An opening journal includes assets, liabilities, VAT balances, and proprietor equity. Date it immediately before the Moneybird start period. For a 1 January start, the date is 31 December of the previous year. Reconcile the presentation of fixed assets and accumulated depreciation so historical depreciation is not posted twice.

- Product reference: [opening balance](https://helpcenter.moneybird.nl/nl/articles/207967-beginbalans-opstellen), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 6. BANK RECONCILIATION

Reconcile each bank transaction to the right invoice, receipt, category, or private account. Review automatic suggestions and handle unmatched transactions explicitly. A VAT-bearing cost should retain its invoice or receipt and be matched to that evidence. Do not leave unexplained balances.

- Product references: [automatic bank transaction processing](https://helpcenter.moneybird.nl/nl/articles/207581-automatisch-je-banktransacties-verwerken) and [matching an invoice or category](https://helpcenter.moneybird.nl/nl/articles/207583-factuur-of-categorie-koppelen-aan-transactie), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 7. VAT AND PERIOD CONTROL

An eligible Moneybird administration can submit a VAT return through the product. The operator reviews and files the return, and arranges payment separately. This assistant never submits or files any return. A VAT correction comparison depends on prior returns filed through Moneybird. If earlier returns were filed elsewhere, use the tax authority's correction process. A filed return does not automatically lock the accounting period. Set or review a lock date deliberately and only when authorized.

Moneybird does not prepare the proprietor's complete personal income-tax return. Its profit and loss, balance sheet, and fixed-asset reports can support an external return preparer, per Moneybird help reviewed on 2026-10-10. This assistant never files the return.

- Product reference: [income-tax reporting](https://helpcenter.moneybird.nl/nl/articles/207660-inkomstenbelasting-aangifte-met-de-hulp-van-moneybird).
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

- Product references: [VAT filing](https://helpcenter.moneybird.nl/nl/articles/223650-de-btw-aangifte-indienen), [VAT corrections](https://helpcenter.moneybird.nl/nl/articles/223663-btw-correcties-suppletie), and [period unlocking](https://helpcenter.moneybird.nl/nl/articles/207254-periode-ontgrendelen), per Moneybird help reviewed on 2026-10-10.
- Guarded CLI route: [cli-moneybird](../../cli-moneybird/SKILL.md).

---

## 8. RELATED RESOURCES

- [Dutch tax rules](./dutch-tax-rules.md) explains the general tax rules and routes to the year folders with the yearly amounts.
- [Purchase invoices](./purchase-invoices.md) explains booking purchase invoices, receipts and orders with Dutch or reverse-charged VAT.
- [Jortt to Moneybird mapping](./migration/jortt-to-moneybird-mapping.md) explains source-to-target concept mapping.
- [Migration phase index](./migration/README.md) routes historical migration work.
