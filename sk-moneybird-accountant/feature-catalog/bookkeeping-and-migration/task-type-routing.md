---
title: Task type routing
description: Classifies each request to a task type that decides the tool route, read set, token budget and tie rule.
trigger_phrases:
  - Task type routing
  - which task type is this request
  - task type table
  - route record
version: 1.0.0.0
---

# Task type routing

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Classifies each request to exactly one task type of the Task-Type Table in ROUTER.md section 2.

The winning row decides the tool route, the read set and the token budget key for the answer. The types cover migration phase and migration concept work, live periods, purchase invoices, tax figures, cross-year rules, CLI actions, unknown or out-of-scope requests and onboarding.

---

## 2. HOW IT WORKS

The agent scores the Dutch and English signal columns of each row. The table holds twelve rows. T10 prepares the VAT return (btw-aangifte), T11 prepares the yearly overview (jaaroverzicht) and T12 prepares the income tax return (aangifte inkomstenbelasting), each with its signals, a marked read set, a budget key and a tie outcome that settles its overlap with T3 or T5. T8 wins over T10, T11 and T12 when an explicit file, submit, pay or lock request is present, so a filing request receives the refusal and never a prepared return. Every row names its tool route, its read set, a token budget key such as `tok:T3` and a tie rule that settles overlaps, so a named invoice or a named phase shifts the route before a tie is called. A weak term such as `btw` alone never decides a row.

When the top two rows sit inside the route margin and no tie rule decides, the answer abstains, names the candidate rows and asks one question. The CLI action row is additive and never wins alone. It appends the sibling tool skill to the row already matched. Every answer ends with a route record that names the selected row, the references read and the boundary result.

Every read-set cell uses the `!`, `?`, `@section-id`, `{year}`, `{phase-file}` and `{topic-figures}` grammar. `check-route-table.py` expands each item, fails a missing required path or anchor and lists a missing conditional read. The router block carries `REQUIRED_READS`, `CONDITIONAL_READS`, `SECTION_TARGETS`, `PHASE_FILES` and `TOPIC_FILES`. A request outside the skill's scope gets the out-of-scope refusal, and a request for a tax deliverable whose procedure is not written gets the documented gap from the `gaps` ledger in `references/index.json`.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/ROUTER.md | Shared | Defines the Task-Type Table, the tie rules, the abstain margin and the route record. |
| sk-moneybird-accountant/scripts/check-route-table.py | Shared | Generates the router block and the multi-word intent signals from the table and fails on drift. |
| sk-moneybird-accountant/assets/route-calibration.json | Shared | Holds the frozen route margin, fallback floor and calibration record. |
| sk-moneybird-accountant/graph-metadata.json | Shared | Carries the generated intent signals and the curated routing vocabulary. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/manual-testing-playbook.md | Manual playbook | Root index of the offline routing scenarios that exercise the task type rows. |
| sk-moneybird-accountant/scripts/route-replay/route-replay.py | Test harness | Scores the routing corpus offline and replays each refusal through the guard and the stub. |
| sk-moneybird-accountant/scripts/route-replay/routing-gold.json | Fixture | The corpus with the T10 to T12 rows, the VAT branch rows, the pack rows and the refusal rows. |
| sk-moneybird-accountant/evals/evals.json | Fixture | The eval cases for the branch, pack and refusal routes. |
| sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh | Automated test | Checks the harness with a deleted path, a twin mismatch, two dated runs and one pass case per new row. |
| sk-moneybird-accountant/scripts/run-evals.py | Test harness | Grades captured answers against the eval cases in `evals/evals.json`. |
| sk-moneybird-accountant/scripts/route-table-test.sh | Automated test | Checks the route table, the T10 to T12 rows, the read-set grammar, the gap ledger, the router block and the intent-signal drift on mutants. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/task-type-routing.md

Related references:
- [api-tool-handoff.md](api-tool-handoff.md) - Related workflow behavior.
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
