---
title: Yearly overview preparation
description: Entry index for preparing a Dutch sole-trader yearly overview in Moneybird. The folder holds the ordered close steps, the preparation checklist, the fiscal reconciliation and the report and export limits. It prepares and never files.
trigger_phrases:
  - yearly overview preparation
  - prepare the yearly overview
  - yearly-overview folder
  - jaaroverzicht pack
  - annual accounts
version: 1.0.0.0
---

# Yearly overview (jaaroverzicht) preparation

## 1. OVERVIEW

Entry index for preparing a Dutch sole-trader yearly overview (jaaroverzicht) in Moneybird. The folder holds the ordered close steps, the preparation checklist, the fiscal reconciliation and the report and export limits. It prepares and never files.

The T11 task-type row routes a prepare-the-yearly-overview request into `references/yearly-overview/`. The agent assembles the balance sheet (balans), the profit and loss account (winst- en verliesrekening), the schedules, the fiscal reconciliation and the hand-off, names every exception and stops before the year-end closing (jaarafsluiting). The Operator checks the pack, confirms the judgement points, performs the closing actions in the Moneybird UI and files in the Dutch Tax and Customs Administration (Belastingdienst) portal.

---

## 2. HOW IT WORKS

### The ordered close and the auditfile gate

The README holds the ordered steps and the eleven Dutch close signals. The auditfile export stands before the year-end closing (jaarafsluiting) as an evidence gate, followed by the close checks, the equity-continuity check and the exception list. The T11 row reads the procedure README, the costs-and-car figures and the investments figures of the tax year as its required set and declares no conditional read. For an ordinary LIVE year the Operator runs the export in the Moneybird UI and the AI only checks the artifact and records its year, version and SHA-256. A migrated year inside phases 10 to 16 keeps its SG-10.2 route and a year inside phases 19 to 21 keeps its journal-backed route.

### The pack, the template and the boundary

The fiscal reconciliation file holds the reconciliation template, the three-column hand-off template and the prepared-not-filed stop. The printable A4 layout is `assets/yearly-overview/yearly-overview-template.html`, a self-contained bilingual template with a braced placeholder for every value and a closing statement that the overview is prepared and not filed. Every amount in a template is a braced placeholder. The yearly-overview-template suite fills the template with synthetic values and proves the closed token list, the repeat expansion, the escaping, the no-remote-asset rule and the prepared-not-filed line. The folder prepares and never files, submits or pays, and an explicit file, submit, pay or lock request leaves T11 for the T8 refusal.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/yearly-overview/README.md` | Shared | Entry index, the ordered steps, the close signals, the boundary and the figure link rule. |
| `sk-moneybird-accountant/references/yearly-overview/preparation-checklist.md` | Shared | The auditfile-first evidence gate with the Operator UI export, the close checks, the equity continuity and the exception list. |
| `sk-moneybird-accountant/references/yearly-overview/fiscal-reconciliation.md` | Shared | The fiscal reconciliation template, the three-column hand-off template and the prepared-not-filed stop. |
| `sk-moneybird-accountant/references/yearly-overview/report-and-export-limits.md` | Shared | The report rows, the twelve-month window, the mode-scoped auditfile export order and the unverified items. |
| `sk-moneybird-accountant/assets/yearly-overview/yearly-overview-template.html` | Asset | The printable A4 layout with bilingual labels, braced placeholders and no script or remote asset. |
| `sk-moneybird-accountant/SKILL.md` | Shared | Holds the T11 row that routes a prepare-the-yearly-overview request into this folder. |
| `sk-moneybird-accountant/references/tax-rules/{year}/README.md` | Shared | The required year read before any year figure is used. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/manual-testing-playbook/offline-routing/yearly-overview-pack.md` | Manual playbook | Scenario PACK-001 with gold row PACK-YEARLY-01 and eval case yearly-overview-pack, including the auditfile-before-year-end-closing (jaarafsluiting) order, the Operator UI export and the phase 19 to 21 twin. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | The PACK-YEARLY-01 row with its covers tag and token ceiling. |
| `sk-moneybird-accountant/evals/evals.json` | Fixture | The yearly-overview-pack case, the LIVE UI export case with its forbidden writer patterns and the phase 19 to 21 twin case. |
| `sk-moneybird-accountant/scripts/yearly-overview-template-fill.py` | Script | Fills the template from its declared token list, expands the repeat blocks and checks the closed list, the escaping, the remote assets and the prepared-not-filed line. |
| `sk-moneybird-accountant/scripts/yearly-overview-template-test.sh` | Automated test | Runs the fill on the real template and on five mutants: a broken repeat marker, a remote asset, a missing prepared-not-filed line, an undeclared token and a declared token the body never uses. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | The pass case for the pack row. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/yearly-overview-preparation.md

Related references:
- [task-type-routing.md](task-type-routing.md) - The T11 row, its signals and its read set.
- [fixed-asset-booking.md](fixed-asset-booking.md) - The asset and depreciation route the close reads.
- [operator-tax-boundary.md](operator-tax-boundary.md) - The filing boundary the pack stops at.
