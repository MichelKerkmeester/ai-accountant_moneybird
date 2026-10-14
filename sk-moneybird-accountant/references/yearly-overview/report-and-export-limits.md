---
title: Report and export limits for the yearly overview
description: The guarded report rows, the twelve-month window and the auditfile export order this procedure depends on, with every item not confirmed against pinned CLI help marked UNVERIFIED and the check that would settle it.
nav_label: "Report and export limits for the yearly overview"
trigger_phrases:
  - report and export limits
  - twelve-month window
  - auditfile export order
  - guarded report rows
importance_tier: normal
contextType: general
version: 1.0.0.0
---

# Report and export limits for the yearly overview

**Rule:** This file records what the procedure may read and export. It records what stays `UNVERIFIED` until pinned CLI help and a dry run confirm it. A row marked `UNVERIFIED` is never a computation basis. Every report read runs under the Read Step Contract in [cli-moneybird](../../../cli-moneybird/SKILL.md).

---

## 1. THE REPORT ROWS

These rows come from the reports row and the auditfile export row in [cli-moneybird](../../../cli-moneybird/SKILL.md) section 2.

| Report row | What it returns for the close | Limit | Status |
|---|---|---|---|
| `profit_loss` | The profit and loss account for the year. | One request covers at most the twelve-month window. | The action is named in the CLI skill. The date argument names are `UNVERIFIED`. |
| `balance_sheet` | The balance at the closing date. | The same twelve-month window per request. | The action is named in the CLI skill. The date argument names are `UNVERIFIED`. |
| `general_ledger` | The ledger detail per account and period. | The same window. | The action is named in the CLI skill. The date argument names are `UNVERIFIED`. |
| `journal_entries` | The journal detail for the year. | The same window. | The action name is `UNVERIFIED` until pinned CLI help names it. |
| `tax` | The tax report the close reconciles. | The same window. | The action name is `UNVERIFIED` until pinned CLI help names it. |
| `reports export auditfile` | The auditfile for the open year and version. | Export before the jaarafsluiting. | The flags and the downloads route are `UNVERIFIED`. |

The twelve-month window is the read boundary. A request covers at most twelve months. A longer period splits into parts that each record their period and count and reconcile to the whole. The year of a close is one twelve-month window, so the close reads it in one part unless the administration's own book year differs.

The guarded reads are listed in [cli-moneybird](../../../cli-moneybird/SKILL.md) section 2. A report row that the pinned CLI help does not confirm stays on this page and never becomes a step.

---

## 2. THE AUDITFILE EXPORT ORDER

The auditfile export comes first, before the closing entry and before the period lock. An auditfile downloaded after the jaarafsluiting can lack the profit and loss data, because the closing entry contra-books the result accounts. The migration rule at sub-goal SG-10.2 in `references/migration/phases-10-to-16.md` carries the same order. Read [the Phase 10 to 16 rule](../migration/phases-10-to-16.md). Once the year is closed, a later export does not repair a missing first export.

The export runs through the guarded writer session with the approval the migration plan names. The route flags and the downloads step stay `UNVERIFIED` until pinned CLI help and a dry run confirm them.

---

## 3. THE UNVERIFIED LIST

Every row below names what would settle it. No later run builds a computation on a row that stays open.

| Item | Status | What would settle it |
|---|---|---|
| The date argument names of the `profit_loss` and `balance_sheet` report rows | `UNVERIFIED` | Pinned CLI help for the reports action plus a dry run on a read-only administration. |
| The date argument names of the `general_ledger` report row | `UNVERIFIED` | Pinned CLI help for the reports action plus a dry run. |
| The action name and the date arguments of the `journal_entries` and `tax` rows | `UNVERIFIED` | Pinned CLI help for the reports action. |
| The flags of the auditfile export and the downloads route that fetches it | `UNVERIFIED` | Pinned CLI help for the export and downloads actions plus a dry run. |
| The body field names of a general journal document | `UNVERIFIED` | Pinned CLI help for the general journal document action. |

---

## 4. YEAR FILE STATUS

A figure that the year file marks `UNVERIFIED`, `proposed` or `unknown` is not a computation basis. The status tags and the refusal rule are in [year and state resolution](../tax-rules/year-and-state.md) section 3. A deadline or a procedure value for the resolved year comes from [Procedure 2026 figures](../tax-rules/2026/procedure/figures.md).
