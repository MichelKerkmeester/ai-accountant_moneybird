---
title: Yearly overview preparation
description: Entry index for preparing a Dutch sole-trader yearly overview in Moneybird. The folder holds the ordered close steps, the preparation checklist, the fiscal reconciliation and the report and export limits. It prepares and never files.
trigger_phrases:
  - yearly overview
  - jaaroverzicht
  - jaarrekening
  - jaarafsluiting
  - winst-en-verliesrekening
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Yearly overview preparation

**Rule:** This folder prepares the yearly overview for Operator review. It never files, submits or pays. Every figure, rate, threshold and deadline lives in the year files under `references/tax-rules/`. Nothing here is tax advice.

---

## 1. OVERVIEW

This folder is the procedure for a prepare-the-yearly-overview request. The agent assembles the balance sheet, the profit and loss account, the schedules, the fiscal reconciliation and the hand-off, names every exception and stops before the jaarafsluiting. The Operator checks the pack, confirms the judgement points, performs the closing actions in the Moneybird UI and files in the Belastingdienst portal.

The mode is LIVE. Resolve the year as `year_key` with [year and state resolution](../tax-rules/year-and-state.md), load the year README and the year topic files, then read the administration's own data at run time with moneybird-guard under `MONEYBIRD_GUARD_READ_ONLY=1`, following [cli-moneybird](../../../cli-moneybird/SKILL.md). The jaarafsluiting, the period lock, the tax-rate creation and the filing stay UI and Operator actions.

---

## 2. THE FOUR FILES

| File | What it holds |
|---|---|
| `README.md` | This entry index, the ordered steps, the close-signal list, the boundary and the figure link rule. |
| [preparation-checklist.md](preparation-checklist.md) | The auditfile-first evidence gate, the close checks, the year-end closing mechanics, the equity-continuity check and the exception list. |
| [fiscal-reconciliation.md](fiscal-reconciliation.md) | The fiscal reconciliation template, the three-column hand-off template and the prepared-not-filed stop. |
| [report-and-export-limits.md](report-and-export-limits.md) | The report rows this procedure reads, the twelve-month window, the auditfile export order and the unverified items. |

---

## 3. THE ORDERED STEPS

| Step | Action | Owner |
|---|---|---|
| 1 | Resolve the year, the administration and the mode. | Agent. The Operator confirms a doubtful year. |
| 2 | Export the auditfile before any closing action. | `[Operator + AI]` |
| 3 | Capture the commercial reports for the year. | Agent |
| 4 | Resolve the bank and suspense balances. | Agent. The Operator dispositions an item without evidence. |
| 5 | Tie the opening balance and run the equity-continuity check. | Agent |
| 6 | Tie the asset register and the year's depreciation. | Agent. The Operator or a bookkeeper decides the fiscal classification. |
| 7 | Reconcile each filed VAT period and route each correction. | Agent. The Operator owns the correction route. |
| 8 | Build the cut-off and year-attribution list. | Agent. The Operator or a bookkeeper decides every judgement case. |
| 9 | Draft the fiscal reconciliation. | Agent |
| 10 | Assemble the pack and the exception list. | Agent |
| 11 | Perform the closing entry, the inventory count, the accrual reversal and the period lock. | `[Operator]` |
| 12 | Hand the three-column pack to the Operator and stop before filing. | Agent prepares. `[Operator]` files. |

The full checklist is in [the preparation checklist](preparation-checklist.md). The templates are in [the fiscal reconciliation](fiscal-reconciliation.md).

---

## 4. THE ELEVEN CLOSE SIGNALS AND THE TWO CONDITIONAL READS

This list is authored here. The route table that consumes it belongs to the routing owner, `SKILL.md` and `references/routing-signals.md`, so this folder edits no route row.

The eleven Dutch close signals are:

- `jaaroverzicht`
- `jaarrekening`
- `jaarafsluiting`
- `eindejaar`
- `balans opmaken`
- `winst-en-verliesrekening`
- `overlopende posten`
- `vooruitbetaalde kosten`
- `toerekenen`
- `privé-opnamen`
- `suppletie`

A close request that arrives through this list reads the year file `references/tax-rules/{year}/README.md` and, when an asset, an investment or depreciation is in scope, the fixed-assets reference `references/fixed-assets.md`. The two reads are conditional. The year file is required before any year figure is used. Read the concrete files for the resolved `year_key`, for example [the 2026 year README](../tax-rules/2026/README.md) and [the fixed assets reference](../fixed-assets.md).

---

## 5. BOUNDARY AND FIGURE LINKS

- This folder prepares. It never files, submits or pays. It never states that a return was filed or a payment made.
- Every figure, rate, threshold, euro amount and deadline stays in the year files. A figure that is not read from a year file or from the administration at run time is a blocker.
- Every judgement point carries an `[Operator]` marker. The tax treatment, the value of an onttrekking, the fiscal classification, the lock direction and the filing are Operator decisions.
- A figure link names the file that owns the figure, for example [Kosten en auto 2026 figures](../tax-rules/2026/kosten-en-auto/figures.md) and [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md). The folder never copies a figure.
- The auditfile export stands before the jaarafsluiting. The order and the evidence gate are in [the preparation checklist](preparation-checklist.md#1-auditfile-first).

---

## 6. RELATED RESOURCES

- [Moneybird bookkeeping](../moneybird-bookkeeping.md) for the cadence, the private-movement accounts and the period control.
- [Preparation checklist](preparation-checklist.md), [fiscal reconciliation](fiscal-reconciliation.md) and [report and export limits](report-and-export-limits.md).
- [VAT return preparation](../vat-return/README.md) for the final-period settlements that feed the year-end VAT reconciliation.
- [Fixed assets](../fixed-assets.md) for the asset and depreciation register.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) for the guarded reads.
