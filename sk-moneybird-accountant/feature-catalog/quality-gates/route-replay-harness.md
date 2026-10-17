---
title: Route replay harness
description: Scores the routing corpus offline and replays the refusal and hostile rows through the guard and the stub.
trigger_phrases:
  - Route replay harness
  - route-replay.py
  - routing gold corpus
  - router snapshot hash
  - refusal rows
version: 1.0.0.0
---

# Route replay harness (route-replay.py)

## 1. OVERVIEW

Scores the routing corpus offline and replays the refusal and hostile rows through the guard and the stub.

`scripts/route-replay/route-replay.py` builds a router snapshot from the Task-Type Table in `ROUTER.md` section 2, the constants in `references/routing-signals.md` and the resource map. In resolve mode it runs a connectivity gate over every routed path and scores each corpus row for mode, task type, read set, expected facts and the token ceiling. A row with `gold_packets` is also scored for the hub packet chain. In replay mode it runs the guard in test mode against the stub CLI and asserts the recorded command line and exit code of every refusal row and hostile invoice case.

---

## 2. HOW IT WORKS

The corpus in `scripts/route-replay/routing-gold.json` labels each row with its split and its expected route before any tuning, so the calibration and held-out results can be read apart. Time, environment and absolute paths never enter an output.

The corpus covers the T10 to T12 prepare rows, the five VAT branch rows VAT-BRANCH-Q1-01 to VAT-BRANCH-COR-01, the pack rows PACK-YEARLY-01 and PACK-INCOME-01 and the four refusal forms REFUSE-ROUTE-FILE-01 to REFUSE-ROUTE-LOCK-01 with their guard twins.

Stage one of the hub is scored from `mode-registry.json`, `hub-router.json` and the winning tool route. A request that names a CLI signal and holds no accountant task once the CLI signals and the system names are set aside starts in that CLI packet and reads no accountant reference. Every other request starts in the accountant packet and hands off to each CLI packet its tool route names, in that order, then to the destination of a T7 hit. A refusal hands off to none, also when it names a CLI and routes to a task row on the system name. An abstain hands off to none, and a CLI signal matches whole words only. The `packets` column holds the chain, and the HUB rows HUB-001 to HUB-010, most with a Dutch twin, name the chain they expect. Twin parity compares the chain too.

Output is `results.csv` and `report.md` under the run folder. The report holds the route accuracy per language and per split, the abstain and false-abstain counts, the hub packet chain, the facts and tokens per row and the held-out result. Token counts read the pinned cache and a missing or changed encoding data file stops the run before any download. `--rev` scores a revision, `--covers` filters by tag and `--corpus`, `--out`, `--guard` and `--stub` point at other inputs.

The suite copies the skill and the two hub files to a temp root and proves both modes, a deleted routed path, a twin mismatch, an unmet claim, a wrong expected exit, an empty corpus, a missing cache and two dated runs that produce identical outputs. A Jortt hub signal dropped from `hub-router.json` fails HUB-001, and a missing `mode-registry.json` fails the HUB rows.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/route-replay/route-replay.py` | Script | Builds the router snapshot, scores the corpus and replays the guard rows. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Shared | Holds the offline routing scenarios, their twins and their labels. |
| `sk-moneybird-accountant/references/routing-signals.md` | Shared | Owns the tie constants, the warning band and the signal sources the snapshot reads. |
| `sk-moneybird-accountant/assets/route-calibration.json` | Shared | Holds the frozen calibration record the snapshot reads. |
| `mode-registry.json`, `hub-router.json` | Hub | The packets, the default packet and the stage one signals the packet chain reads. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | Proves both modes on a temp copy, including a deleted path, a missing cache, two dated runs and one pass case per new row with three seeded mutants. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | The branch, pack, refusal and HUB rows the suite scores and replays. |
| `sk-moneybird-accountant/benchmark/reports/route-replay/report.md` | Reference | The recorded run and its accuracy rows. |
| `.github/workflows/skill-health.yml` | Test harness | Runs both replay modes on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/route-replay-harness.md

Related references:
- [eval-grader.md](eval-grader.md) - The captured-answer grader beside the corpus scorer.
- [token-budget-baseline.md](token-budget-baseline.md) - The pinned cache and budget rows.
