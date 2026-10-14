---
title: Rubrieken and derivation for the VAT return
description: The rubriek table for 1a to 5b with the law and the Moneybird source per line. The derivation map from a booking to a return line, the run-time rate step and the reverse-charge, KOR, 3b to ICP and OSS rules.
nav_label: "Rubrieken and derivation for the VAT return"
trigger_phrases:
  - VAT rubrieken
  - btw rubrieken 1a tot 5b
  - rubriek indeling btw
  - voorbelasting rubriek
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Rubrieken and derivation for the VAT return

**Rule:** Derive every line from the administration's own rate list and VAT overview at run time. Never use a hard-coded rate-to-rubriek table. A rate used in the period without a report reference is a blocker. Every rate, threshold and figure is in the year files under `references/tax-rules/`.

---

## 1. OVERVIEW

The return is organised as five rubrieken. A business that trades only inside the Netherlands normally needs rubriek 1 and rubriek 5 only. The law column states what a line reports. The Moneybird column states how a booking reaches it. The rates themselves are in the year file, for example [BTW 2026 figures](../tax-rules/2026/vat/figures.md).

---

## 2. THE RUBRIEK TABLE

| Rubriek | What it reports (law) | Moneybird source |
|---|---|---|
| 1a | Domestic taxable supplies at the high rate, net base and VAT. Wet OB art. 9(1). | Sales invoice lines on a rate whose `Btw-rapport` reference names rubriek 1a. |
| 1b | Domestic taxable supplies at the low rate, the goods and services in Tabel I. | Sales lines on the low-rate report reference. |
| 1c | Domestic supplies at other special non-zero rates, such as the sport-canteen forfait. | The special-rate lines only. |
| 1d | VAT payable on private use and a correction of earlier input VAT. | A `Privé-gebruik` memoriaal rate and the `Btw privégebruik` category. A purchase-time split limits the input VAT at purchase and is not the 1d correction. |
| 1e | Domestic zero-rated turnover and turnover not taxed at the business, including domestic reverse-charged sales. | Zero-rate and domestic reverse-charge sales lines. |
| 2a | VAT shifted to the business on domestic goods or services. Wet OB art. 12. | Purchase lines on the domestic reverse-charge rates. |
| 3a | Goods exported from the Netherlands to non-EU countries, the supplies in Tabel II. | Export sales lines plus customs or transport evidence. |
| 3b | Intra-EU supplies of goods and services under the relevant conditions. | EU sales lines plus the `ICP-overzicht` per customer VAT number. |
| 3c | Installation or assembly in another EU country and distance sales not declared through the Union OSS. | Consumer distance-sale lines not routed through OSS. |
| 4a | Import under the Article 23 permit and services from a non-EU supplier with reverse charge. | Purchase lines on the `Buiten EU` rates, including the KOR and exempt variants. |
| 4b | Intra-Community acquisitions of goods and services from an EU supplier with reverse charge. | Purchase lines on the `Binnen EU` rates, including the KOR and exempt variants. |
| 5a | Total VAT due from rubrieken 1 to 4. | Arithmetic over the rubriek table. |
| 5b | Deductible input VAT, including the VAT declared under 2a, 4a and 4b. | The supported input VAT per line, never a blanket VAT total. |
| 5c to 5g | Unresolved. No current primary explanation was reachable, so the labels and the semantics are not established. | Do not compute these from transaction data. See [README](README.md#5-open-points), open point `O1`. |

The 1e and 2a mirror rule. The supplier reports a domestic reverse-charged sale in 1e and the buyer reports the same charge in 2a. A domestic reverse-charged sale is never 2a on the supplier side.

---

## 3. THE DERIVATION MAP

The derivation unit is the invoice line plus its tax rate, not the ledger account. Moneybird computes VAT per line. The invoice date and the rate are decisive.

| From | To | Rule |
|---|---|---|
| A sales invoice line | Rubriek 1 or rubriek 3 | Read the line's tax rate and its `Btw-rapport` reference. The base and the VAT land on the rubriek the reference names. |
| A purchase invoice line | Rubriek 2, rubriek 4 or 5b | Read the same pair. A supported input-VAT line also lands in 5b when the purchase serves taxed turnover. |
| A bank transaction booked straight to a category | No return line by itself | A category posting with no VAT line is a product check, not a return basis. Reclassify it or record the exception. |
| A memoriaal booking | The rubriek its rate names | Check the memoriaal rate and its reference. Revenue booked through a memoriaal is a documented reconciliation cause. |
| A rate with no report reference | Nothing | Blocker. Read the rate list and fix the rate or record it as unsupported. |
| A profit-and-loss total | Not a return base | Never force the profit and loss totals to equal the return. Explain each difference by cause. |

---

## 4. THE RUN-TIME RATE STEP

1. Read the administration's own `Btw-tarieven` list through moneybird-guard under `MONEYBIRD_GUARD_READ_ONLY=1`.
2. Read the period's rate overview and, for every rate used, the `Btw-rapport` reference that names its rubriek.
3. Build each return line from the base and the VAT of the matching rates.
4. Name every rate used in the period without a report reference as a blocker. Never map such a rate by hand and never guess its rubriek.

No fixed rate-to-rubriek table sits in this folder. The map comes from the administration at run time, because the public help documents only a part of it and a hand-built map goes stale. The administration's rates are product records, so a renamed or hand-added rate can differ from the standard set.

---

## 5. THE REVERSE-CHARGE BRANCH

| Case | The return lines |
|---|---|
| Domestic reverse-charged sale | Supplier 1e, buyer 2a. |
| Domestic reverse-charged purchase | Buyer 2a and the same VAT in 5b when the purchase serves taxed turnover. |
| Goods or a service from an EU supplier with reverse charge | Buyer 4b and the same VAT in 5b when the purchase serves taxed turnover. |
| A service from a non-EU supplier with reverse charge | Buyer 4a and the same VAT in 5b when the purchase serves taxed turnover. |
| Import under the Article 23 permit | 4a, with the same VAT in 5b when deductible. |
| A KOR or exempt business | 4a or 4b only. Nothing in 5b. |

Reverse-charge VAT is not automatically net zero. The deduction in 5b depends on taxable use. The rate naming and the `btw verlegd` requirements are in [purchase invoices](../purchase-invoices.md). The law is in the year file, for example [BTW 2026 rules](../tax-rules/2026/vat/rules.md).

---

## 6. THE KOR BRANCH

The KOR is an exemption, not a reduction. Ordinary KOR turnover does not enter rubriek 1, so the old reduction line has nothing to reduce.

- Reverse-charged purchases survive the KOR. The VAT must still be declared and cannot be reclaimed.
- A KOR rate set reports in 4a or 4b and puts nothing in 5b.
- A KOR participant with an intra-Community acquisition or a reverse-charged service still has an incidental filing duty.
- The ceiling test runs per calendar year. The supply that crosses it is taxed in full. The exemption does not apply for the rest of that year or the next.
- The KOR conditions, the ceiling and the exit rules are in the year file, for example [BTW 2026 figures](../tax-rules/2026/vat/figures.md) and [BTW 2026 rules](../tax-rules/2026/vat/rules.md).

A KOR quarter with a reverse-charged purchase is not skipped. The incidental filing duty still applies.

---

## 7. THE SALES RULE: 3B TO ICP AND OSS

- The 3b total must tie to the per-customer ICP detail. Take both from the administration's own reports, not from memory.
- A period with no intra-EU supply needs no ICP while the Dutch return is still due.
- Moneybird's ICP article labels its intra-community line as `3a`. That is a product label and never enters the return table, where 3a is the non-EU export line and 3b is the intra-EU line.
- Keep every OSS amount out of the Dutch return. Do not net OSS and 3c.
- Moneybird cannot file the Union or import OSS returns. Those go through the Belastingdienst.
- The ICP period rules and the distance-sales threshold are in the year file, for example [BTW 2026 rules](../tax-rules/2026/vat/rules.md).
- The ICP deadline is an open point. See [README](README.md#5-open-points), open point `O2`.

A below-threshold distance sale belongs in 3c only when the supplier opted for foreign VAT and files abroad. Test that before placing a line.

---

## 8. CORRECTION PHRASES

A correction request uses one of these three phrases. The routing between them is in [year-end-and-corrections.md](year-end-and-corrections.md).

- `suppletie`
- `naheffing`
- `correctie vorige periode`

A correction at or below the boundary the year file states goes into the next return in the same rubriek. A correction above the boundary goes through the suppletie. The boundary, the reporting period and the interest rules are in the year file, for example [BTW 2026 figures](../tax-rules/2026/vat/figures.md) and [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md).

---

## 9. RELATED RESOURCES

- [README](README.md) for the boundary and the open points.
- [Preparation](preparation.md) for the step that runs this file.
- [Year-end and corrections](year-end-and-corrections.md) for the settlement and correction branches.
- [Review pack](review-pack.md) for the output contract.
- [Purchase invoices](../purchase-invoices.md) for the booking and rate cases.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing.
