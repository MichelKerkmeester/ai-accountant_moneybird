# Route replay report

Router snapshot: sha256:1f68b8ec1217f4b6444b8a80ee09ead1905fd43ab9099857a343af111bf99ca3
Mode: resolve
Corpus: routing-gold.json with 86 rows
Token encoding: o200k_base from the pinned cache
Route margin: 0.25. Warning band: 0.08. Fallback floor: 0.5.

## Scored dimensions

- Route: scored, mode and task type against the gold route.
- Read set: scored, expected paths loaded and forbidden paths absent.
- Connectivity: scored by the gate before any row is scored.
- Answer quality: unscored. No judge model grades an answer.

## Accuracy

- route accuracy en: 49/49 (1.000)
- route accuracy nl: 33/33 (1.000)
- route accuracy mixed: 4/4 (1.000)
- route accuracy calibration: 57/57 (1.000)
- route accuracy held-out: 29/29 (1.000)
- held-out route accuracy: 29/29 (1.000)
- rows passed: 86 of 86
- abstain: 18 of 18 expected
- missing tax year, tier C: 1
- false abstain: 0
- Dutch parity: 27 of 27 twin pairs match

## Additive T7 assertion

The additive CLI row never wins alone. A row whose prompt matches a T7 signal keeps the row it matched and appends the sibling tool skill.

- rows matching a T7 signal: 7
- additive row wins alone: 0
- MIG-002: T7 signal with route MIGRATION/T1
- MIG-004: T7 signal with route MIGRATION/T1
- API-001: T7 signal with route MIGRATION/T1
- MIG-002-nl: T7 signal with route MIGRATION/T1
- MIG-004-nl: T7 signal with route MIGRATION/T1
- API-001-nl: T7 signal with route MIGRATION/T1
- T7-ADDITIVE-01: T7 signal with route LIVE/T4

## Per-type precision and recall

Precision divides the correct routes by the rows routed to that type. Recall divides them by the rows whose gold type it is.

- T1 precision 15/15 (1.000), recall 15/15 (1.000)
- T2 precision 3/3 (1.000), recall 3/3 (1.000)
- T3 precision 7/7 (1.000), recall 7/7 (1.000)
- T4 precision 16/16 (1.000), recall 16/16 (1.000)
- T5 precision 9/9 (1.000), recall 9/9 (1.000)
- T6 precision 3/3 (1.000), recall 3/3 (1.000)
- T7 precision 0/0 (n/a), recall 0/0 (n/a)
- T8 precision 17/17 (1.000), recall 17/17 (1.000)
- T9 precision 2/2 (1.000), recall 2/2 (1.000)
- T10 precision 7/7 (1.000), recall 7/7 (1.000)
- T11 precision 3/3 (1.000), recall 3/3 (1.000)
- T12 precision 3/3 (1.000), recall 3/3 (1.000)

## Read counts

| scenario | route | reads |
|---|---|---:|
| MODE-001 | MIGRATION/T1 | 4 |
| MIG-005 | MIGRATION/T1 | 3 |
| MIG-006 | MIGRATION/T9 | 1 |
| MIG-001 | MIGRATION/T1 | 3 |
| MIG-002 | MIGRATION/T1 | 3 |
| MIG-003 | MIGRATION/T1 | 4 |
| MIG-004 | MIGRATION/T1 | 4 |
| LIVE-001 | LIVE/T3 | 2 |
| LIVE-002 | LIVE/T3 | 3 |
| LIVE-003 | LIVE/T4 | 3 |
| TAX-001 | LIVE/T5 | 2 |
| TAX-002 | ABSTAIN/T8 | 0 |
| TAX-003 | LIVE/T5 | 1 |
| PRIV-001 | ABSTAIN/T8 | 0 |
| API-001 | MIGRATION/T1 | 3 |
| MODE-001-nl | MIGRATION/T1 | 4 |
| MIG-005-nl | MIGRATION/T1 | 3 |
| MIG-006-nl | MIGRATION/T9 | 1 |
| MIG-001-nl | MIGRATION/T1 | 3 |
| MIG-002-nl | MIGRATION/T1 | 3 |
| MIG-003-nl | MIGRATION/T1 | 4 |
| MIG-004-nl | MIGRATION/T1 | 4 |
| LIVE-001-nl | LIVE/T3 | 2 |
| LIVE-002-nl | LIVE/T3 | 3 |
| LIVE-003-nl | LIVE/T4 | 3 |
| TAX-001-nl | LIVE/T5 | 2 |
| TAX-002-nl | ABSTAIN/T8 | 0 |
| TAX-003-nl | LIVE/T5 | 1 |
| PRIV-001-nl | ABSTAIN/T8 | 0 |
| API-001-nl | MIGRATION/T1 | 3 |
| GAP-T2-01 | MIGRATION/T2 | 1 |
| MIG-007 | MIGRATION/T2 | 1 |
| MIG-007-nl | MIGRATION/T2 | 1 |
| TIE-T4-T2-01 | LIVE/T4 | 3 |
| TIE-T4-T2-01-nl | LIVE/T4 | 3 |
| GAP-T6-01 | LIVE/T6 | 1 |
| TIE-T4-T3-01 | LIVE/T4 | 3 |
| TIE-T5-T6-01 | LIVE/T5 | 2 |
| TIE-T1-T3-01 | MIGRATION/T1 | 3 |
| TIER-A-01 | ABSTAIN/T8 | 0 |
| TIER-B-01 | ABSTAIN/abstain | 0 |
| TIER-C-01 | LIVE/T5 | 0 |
| OUT-OF-SCOPE-01 | ABSTAIN/T8 | 0 |
| FOLLOW-01 | LIVE/T3 | 2 |
| MIX-01 | LIVE/T4 | 3 |
| MIX-02 | LIVE/T3 | 2 |
| LIVE-004 | LIVE/T4 | 4 |
| LIVE-004-nl | LIVE/T4 | 4 |
| MIX-03 | LIVE/T4 | 4 |
| LIVE-005 | LIVE/T4 | 4 |
| LIVE-005-nl | LIVE/T4 | 4 |
| MIX-04 | LIVE/T4 | 4 |
| TIE-T4-T6-01 | LIVE/T6 | 1 |
| TIE-T4-T5-01 | LIVE/T5 | 2 |
| LIVE-004-b | LIVE/T4 | 4 |
| TIE-T4-T5-02 | LIVE/T5 | 2 |
| TIE-T4-T5-02-nl | LIVE/T5 | 2 |
| TIE-T4-T6-02 | LIVE/T6 | 1 |
| TIE-T3-T4-01 | LIVE/T3 | 2 |
| LIVE-005-b | LIVE/T4 | 4 |
| LIVE-005-b-nl | LIVE/T4 | 4 |
| PREP-T10-01 | LIVE/T10 | 2 |
| PREP-T10-01-nl | LIVE/T10 | 2 |
| PREP-T11-01 | LIVE/T11 | 3 |
| PREP-T11-01-nl | LIVE/T11 | 3 |
| PREP-T12-01 | LIVE/T12 | 3 |
| PREP-T12-01-nl | LIVE/T12 | 3 |
| FILE-T10-01 | ABSTAIN/T8 | 0 |
| FILE-T10-01-nl | ABSTAIN/T8 | 0 |
| FILE-T11-01 | ABSTAIN/T8 | 0 |
| FILE-T11-01-nl | ABSTAIN/T8 | 0 |
| FILE-T12-01 | ABSTAIN/T8 | 0 |
| FILE-T12-01-nl | ABSTAIN/T8 | 0 |
| TWO-TURN-01 | ABSTAIN/T8 | 0 |
| T7-ADDITIVE-01 | LIVE/T4 | 3 |
| VAT-BRANCH-Q1-01 | LIVE/T10 | 2 |
| VAT-BRANCH-RC-01 | LIVE/T10 | 2 |
| VAT-BRANCH-KOR-01 | LIVE/T10 | 2 |
| VAT-BRANCH-YE-01 | LIVE/T10 | 2 |
| VAT-BRANCH-COR-01 | LIVE/T10 | 2 |
| PACK-YEARLY-01 | LIVE/T11 | 3 |
| PACK-INCOME-01 | LIVE/T12 | 3 |
| REFUSE-ROUTE-FILE-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-SUBMIT-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-PAY-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-LOCK-01 | ABSTAIN/T8 | 0 |

## Warning band sink

Rows whose winning gap sits in the 0.08 warning band above the route margin. Telemetry only, the route never changes.

- none

## Rows

| scenario | lang | split | route | tokens loaded | facts found | verdict |
|---|---|---|---|---:|---|---|
| MODE-001 | en | calibration | MIGRATION/T1 | 16996 | 2 of 2 | PASS |
| MIG-005 | en | calibration | MIGRATION/T1 | 17960 | 2 of 2 | PASS |
| MIG-006 | en | held-out | MIGRATION/T9 | 5732 | 2 of 2 | PASS |
| MIG-001 | en | calibration | MIGRATION/T1 | 13115 | 2 of 2 | PASS |
| MIG-002 | en | calibration | MIGRATION/T1 | 12879 | 2 of 2 | PASS |
| MIG-003 | en | calibration | MIGRATION/T1 | 18611 | 2 of 2 | PASS |
| MIG-004 | en | held-out | MIGRATION/T1 | 18611 | 2 of 2 | PASS |
| LIVE-001 | en | calibration | LIVE/T3 | 5975 | 2 of 2 | PASS |
| LIVE-002 | en | held-out | LIVE/T3 | 10682 | 2 of 2 | PASS |
| LIVE-003 | en | calibration | LIVE/T4 | 17112 | 2 of 2 | PASS |
| TAX-001 | en | calibration | LIVE/T5 | 6794 | 2 of 2 | PASS |
| TAX-002 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003 | en | held-out | LIVE/T5 | 3741 | 2 of 2 | PASS |
| PRIV-001 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001 | en | calibration | MIGRATION/T1 | 12879 | 2 of 2 | PASS |
| MODE-001-nl | nl | calibration | MIGRATION/T1 | 16996 | 2 of 2 | PASS |
| MIG-005-nl | nl | calibration | MIGRATION/T1 | 17960 | 2 of 2 | PASS |
| MIG-006-nl | nl | held-out | MIGRATION/T9 | 5732 | 2 of 2 | PASS |
| MIG-001-nl | nl | calibration | MIGRATION/T1 | 13115 | 2 of 2 | PASS |
| MIG-002-nl | nl | calibration | MIGRATION/T1 | 12879 | 2 of 2 | PASS |
| MIG-003-nl | nl | calibration | MIGRATION/T1 | 18611 | 2 of 2 | PASS |
| MIG-004-nl | nl | held-out | MIGRATION/T1 | 18611 | 2 of 2 | PASS |
| LIVE-001-nl | nl | calibration | LIVE/T3 | 5975 | 2 of 2 | PASS |
| LIVE-002-nl | nl | held-out | LIVE/T3 | 10682 | 2 of 2 | PASS |
| LIVE-003-nl | nl | calibration | LIVE/T4 | 17112 | 2 of 2 | PASS |
| TAX-001-nl | nl | calibration | LIVE/T5 | 6794 | 2 of 2 | PASS |
| TAX-002-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003-nl | nl | held-out | LIVE/T5 | 3741 | 2 of 2 | PASS |
| PRIV-001-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001-nl | nl | calibration | MIGRATION/T1 | 12879 | 2 of 2 | PASS |
| GAP-T2-01 | en | calibration | MIGRATION/T2 | 1117 | 1 of 1 | PASS |
| MIG-007 | en | calibration | MIGRATION/T2 | 1117 | 1 of 1 | PASS |
| MIG-007-nl | nl | calibration | MIGRATION/T2 | 1117 | 1 of 1 | PASS |
| TIE-T4-T2-01 | en | calibration | LIVE/T4 | 17112 | 0 of 0 | PASS |
| TIE-T4-T2-01-nl | nl | calibration | LIVE/T4 | 17112 | 0 of 0 | PASS |
| GAP-T6-01 | en | calibration | LIVE/T6 | 11967 | 1 of 1 | PASS |
| TIE-T4-T3-01 | nl | calibration | LIVE/T4 | 17112 | 1 of 1 | PASS |
| TIE-T5-T6-01 | nl | calibration | LIVE/T5 | 6799 | 2 of 2 | PASS |
| TIE-T1-T3-01 | en | calibration | MIGRATION/T1 | 17960 | 2 of 2 | PASS |
| TIER-A-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TIER-B-01 | nl | calibration | ABSTAIN/abstain | 0 | 0 of 0 | PASS |
| TIER-C-01 | nl | calibration | LIVE/T5 | 0 | 0 of 0 | PASS |
| OUT-OF-SCOPE-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FOLLOW-01 | nl | calibration | LIVE/T3 | 5975 | 2 of 2 | PASS |
| MIX-01 | mixed | calibration | LIVE/T4 | 17112 | 2 of 2 | PASS |
| MIX-02 | mixed | calibration | LIVE/T3 | 5975 | 2 of 2 | PASS |
| LIVE-004 | en | held-out | LIVE/T4 | 23943 | 2 of 2 | PASS |
| LIVE-004-nl | nl | held-out | LIVE/T4 | 23943 | 2 of 2 | PASS |
| MIX-03 | mixed | held-out | LIVE/T4 | 23943 | 2 of 2 | PASS |
| LIVE-005 | en | held-out | LIVE/T4 | 25809 | 2 of 2 | PASS |
| LIVE-005-nl | nl | held-out | LIVE/T4 | 25809 | 2 of 2 | PASS |
| MIX-04 | mixed | held-out | LIVE/T4 | 25809 | 2 of 2 | PASS |
| TIE-T4-T6-01 | en | calibration | LIVE/T6 | 11967 | 0 of 0 | PASS |
| TIE-T4-T5-01 | en | calibration | LIVE/T5 | 6794 | 1 of 1 | PASS |
| LIVE-004-b | en | calibration | LIVE/T4 | 23943 | 1 of 1 | PASS |
| TIE-T4-T5-02 | en | calibration | LIVE/T5 | 4523 | 0 of 0 | PASS |
| TIE-T4-T5-02-nl | nl | calibration | LIVE/T5 | 4523 | 0 of 0 | PASS |
| TIE-T4-T6-02 | en | calibration | LIVE/T6 | 11967 | 0 of 0 | PASS |
| TIE-T3-T4-01 | en | calibration | LIVE/T3 | 5975 | 0 of 0 | PASS |
| LIVE-005-b | en | calibration | LIVE/T4 | 25809 | 0 of 0 | PASS |
| LIVE-005-b-nl | nl | calibration | LIVE/T4 | 25809 | 0 of 0 | PASS |
| PREP-T10-01 | en | held-out | LIVE/T10 | 6000 | 2 of 2 | PASS |
| PREP-T10-01-nl | nl | held-out | LIVE/T10 | 6000 | 2 of 2 | PASS |
| PREP-T11-01 | en | held-out | LIVE/T11 | 8710 | 2 of 2 | PASS |
| PREP-T11-01-nl | nl | held-out | LIVE/T11 | 8710 | 2 of 2 | PASS |
| PREP-T12-01 | en | held-out | LIVE/T12 | 7179 | 2 of 2 | PASS |
| PREP-T12-01-nl | nl | held-out | LIVE/T12 | 7179 | 2 of 2 | PASS |
| FILE-T10-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T10-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T11-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T11-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T12-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T12-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TWO-TURN-01 | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| T7-ADDITIVE-01 | en | calibration | LIVE/T4 | 17112 | 2 of 2 | PASS |
| VAT-BRANCH-Q1-01 | en | held-out | LIVE/T10 | 6000 | 3 of 3 | PASS |
| VAT-BRANCH-RC-01 | en | held-out | LIVE/T10 | 6000 | 3 of 3 | PASS |
| VAT-BRANCH-KOR-01 | en | held-out | LIVE/T10 | 6000 | 3 of 3 | PASS |
| VAT-BRANCH-YE-01 | en | held-out | LIVE/T10 | 6000 | 3 of 3 | PASS |
| VAT-BRANCH-COR-01 | en | held-out | LIVE/T10 | 6000 | 3 of 3 | PASS |
| PACK-YEARLY-01 | en | held-out | LIVE/T11 | 8710 | 5 of 5 | PASS |
| PACK-INCOME-01 | en | held-out | LIVE/T12 | 7179 | 7 of 7 | PASS |
| REFUSE-ROUTE-FILE-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-SUBMIT-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-PAY-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-LOCK-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
