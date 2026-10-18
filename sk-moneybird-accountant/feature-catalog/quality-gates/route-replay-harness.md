---
title: Route replay harness
description: Scores the routing corpus offline and replays the refusal and hostile rows through the guard and the stub.
trigger_phrases:
  - Route replay harness
  - route-replay.py
  - routing gold corpus
  - refusal rows
version: 1.0.0.0
---

# Route replay harness (route-replay.py)

## 1. OVERVIEW

Scores the routing corpus offline and replays the refusal and hostile rows through the guard and the stub.

`scripts/route-replay/route-replay.py` reads the Task-Type Table and the route margin from `ROUTER.md` section 2. In resolve mode it scores each corpus row for mode, task type, read set, expected facts and the token ceiling. A row with `gold_packets` is also scored for the hub packet chain. In replay mode it runs the guard in test mode against the stub CLI and asserts the recorded command line and exit code of every refusal row and hostile invoice case.

---

## 2. HOW IT WORKS

The corpus in `scripts/route-replay/routing-gold.json` labels each row with its split and its expected route. The calibration and held-out labels were written before any tuning, so those results can be read apart. A regression row was written after a review to pin a fixed case, so the signals were tuned on it and it is scored apart from both. Time, environment and absolute paths never enter an output.

The corpus covers the T10 to T12 prepare rows, the five VAT branch rows VAT-BRANCH-Q1-01 to VAT-BRANCH-COR-01, the pack rows PACK-YEARLY-01 and PACK-INCOME-01 and the four refusal forms REFUSE-ROUTE-FILE-01 to REFUSE-ROUTE-LOCK-01. Replay mode runs the nine guard gate rows REFUSE-3-01 to REFUSE-1-01 and the 22 hostile invoice cases.

Stage one of the hub is scored from `mode-registry.json`, `hub-router.json` and the winning tool route. A request that names a CLI signal it does not negate and holds no accountant task once the CLI signals and the system names are set aside starts in that CLI packet and reads no accountant reference. A request that names a phase number, or both systems with a bare system name or a move verb, holds a migration task, and a CLI name counts for its system. So does a T1 or T2 route that holds a move verb, as in `use jortt-cli to copy the Jortt export`. Every other request starts in the accountant packet and hands off to each CLI packet its tool route names, in that order, then to the destination of a T7 hit. A refusal hands off to none, also when it names a CLI and routes to a task row on the system name. An abstain hands off to none, and a CLI signal matches whole words only. The `packets` column holds the chain, and the HUB rows HUB-001 to HUB-030, most with a Dutch twin, name the chain they expect. Twin parity compares the chain too. A row also fails when its gold tier differs from the route tier, so a missing-year question cannot turn into an answer, and the `tier` column holds the route tier.

Output is `results.csv` and `report.md`. The report holds the route accuracy per language and per split, the abstain and false-abstain counts, the hub packet chain, the facts and tokens per row and the held-out result. Without `--out` the files go to a fresh temp folder, and the run names it on its last line as `route-replay: output in <dir>`, so a run leaves the repository tree clean. `--out DIR` names the folder instead. Token counts read the pinned cache and a missing or changed encoding data file stops the run before any download.

The suite copies the skill and the two hub files to a temp root and proves both modes, the default output folder in each, a twin mismatch, an unmet claim, a wrong expected exit and a missing cache. A Jortt hub signal dropped from `hub-router.json` fails HUB-001, and a missing `mode-registry.json` fails the HUB rows. Five scoring cases break one scored field in a corpus copy each: the tier, the token ceiling, a forbidden path, the first turn of a follow-up and the read set of a twin.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/route-replay/route-replay.py` | Script | Reads the route table, scores the corpus and replays the guard rows. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Shared | Holds the offline routing scenarios, their twins and their labels. |
| `sk-moneybird-accountant/references/routing-signals.md` | Shared | Owns the tie margin, the specificity clauses and the filing grammar the resolver reads. |
| `mode-registry.json`, `hub-router.json` | Hub | The packets, the default packet and the stage one signals the packet chain reads. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | Proves both modes on a temp copy, including a missing cache, the default output folder and one pass case per new row with three seeded mutants. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | The branch, pack, refusal and HUB rows the suite scores and replays. |
| `.github/workflows/skill-health.yml` | Test harness | Runs both replay modes on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/route-replay-harness.md

Related references:
- [eval-grader.md](eval-grader.md) - The captured-answer grader beside the corpus scorer.
- [token-budget-baseline.md](token-budget-baseline.md) - The pinned cache and budget rows.
