---
title: "Reference library"
description: "Generated index of the reference tree: the tax year folders, the tax-rule top-level files and the migration files, with the description each file carries."
trigger_phrases:
  - "reference library"
  - "reference tree index"
importance_tier: important
contextType: reference
version: 1.0.0.0
nav_label: "References"
---

# Reference library

**Rule:** Generated landing page for the reference tree. Every row comes from the frontmatter description of the file it names, so one regeneration picks up a new file or a changed description. A folder README belongs to the folder that owns it, and the task-type table in SKILL.md routes a request to its file.

---

## 1. OVERVIEW

The reference library holds the tax year folders, the tax-rule top-level files and the migration files. Every row names one file and carries the description that file already publishes.

---

## 2. TAX YEAR FOLDERS

the twelve topic files and the headline figures of one tax year

| File | Covers |
|---|---|
| [Tax year 2020](tax-rules/2020/README.md) | Overview of Dutch tax year 2020 for a ZZP sole trader who may also own a BV: the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2021](tax-rules/2021/README.md) | Overview of Dutch tax year 2021 for a sole trader (ZZP) who may also own a private limited company (BV): the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2022](tax-rules/2022/README.md) | Overview of Dutch tax year 2022 for a self-employed sole trader (ZZP) who may also own a private limited company (BV): the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2023](tax-rules/2023/README.md) | Overview of Dutch tax year 2023 for a self-employed sole trader (ZZP) who may also own a private limited company (BV). It lists the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2024](tax-rules/2024/README.md) | Overview of Dutch tax year 2024 for a sole trader (ZZP) who may also own a BV: the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2025](tax-rules/2025/README.md) | Overview of Dutch tax year 2025 for a ZZP sole trader who may also own a BV: the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2026](tax-rules/2026/README.md) | Overview of Dutch tax year 2026 for a self-employed sole trader (ZZP) who may also own a private limited company (BV): the twelve topic files, their headline figures and how many values are open. |
| [Tax year 2027](tax-rules/2027/README.md) | Overview of Dutch tax year 2027 for a self-employed sole trader (ZZP) who may also own a private limited company (BV): the twelve topic files, their headline figures and how many values are open. |

---

## 3. TAX-RULE FILES

the general rules, the year index, the change overview and the source upkeep files

| File | Covers |
|---|---|
| [Tax rules reference index](tax-rules/README.md) | Index of the Dutch tax knowledge base for a sole trader (ZZP) who may also own a BV: the eight tax year folders with their topic counts and the five cross-year files. |
| [Dutch tax rules](tax-rules/dutch-tax-rules.md) | General Dutch tax rules for a sole trader (ZZP) who may also own a BV, 2020 to 2027: how to find the year file, how each topic works across years, the settled and open source conflicts, and the record and invoice duties. |
| [External source library](tax-rules/source-library.md) | Every external source the skill family was built from, grouped by authority, with what each answers and how an AI agent can reach it. |
| [Year and state resolution](tax-rules/year-and-state.md) | How the router resolves the tax year from session-context.json, refuses an out-of-range or unsettled figure, and computes the post-cutover migration state at route time. |
| [Year changes](tax-rules/year-changes.md) | Generated overview of the changes in every tax year, newest first, with the path to each year note. |
| [Year rollover](tax-rules/year-rollover.md) | The 1 January runbook that carries the year corpus into the next tax year, the five-checkpoint release calendar with its check-by dates and the owner of both. |

---

## 4. MIGRATION FILES

the phase files, the mapping and the write contract

| File | Covers |
|---|---|
| [Moneybird migration reference index](migration/README.md) | Execution-order route to all migration phases and shared controls. |
| [Migration control framework](migration/control-framework.md) | Agent roles, risk and verification rules, exception controls, stop recovery, dashboard, and completion. |
| [Jortt to Moneybird concept mapping](migration/jortt-to-moneybird-mapping.md) | Conceptual mapping for Jortt bookkeeping data to Moneybird categories, records, assets, VAT and opening balances. |
| [Migration overview and setup](migration/overview-and-setup.md) | Migration goal, tool boundaries, workspace layout and required configuration. |
| [Migration completion, phase 22](migration/phase-22-completion.md) | One-time completion and Jortt decommission gate. |
| [Migration phases 0 to 2](migration/phases-0-to-2.md) | Safety, source inventory and evidence collection. |
| [Migration phases 10 to 16](migration/phases-10-to-16.md) | Annual checks, continuity, locking and cutover preparation. |
| [Migration phases 17 to 18](migration/phases-17-to-18.md) | Source freeze, archive readiness and the live switch. |
| [Live workflows, phases 19 to 21](migration/phases-19-to-21.md) | Recurring monthly, VAT-period and yearly reviews. |
| [Migration phases 3 to 5](migration/phases-3-to-5.md) | Independent reconstruction, reconciliation and anomaly review. |
| [Migration phases 6 to 9](migration/phases-6-to-9.md) | Mapping, pilot, historical batches and VAT verification. |
| [Migration shared mechanisms and route contract](migration/shared-mechanisms.md) | Shared controls used by every migration phase, with tool and export routes. |
