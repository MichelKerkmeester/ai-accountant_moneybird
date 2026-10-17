---
title: Glossary router
description: Which glossary file holds which Dutch terms, and where a term used in several topics goes.
nav_label: "Glossary router"
trigger_phrases:
  - glossary
  - dutch term
  - english name
  - translation
importance_tier: normal
contextType: general
version: 1.0.0.0
---

# Glossary router

**Rule:** Every reference leads with the English term and adds the Dutch term in brackets at its first use in a section, for example "supplementary assessment (naheffingsaanslag)". Each English and Dutch pair lives in exactly one file below, and `scripts/check-english-first.py` reads every category file in this folder.

---

## 1. OVERVIEW

Dutch stays where it is the data: routing signals, Dutch test prompts, quoted official text, form and box names, legal citations, source columns and the bilingual yearly overview (jaaroverzicht) template. Everywhere else the English name leads.

A request that asks what a Dutch term means or what its English name is reads this router and every file that holds a term it names. It also reads the glossary file of each topic its route reads: a `tax-rules/<year>/<topic>/` file or a general file of that topic maps to its topic file, a VAT return (btw-aangifte) file maps to `vat.md`, any other tax-rules file maps to `general.md` and any other reference maps to `bookkeeping.md`. A term request that waits on a missing tax year or matches no task row still reads the router and the term's files. A refusal reads no glossary file, and a CLI action follows the task row it joins.

---

## 2. FILES

| File | Holds |
|---|---|
| [vat.md](vat.md) | Terms used most in `tax-rules/<year>/vat/` |
| [income-tax.md](income-tax.md) | Terms used most in `tax-rules/<year>/income-tax/` |
| [box-2.md](box-2.md) | Terms used most in `tax-rules/<year>/box-2/` |
| [box-3.md](box-3.md) | Terms used most in `tax-rules/<year>/box-3/` |
| [business-deductions.md](business-deductions.md) | Terms used most in `tax-rules/<year>/business-deductions/` |
| [costs-and-car.md](costs-and-car.md) | Terms used most in `tax-rules/<year>/costs-and-car/` |
| [health-insurance-contribution.md](health-insurance-contribution.md) | Terms used most in `tax-rules/<year>/health-insurance-contribution/` |
| [investments.md](investments.md) | Terms used most in `tax-rules/<year>/investments/` |
| [pension-and-disability-insurance.md](pension-and-disability-insurance.md) | Terms used most in `tax-rules/<year>/pension-and-disability-insurance/` |
| [private-company-and-corporate-tax.md](private-company-and-corporate-tax.md) | Terms used most in `tax-rules/<year>/private-company-and-corporate-tax/` |
| [procedure.md](procedure.md) | Terms used most in `tax-rules/<year>/procedure/` |
| [work-relationship.md](work-relationship.md) | Terms used most in `tax-rules/<year>/work-relationship/` |
| [bookkeeping.md](bookkeeping.md) | Terms used most outside `tax-rules/`, in the Moneybird, migration and preparation docs |
| [general.md](general.md) | Terms with no topic at half their uses, and terms no reference uses yet |
| [official-names.md](official-names.md) | Names of laws, decrees, authorities, schemes, forms and products |
| [abbreviations.md](abbreviations.md) | Dutch short forms such as BV or Vpb |

---

## 3. WHERE A TERM GOES

- A term with the note `official name` goes to [official-names.md](official-names.md) and one with the note `abbreviation` to [abbreviations.md](abbreviations.md), whatever topic uses it.
- Any other term goes to the topic that holds at least half of its uses in the references, counted on the Dutch term over every year. A file outside the tax-rules folder counts for [bookkeeping.md](bookkeeping.md), except the VAT return (btw-aangifte) files, which count for [vat.md](vat.md). A general topic file under `tax-rules/general/` counts for its topic, and any other tax-rules file outside a topic folder, such as a year README, counts for [general.md](general.md).
- A term with no topic at half its uses, or with no use yet, goes to [general.md](general.md).
- Two Dutch spellings of one English term stay in one file, unless one of them is an official name or an abbreviation.
- A pair is never held in two files. The checker reports it when it is.
