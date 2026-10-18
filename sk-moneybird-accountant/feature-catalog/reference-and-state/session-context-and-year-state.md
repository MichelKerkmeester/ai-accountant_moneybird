---
title: Session context and year resolution
description: Writes the git-ignored session context from the clock and a migration projection and resolves the tax year and post-cutover state at route time.
trigger_phrases:
  - Session context and year resolution
  - session-context.json
  - year_key
  - post-cutover state
  - build-session-context.py
version: 1.0.0.0
---

# Session context and year resolution (build-session-context.py)

## 1. OVERVIEW

Writes the git-ignored session context from the clock and a migration projection and resolves the tax year and post-cutover state at route time.

`scripts/build-session-context.py` writes `session-context.json` at the repository root for the router to read. The rules that turn that file into a year and a migration state live in `references/tax-rules/year-and-state.md` and the Task-Type Table in `ROUTER.md` section 2 consumes both.

---

## 2. HOW IT WORKS

### Context fields

The builder reads the migration config and the phase dashboard, projects a fixed set of allowlisted fields onto the context file and drops everything else. The config holds the template shape, a `fields` list of rows that each carry a `field` and a `value`. A `PENDING` or empty value in a row reads as null. The phase statuses come from the phase table of the markdown dashboard that `init-workspace.sh` copies into `Plans/`, where a status such as `GATE PASSED` reads as `GATE_PASSED`. A date or year field is kept only in its exact stored form. Output is stable for a given clock and inputs, so two runs with the same inputs produce the same bytes. The clock comes from `SOURCE_DATE_EPOCH` when it holds an integer, otherwise from the runtime UTC clock.

### Year resolution

The router resolves the year as `year_key`: an explicit year, else the period under review, else the return-year mapping, else the clock year. A figure or cross-year question outside the corpus is refused with its out-of-range state and a figure whose support is not settled is refused as `value_not_settled`. Migration routing is never refused by year.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/build-session-context.py` | Script | Writes the session context. |
| `sk-moneybird-accountant/references/tax-rules/year-and-state.md` | Shared | Holds the year resolver, the refusal states and the post-cutover predicate. |
| `sk-moneybird-accountant/references/routing-signals.md` | Shared | Names the signal sources and tie mechanics the router reads. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Routes the resolved year and state through the Task-Type Table. |
| `AGENTS.md` | Shared | Tells the agent to run the builder when `session-context.json` is missing and to ask for the year when none resolves. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/session-context-test.sh` | Automated test | Runs the builder against offline fixtures for the clock, the interactive flag, the allowlist, the template `fields` rows and the markdown dashboard table. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the suite as the `Suite session-context` step on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/session-context-and-year-state.md

Related references:
- [reference-index-and-year-changes.md](reference-index-and-year-changes.md) - The generated reference tree this context feeds.
- [year-rollover-runbook.md](year-rollover-runbook.md) - The annual refresh of the corpus the context reads.
