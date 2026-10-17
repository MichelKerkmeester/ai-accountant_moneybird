---
title: English first check
description: Checks that the skill family writes English first and reports every Dutch term without an English lead, every first use without its Dutch label and every label no glossary row names.
trigger_phrases:
  - english first check
  - check-english-first.py
  - dutch label check
  - glossary label check
  - english-first-exceptions.json
version: 1.0.0.0
---

# English first check (check-english-first.py)

## 1. OVERVIEW

Checks that the skill family writes English first and reports every Dutch term without an English lead, every first use without its Dutch label and every label no glossary row names.

A Dutch term reads as the English name with the Dutch in brackets at its first use in a section, for example "supplementary assessment (naheffingsaanslag)". Official names of laws, agencies and handbooks carry the Dutch name once per file. Dutch stays as it is where it is data: routing signal cells, test prompts, quoted official text, form and box names, legal citations and source titles.

---

## 2. HOW IT WORKS

### The rules

`check-english-first.py` reads every category file in `references/glossary/`, leaving out its router README, and builds one index of English and Dutch terms. It reports six problem kinds. A `residual` is a Dutch glossary term that stands without an English lead. A `first-use` is an English term whose first use in an H2 section drops its Dutch label. A `doubled` label repeats its own text and a `reversed` pair puts the Dutch first. An `unglossed` label is a bracketed Dutch span that no glossary row names and a `duplicate` is a term pair that two glossary rows hold, compared without case. A full stop or other punctuation mark ends a term, so "deductible. Costs" never reads as "deductible costs".

### The masks and the exceptions

Before the rules run the checker blanks the places where Dutch is data: frontmatter, code fences, inline code, generated blocks, HTML comments, links, quotes, legal citations, Source and Title columns, VAT return box (rubriek) codes and every playbook `Prompt:` line, `Real user request:` line and Exact Prompt cell. A term the rules must keep goes in `assets/english-first-exceptions.json` with its file, the check it suppresses, an E1, E2 or E3 rule and a reason. A row that suppresses nothing is reported as `stale-exception`.

### The output and the CI route

The run prints one sorted line per problem as path, line, rule and term, then the count line, for example `0 problems`. `--summary` prints one count per rule instead. It exits 0 on a clean corpus, 1 when a problem remains and 2 on a usage error, and it makes no network call. The skill health workflow runs `check-english-first-test.sh`, which ends with the real corpus, so a new unlabelled term fails the job.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-english-first.py` | Script | Masks the data regions, applies the six rules and the exceptions and prints the sorted problem lines. |
| `sk-moneybird-accountant/references/glossary/` | Shared | Holds the English and Dutch term pairs the rules read, one file per category behind a router README. |
| `sk-moneybird-accountant/assets/english-first-exceptions.json` | Shared | Lists each kept Dutch term with its file, check, rule and reason. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-english-first-test.sh` | Automated test | Proves each rule on a bad and a fixed fixture, every mask, the exceptions file, byte stability and the summary, then runs the checker on the real corpus. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the suite as the `Suite check-english-first` step on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/english-first-check.md

Related references:
- [outline-check.md](outline-check.md) - The sibling wording check over the year and general topic files.
- [fragment-link-check.md](fragment-link-check.md) - The structural check that keeps relabelled headings linkable.
- [repository-ci-gates.md](repository-ci-gates.md) - The CI workflows that run the suite.
