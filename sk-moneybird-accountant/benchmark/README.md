---
title: sk-moneybird-accountant Benchmark Artifacts
description: Offline routing benchmark inputs and reports for the sk-moneybird-accountant skill.
trigger_phrases:
  - sk-moneybird-accountant benchmark
  - offline bookkeeping routing review
importance_tier: normal
contextType: general
version: 1.0.0.0
---

# sk-moneybird-accountant Benchmark Artifacts

> Inputs and reports for offline routing runs that measure the bookkeeping and migration skill.

---

## 1. OVERVIEW

This folder holds the benchmark inputs and the reports from offline routing runs for the bookkeeping and migration skill. A reviewer uses it to check mode selection, reference routing, tool handoffs, tax boundaries and privacy behavior without a live system.

Use the manual playbook scenarios as the candidate prompts. A run stays offline, so it must not call Jortt, Moneybird, the web or tax authority APIs.

---

## 2. STRUCTURE

```text
benchmark/
+-- README.md                    # This guide
+-- token-baseline.json          # Pinned token counts
`-- reports/
    +-- README.md                # Index of completed run folders
    `-- route-replay/
        `-- report.md            # Generated resolve-mode route report
```

| Path | Contents |
|---|---|
| [`reports/`](./reports/) | Run index plus the generated route replay report |
| [`reports/route-replay/report.md`](./reports/route-replay/report.md) | Resolve-mode output of the offline route replay |
| [`token-baseline.json`](./token-baseline.json) | Pinned token counts for the reference corpus, the named units, the overhead rows and the car route |

The manual scenario corpus is in [`manual-testing-playbook/`](../manual-testing-playbook/manual-testing-playbook.md). The corpus is an input and is not rewritten by a run.

---

## 3. TOKEN BASELINE

`token-baseline.json` is the pinned token measure of the reference corpus. `../scripts/token-baseline.py` writes it, and `--check` compares it. The file holds one row per reference file with its H2 sections, the named units, the overhead rows, the encoding pin and the car route ratio. It carries no timestamp.

The read budget ladder, in tokens:

| Unit | Budget |
|---|---|
| One year README | 3,000 tokens |
| One section | 5,000 tokens |
| One full topic file or part | 15,000 tokens |

The pin names `o200k_base` as the lead encoding, `cl100k_base` as the second column, `tiktoken` 0.11.0 and the sha256 of each encoding data file.

| Encoding | Role | Data sha256 |
|---|---|---|
| `o200k_base` | lead | `446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d` |
| `cl100k_base` | second column | `223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7` |

The Operator chose `o200k_base` as the lead on 2026-10-12. Both encodings are proxies, so every count stands in for a model family and none is exact.

Offline rule: the data files come from a seeded cache named by `TIKTOKEN_CACHE_DIR`, for example `../tiktoken-cache` from the repository root. A missing file or a changed file stops the run with exit code 2. Nothing downloads an encoding.

Re-measure rule: on every reference change, run `token-baseline.py` and commit the updated JSON with the change. A passing check ends with:

```text
token-baseline: check ok, 143 files, 993 sections
token-baseline: car route ratio: o200k_base 0.2840, cl100k_base 0.2870
```

Canary: `../scripts/token-canary-test.sh` covers the 2026 car question on the KEY FIGURES route. The proposed route must stay at or under 35 percent of the current route and at or under 8,000 `cl100k_base` tokens, which is the year README row plus the one section row. A whole-file load fails the gate, and the suite ends with `8 passed, 0 failed`.

---

## 4. USAGE EXAMPLES

Record a completed run in a dated folder under `reports/` and add one row to the run index.

```text
benchmark/reports/<YYYY-MM-DD>--<subject>--<variant>/
```

The execution date names the folder. The index row names the folder, the runtime, the result, the verdict and the source packet.

Check the token baseline after a reference change. Run from the repository root:

```bash
TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check
```

Expected: `token-baseline: check ok, 143 files, 993 sections`.

---

## 5. RELATED RESOURCES

| Document | Purpose |
|---|---|
| [`reports/README.md`](./reports/README.md) | Index of completed run folders and the storage rule |
| [`../manual-testing-playbook/manual-testing-playbook.md`](../manual-testing-playbook/manual-testing-playbook.md) | Candidate scenarios for a benchmark run |
| [`../scripts/README.md`](../scripts/README.md) | Token baseline, canary and the checkers that own the numbers |
