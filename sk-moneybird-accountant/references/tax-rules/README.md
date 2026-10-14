---
title: "Tax rules reference index"
description: "Index of the Dutch tax knowledge base for a ZZP sole trader who may also own a BV: the eight tax year folders with their topic counts and the five cross-year files."
trigger_phrases:
  - "tax rules index"
  - "tax year folders"
  - "dutch tax knowledge base"
importance_tier: important
contextType: research
version: 1.0.0.0
checked_on: "2026-10-14"
---

# Tax rules reference index

> Index of the Dutch tax knowledge base for a ZZP sole trader who may also own a BV: the eight tax year folders with their topic counts and the five cross-year files.

**Rule:** Every figure lives in one topic file of one year folder, and the five cross-year files hold the rules and the sources that span the years. This is not tax advice, and the Operator or a bookkeeper decides any personal case.

---

## 1. OVERVIEW

The tax knowledge base sits in eight year folders, 2020 to 2027, and five cross-year files at this level. A figure question resolves the year first, then loads the year README and the one topic file it names. A cross-year rule question reads the guide, [dutch-tax-rules.md](dutch-tax-rules.md). The [routing signals](../routing-signals.md) file maps a request to its task type, and [year-and-state.md](year-and-state.md) fixes the year and the state of a value before it is used.

---

## 2. YEAR FOLDERS

Every year folder holds twelve topic files, a README with its topic table, a correction log and the year change note.

| Year | Topics | Folder | Year README |
|---:|---:|---|---|
| 2020 | 12 | `2020/` | [Tax year 2020](2020/README.md) |
| 2021 | 12 | `2021/` | [Tax year 2021](2021/README.md) |
| 2022 | 12 | `2022/` | [Tax year 2022](2022/README.md) |
| 2023 | 12 | `2023/` | [Tax year 2023](2023/README.md) |
| 2024 | 12 | `2024/` | [Tax year 2024](2024/README.md) |
| 2025 | 12 | `2025/` | [Tax year 2025](2025/README.md) |
| 2026 | 12 | `2026/` | [Tax year 2026](2026/README.md) |
| 2027 | 12 | `2027/` | [Tax year 2027](2027/README.md) |

Each topic file carries its KEY FIGURES table, the rule text, the worked examples, the changes from the year before, the notes for the books and the open points. The year README names the twelve topic files.

---

## 3. CROSS-YEAR FILES

| File | Purpose |
|---|---|
| [Dutch tax rules](dutch-tax-rules.md) | The general rules, the settled conflicts and the generated section 3 value rows that name their owning file, year, Status and Check. |
| [Year changes](year-changes.md) | The generated overview of every year change note, newest first, with the path link to each note. |
| [Year rollover](year-rollover.md) | The yearly rollover runbook and its checkpoint table. |
| [Year and state](year-and-state.md) | How the session resolves the tax year and the state of a value before it is used. |
| [Source library](source-library.md) | Every cited official source, one row per URL, mirrored to `assets/source-library.json`. |

---

## 4. HOW TO READ

1. Resolve the year and the value state from [year-and-state.md](year-and-state.md) before any figure is used.
2. For one year, read its year README and then the one topic file the README names, starting at its KEY FIGURES section.
3. For a rule across years, read section 3 of [dutch-tax-rules.md](dutch-tax-rules.md#3-general-rules), then only the one file under `general/` its table names.
4. For the official text behind a figure, read [source-library.md](source-library.md).
