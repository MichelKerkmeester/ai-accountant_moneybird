---
title: VAT return review pack
description: The output contract for a prepared VAT period. The nine pack blocks P1 to P9, the three confirmation parts C1 to C3, the deadline and payment block, the escalation list and Moneybird's five filing-time product checks.
nav_label: "VAT return review pack"
trigger_phrases:
  - VAT return review pack
  - btw-aangifte controle
  - btw-aangifte review
  - confirm the VAT return
importance_tier: important
contextType: general
version: 1.0.0.0
---

# VAT return (btw-aangifte) review pack

**Rule:** The pack is the output contract. It carries the figures for review, the exceptions and the confirmation the Operator needs. It never files, submits or pays. Every deadline and figure is a link to the year files under `references/tax-rules/`.

---

## 1. OVERVIEW

The agent prepared the return and did not file, submit or pay it.

The pack is ordered like the Dutch Tax and Customs Administration (Belastingdienst) screens: Domestic (Binnenland), Foreign (Buitenland) and Input VAT (Voorbelasting). The Operator can then verify a figure without a mental re-map. The pack carries the `betalingskenmerk` and its number-match status, because a wrong VAT number (omzetbelastingnummer) is a documented cause of a fine despite an on-time filing.

---

## 2. THE NINE PACK BLOCKS

| ID | Block | What it holds |
|---|---|---|
| P1 | Identity and period | The administration, the legal form (rechtsvorm), the resolved period and `year_key`, the cadence and the VAT regime, the `betalingskenmerk` and its number-match status. |
| P2 | Gate status per check | Every check from [preparation.md](preparation.md), with its status and its evidence path. |
| P3 | Section (Rubriek) table | The base and the VAT per line for 1a to 5b plus the rate set that feeds each line. Built from the rate overview, not from the ledger. |
| P4 | Ledger-to-return reconciliation | Every difference between the period profit and loss totals and the return bases, each classified into a documented cause. An unexplained difference is a blocker. |
| P5 | Open-exception list | Every item that is not a figure, with its owner and its next action. |
| P6 | Escalated judgement calls | Every judgement call from the escalation list in section 6, with the Operator question. |
| P7 | Arithmetic and outcome | The arithmetic gate result for 5a and 5b and the resulting payable or reclaimable amount. 5c to 5g stay unverified. |
| P8 | Post-confirmation actions | What the Operator does after confirming. The filing route and the payment route that each confirmation part enables. |
| P9 | Evidence manifest | Every figure traced to a booked item and its invoice, receipt, customs or transport evidence, with the retrievable link and the retention rule. |

The section rows and the rate sets are from [return-boxes.md](return-boxes.md#2-the-rubriek-table). The year-end settlements are from [year-end-and-corrections.md](year-end-and-corrections.md).

---

## 3. THE THREE CONFIRMATION PARTS

Confirmation is three separable decisions, not one click.

| ID | Part | What the Operator confirms |
|---|---|---|
| C1 | The figures | The section (rubriek) table, the reconciliation and the outcome. |
| C2 | The filing route | The return route, the ICP duty where it applies and any correction route. The `[Operator]` files the return. |
| C3 | The payment | The payable or reclaimable amount, the payment route and the account. The `[Operator]` pays. |

An open exception or a failed gate blocks C1. The pack states prepared, not filed. It never claims a filing or a payment.

---

## 4. DEADLINE AND PAYMENT BLOCK

Every date comes from the year file. The pack links the source and never repeats a date.

- The period's filing deadline (aangiftetermijn) and the software submission window are in [VAT 2026 figures](../tax-rules/2026/vat/figures.md).
- The payment date, the late-payment rules and any tax interest (belastingrente) are in [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md).
- The Operator's own filing invitation letter (aangiftebrief) and My Tax and Customs Administration Business (Mijn Belastingdienst Zakelijk) govern the individual case. Check them, because the year file states the general schedule only.
- Payment counts as timely when the amount is credited, so allow bank processing time and do not treat the transfer initiation as proof.
- Neither Moneybird nor the Dutch Tax and Customs Administration sends a payment reminder.

The block names the route and the source for each date. A date with no year file source is a blocker and is never filled from memory.

---

## 5. PRODUCT CHECKS AT FILING TIME

Moneybird runs five checks when the return is filed. They are unprocessed bank transactions, incoming documents on `Nieuw`, duplicate attachments, a category posting without a VAT line and a rate that is not on the return. They are detectors, not certification. A product check never blocks a filing. A clean product screen is never a passed agent gate.

| Product check | What it catches | Disposition |
|---|---|---|
| Unprocessed bank transactions | A bank transaction that is not booked, so its VAT is not in the return. | Match or disposition each one. An open item stays an exception in P5. |
| Incoming documents on `Nieuw` | A document that does not count in the books or the return yet. | Process or disposition each one. An open item stays an exception in P5. |
| Duplicate attachments | Two documents that share an attachment and risk a double input-VAT claim. | Remove the duplicate link or record the exception. |
| A category posting without a VAT line | Turnover or costs booked straight onto a category carry no VAT, so the amount is absent from the return. | Reclassify or record the exception. |
| Lines on a rate that is not on the return | A rate without a report reference, so its amount reaches no section (rubriek). | Read the rate list and the `Btw-rapport`. A rate without a report reference is a blocker. |

The agent's gate is independent of these product checks and runs the full step list in [preparation.md](preparation.md).

---

## 6. ESCALATION LIST

Escalate these to the Operator or a bookkeeper:

- An unexplained profit-and-loss to return difference.
- A rate used in the period without a report reference.
- A correction above the boundary or outside the correction window.
- A small businesses scheme (kleineondernemersregeling, KOR) case, the ceiling test or the incidental filing duty.
- The ICP deadline, the ICP period or a 3b difference against the ICP detail.
- An OSS or distance-sale case.
- The business-car flat rate (forfait) and its lease scope.
- A private-use, mixed-use or revision allocation.
- A disputed input-VAT deduction.
- Import VAT under the Article 23 permit or a non-EU service case.
- The VAT number (omzetbelastingnummer) or a `betalingskenmerk` mismatch.
- Any open point from [README](README.md#5-open-points) that a step needs.

An escalation is an Operator question with the evidence attached. The pack does not answer it.

---

## 7. RELATED RESOURCES

- [README](README.md) for the boundary and the open points.
- [Preparation](preparation.md) for the step list the gate status refers to.
- [Sections](return-boxes.md) for the section table and the derivation.
- [Year-end and corrections](year-end-and-corrections.md) for the settlements and the correction routing.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) for the guarded reads.
