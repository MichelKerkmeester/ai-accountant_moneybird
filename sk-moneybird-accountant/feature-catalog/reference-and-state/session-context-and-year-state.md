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

`scripts/build-session-context.py` writes `session-context.json` at the repository root for the router to read. The rules that turn that file into a year and a migration state live in `references/year-and-state.md` and the Task-Type Table in `SKILL.md` section 2 consumes both.

---

## 2. HOW IT WORKS

### Context fields

The builder reads the migration config and the phase dashboard, projects a fixed set of allowlisted fields onto the context file and drops everything else. A date or year field is kept only in its exact stored form. Output is stable for a given clock and inputs, so two runs with the same inputs produce the same bytes. The clock comes from `SOURCE_DATE_EPOCH` when it holds an integer, otherwise from the runtime UTC clock.

### Check and route state

The check mode reads an existing context file and reports every rule breach, one line per problem. It confirms the allowlist, the dashboard vocabulary, the staleness window, the date and gate field shapes and the absence of a path, amount or name in a string value. The route-state mode prints exactly one post-cutover state for the router, computed from the file alone and never written back.

### Year resolution

The router resolves the year as `year_key`: an explicit year, else the period under review, else the return-year mapping, else the clock year. A figure or cross-year question outside the corpus is refused with its out-of-range state and a figure whose support is not settled is refused as `value_not_settled`. Migration routing is never refused by year.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/build-session-context.py` | Script | Writes and checks the session context and prints the route state. |
| `sk-moneybird-accountant/references/year-and-state.md` | Shared | Holds the year resolver, the refusal states and the post-cutover predicate. |
| `sk-moneybird-accountant/references/routing-signals.md` | Shared | Names the signal sources and tie mechanics the router reads. |
| `sk-moneybird-accountant/SKILL.md` | Shared | Routes the resolved year and state through the Task-Type Table. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/session-context-test.sh` | Automated test | Runs the builder against offline fixtures for the clock, the allowlist, staleness and the post-cutover states. |
| `.github/workflows/plan-kit.yml` | Test harness | Runs the session context suite on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/session-context-and-year-state.md

Related references:
- [reference-index-and-year-changes.md](reference-index-and-year-changes.md) - The generated reference tree this context feeds.
- [year-rollover-runbook.md](year-rollover-runbook.md) - The annual refresh of the corpus the context reads.
