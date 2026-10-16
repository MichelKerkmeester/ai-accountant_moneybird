---
title: Income tax return preparation
description: Entry index for preparing a Dutch sole-trader income tax return from Moneybird. The folder holds the ordered procedure, the Operator input checklist, the investment and claim register and the residual open points. It prepares and never files, submits or pays.
nav_label: "Income tax return preparation"
trigger_phrases:
  - income tax return
  - prepare the income tax return
  - aangifte inkomstenbelasting
  - IB-aangifte
  - income tax return review
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Income tax return preparation

**Rule:** This folder prepares one income tax return for Operator review. It never files, submits or pays. Every figure, rate, threshold and deadline lives in the year files under `references/tax-rules/`. Nothing here is tax advice.

---

## 1. OVERVIEW

The agent assembles the return pack for one year, names every Operator input, every evidence item and every open point, and stops before filing. The Operator reviews and confirms the pack and files the return in the Dutch Tax and Customs Administration (Belastingdienst) portal.

The mode is LIVE. Resolve the year as `year_key = return_coverage` with [year and state resolution](../tax-rules/year-and-state.md), then load the year README and the topic figures and rules files the procedure names. Read the administration's own data at run time with moneybird-guard under `MONEYBIRD_GUARD_READ_ONLY=1`, following [cli-moneybird](../../../cli-moneybird/SKILL.md). Filing, payment and the period lock stay Operator-only.

The route that reaches this folder is T12 in [SKILL.md](../../SKILL.md). The folder links the year figures and never copies one.

---

## 2. THE FIVE FILES

| File | What it holds |
|---|---|
| `README.md` | This entry index, the boundary, the figure link rule and the shared disposition vocabulary. |
| [procedure.md](procedure.md) | The ordered cross-year procedure, the source map, the evidence gates, the review pack differences, the stop rules and the residual risk list. |
| [operator-inputs.md](operator-inputs.md) | The official private-part input list and the Operator evidence checklist, one disposition per item. |
| [investment-and-claim-register.md](investment-and-claim-register.md) | The dated per-asset register that evidences an investment allowance claim. |
| [risks-and-open-points.md](risks-and-open-points.md) | The residual unknowns, each labelled unresolved with what would settle it. |

---

## 3. BOUNDARY

- The folder prepares. The Operator reviews and confirms the pack. Filing and payment stay Operator-only.
- The agent may organize, reconcile and explain. It never files, submits, pays, locks a period or chooses a fiscal position.
- Every judgement call is an Operator or bookkeeper question with the evidence attached. The pack records the question, it never answers it.
- Every amount in the pack comes from the administration or from Operator evidence. An absence in the administration is never proof of a nil value.

---

## 4. FIGURE LINK RULE

Every figure path is a link to the year file that holds it, written as `../tax-rules/{year}/income-tax/figures.md` or as a concrete year path such as [Inkomstenbelasting 2026 figures](../tax-rules/2026/income-tax/figures.md). A rate, a threshold, a deadline and a procedure value each point at the year file that owns them, for example [Ondernemersaftrek 2026 figures](../tax-rules/2026/business-deductions/figures.md), [Investeringen 2026 figures](../tax-rules/2026/investments/figures.md) and [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md). The folder never copies a figure.

The year's rules sit beside the figures. Read the rules file beside a figure for the mechanics and the year README for the status tag of each value. A value marked `UNVERIFIED`, `proposed` or `unknown` is not a computation basis.

A figure that no year file owns is a blocker. The procedure stops and names the missing file instead of filling the figure from memory.

---

## 5. SHARED DISPOSITION VOCABULARY

This folder, the VAT return folder and the yearly overview folder share one vocabulary. Every item in [operator-inputs.md](operator-inputs.md) carries exactly one of these dispositions.

| Disposition | Meaning |
|---|---|
| `supplied` | The Operator handed over the item or its evidence. |
| `reconciled` | The agent tied the item to the administration's own reads. |
| `confirmed` | The Operator or a bookkeeper confirmed the value or the judgement. |
| `not applicable` | The item cannot apply to the resolved return. |
| `unresolved` | The item is open and blocks the pack until a named source settles it. |

An item that cannot be settled stays `unresolved` with the evidence that would settle it named. It never becomes a rule and it is never filled from memory.

---

## 6. RELATED RESOURCES

- [Procedure](procedure.md), [operator inputs](operator-inputs.md), [investment and claim register](investment-and-claim-register.md) and [risks and open points](risks-and-open-points.md).
- [VAT return review pack](../vat-return/review-pack.md) for the shared pack shape this folder reuses.
- [Yearly overview preparation checklist](../yearly-overview/preparation-checklist.md) for the auditfile-first evidence gate.
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) for the cadence and the yearly cycle.
- [Fixed assets](../fixed-assets.md) for the asset register and the depreciation schedule.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) for the guarded reads.
