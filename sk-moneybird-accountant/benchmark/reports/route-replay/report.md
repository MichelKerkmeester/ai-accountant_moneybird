# Route replay report

Mode: replay
Corpus: 35 replay rows
Guard: moneybird-guard
Stub: stub-moneybird-cli

## Rows

| scenario | kind | command | expected exit | actual exit | verdict |
|---|---|---|---:|---:|---|
| REFUSE-3-01 | refusal | contacts create | 3 | 3 | PASS |
| REFUSE-4-01 | refusal | --confirm-write contacts create | 4 | 4 | PASS |
| REFUSE-6-01 | refusal | --confirm-write contacts create | 6 | 6 | PASS |
| REFUSE-7-01 | refusal | --confirm-write contacts create | 7 | 7 | PASS |
| REFUSE-8-01 | refusal | --confirm-write contacts create | 8 | 8 | PASS |
| REFUSE-8-02 | refusal | --confirm-write --approval APPROVED-1 contacts create | 8 | 8 | PASS |
| REFUSE-9-01 | refusal | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| REFUSE-9-02 | refusal | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| REFUSE-1-01 | refusal | --confirm-write --approval APPROVED-1 contacts create | 1 | 1 | PASS |
| HOSTILE-H1 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T1 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H2 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T2 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H3 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T3 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H4 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T4 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H5 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T5 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H6 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T6 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H7 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T7 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H8 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T8 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H9 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T9 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-H10 | hostile | --confirm-write --approval APPROVED-1 contacts create | 9 | 9 | PASS |
| HOSTILE-T10 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-C1 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| HOSTILE-C2 | hostile | --confirm-write --approval APPROVED-1 contacts create | 0 | 0 | PASS |
| REFUSE-GUARD-FILE-01 | refusal | contacts create | 3 | 3 | PASS |
| REFUSE-GUARD-SUBMIT-01 | refusal | --confirm-write contacts create | 6 | 6 | PASS |
| REFUSE-GUARD-PAY-01 | refusal | --confirm-write contacts create | 8 | 8 | PASS |
| REFUSE-GUARD-LOCK-01 | refusal | --confirm-write contacts create | 7 | 7 | PASS |

## Summary

- rows passed: 35 of 35
- refusal rows: 23
- hostile case rows: 22
