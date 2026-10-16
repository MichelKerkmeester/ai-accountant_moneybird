---
title: Fiscal reconciliation for the yearly overview
description: The fiscal reconciliation template from the commercial result to the taxable profit, the three-column hand-off template and the explicit prepared-not-filed stop. Every amount cell is a braced placeholder.
nav_label: "Fiscal reconciliation for the yearly overview"
trigger_phrases:
  - fiscal reconciliation
  - aansluiting commercieel fiscaal
  - three-column hand-off
  - prepared not filed
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Fiscal reconciliation for the yearly overview

**Rule:** Prepare the reconciliation and the hand-off for Operator review. Every amount cell is a braced placeholder. Every rate, threshold and eligibility rule is read from the year file that owns it. The agent prepares and never files.

## 1. OVERVIEW

This reference holds the fiscal reconciliation template, the three-column hand-off template and the prepared-not-filed stop. The agent prepares the pack for Operator review and never files a return.

---

## 2. THE FISCAL RECONCILIATION TEMPLATE

| Line | Item | Amount | Source |
|---|---|---|---|
| 1 | Commercial result before the closing entry | `{commercial_result}` | The profit and loss account for the year |
| 2 | Fiscal adjustments, added or removed | `{fiscal_adjustments}` | [Fixed assets](../fixed-assets.md) and the year files |
| 3 | Remove the exempt profit components (vrijgestelde winstbestanddelen) | `{exempt_profit_components}` | [The year README](../tax-rules/2026/README.md) |
| 4 | Profits from business activities (winst uit onderneming) after line 3 | `{business_profit}` | Sum of lines 1 to 3 |
| 5 | Remove the entrepreneur's allowance (ondernemersaftrek) | `{ondernemersaftrek}` | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| 6 | Profit after the entrepreneur's allowance | `{profit_after_aftrek}` | Line 4 minus line 5 |
| 7 | SME profit exemption (MKB-winstvrijstelling) at `{mkb_rate}` on line 6 | `{mkb_exemption}` | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| 8 | Taxable profit from business (belastbare winst uit onderneming) | `{taxable_profit}` | Line 6 minus line 7 |

The order matters. Remove the exempt profit components first, subtract the entrepreneur's allowance, then apply the SME profit exemption to the profit after that deduction. Every rate and threshold comes from the resolved year folder, for example [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md).

`[Operator]` or a bookkeeper decides the entrepreneurship, the hours criterion (urencriterium), the starter history and the deduction eligibility. The pack records each decision with its evidence.

---

## 3. THE THREE-COLUMN HAND-OFF TEMPLATE

Split the pack into the three columns below. The first column is what the administration supplies. The second is what extra evidence can support. The third is what the administration never holds.

| Administration supplies | Administration plus evidence | Never in the administration |
|---|---|---|
| The balance at the closing date `{balance}` | The hours criterion log `{hours_log}` | Private deductions such as mortgage interest (hypotheekrente) `{private_deduction}` |
| The profit and loss account `{profit_and_loss}` | The starter history `{starter_history}` | Private income `{private_income}` |
| The ledger detail `{ledger_detail}` | The state pension (AOW) status `{aow_status}` | Fiscal partnership facts `{partnership_facts}` |
| The asset and depreciation schedule `{asset_schedule}` | The investment amounts with the RVO registrations `{investment_amount}` | The final eligibility judgement `{eligibility_judgement}` |
| The VAT position and the filed returns `{vat_position}` | The private-use shares `{private_use_share}` |  |
| The auditfile reference `{auditfile_reference}` | The accruals and deferrals (transitoria) and the supplementary return (suppletie) corrections `{transitoria}` |  |

The third column is the boundary of the pack. An item there is a note for the Operator or the bookkeeper and never a computed figure from the administration.

---

## 4. PREPARED, NOT FILED

The agent prepared the yearly overview and did not file anything. The pack stops at the three-column hand-off. The Operator checks the balance and the result, confirms every judgement row, performs the closing and locking actions in the Moneybird UI and files the income-tax return in the Dutch Tax and Customs Administration (Belastingdienst) portal. Payment of any assessment is a separate Operator action.

Nothing in this folder states that a return was filed, an assessment exists or a payment was made. The next step after the pack is always an Operator action.
