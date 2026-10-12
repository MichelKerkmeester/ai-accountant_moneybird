# Route replay report

Router snapshot: sha256:96643aa7d05f6367eb3527c194a982410fb69381864f4dcccd4ec6806f411c1b
Mode: resolve
Corpus: routing-gold.json with 42 rows
Token encoding: o200k_base from the pinned cache
Route margin: 0.25. Warning band: 0.08. Fallback floor: 0.5.

## Scored dimensions

- Route: scored, mode and task type against the gold route.
- Read set: scored, expected paths loaded and forbidden paths absent.
- Connectivity: scored by the gate before any row is scored.
- Answer quality: unscored. No judge model grades an answer.

## Accuracy

- route accuracy en: 20/20 (1.000)
- route accuracy nl: 20/20 (1.000)
- route accuracy mixed: 2/2 (1.000)
- route accuracy calibration: 32/32 (1.000)
- route accuracy held-out: 10/10 (1.000)
- held-out route accuracy: 10/10 (1.000)
- rows passed: 42 of 42
- abstain: 7 of 7 expected
- missing tax year, tier C: 1
- false abstain: 0
- Dutch parity: 15 of 15 twin pairs match

## Rows

| scenario | lang | split | route | tokens loaded | facts found | verdict |
|---|---|---|---|---:|---|---|
| MODE-001 | en | calibration | MIGRATION/T1 | 18385 | 2 of 2 | PASS |
| MIG-005 | en | calibration | MIGRATION/T1 | 19374 | 2 of 2 | PASS |
| MIG-006 | en | held-out | MIGRATION/T9 | 5732 | 2 of 2 | PASS |
| MIG-001 | en | calibration | MIGRATION/T1 | 14529 | 2 of 2 | PASS |
| MIG-002 | en | calibration | MIGRATION/T1 | 12843 | 2 of 2 | PASS |
| MIG-003 | en | calibration | MIGRATION/T1 | 18575 | 2 of 2 | PASS |
| MIG-004 | en | held-out | MIGRATION/T1 | 18575 | 2 of 2 | PASS |
| LIVE-001 | en | calibration | LIVE/T3 | 5030 | 2 of 2 | PASS |
| LIVE-002 | en | held-out | LIVE/T3 | 22875 | 2 of 2 | PASS |
| LIVE-003 | en | calibration | LIVE/T4 | 29304 | 2 of 2 | PASS |
| TAX-001 | en | calibration | LIVE/T5 | 6684 | 2 of 2 | PASS |
| TAX-002 | en | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003 | en | held-out | LIVE/T5 | 3027 | 2 of 2 | PASS |
| PRIV-001 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001 | en | calibration | MIGRATION/T1 | 12843 | 2 of 2 | PASS |
| MODE-001-nl | nl | calibration | MIGRATION/T1 | 18385 | 2 of 2 | PASS |
| MIG-005-nl | nl | calibration | MIGRATION/T1 | 19374 | 2 of 2 | PASS |
| MIG-006-nl | nl | held-out | MIGRATION/T9 | 5732 | 2 of 2 | PASS |
| MIG-001-nl | nl | calibration | MIGRATION/T1 | 14529 | 2 of 2 | PASS |
| MIG-002-nl | nl | calibration | MIGRATION/T1 | 12843 | 2 of 2 | PASS |
| MIG-003-nl | nl | calibration | MIGRATION/T1 | 18575 | 2 of 2 | PASS |
| MIG-004-nl | nl | held-out | MIGRATION/T1 | 18575 | 2 of 2 | PASS |
| LIVE-001-nl | nl | calibration | LIVE/T3 | 5030 | 2 of 2 | PASS |
| LIVE-002-nl | nl | held-out | LIVE/T3 | 22875 | 2 of 2 | PASS |
| LIVE-003-nl | nl | calibration | LIVE/T4 | 29304 | 2 of 2 | PASS |
| TAX-001-nl | nl | calibration | LIVE/T5 | 6684 | 2 of 2 | PASS |
| TAX-002-nl | nl | held-out | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TAX-003-nl | nl | held-out | LIVE/T5 | 3027 | 2 of 2 | PASS |
| PRIV-001-nl | nl | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| API-001-nl | nl | calibration | MIGRATION/T1 | 12843 | 2 of 2 | PASS |
| GAP-T2-01 | en | calibration | MIGRATION/T2 | 1114 | 1 of 1 | PASS |
| GAP-T6-01 | en | calibration | LIVE/T6 | 11015 | 1 of 1 | PASS |
| TIE-T4-T3-01 | nl | calibration | LIVE/T4 | 29304 | 1 of 1 | PASS |
| TIE-T5-T6-01 | nl | calibration | LIVE/T5 | 6689 | 2 of 2 | PASS |
| TIE-T1-T3-01 | en | calibration | MIGRATION/T1 | 19374 | 2 of 2 | PASS |
| TIER-A-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| TIER-B-01 | nl | calibration | ABSTAIN/abstain | 0 | 0 of 0 | PASS |
| TIER-C-01 | nl | calibration | LIVE/T5 | 0 | 0 of 0 | PASS |
| OUT-OF-SCOPE-01 | en | calibration | ABSTAIN/T8 | 0 | 0 of 0 | PASS |
| FOLLOW-01 | nl | calibration | LIVE/T3 | 5030 | 2 of 2 | PASS |
| MIX-01 | mixed | calibration | LIVE/T4 | 29304 | 2 of 2 | PASS |
| MIX-02 | mixed | calibration | LIVE/T3 | 5030 | 2 of 2 | PASS |
