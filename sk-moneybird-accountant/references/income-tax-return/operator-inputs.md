---
title: Income tax return operator inputs
description: The official private-part input list and the Operator evidence checklist for a Dutch sole-trader income tax return. Every item carries one disposition from supplied, reconciled, confirmed, not applicable or unresolved and the evidence that settles it.
nav_label: "Income tax return operator inputs"
trigger_phrases:
  - income tax return operator inputs
  - aangifte inkomstenbelasting gegevens
  - private part input list
  - income tax return evidence checklist
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Income tax return operator inputs

**Rule:** Every item below carries exactly one disposition from the shared vocabulary and names the evidence that settles it. A row without its evidence yet stays `unresolved` and blocks the pack. The agent never fills a private value from the administration, and an absence in the books is never a nil value. Every rule reference is a link into the year files under `references/tax-rules/`.

---

## 1. OVERVIEW

The list has two parts. The official private-part input list holds the items the Dutch Tax and Customs Administration (Belastingdienst) checklist asks the taxpayer for and the pre-filled tax return (vooraf ingevulde aangifte) prefills. The Operator evidence checklist holds the evidence the business side of the return needs, from the auditfile and the guarded reads to the Operator attestations.

The Operator supplies every private value and every judgement fact. The agent prepares the rows, ties the administration-side rows to the guarded reads and records the disposition. The confirmation, the filing and the payment stay Operator-only.

The disposition names what closes the row. `supplied` closes on an Operator hand-over, `reconciled` closes on a tie to the guarded reads, `confirmed` closes on an explicit Operator or bookkeeper confirmation, `not applicable` closes on a recorded decision that the item cannot apply, and `unresolved` stays open until its named page or check settles it.

---

## 2. THE OFFICIAL PRIVATE-PART INPUT LIST

| Input item | Official source or evidence | Disposition | Evidence that settles it |
|---|---|---|---|
| Personal, partner and children details | The official checklist and the pre-filled tax return (vooraf ingevulde aangifte) behind DigiD | `unresolved` | The Operator checks every prefilled detail against the home records and corrects it in the return. |
| Children's bank data | The official checklist and the pre-filled tax return | `unresolved` | The Operator supplies the accounts and their reference date (peildatum) values for the box 3 inventory. |
| Received and paid spousal maintenance (partneralimentatie) | The official checklist and the pre-filled tax return | `unresolved` | The Operator supplies the agreement and the payment records. |
| Box 1 income, wage (loon) and other income | The official checklist, the annual statements (jaaropgaven) and the pre-filled tax return | `unresolved` | The Operator supplies the annual statements and corrects the prefill. |
| Box 3 inventory and reference date | The Operator and the pre-filled tax return | `unresolved` | The Operator supplies the dated inventory at the reference date. |
| Partner data and allocation | The Operator and the pre-filled tax return | `unresolved` | The Operator decides the split and confirms the joint items. |
| Crypto holdings | The Operator and the pre-filled tax return | `unresolved` | The Operator supplies the holdings and their reference date valuation. |
| Home and mortgage interest | The Operator with the WOZ decision (beschikking), the annual mortgage statement (hypotheek jaaropgaaf) and the notary statement | `unresolved` | The Operator supplies the documents that settle the owner-occupied home (eigen woning) figures. |
| Gifts and care costs | The Operator proofs of payment (betalingsbewijzen) | `unresolved` | The Operator supplies the payments and the eligibility facts. |
| Annuity premiums and AOV | The Operator annual statement (jaaropgaaf) and the premium statements | `unresolved` | The Operator supplies the statements. |
| Dividend | The Operator dividend statements | `unresolved` | The Operator supplies the statements. |
| Provisional assessments (voorlopige aanslagen) for income tax and Zvw | The Operator and the Dutch Tax and Customs Administration (Belastingdienst) decisions | `unresolved` | The Operator supplies the decisions so the paid or received amounts settle in the return. |
| DigiD of a child | The official checklist | `not applicable` | The official checklist asks for no DigiD of a child, so this row cannot apply. |

---

## 3. THE OPERATOR EVIDENCE CHECKLIST

| Evidence item | Source or evidence | Disposition | Evidence that settles it |
|---|---|---|---|
| The auditfile for the resolved year and version | The guarded export route before the year-end closing (jaarafsluiting) | `supplied` | The exported artifact with its hash and version. |
| Commercial result and profit and loss categories | Moneybird profit and loss statement (resultatenrekening) with its category reports | `reconciled` | Every total ties to its category and ledger support. |
| Balance and ledger detail | Moneybird balance sheet (balans) and the general ledger cards (grootboekkaarten) | `reconciled` | Opening plus movements equal closing and the asset register ties to the balance. |
| VAT position for the year | Moneybird VAT overview (btw-overzicht) and the filed returns | `reconciled` | Every filed period matches its period report and every correction is routed. |
| Hours criterion (urencriterium) hours log | The Operator hours log and the Moneybird hours (uren) registration | `supplied` | The log with its periods and the work it records. |
| Hours completeness attestation | The Operator | `confirmed` | The Operator attests that the log is complete and that standby is excluded. |
| Entrepreneurship (ondernemerschap) and entrepreneur for income tax purposes (IB-ondernemer) facts | The Operator | `confirmed` | The Operator confirms the facts the status test weighs. |
| Starter history and carry-forward | The Operator prior returns and decisions (beschikkingen) | `supplied` | The returns, the decisions and the years the starter's deduction (startersaftrek) was used. |
| Old-age reserve (oudedagsreserve) opening and movements | The Operator prior return and the annuity evidence | `supplied` | The opening reserve and the movement schedule. |
| R&D declaration (S&O verklaring) | The Operator | `unresolved` | The declaration when R&D work ran, otherwise a recorded decision that the deduction (aftrek) does not apply. |
| Disability benefit (arbeidsongeschiktheidsuitkering) evidence | The Operator decision (beschikking) | `unresolved` | The decision when the benefit (uitkering) ran, otherwise a recorded decision that the deduction does not apply. |
| Cessation (staking) facts | The Operator | `unresolved` | The cessation facts with their evidence, otherwise a recorded decision that no cessation applies. |
| Private-use car, phone and home facts | The Operator | `confirmed` | The Operator confirms the use facts and every mixed-use share. |
| WOZ decision (beschikking) for a building | The Operator | `supplied` | The decision that carries the minimum value (bodemwaarde). |
| Per-asset register and RVO proof | The Operator and [the investment and claim register](investment-and-claim-register.md) | `supplied` | The order, payment and in-use dates and the RVO reference per asset. |
| Opening-balance correction | The Operator or a bookkeeper | `confirmed` | The decision that settles an incomplete opening with a correcting entry (correctieboeking). |
| Prior-year return and assessments | The Operator | `supplied` | The prior return, the assessments and the amounts that settle. |
| VIA comparison sheet | The Operator behind DigiD | `confirmed` | Every prefilled field checked against its source and corrected. |

---

## 4. THE DISPOSITION VOCABULARY

| Disposition | Meaning | What closes the row |
|---|---|---|
| `supplied` | The Operator handed over the item or its evidence. | The hand-over with the document or the fact. |
| `reconciled` | The agent tied the item to the administration's own reads. | The guarded read and the tie to the pack. |
| `confirmed` | The Operator or a bookkeeper confirmed the value or the judgement. | The explicit confirmation with the evidence attached. |
| `not applicable` | The item cannot apply to the resolved return. | A recorded decision that names why it cannot apply. |
| `unresolved` | The item is open and blocks the pack. | The named page, decision or document that settles it. |

A row that cannot be settled stays `unresolved`. It never becomes a rule and it is never filled from memory.

---

## 5. RELATED RESOURCES

- [README](README.md) for the boundary and the shared vocabulary.
- [Procedure](procedure.md) for the step that consumes each row.
- [Investment and claim register](investment-and-claim-register.md) for the per-asset evidence shape.
- [Risks and open points](risks-and-open-points.md) for the items that stay unresolved.
- [The yearly overview preparation checklist](../yearly-overview/preparation-checklist.md) for the auditfile gate.
- [The year README for the resolved year](../tax-rules/2026/README.md) and [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the year resolution.
