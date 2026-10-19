---
title: Glossary router
description: Holds every English and Dutch term pair in one file per topic behind a router README, and lets a route read the glossary of the topics it loads when a request asks what a Dutch term means.
trigger_phrases:
  - glossary router
  - topic glossary
  - glossary folder
  - dutch term meaning
version: 1.0.0.0
---

# Glossary router (references/glossary/)

## 1. OVERVIEW

Holds every English and Dutch term pair in one file per topic behind a router README, and lets a route read the glossary of the topics it loads when a request asks what a Dutch term means.

`references/glossary/README.md` lists 16 category files: one per tax-rules topic, `bookkeeping.md` for the Moneybird, migration and preparation docs, `general.md`, `official-names.md` and `abbreviations.md`. Each file keeps the English, Dutch and note table, and each pair lives in exactly one file.

---

## 2. HOW IT WORKS

### Where a term goes

A term with the note `official name` or `abbreviation` goes to its own file. Any other term goes to the topic that holds at least half of its uses in the references, counted on the Dutch term over every year, else to `general.md`. A file outside the tax-rules folder counts for `bookkeeping.md`, except the VAT return (btw-aangifte) files, which count for `vat.md`.

### The route rule

The accountant `ROUTER.md` states one rule: a request that asks what a Dutch term means or its English name also reads the router, the glossary file of the term and the glossary file of each topic its route reads. The resolver spots a term request through fixed English and Dutch question frames, such as "what does T mean", "T in English" and "wat betekent T", and takes the longest glossary term the frame holds. A comma, semicolon or colon ends the term, and in an "in English" frame the term must fill the clause, so "Summarize my inkoopfactuur in English" asks no meaning. It adds the router and every file holding that term, then the file of each topic read: a `tax-rules/<year>/<topic>/` file or a general file of that topic maps to its topic file, a VAT return (btw-aangifte) file maps to `vat.md`, any other tax-rules file maps to `general.md` and any other reference maps to `bookkeeping.md`. A general topic file that covers two topics maps to both. A term request that abstains, or waits on a missing tax year, still reads the router and the term's files. A refusal (T8) reads none, and a CLI action (T7) adds to the task row it joins, so the term request follows that row. A request that asks no meaning reads no glossary file, so every route that answers a task stays as it was.

### The checks

`check-english-first.py` reads every category file and reports a pair that two rows hold as `duplicate`. `check-route-table.py` fails when the accountant `ROUTER.md` drops the rule, when a topic folder has no glossary file or when the router does not link a category file.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/glossary/README.md` | Shared | Lists the category files and the placement rule. |
| `sk-moneybird-accountant/references/glossary/` | Shared | Holds one term table per category. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay.py` | Script | Adds the glossary reads on a term request. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | States the glossary read rule next to the read budget ladder. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | Seventeen GLOSS rows. GLOSS-001, GLOSS-002 and GLOSS-006 with their Dutch twins prove the reads on a topic route, a bookkeeping route and an abstained request, GLOSS-007 an abbreviation, GLOSS-008 a two-topic general file, GLOSS-010 a request waiting on the tax year, GLOSS-012 a comma after the term, GLOSS-013 a term in two files and GLOSS-014 a CLI action. GLOSS-003, GLOSS-004, GLOSS-005, GLOSS-009 and GLOSS-011 prove that a plain request, "answer in English", "wat betekent dit", a refusal and a task that ends on "in English" read none. |
| `sk-moneybird-accountant/scripts/check-route-table.py` | Test harness | Fails on a missing rule, glossary file or router link. |
| `sk-moneybird-accountant/scripts/route-table-test.sh` | Automated test | Proves each of the three glossary failures. |
| `sk-moneybird-accountant/scripts/check-english-first-test.sh` | Automated test | Proves the folder read, the router exclusion and the duplicate rule. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/glossary-router.md

Related references:
- [../quality-gates/english-first-check.md](../quality-gates/english-first-check.md) - The check that reads the glossary folder.
- [../bookkeeping-and-migration/task-type-routing.md](../bookkeeping-and-migration/task-type-routing.md) - The route table the rule extends.
