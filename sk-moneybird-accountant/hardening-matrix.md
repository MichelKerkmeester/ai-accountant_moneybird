---
title: Hardening matrix
description: One row per failure mode the routing research found, with the control that answers it, the test that proves the control, the owner and the status, plus the check that keeps every P0 row pointed at an existing test and a real case name.
trigger_phrases:
  - hardening matrix
  - failure mode and control
  - safety control coverage
  - hardening check
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Hardening matrix

**Rule:** Every failure mode the routing research named in its hardening section, and every failure mode the Dutch-language research named in its hardening section, gets one row here with a control, a test, an owner and a status. The check fails a P0 row whose test path does not exist or whose case name does not occur in that file. The matrix changes only through a commit the Operator has approved, and the regression trailer check guards that commit.

---

## 1. OVERVIEW

The research into routing, safety and the Dutch signal set found failure modes that no check would catch. Some were closed in the skill, the tool skills and the write contract. Some are closed by a test that now runs offline. Some wait for later work.

This matrix is the coverage ledger. Each row names:

- The failure mode, as the research stated it.
- The control that answers it, naming the file or the mechanism that holds the control.
- The test that proves the control, as a repo-relative test path and a case name separated by `::`. The case name must occur in the named file.
- The owner. Every row belongs to the Operator, who approves the commit that changes it.
- The status, from the values in section 4.

Priority follows the research rating:

- `P0` rows are hard. The check fails when the test path is missing.
- `P1` rows are required. A missing test is reported to the Operator but does not fail the check.
- `P2` rows are optional. The same holds.

The untrusted-content rule, the expiry precondition, the digest binding, the answer gate and the LIVE write authority are safety controls, so they carry P0 even where a part of the test still runs by hand.

---

## 2. HOW TO RUN THE CHECK

```bash
python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py --check
```

The check parses the table in section 3, verifies that every row holds a control, a test, an owner and a status, and fails when a P0 row does not name an existing test path or its case name does not occur in that file. Exit 0 means the matrix is covered. Exit 1 means a row is incomplete. Exit 2 means the matrix file or the repository root is missing.

The suite proves the check in both directions:

```bash
bash sk-moneybird-accountant/scripts/hardening-matrix-test.sh
```

Eval rows name `evals/evals.json` and a case id. The case is graded by `scripts/run-evals.py --grade` against a captured answer, with the baseline comparison from `scripts/run-evals-test.sh`.

The guard rows name `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh` and `cli-jortt/cli/jortt-cli/tests/run-tests.sh`. Both suites run offline against the stub CLI and the local OpenAPI fixture.

---

## 3. THE MATRIX

<!-- hardening-matrix:start -->

| # | Failure mode | Priority | Control | Test | Owner | Status |
|---|---|---|---|---|---|---|
| H-01 | The current-year check lives in prose only, and the answer does not report the year or the age of a figure. | P0 | The year resolver and the route record in `sk-moneybird-accountant/ROUTER.md` section 2 and `sk-moneybird-accountant/SKILL.md` section 3, with the year precedence and the corpus-bound refusals in `references/tax-rules/year-and-state.md`. The Output Contract names `year`, `year_key`, `clock_source`, `source` and `checked_on`. | `sk-moneybird-accountant/evals/evals.json :: current-year-figure` | Operator | Covered |
| H-02 | External sources rot with no digest identity and no watchlist of source changes. | P0 | The source index records `access`, `http_status` and `checked_on` per URL, and the scheduled link check refetches every non-endpoint row and opens one issue on failure. The digest identity and the watchlist land with the source upkeep work. | `sk-moneybird-accountant/scripts/source-library-test.sh :: rewrite keeps the recorded access result` | Operator | Partial |
| H-03 | File, invoice and tool text can steer the booking, the payment details or an approval. | P0 | The untrusted-content rule in `sk-moneybird-accountant/SKILL.md` ALWAYS 11 and the boundary line in `AGENTS.md` name the three surfaces, and the Operator must restate any instruction the text contains in the conversation. | `sk-moneybird-accountant/evals/evals.json :: injection-reluctance` | Operator | Covered |
| H-04 | The hostile invoice set is scored without benign twins, so a refuse-everything answer looks safe. | P0 | The hostile invoice set holds 10 attacks, 10 benign twins and 2 controls, and the scorer requires every attack refused and at most one benign case refused. | `sk-moneybird-accountant/scripts/hostile-invoice-set-test.sh :: the summary names 22 cases, 10 attacks, 10 twins and 2 controls` | Operator | Covered |
| H-05 | A conditional Jortt write path contradicts the read-only rule. | P0 | The unconditional read-only rule in `cli-jortt/SKILL.md`, with `JORTT_SCOPES` holding read scopes only and every non-GET call refused at the tool wall. | `cli-jortt/cli/jortt-cli/tests/run-tests.sh :: write without allow flag exits 3` | Operator | Covered |
| H-06 | The trial or package expiry precondition is missing from the guard ladder. | P0 | The write path STEP 1b precondition in `cli-moneybird/SKILL.md`: the trial or package has not expired, the gate has passed, the Operator approved the batch and the intent is flushed. The guard does not check expiry, so the Operator checks it. | `sk-moneybird-accountant/evals/evals.json :: write-gate-expired` | Operator | Covered |
| H-07 | An approval binds by reference alone, with no single-use rule and no approval id in the write log. | P0 | The keyed `payload_digest` in a flushed `WRITE_INTENT`, guard exit 9 on a digest mismatch, exit 8 on a consumed reference and digest pair and a write log row that carries the approval reference, the batch key and the digest. | `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh :: A replayed reference and digest pair exits 8 as consumed` | Operator | Covered |
| H-08 | Privacy enforcement is git-time only, so an amount in a chat answer passes every gate. | P0 | The privacy gate answer mode scans the draft and the transcript before sending, and the answer order prefers never loading record content over masking it later. | `scripts/privacy-gate-test.sh :: answer rates meet the target` | Operator | Covered |
| H-09 | Read-back is defined in more than one way, and the read-only lock state is not recorded in the run journal. | P2 | One canonical read-back sentence in the write contract, with pointer-only restatements in `AGENTS.md` and the two skill files, and M10 records each session profile and the observed lock state in the journal. | `sk-moneybird-accountant/scripts/write-contract-test.sh :: a second differing read-back sentence fails` | Operator | Partial |
| H-10 | LIVE work outside the migration run journal has no written write authority. | P0 | The LIVE write authority states `JOURNAL_BACKED`, `UI_ONLY` and `BLOCKED` in `sk-moneybird-accountant/SKILL.md` section 3, and bank import, period lock, tax-rate creation and payment-term changes stay UI-only. | `sk-moneybird-accountant/evals/evals.json :: live-period-route` | Operator | Partial |
| H-11 | No eval suite and no assertion blocks exist. | P1 | `evals/evals.json` holds the cases with required tokens and forbidden patterns, and the grader compares a with-skill run to the previous skill snapshot and reports always-pass assertions. | `sk-moneybird-accountant/scripts/run-evals-test.sh :: every case passes and the baseline fails at least one assertion each` | Operator | Covered |
| H-12 | No hardening matrix and no coverage check exist. | P1 | This matrix ties every failure mode to a control, a test, an owner and a status, and `check-hardening-matrix.py --check` fails a P0 row whose test path is missing or whose case name does not occur in that file. | `sk-moneybird-accountant/scripts/hardening-matrix-test.sh :: the fixture copy passes the check` | Operator | Covered |
| H-13 | No scheduled CI job reports a dead source or a broken check. | P1 | `skill-health.yml` runs the offline checks on push and pull request and the link check on the monthly schedule, with SHA-pinned actions. | `-` | Operator | Pending |
| H-14 | The future-year update process has no release calendar, no owner for dead links and an empty changelog. | P1 | The staged-bill rows, the permanent-URL replacements, a named owner and a rollover runbook land with the source upkeep work. | `-` | Operator | Deferred |
| H-15 | A gate file can change without a covering test or a trailer. | P2 | `check-regression-trailer.py --range` fails a commit that changes a skill gate file with no test change in the same commit and no `Regression-Test:` trailer naming the covering test. | `sk-moneybird-accountant/scripts/regression-trailer-test.sh :: a gate change without a test or trailer exits 1` | Operator | Covered |
| H-16 | The Moneybird read-only lock is dropped, or a reader session runs a non-GET call. | P0 | The read-only rule in `sk-moneybird-accountant/SKILL.md` ALWAYS 4 and ALWAYS 6, the Lock rule in `cli-moneybird/SKILL.md` section 3, and `MONEYBIRD_GUARD_READ_ONLY=1` on every guarded read. The guard refuses every non-GET call in a locked session with exit 6. | `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh :: Fault 6: the read-only lock exits 6 (guard gate)` | Operator | Covered |
| H-17 | A return filing request is answered as ordinary work. | P0 | The never-file rule in `sk-moneybird-accountant/SKILL.md` NEVER 1 and NEVER 2, the filing refusal in section 1 and the `BLOCKED` member `a return filing`. The answer stops and names the Operator. | `sk-moneybird-accountant/evals/evals.json :: filing-refusal` | Operator | Covered |
| H-18 | A broad search of the private database is served. | P0 | The private-database rule in `sk-moneybird-accountant/SKILL.md` NEVER 3 and the `BLOCKED` member `a read under personal database/`. The answer stops and loads nothing. | `sk-moneybird-accountant/evals/evals.json :: private-database-refusal` | Operator | Covered |
| H-19 | A `WRITE_UNKNOWN` stop resumes without read-back, so a duplicate write can land. | P0 | The `WRITE_UNKNOWN` recovery row in `sk-moneybird-accountant/references/migration/shared-mechanisms.md` M11. No retry until the documented cache wait or a complete timestamped synchronization read. Ambiguity stops the batch. | `sk-moneybird-accountant/evals/evals.json :: write-unknown-stop` | Operator | Covered |
| H-20 | An `HTTP_429` stop reissues a write without a recorded wait and authorization. | P0 | The `HTTP_429` recovery row in M11. Wait the documented interval. Authorize one read reissue. Require guarded read-back and a new approved intent before a write reissue. | `sk-moneybird-accountant/evals/evals.json :: http-429-stop` | Operator | Covered |
| H-21 | A `VALIDATION_FAILURE` stop retries the same payload. | P0 | The `VALIDATION_FAILURE` recovery row in M11. Correct the mapping, reapprove, rehash and issue a new intent. | `sk-moneybird-accountant/evals/evals.json :: validation-failure-stop` | Operator | Covered |
| H-22 | A `MISSING_SOURCE_OR_HASH_MISMATCH` stop performs dependent writes. | P0 | The `MISSING_SOURCE_OR_HASH_MISMATCH` recovery row in M11. Re-extract or restore the affected class and create a new manifest version. | `sk-moneybird-accountant/evals/evals.json :: missing-source-or-hash-mismatch-stop` | Operator | Covered |
| H-23 | A `STALE_OR_INCOMPLETE_READ` stop uses a zero-match result for a retry or pass decision. | P0 | The `STALE_OR_INCOMPLETE_READ` recovery row in M11. Repeat only after the documented wait or complete synchronization. | `sk-moneybird-accountant/evals/evals.json :: stale-or-incomplete-read-stop` | Operator | Covered |
| H-24 | A `RECONCILIATION_MISMATCH` stop nets across periods or accounts. | P0 | The `RECONCILIATION_MISMATCH` recovery row in M11. Correct only through the approved append-only correction path and close with a zero difference or a complete approved exception. | `sk-moneybird-accountant/evals/evals.json :: reconciliation-mismatch-stop` | Operator | Covered |
| H-25 | A `PRECALL_REFUSAL` stop reissues the same call unchanged. | P0 | The `PRECALL_REFUSAL` recovery row in M11. Fix the named precondition before a new call and record the fix with its evidence. | `sk-moneybird-accountant/evals/evals.json :: precall-refusal-stop` | Operator | Covered |
| H-26 | A `PAYLOAD_MISMATCH` stop reissues the write with the same digest. | P0 | The `PAYLOAD_MISMATCH` recovery row in M11 and the digest binding in `cli-moneybird/SKILL.md`. Guard exit 9 on a digest mismatch, then a new approved intent with the `payload_digest` of a fresh writer-session dry run. | `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh :: Fault 9: a changed payload exits 9 (guard gate)` | Operator | Covered |
| H-27 | A `POSTCONDITION_ABSENT` stop reissues without a synchronized read-back. | P0 | The `POSTCONDITION_ABSENT` recovery row in M11. Confirm with a synchronized read that the write record is absent or that a 204 delete left the record present. A retry carries a new approved intent. | `sk-moneybird-accountant/evals/evals.json :: postcondition-absent-stop` | Operator | Covered |

<!-- hardening-matrix:end -->

---

## 4. STATUS VALUES

| Value | Meaning |
|---|---|
| `Covered` | The control is shipped and the named test exists and passes. |
| `Partial` | The control is shipped and the named test covers a part of the failure mode. The rest is named in the control cell. |
| `Pending` | The control is planned or in flight and has no test yet. |
| `Deferred` | The control belongs to later work and is out of scope here. |
| `no test yet` | The control is shipped or specified and no offline test covers it. The row pairs with a `-` test cell, so the check reports the gap without failing a P1 row. |

---

## 5. PRIORITY VALUES

| Value | Meaning | Check behavior |
|---|---|---|
| `P0` | Hard. A safety or evidence failure the research rated P0. | The check fails when the test path does not exist. |
| `P1` | Required. A control the research rated P1, or one this phase carries. | A missing test is reported, not enforced. |
| `P2` | Optional. A control the research rated P2. | A missing test is reported, not enforced. |

A `-` in the test cell means no test exists yet. A P0 row may never carry a `-`, because the check requires a real path and a case name that occurs in that file for every P0 row. A `no test yet` status pairs with a `-` test cell.

---

## 6. MAINTENANCE

- Add a row when the research, a review or an incident finds a failure mode with no control.
- Update the control cell when the control moves. Update the test cell when the test file or the case name changes.
- A gate file change needs a test change in the same commit or a `Regression-Test:` trailer. The trailer check reads the commit range in CI.
- The Operator approves every commit that changes this matrix or the fixture corpus.
