# Route replay report

Router snapshot: sha256:3df207101e45ac59f7a48d7eeaa5098f09ae58bf885655a332b57a18c02d6560
Mode: resolve
Corpus: routing-gold.json with 131 rows
Token encoding: o200k_base from the pinned cache
Route margin: 0.25. Warning band: 0.08. Fallback floor: 0.5.

## Scored dimensions

- Route: scored, mode and task type against the gold route.
- Read set: scored, expected paths loaded and forbidden paths absent.
- Connectivity: scored by the gate before any row is scored.
- Answer quality: unscored. No judge model grades an answer.

## Accuracy

- route accuracy en: 69/69 (1.000)
- route accuracy nl: 57/57 (1.000)
- route accuracy mixed: 5/5 (1.000)
- route accuracy calibration: 57/57 (1.000)
- route accuracy held-out: 74/74 (1.000)
- held-out route accuracy: 74/74 (1.000)
- rows passed: 131 of 131
- abstain: 27 of 27 expected
- missing tax year, tier C: 1
- false abstain: 0
- Dutch parity: 50 of 50 twin pairs match

## Additive T7 assertion

The additive CLI row never wins alone. A row whose prompt matches a T7 signal keeps the row it matched and appends the sibling tool skill.

- rows matching a T7 signal: 13
- additive row wins alone: 0
- MIG-002: T7 signal with route MIGRATION/T1
- MIG-004: T7 signal with route MIGRATION/T1
- API-001: T7 signal with route MIGRATION/T1
- MIG-002-nl: T7 signal with route MIGRATION/T1
- MIG-004-nl: T7 signal with route MIGRATION/T1
- API-001-nl: T7 signal with route MIGRATION/T1
- T7-ADDITIVE-01: T7 signal with route LIVE/T4
- T7-DEST-JORTT-01: T7 signal with route MIGRATION/T1
- T7-DEST-JORTT-01-nl: T7 signal with route MIGRATION/T1
- T7-DEST-MONEYBIRD-01: T7 signal with route LIVE/T3
- T7-DEST-MONEYBIRD-01-nl: T7 signal with route LIVE/T3
- T7-DEST-BLOCKED-01: T7 signal with route ABSTAIN/T8
- T7-DEST-BLOCKED-01-nl: T7 signal with route ABSTAIN/T8

## Per-type precision and recall

Precision divides the correct routes by the rows routed to that type. Recall divides them by the rows whose gold type it is.

- T1 precision 17/17 (1.000), recall 17/17 (1.000)
- T2 precision 3/3 (1.000), recall 3/3 (1.000)
- T3 precision 9/9 (1.000), recall 9/9 (1.000)
- T4 precision 18/18 (1.000), recall 18/18 (1.000)
- T5 precision 13/13 (1.000), recall 13/13 (1.000)
- T6 precision 3/3 (1.000), recall 3/3 (1.000)
- T7 precision 0/0 (n/a), recall 0/0 (n/a)
- T8 precision 26/26 (1.000), recall 26/26 (1.000)
- T9 precision 2/2 (1.000), recall 2/2 (1.000)
- T10 precision 18/18 (1.000), recall 18/18 (1.000)
- T11 precision 11/11 (1.000), recall 11/11 (1.000)
- T12 precision 10/10 (1.000), recall 10/10 (1.000)

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
| PREP-T10-01 | LIVE/T10 | 3 |
| PREP-T10-01-nl | LIVE/T10 | 3 |
| PREP-T11-01 | LIVE/T11 | 4 |
| PREP-T11-01-nl | LIVE/T11 | 4 |
| PREP-T12-01 | LIVE/T12 | 4 |
| PREP-T12-01-nl | LIVE/T12 | 4 |
| FILE-T10-01 | ABSTAIN/T8 | 0 |
| FILE-T10-01-nl | ABSTAIN/T8 | 0 |
| FILE-T11-01 | ABSTAIN/T8 | 0 |
| FILE-T11-01-nl | ABSTAIN/T8 | 0 |
| FILE-T12-01 | ABSTAIN/T8 | 0 |
| FILE-T12-01-nl | ABSTAIN/T8 | 0 |
| TWO-TURN-01 | ABSTAIN/T8 | 0 |
| T7-ADDITIVE-01 | LIVE/T4 | 3 |
| VAT-BRANCH-Q1-01 | LIVE/T10 | 3 |
| VAT-BRANCH-RC-01 | LIVE/T10 | 3 |
| VAT-BRANCH-KOR-01 | LIVE/T10 | 3 |
| VAT-BRANCH-YE-01 | LIVE/T10 | 3 |
| VAT-BRANCH-COR-01 | LIVE/T10 | 3 |
| PACK-YEARLY-01 | LIVE/T11 | 4 |
| PACK-INCOME-01 | LIVE/T12 | 4 |
| REFUSE-ROUTE-FILE-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-SUBMIT-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-PAY-01 | ABSTAIN/T8 | 0 |
| REFUSE-ROUTE-LOCK-01 | ABSTAIN/T8 | 0 |
| AUDITFILE-LIVE-01 | LIVE/T11 | 4 |
| AUDITFILE-LIVE-01-nl | LIVE/T11 | 4 |
| PREP-KEEP-T10-01 | LIVE/T10 | 3 |
| PREP-KEEP-T10-01-nl | LIVE/T10 | 3 |
| PREP-KEEP-T11-01 | LIVE/T11 | 4 |
| PREP-KEEP-T11-01-nl | LIVE/T11 | 4 |
| PREP-KEEP-T12-01 | LIVE/T12 | 4 |
| PREP-KEEP-T12-01-nl | LIVE/T12 | 4 |
| FILE-HO-T10-01 | ABSTAIN/T8 | 0 |
| FILE-HO-T10-01-nl | ABSTAIN/T8 | 0 |
| FILE-HO-T11-01 | ABSTAIN/T8 | 0 |
| FILE-HO-T11-01-nl | ABSTAIN/T8 | 0 |
| FILE-HO-T12-01 | ABSTAIN/T8 | 0 |
| FILE-HO-T12-01-nl | ABSTAIN/T8 | 0 |
| PREP-WORD-SUBMIT-01 | LIVE/T10 | 3 |
| PREP-WORD-DIEN-01-nl | LIVE/T10 | 3 |
| PREP-TIE-10-01 | LIVE/T10 | 3 |
| PREP-TIE-10-01-nl | LIVE/T10 | 3 |
| PREP-TIE-11-01 | LIVE/T11 | 4 |
| PREP-TIE-11-01-nl | LIVE/T11 | 4 |
| PREP-TIE-12-01 | LIVE/T12 | 4 |
| PREP-TIE-12-01-nl | LIVE/T12 | 4 |
| SRC-PDF-01 | LIVE/T5 | 1 |
| SRC-PDF-01-nl | LIVE/T5 | 1 |
| TAX-FIG-SRC-01 | LIVE/T5 | 3 |
| TAX-FIG-SRC-01-nl | LIVE/T5 | 3 |
| SRC-INV-01 | LIVE/T4 | 3 |
| SRC-INV-01-nl | LIVE/T4 | 3 |
| PREP-T10-SRC-01 | LIVE/T10 | 4 |
| PREP-T10-SRC-01-nl | LIVE/T10 | 4 |
| PREP-T12-SRC-01 | LIVE/T12 | 5 |
| PREP-T12-SRC-01-nl | LIVE/T12 | 5 |
| VAT-Q4-JAN-01 | LIVE/T10 | 3 |
| VAT-Q4-JAN-01-nl | LIVE/T10 | 3 |
| T11-CLOSE-01 | LIVE/T11 | 4 |
| T11-CLOSE-01-nl | LIVE/T11 | 4 |
| PREP-SPACE-T10-01 | LIVE/T10 | 3 |
| PREP-SPACE-T12-01 | LIVE/T12 | 4 |
| BARE-AANGIFTE-01 | ABSTAIN/T8 | 0 |
| T7-DEST-JORTT-01 | MIGRATION/T1 | 3 |
| T7-DEST-JORTT-01-nl | MIGRATION/T1 | 3 |
| T7-DEST-MONEYBIRD-01 | LIVE/T3 | 2 |
| T7-DEST-MONEYBIRD-01-nl | LIVE/T3 | 2 |
| T7-DEST-BLOCKED-01 | ABSTAIN/T8 | 0 |
| T7-DEST-BLOCKED-01-nl | ABSTAIN/T8 | 0 |

## Warning band sink

Rows whose winning gap sits in the 0.08 warning band above the route margin. Telemetry only, the route never changes.

- none

## Rows

| scenario | lang | split | route | tokens loaded | facts found | verdict |
|---|---|---|---|---:|---|---|
| MODE-001 | en | calibration | MIGRATION/T1 | 17018 | 2 of 2 | PASS |
| MIG-005 | en | calibration | MIGRATION/T1 | 17956 | 2 of 2 | PASS |
| MIG-006 | en | held-out | MIGRATION/T9 | 5748 | 2 of 2 | PASS |
| MIG-001 | en | calibration | MIGRATION/T1 | 13141 | 2 of 2 | PASS |
| MIG-002 | en | calibration | MIGRATION/T1 | 12992 | 2 of 2 | PASS |
| MIG-003 | en | calibration | MIGRATION/T1 | 18740 | 2 of 2 | PASS |
| MIG-004 | en | held-out | MIGRATION/T1 | 18740 | 2 of 2 | PASS |
| LIVE-001 | en | calibration | LIVE/T3 | 6190 | 2 of 2 | PASS |
| LIVE-002 | en | held-out | LIVE/T3 | 11666 | 2 of 2 | PASS |
| LIVE-003 | en | calibration | LIVE/T4 | 18172 | 2 of 2 | PASS |
| TAX-001 | en | calibration | LIVE/T5 | 8037 | 2 of 2 | PASS |
| TAX-002 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003 | en | held-out | LIVE/T5 | 396 | 1 of 1 | PASS |
| PRIV-001 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001 | en | calibration | MIGRATION/T1 | 12992 | 2 of 2 | PASS |
| MODE-001-nl | nl | calibration | MIGRATION/T1 | 17018 | 2 of 2 | PASS |
| MIG-005-nl | nl | calibration | MIGRATION/T1 | 17956 | 2 of 2 | PASS |
| MIG-006-nl | nl | held-out | MIGRATION/T9 | 5748 | 2 of 2 | PASS |
| MIG-001-nl | nl | calibration | MIGRATION/T1 | 13141 | 2 of 2 | PASS |
| MIG-002-nl | nl | calibration | MIGRATION/T1 | 12992 | 2 of 2 | PASS |
| MIG-003-nl | nl | calibration | MIGRATION/T1 | 18740 | 2 of 2 | PASS |
| MIG-004-nl | nl | held-out | MIGRATION/T1 | 18740 | 2 of 2 | PASS |
| LIVE-001-nl | nl | calibration | LIVE/T3 | 6190 | 2 of 2 | PASS |
| LIVE-002-nl | nl | held-out | LIVE/T3 | 11666 | 2 of 2 | PASS |
| LIVE-003-nl | nl | calibration | LIVE/T4 | 18172 | 2 of 2 | PASS |
| TAX-001-nl | nl | calibration | LIVE/T5 | 8037 | 2 of 2 | PASS |
| TAX-002-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003-nl | nl | held-out | LIVE/T5 | 396 | 1 of 1 | PASS |
| PRIV-001-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001-nl | nl | calibration | MIGRATION/T1 | 12992 | 2 of 2 | PASS |
| GAP-T2-01 | en | calibration | MIGRATION/T2 | 1125 | 1 of 1 | PASS |
| MIG-007 | en | calibration | MIGRATION/T2 | 1125 | 1 of 1 | PASS |
| MIG-007-nl | nl | calibration | MIGRATION/T2 | 1125 | 1 of 1 | PASS |
| TIE-T4-T2-01 | en | calibration | LIVE/T4 | 18172 | 0 of 0 | PASS |
| TIE-T4-T2-01-nl | nl | calibration | LIVE/T4 | 18172 | 0 of 0 | PASS |
| GAP-T6-01 | en | calibration | LIVE/T6 | 13024 | 1 of 1 | PASS |
| TIE-T4-T3-01 | nl | calibration | LIVE/T4 | 18172 | 1 of 1 | PASS |
| TIE-T5-T6-01 | nl | calibration | LIVE/T5 | 7775 | 2 of 2 | PASS |
| TIE-T1-T3-01 | en | calibration | MIGRATION/T1 | 17956 | 2 of 2 | PASS |
| TIER-A-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TIER-B-01 | nl | calibration | ABSTAIN/abstain | 0 | 0 of 0 | PASS |
| TIER-C-01 | nl | calibration | LIVE/T5 | 0 | 0 of 0 | PASS |
| OUT-OF-SCOPE-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FOLLOW-01 | nl | calibration | LIVE/T3 | 6190 | 2 of 2 | PASS |
| MIX-01 | mixed | calibration | LIVE/T4 | 18172 | 2 of 2 | PASS |
| MIX-02 | mixed | calibration | LIVE/T3 | 6190 | 2 of 2 | PASS |
| LIVE-004 | en | held-out | LIVE/T4 | 25344 | 2 of 2 | PASS |
| LIVE-004-nl | nl | held-out | LIVE/T4 | 25344 | 2 of 2 | PASS |
| MIX-03 | mixed | held-out | LIVE/T4 | 25344 | 2 of 2 | PASS |
| LIVE-005 | en | held-out | LIVE/T4 | 27399 | 2 of 2 | PASS |
| LIVE-005-nl | nl | held-out | LIVE/T4 | 27399 | 2 of 2 | PASS |
| MIX-04 | mixed | held-out | LIVE/T4 | 27399 | 2 of 2 | PASS |
| TIE-T4-T6-01 | en | calibration | LIVE/T6 | 13024 | 0 of 0 | PASS |
| TIE-T4-T5-01 | en | calibration | LIVE/T5 | 8037 | 1 of 1 | PASS |
| LIVE-004-b | en | calibration | LIVE/T4 | 25344 | 1 of 1 | PASS |
| TIE-T4-T5-02 | en | calibration | LIVE/T5 | 5055 | 0 of 0 | PASS |
| TIE-T4-T5-02-nl | nl | calibration | LIVE/T5 | 5055 | 0 of 0 | PASS |
| TIE-T4-T6-02 | en | calibration | LIVE/T6 | 13024 | 0 of 0 | PASS |
| TIE-T3-T4-01 | en | calibration | LIVE/T3 | 6190 | 0 of 0 | PASS |
| LIVE-005-b | en | calibration | LIVE/T4 | 27399 | 0 of 0 | PASS |
| LIVE-005-b-nl | nl | calibration | LIVE/T4 | 27399 | 0 of 0 | PASS |
| PREP-T10-01 | en | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-T10-01-nl | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-T11-01 | en | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-T11-01-nl | nl | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-T12-01 | en | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| PREP-T12-01-nl | nl | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| FILE-T10-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T10-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T11-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T11-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T12-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-T12-01-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TWO-TURN-01 | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| T7-ADDITIVE-01 | en | calibration | LIVE/T4 | 18172 | 2 of 2 | PASS |
| VAT-BRANCH-Q1-01 | en | held-out | LIVE/T10 | 9651 | 3 of 3 | PASS |
| VAT-BRANCH-RC-01 | en | held-out | LIVE/T10 | 9651 | 3 of 3 | PASS |
| VAT-BRANCH-KOR-01 | en | held-out | LIVE/T10 | 9651 | 3 of 3 | PASS |
| VAT-BRANCH-YE-01 | en | held-out | LIVE/T10 | 9651 | 3 of 3 | PASS |
| VAT-BRANCH-COR-01 | en | held-out | LIVE/T10 | 9651 | 3 of 3 | PASS |
| PACK-YEARLY-01 | en | held-out | LIVE/T11 | 12951 | 5 of 5 | PASS |
| PACK-INCOME-01 | en | held-out | LIVE/T12 | 11148 | 7 of 7 | PASS |
| REFUSE-ROUTE-FILE-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-SUBMIT-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-PAY-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| REFUSE-ROUTE-LOCK-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| AUDITFILE-LIVE-01 | en | held-out | LIVE/T11 | 12951 | 1 of 1 | PASS |
| AUDITFILE-LIVE-01-nl | nl | held-out | LIVE/T11 | 12951 | 1 of 1 | PASS |
| PREP-KEEP-T10-01 | en | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-KEEP-T10-01-nl | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-KEEP-T11-01 | en | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-KEEP-T11-01-nl | nl | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-KEEP-T12-01 | en | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| PREP-KEEP-T12-01-nl | nl | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| FILE-HO-T10-01 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-HO-T10-01-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-HO-T11-01 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-HO-T11-01-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-HO-T12-01 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FILE-HO-T12-01-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| PREP-WORD-SUBMIT-01 | en | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-WORD-DIEN-01-nl | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-TIE-10-01 | en | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-TIE-10-01-nl | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-TIE-11-01 | en | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-TIE-11-01-nl | nl | held-out | LIVE/T11 | 12951 | 2 of 2 | PASS |
| PREP-TIE-12-01 | en | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| PREP-TIE-12-01-nl | nl | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| SRC-PDF-01 | en | held-out | LIVE/T5 | 396 | 2 of 2 | PASS |
| SRC-PDF-01-nl | nl | held-out | LIVE/T5 | 396 | 2 of 2 | PASS |
| TAX-FIG-SRC-01 | en | held-out | LIVE/T5 | 8433 | 3 of 3 | PASS |
| TAX-FIG-SRC-01-nl | nl | held-out | LIVE/T5 | 8433 | 3 of 3 | PASS |
| SRC-INV-01 | en | held-out | LIVE/T4 | 18172 | 1 of 1 | PASS |
| SRC-INV-01-nl | nl | held-out | LIVE/T4 | 18172 | 1 of 1 | PASS |
| PREP-T10-SRC-01 | en | held-out | LIVE/T10 | 10047 | 3 of 3 | PASS |
| PREP-T10-SRC-01-nl | nl | held-out | LIVE/T10 | 10047 | 3 of 3 | PASS |
| PREP-T12-SRC-01 | en | held-out | LIVE/T12 | 11544 | 3 of 3 | PASS |
| PREP-T12-SRC-01-nl | nl | held-out | LIVE/T12 | 11544 | 3 of 3 | PASS |
| VAT-Q4-JAN-01 | en | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| VAT-Q4-JAN-01-nl | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| T11-CLOSE-01 | mixed | held-out | LIVE/T11 | 12951 | 1 of 1 | PASS |
| T11-CLOSE-01-nl | nl | held-out | LIVE/T11 | 12951 | 1 of 1 | PASS |
| PREP-SPACE-T10-01 | nl | held-out | LIVE/T10 | 9651 | 2 of 2 | PASS |
| PREP-SPACE-T12-01 | nl | held-out | LIVE/T12 | 11148 | 2 of 2 | PASS |
| BARE-AANGIFTE-01 | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| T7-DEST-JORTT-01 | en | held-out | MIGRATION/T1 | 12992 | 1 of 1 | PASS |
| T7-DEST-JORTT-01-nl | nl | held-out | MIGRATION/T1 | 12992 | 1 of 1 | PASS |
| T7-DEST-MONEYBIRD-01 | en | held-out | LIVE/T3 | 6190 | 1 of 1 | PASS |
| T7-DEST-MONEYBIRD-01-nl | nl | held-out | LIVE/T3 | 6190 | 1 of 1 | PASS |
| T7-DEST-BLOCKED-01 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| T7-DEST-BLOCKED-01-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
