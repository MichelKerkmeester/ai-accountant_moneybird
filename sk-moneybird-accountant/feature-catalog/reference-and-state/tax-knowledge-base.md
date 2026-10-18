---
title: Tax knowledge base
description: Holds the Dutch tax knowledge base tree with the eight year folders, the general topic files and the five cross-year files, and routes a figure question through the year index.
trigger_phrases:
  - tax knowledge base
  - tax-rules tree
  - tax year folders
  - dutch-tax-rules.md
  - tax-rules README
version: 1.0.0.0
---

# Tax knowledge base

## 1. OVERVIEW

Holds the Dutch tax knowledge base tree with the eight year folders, the general topic files and the five cross-year files, and routes a figure question through the year index.

The tree sits at `references/tax-rules/`. Every figure lives in one topic file of one year folder. The five cross-year files hold the rules and the sources that span the years. The folder README is the index a reader opens first.

---

## 2. HOW IT WORKS

### The year folders and the four part files

Eight year folders cover 2020 to 2027. Each year folder holds twelve topic folders, a year README with its topic table, a correction log and the year change note. Every topic folder holds `figures.md`, `rules.md`, `examples.md` and `notes.md`. A figure question resolves the year first, then reads the year README and the one part the README names, starting at the KEY FIGURES section.

### The general files and the cross-year files

The general topics of the entry guide sit as one file per topic under `general/`. A cross-year rule question reads section 3 of `dutch-tax-rules.md` and then only the one general file its table names. The five cross-year files are the entry guide, the year changes overview, the year rollover runbook, the year and state resolver and the source library. The source library mirrors every cited URL to `assets/source-library.json`.

### The checks around the tree

`check-fragments.py` resolves every relative link and fragment into and inside the tree. The year and state resolver fixes the year and the state of a value before any figure is used, and an unsettled value is refused rather than answered.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/tax-rules/README.md` | Shared | The tree index with the eight year folder rows and the five cross-year file rows. |
| `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md` | Shared | The general rules, the settled conflicts and the pointer table to the general topic files. |
| `sk-moneybird-accountant/references/tax-rules/year-and-state.md` | Shared | Fixes the tax year and the state of a value before it is used. |
| `sk-moneybird-accountant/references/tax-rules/year-changes.md` | Shared | The generated overview of every year change note, newest first. |
| `sk-moneybird-accountant/references/tax-rules/year-rollover.md` | Shared | The yearly rollover runbook, the release calendar and the carry-forward authoring rule. |
| `sk-moneybird-accountant/references/tax-rules/source-library.md` | Shared | Every cited official source with its access result, mirrored to `assets/source-library.json`. |
| `sk-moneybird-accountant/references/tax-rules/general/` | Shared | The 13 general topic files one cross-year question is routed through. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-fragments.py` | Test harness | Resolves every relative link and fragment into and inside the tree. |
| `sk-moneybird-accountant/manual-testing-playbook/offline-routing/current-year-zzp-question.md` | Manual playbook | Routes a current-year figure question through the year README and one topic part offline. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the fragment check on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/tax-knowledge-base.md

Related references:
- [year-rollover-runbook.md](year-rollover-runbook.md) - The runbook that carries the tree into the next tax year.
- [reference-entry-surfaces.md](reference-entry-surfaces.md) - The generated entry surfaces that make the tree cheap to open.
