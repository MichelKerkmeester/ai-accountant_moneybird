---
title: Yearly overview preparation checklist
description: The ordered close checklist for a Dutch sole-trader yearly overview. The auditfile evidence gate comes first, then the close checks, the year-end closing mechanics, the equity-continuity check and the exception list.
trigger_phrases:
  - yearly overview checklist
  - jaarafsluiting checklist
  - auditfile before closing
  - balans opmaken
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Yearly overview preparation checklist

**Rule:** Run the four sections in order. Stop at the first failed check and record it. The auditfile export comes before the jaarafsluiting. Every figure comes from the year files under `references/tax-rules/`. Every amount in this file is a braced placeholder. The Operator performs every closing action. Nothing here files a return.

---

## 1. AUDITFILE FIRST

Export the auditfile for the open year before any closing action, then record its SHA-256 together with the year and the version. The export is the evidence gate for everything below it. An auditfile downloaded after the jaarafsluiting can lack the profit and loss data, because the closing entry contra-books the result accounts.

The migration control carries the same rule at sub-goal SG-10.2 in `references/migration/phases-10-to-16.md`. Read [the Phase 10 to 16 rule](../migration/phases-10-to-16.md) for the migration evidence, the export route and its approval. A migrated historical year consumes that evidence and does not rerun the migration gate.

Check: the export exists for the resolved year and version and its hash is recorded. A missing export is an open step, so the checklist stops here and the jaarafsluiting waits.

`[Operator]` authorizes the export route and confirms the artifact. The guarded export row is in [cli-moneybird](../../../cli-moneybird/SKILL.md). The route fields that stay unverified are in [report and export limits](report-and-export-limits.md).

---

## 2. THE CHECKS

Run the checks in this order. Each check names its evidence, the year file that owns its figures and its Operator point.

| Check | What it proves | Year file |
|---|---|---|
| Resolve the year and the mode | `year_key`, the administration and the migrated or LIVE state are unambiguous. | [Year and state resolution](../tax-rules/year-and-state.md) |
| Capture the commercial reports | The balance at the closing date, the profit and loss account for the year, the kolommenbalans and the journal detail are captured with their dates. | [The year README for the resolved year](../tax-rules/2026/README.md) |
| Resolve the bank and suspense balances | Every te rubriceren item and every unprocessed bank transaction is matched or listed as an exception. | [Bank reconciliation](../moneybird-bookkeeping.md#6-bank-reconciliation) |
| Tie the opening balance | Each prior closing line opens immediately before the Moneybird start period, including the bank and the open receivables and payables. | [Opening balance](../moneybird-bookkeeping.md#5-assets-and-opening-balance) |
| Tie the asset register | The register's cost, prior depreciation and the year's write-off tie to the balance and the profit and loss account. | [Fixed assets](../fixed-assets.md) and [Investeringen 2026 figures](../tax-rules/2026/investments/figures.md) |
| Reconcile VAT | Each filed period matches its period report. Every correction is routed. | [VAT return preparation](../vat-return/README.md) and [BTW 2026 figures](../tax-rules/2026/vat/figures.md) |
| Build the cut-off list | Each prepaid or accrued item names the period it belongs to and the treatment, consistent with the prior policy. | [Year attribution in year and state resolution](../tax-rules/year-and-state.md#2-year-resolution) |
| Assemble the pack | Every part is present. Every exception has an owner and a status. Every figure names the year file it came from. | [Fiscal reconciliation](fiscal-reconciliation.md) and [year and state resolution](../tax-rules/year-and-state.md) |

### Year-end closing mechanics

The closing mechanics are prepared here with their evidence and performed by the Operator in the Moneybird UI. This is the third booking cluster the yearly procedure owns.

1. Prepare the closing entry that zeroes the profit and loss accounts against the owner equity, with the evidence for each line. `[Operator + AI]`
2. Count the inventory and record the closing inventory value with its source. `[Operator + AI]`
3. Reverse the cut-off items that were accrued in the prior year and record the accrual for the open year. `[Operator + AI]`
4. Check the private-movement lines against the owner-equity table in [Moneybird bookkeeping](../moneybird-bookkeeping.md#private-withdrawals-and-deposits-in-the-accounts) before the closing entry. `[Operator + AI]`
5. Set the period lock only when every check is green and the Operator directs it. `[Operator]`

Check: after the closing, the open-year result category is gone from the balance and the contra-booking has zeroed the result accounts. The lock date is recorded with its direction.

---

## 3. EQUITY CONTINUITY

The equity check is arithmetic. Prepare it from the year's own data. Let the Operator confirm every judgement line.

Opening equity + the result for the year - private withdrawals + private deposits = closing equity

Worked example with braced placeholders:

| Line | Placeholder |
|---|---|
| Opening equity | `{opening_equity}` |
| Result for the year | `{result}` |
| Private withdrawals | `{private_withdrawals}` |
| Private deposits | `{private_deposits}` |
| Closing equity | `{closing_equity}` |

Check: `{opening_equity}` + `{result}` - `{private_withdrawals}` + `{private_deposits}` equals `{closing_equity}`. The result on that line equals the profit and loss result before the closing zeroes it. Every difference is an exception, never an unexplained balancing entry.

The result, the ondernemersaftrek and the profit exemption are year values. Read them from the resolved year folder, for example [Ondernemersaftrek 2026 figures](../tax-rules/2026/business-deductions/figures.md) and [the 2026 year README](../tax-rules/2026/README.md). The rule that decides the year a cost or revenue belongs to is the sourced sentence in [year and state resolution](../tax-rules/year-and-state.md).

`[Operator]` decides the value of an onttrekking and the private-use treatment.

---

## 4. EXCEPTION LIST

Every difference, missing document, unclear year and failed check becomes one row here. A row names the item, the placeholder `{amount}`, the evidence, the owner and the status. An exception is never closed by a balancing entry and never by a guess.

| Exception | Amount | Evidence | Owner | Status |
|---|---|---|---|---|
| `{exception_item}` | `{amount}` | `{evidence}` | `{owner}` | open or dispositioned |

The Operator or a bookkeeper decides each open row. The pack goes to the Operator only when every row carries a status and every judgement row names its decider.

Check: zero rows without an owner or a status. An open row blocks the hand-off.
