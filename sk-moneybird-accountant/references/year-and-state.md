---
title: Year and state resolution
description: How the router resolves the tax year from session-context.json, refuses an out-of-range or unsettled figure, and computes the post-cutover migration state at route time.
trigger_phrases:
  - year resolution
  - session context clock
  - out of range year
  - value not settled
  - post-cutover state
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Year and state resolution

**Rule:** This reference holds the year resolver and the post-cutover predicate behind the Task-Type Table in `SKILL.md`. The table stays the single source of truth for routing. Nothing here changes a row, its read set or a year folder.

---

## 1. OVERVIEW

At session start `scripts/build-session-context.py` writes `session-context.json` at the repository root. The router reads that one file. It never opens a path under `migration-workspace/`. Git ignores the generated file, so it never ships with the skill.

The file holds an allowlist of field names, dates, gate numbers and enum statuses. It carries the clock, the `interactive` flag and a narrow migration projection. The generator is the only reader of the migration config and the phase dashboard.

Every value in this reference is derived at route time from that file. A resolved year, an active flag or a route state is never stored.

---

## 2. YEAR RESOLUTION

`year_key` is the year the answer uses. The key is `transaction_date` for a transaction and `return_coverage` for a return.

Resolution follows one order:

1. An explicit year in the request.
2. The period under review.
3. The return-year mapping. A transaction dated in one year inside a return for another year uses the return year.
4. The clock year, read from `clock_utc`.

The answer reports the resolved year, its `year_key` and the `clock_source`. `clock_source` is `SOURCE_DATE_EPOCH` when the session pinned the clock, otherwise `runtime`.

A year with no folder under `references/` is answered as "no year file, unverified". The resolver never borrows the nearest year.

The generator stops with `clock_missing` when no clock is available. A corpus date is never used as the clock.

---

## 3. OUT-OF-RANGE AND PUBLICATION STATE

These refusals apply to the figure and cross-year rows only. MIGRATION routing is never refused by year, because migration reads historical years.

A figure or cross-year question for a year before 2020 returns `year_before_corpus_start`. One for a year after 2027 returns `year_after_corpus_end` plus a pointer to the forward-looking rows in the newest year folder and their status. Neither branch loads another year's file.

Publication state decides the second refusal, not the year. A figure whose only support for the year asked is tagged `proposed`, `unknown`, `UNVERIFIED` or `adopted-not-yet-in-force` is refused with `value_not_settled`. The tags are the ones in `references/dutch-tax-rules.md` section 2.

The refusal reason is `value_not_settled` in every case. The message keeps the two publication cases apart. "Adopted but not yet in the Staatsblad" is one reason and "not adopted" is another. The router never merges them.

Any projection is labelled a forecast and names the bill it comes from.

A value tagged `Verified`, `Corrected` or `enacted` still answers, because the refusal is per value and not per year.

---

## 4. POST-CUTOVER STATE

The LIVE row loads the recurring-cycle files only when the migration is in post-cutover monitoring. The router computes that state at route time from `last_passed_gate`, `phase_22_status`, `monitoring_start_date`, `monitoring_end_date` and the clock date.

The state is one of five values:

- `pre_cutover`: `last_passed_gate` is below 18.
- `monitoring_active`: gate 18 passed and the monitoring window still covers the clock date. An end date of `OPEN_ENDED` also counts as active.
- `monitoring_lapsed_phase22_open`: the window ended while `phase_22_status` is not passed. The router loads `references/migration/phases-19-to-21.md` and `references/migration/phase-22-completion.md`. The migration is unfinished, never done.
- `migration_complete`: `phase_22_status` is `GATE_PASSED`. Only that field decides completion.
- `gate_window_conflict`: gate 18 passed but the start date is absent, or the end date precedes the start date. The router asks instead of choosing.

No active flag is stored. The state is recomputed on each route from the current file.

---

## 5. HEADLESS SESSIONS

`interactive` is false when stdin is not a terminal or the `CI` variable is set. A headless session cannot ask a question. A tie or a missing year then returns the candidate routes together with the question text instead of asking.

---

## 6. RELATED RESOURCES

- `SKILL.md` holds the Task-Type Table whose figure, cross-year and live rows use this resolver.
- `references/dutch-tax-rules.md` section 2 holds the status tags the refusal set draws on.
- `references/migration/control-framework.md` holds the Master dashboard and its five statuses.
- `references/migration/phases-19-to-21.md` holds the recurring live workflows.
- `references/migration/phase-22-completion.md` holds the Phase 22 completion gate.
- `scripts/build-session-context.py` writes `session-context.json` from the clock and the projection.
