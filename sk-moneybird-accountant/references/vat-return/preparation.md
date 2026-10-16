---
title: VAT return preparation procedure
description: The ordered procedure to prepare one Dutch VAT period from Moneybird for Operator review. Steps 0 to 12, each with its check, its evidence and its Operator decision point.
nav_label: "VAT return preparation procedure"
trigger_phrases:
  - VAT return procedure
  - btw-aangifte stappen
  - btw-aangifte voorbereiden stappen
  - prepare the VAT period
importance_tier: important
contextType: general
version: 1.0.0.0
---

# VAT return preparation procedure

**Rule:** Run the steps in order. Stop at the first failed check and record it. Every figure, rate, threshold and deadline comes from the year files under `references/tax-rules/`. The agent prepares and never files, submits or pays.

---

## 1. OVERVIEW

Steps 0 to 12 follow the order the research fixes. Each step names its check, the evidence it leaves and its owner. A step with a human decision or action carries `[Operator]`.

Before step 0, resolve the year as `year_key`, load the year README and the year VAT files and read the administration's rate list and VAT overview at run time. The rate-to-section step is in [return-boxes.md](return-boxes.md#4-the-run-time-rate-step).

Reads use moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, following [cli-moneybird](../../../cli-moneybird/SKILL.md). Period unlocking, rate creation and filing stay UI and `[Operator]` actions.

---

## 2. THE STEPS

| Step | Action | Check | Evidence | Owner |
|---|---|---|---|---|
| 0 | Resolve the administration, the legal form, the tax year, the cadence and the period under review. Resolve `year_key` and load the year files. | The period, the year, the cadence and the VAT regime are unambiguous. | The resolved period and `year_key` in the workpaper, with the year file paths read. | Agent. `[Operator]` confirms the cadence when it differs from the usual pattern. |
| 1 | Check the filing order and record the lock state. Verify that no later period was already filed. | No later period blocks this one. The lock state is recorded. A lock is not a legal prerequisite and not a completeness proof. | The filing-order note and the recorded lock state. | Agent records. `[Operator]` authorizes any change that a lock blocks. |
| 2 | Reconcile the bank. Match or disposition every bank transaction in the period. | Every transaction is matched or dispositioned. An open transaction is not booked and leaves its VAT out of the return. | The guarded unprocessed-state read with an explicit period. | Agent. `[Operator]` dispositions a transaction that has no evidence. |
| 3 | Reconcile the documents. | No incoming document stays on `Nieuw` and no attachment hangs on two documents. | The incoming-document list and the attachment link check. | Agent. `[Operator]` dispositions a missing or duplicate document. |
| 4 | Check the rate reach. For every rate used in the period, read the rate list and its report reference. | Every rate used in the period has a report reference, so it reaches a section (rubriek). The check is reach not correctness of the percentage. | The `Btw-tarieven` read and the `Btw-rapport` reference per rate used. | Agent. `[Operator]` dispositions a rate with no reference. |
| 5 | Walk the purchase side for input VAT that may not be deducted. | Private use, catering, exempt-turnover costs and mixed-use private shares are excluded or corrected. | The purchase-side list with each exclusion or correction named and its source. | Agent prepares. `[Operator]` or a bookkeeper decides a disputed allocation. |
| 6 | Check the reverse-charge completeness. | Every foreign purchase sits on the right rate for its case, prints `btw verlegd` and the buyer's own VAT ID where reverse charge applies, falls in the correct period and, for a small businesses scheme (KOR) business, is checked against the incidental filing duty. | The foreign-purchase list with its rate, its invoice text and its period. | Agent. `[Operator]` or a bookkeeper decides a doubtful case. |
| 7 | Classify the sales. Place every sales line in 1a, 1b, 1c, 1e, 3a, 3b or 3c. Rubriek 1d is the private-use charge, not a sale. A domestic reverse-charged sale belongs in 1e. | Every sales line is placed. The 3b total ties to the per-customer ICP detail. Consumer distance sales stay separate from B2B. OSS use is tested before a line is placed. | The sales classification list and the ICP detail tie. | Agent. `[Operator]` or a bookkeeper decides a doubtful OSS or distance-sale case. |
| 8 | Build the section (rubriek) table from the period's rate overview. | Each line carries the base and the VAT and names the rate set that feeds it. The table is built from the rate overview, not from the ledger or the profit and loss statement. | The section table with the base, the VAT and the rate set per line. | Agent. |
| 9 | Reconcile the ledger against the return bases and classify every difference. | Every difference is classified into a documented cause. An unexplained difference is a blocker. | The reconciliation sheet with each difference and its cause. | Agent. `[Operator]` or a bookkeeper decides a disputed cause. |
| 10 | Read the detected corrections for the period and split them at the correction boundary. | Each correction is routed. Mark a correction the Dutch Tax and Customs Administration (Belastingdienst) already knows so it is not counted twice. Check whether the affected period was ever filed through Moneybird. | The correction list with the route and the prior-filing note per item. | Agent prepares. `[Operator]` owns the correction route and the supplementary return filing. |
| 11 | Run the arithmetic gate. | 5a equals the sum of sections 1 to 4. 5b equals the deductible input VAT including the VAT declared under 2a, 4a and 4b. A deviation is an arithmetic error. 5c to 5g stay unverified and are not fabricated. | The arithmetic result and the section table it was run over. | Agent. `[Operator]` decides an unresolvable outcome. |
| 12 | Branch for the final VAT period of the calendar year. | The period is checked against the final-period condition before the pack is built. | The branch note that names the settlements run. | Agent prepares. `[Operator]` decides the private-use and revision outcomes. |

The year rules behind steps 4 to 10 are in the year files, for example [VAT 2026 rules](../tax-rules/2026/vat/rules.md). Every rate and threshold is in [VAT 2026 figures](../tax-rules/2026/vat/figures.md). The rates change by year, so read the file for the resolved `year_key`.

---

## 3. FINAL-QUARTER VARIANT

When the period is the final VAT period of a calendar year, run the four settlements `S1` to `S4` in [year-end-and-corrections.md](year-end-and-corrections.md) before the arithmetic gate and the pack. The private-use outcome, the revision, the correction route, the supplementary return (suppletie) filing and the payment stay `[Operator]` decisions.

A final period with no settlement to make still records why each settlement is not applicable.

---

## 4. STOP CONDITIONS

Stop and record the item when any of these remain open:

- An unmatched or undispositioned bank transaction.
- An incoming document on `Nieuw` or a duplicate attachment.
- A rate used in the period without a report reference.
- An unexplained profit-and-loss to return difference.
- A correction above the boundary without the supplementary return (suppletie) route.
- A correction outside the correction window.
- A doubtful reverse-charge, small businesses scheme (KOR), OSS, private-use or revision case.
- An open point from [README.md](README.md#5-open-points) that a step needs.

A stop condition leaves the pack in the open state. The Operator decides the next action.

---

## 5. RELATED RESOURCES

- [README](README.md) for the boundary and the open points.
- [Sections](return-boxes.md) for the section table and the run-time rate step.
- [Year-end and corrections](year-end-and-corrections.md) for the final-quarter settlements.
- [Review pack](review-pack.md) for the output contract.
- [Purchase invoices](../purchase-invoices.md) for the rate and booking cases.
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) for the cadence and the bank reconciliation.
