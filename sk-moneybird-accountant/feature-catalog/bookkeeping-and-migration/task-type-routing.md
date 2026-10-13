---
title: Task type routing
description: Classifies each request to one of nine task types that decide the tool route, read set, token budget, and tie rule.
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

Classifies each request to exactly one of the nine task types T1 to T9 in the Task-Type Table in SKILL.md section 2.

The winning row decides the tool route, the read set, and the token budget key for the answer. The types cover migration phase and migration concept work, live periods, purchase invoices, tax figures, cross-year rules, CLI actions, unknown or out-of-scope requests, and onboarding.

---

## 2. HOW IT WORKS

The agent scores the Dutch and English signal columns of each row. Every row names its tool route, its read set, a token budget key such as `tok:T3`, and a tie rule that settles overlaps, so a named invoice or a named phase shifts the route before a tie is called. A weak term such as `btw` alone never decides a row.

When the top two rows sit inside the route margin and no tie rule decides, the answer abstains, names the candidate rows, and asks one question. The CLI action row is additive and never wins alone, it appends the sibling tool skill to the row already matched. Every answer ends with a route record that names the selected row, the references read, and the boundary result.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Defines the Task-Type Table, the tie rules, the abstain margin, and the route record. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/check-route-table.py | Shared | Generates the router block and the multi-word intent signals from the table and fails on drift. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/manual-testing-playbook.md | Manual playbook | Root index of the offline routing scenarios that exercise the task type rows. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/route-replay/route-replay.py | Automated harness | Scores the routing corpus offline and replays each refusal through the guard and the stub. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh | Automated test | Checks the harness with a deleted path, a twin mismatch and two dated runs. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/run-evals.py | Automated grader | Grades captured answers against the eval cases in `evals/evals.json`. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/hardening-matrix.md | Matrix | Names the test behind each failure mode, checked by `check-hardening-matrix.py`. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/task-type-routing.md

Related references:
- [api-tool-handoff.md](api-tool-handoff.md) - Related workflow behavior.
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
