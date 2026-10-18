---
title: Token budget baseline
description: Pins the token counts of the reference corpus and fails when a reference change moves a budgeted row.
trigger_phrases:
  - Token budget baseline
  - token-baseline.py
  - reference token budget
  - token canary
  - o200k_base
version: 1.0.0.0
---

# Token budget baseline (token-baseline.py)

## 1. OVERVIEW

Pins the token counts of the reference corpus and fails when a reference change moves a budgeted row.

`scripts/token-baseline.py` counts every markdown file under `references/` in the two pinned encodings, whole file and per H2 section and adds the named units, the overhead rows and the car route. `benchmark/token-baseline.json` holds the result, sorted and without a timestamp, so two runs produce the same bytes.

---

## 2. HOW IT WORKS

The read budget ladder the table rows use is owned by `scripts/README.md` and `ROUTER.md`, and `check-route-table.py` fails when the ladder sentence in `ROUTER.md` differs from section 5 of `references/routing-signals.md` or from the file line in `token-baseline.py`. The baseline checks that each pinned encoding data file exists and matches its recorded hash before it loads an encoder, so a missing or changed file stops the run instead of downloading anything.

`--check` also holds the three skill files every accountant request reads after the repository `AGENTS.md`, the hub `SKILL.md`, the accountant `ROUTER.md` and the accountant `SKILL.md`, within a request line of 12,000 `o200k_base` tokens. `AGENTS.md` is the bootstrap and stays outside the line. It names the three files and the sum when they pass it.

The canary suite runs the car-question route through the year README and one topic section and asserts the proposed route stays under its ratio and its token ceiling. Three mutants prove the gate: a route pointed at the whole topic file, a swapped encoding in the cache and a fixture that passes one budget and fails the other.

A sibling word check holds each `SKILL.md` and `ROUTER.md` at a 3,000-word loading budget with a 4,000-word ceiling. `check-skill-words.py` warns above the budget, fails above the ceiling and exits 2 when a file is missing or unreadable, and `check-route-table.py` runs it beside the baseline check. The walk skips hidden folders, `specs/`, `node_modules/` and the two private folders.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/token-baseline.py` | Script | Counts every reference file and the named units and checks the pinned baseline. |
| `sk-moneybird-accountant/benchmark/token-baseline.json` | Shared | Holds the pinned counts without a timestamp. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | States the read budget ladder the table rows use. |
| `sk-moneybird-accountant/scripts/README.md` | Shared | Documents the encodings, the pin and the re-measure rule. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/token-canary-test.sh` | Automated test | Runs the car-question route, three budget mutants and a router grown past the request line. |
| `sk-moneybird-accountant/scripts/check-skill-words.py` | Test harness | Holds each `SKILL.md` and `ROUTER.md` at the 3,000-word budget with the 4,000-word ceiling and is run by the route table step. |
| `sk-moneybird-accountant/scripts/check-skill-words-test.sh` | Automated test | Proves the 2,999-word, 3,001-word and 4,001-word bands and the missing file exit. |
| `.github/workflows/skill-health.yml` | Test harness | Seeds the pinned tokenizer cache and runs the baseline check. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/token-budget-baseline.md

Related references:
- [../reference-and-state/reference-index-and-year-changes.md](../reference-and-state/reference-index-and-year-changes.md) - The generator that runs after a reference change.
- [route-replay-harness.md](route-replay-harness.md) - The harness that reads the pinned cache.
