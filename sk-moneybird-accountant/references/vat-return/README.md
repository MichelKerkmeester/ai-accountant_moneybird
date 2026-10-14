---
title: VAT return preparation
description: Entry index for preparing a Dutch VAT period from Moneybird. The folder holds the ordered procedure, the rubriek and derivation rules, the year-end branch and the review pack. It prepares and never files, submits or pays.
nav_label: "VAT return preparation"
trigger_phrases:
  - prepare the VAT return
  - btw-aangifte voorbereiden
  - btw-aangifte klaarzetten
  - btw-aangifte controleren
  - quarterly VAT return
importance_tier: important
contextType: general
version: 1.0.0.0
---

# VAT return preparation

**Rule:** This folder prepares one VAT period for Operator review. It never files, submits or pays. Every figure, rate, threshold and deadline lives in the year files under `references/tax-rules/`. Nothing here is tax advice.

---

## 1. OVERVIEW

This folder is the procedure for a prepare-the-VAT-return request. The agent assembles the rubriek table, the checks and the review pack for one period, names every exception and stops before filing. The Operator checks, confirms, files and pays.

The mode is LIVE. Resolve the year as `year_key`, load the year README and the year BTW files, then read the administration's own data at run time with moneybird-guard under `MONEYBIRD_GUARD_READ_ONLY=1`, following [cli-moneybird](../../../cli-moneybird/SKILL.md). Period unlocking, tax-rate creation and filing stay UI and Operator actions. The route that reaches this folder is T10 in [SKILL.md](../../SKILL.md).

---

## 2. THE FIVE FILES

| File | What it holds |
|---|---|
| `README.md` | This entry index, the boundary, the figure link rule and the open points `O1` to `O5`. |
| [preparation.md](preparation.md) | The ordered period procedure, steps 0 to 12, each with its check, its evidence and its Operator point. |
| [return-boxes.md](return-boxes.md) | The rubriek table for 1a to 5b, the derivation map from a booking to a line, the run-time rate step and the reverse-charge, KOR, 3b to ICP and OSS rules. |
| [year-end-and-corrections.md](year-end-and-corrections.md) | The four year-end settlements `S1` to `S4` and the correction and suppletie routing. |
| [review-pack.md](review-pack.md) | The output contract: the pack blocks `P1` to `P9`, the confirmation parts `C1` to `C3`, the deadline and payment block and the escalation list. |

---

## 3. BOUNDARY

- The folder prepares. It never files, submits or pays. It never states that a return was filed or a payment made.
- Every figure, rate, threshold, euro amount and deadline stays in the year files. A figure that is not read from a year file or from the administration at run time is a blocker.
- Every human decision carries an `[Operator]` marker. The cadence confirmation, the period unlock, the tax-rate creation, the correction route, the suppletie filing and the payment are Operator actions.
- The migration Phase 20 exit gate is untouched. The per-step content for a LIVE VAT period is in this folder, as [Phase 20](../migration/phases-19-to-21.md#phase-20-live-vat-period-workflow) states.

---

## 4. FIGURE LINK RULE

Every figure path is a link to the year file that holds it, written as `../tax-rules/{year}/vat/figures.md` or as a concrete year path such as [BTW 2026 figures](../tax-rules/2026/vat/figures.md). A deadline or a correction route points at the year's procedure figures, such as [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md). The folder never copies a figure.

The year's rules sit beside the figures. Read [BTW 2026 rules](../tax-rules/2026/vat/rules.md) for the mechanics and the year README for the status tag of each value. A value marked unverified is not a computation basis.

---

## 5. OPEN POINTS

The five unresolved items. Each one is a missing capability, not a work item for this folder.

| ID | Open point | Missing capability | Rule |
|---|---|---|---|
| O1 | The current labels and semantics of rubrieken 5c to 5g | A current form explanation or the live return screen | Never filled from memory or computed from transaction data. |
| O2 | The statutory ICP filing deadline | A primary source or the Operator's own ICP notice | Never filled from memory or computed from transaction data. |
| O3 | The monthly-filing trigger | A current rule source or an updated Handbook | Never filled from memory or computed from transaction data. |
| O4 | The lease scope of the business-car forfait | An Operator or bookkeeper decision with the contract and the use facts | Never filled from memory or computed from transaction data. |
| O5 | The guarded CLI report date-argument names | Pinned CLI help and a dry run before a live use | Never filled from memory or computed from transaction data. |

The administration's own rate list and VAT overview settle the rate-to-rubriek map at run time, so the folder stores no fixed map.

---

## 6. RELATED RESOURCES

- [Preparation](preparation.md), [rubrieken](return-boxes.md), [year-end and corrections](year-end-and-corrections.md) and [review pack](review-pack.md).
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) for the cadence and the period control.
- [Purchase invoices](../purchase-invoices.md) for the reverse-charge and KOR rate cases.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) for the guarded reads.
