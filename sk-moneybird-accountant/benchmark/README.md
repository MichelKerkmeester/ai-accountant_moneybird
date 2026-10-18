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
    `-- README.md                # Index of completed run folders
```

| Path | Contents |
|---|---|
| [`reports/`](./reports/) | Run index for completed run folders |
| [`token-baseline.json`](./token-baseline.json) | Pinned token counts for the reference corpus, the corpus total and the three skill files every request reads |

The manual scenario corpus is in [`manual-testing-playbook/`](../manual-testing-playbook/manual-testing-playbook.md). The corpus is an input and is not rewritten by a run.

The route replay harness keeps no report in this folder. Each run of `../scripts/route-replay/route-replay.py` writes `results.csv` and `report.md` to a fresh temp folder and prints `route-replay: output in <dir>` as its last line. Pass `--out DIR` to write to a folder you name. Copy the files into a dated run folder under `reports/` to keep them.

---

## 3. TOKEN BASELINE

`token-baseline.json` is the pinned token measure of the reference corpus. `../scripts/token-baseline.py` writes it, and `--check` compares it. The file holds one row per reference file with its H2 sections, the corpus total, the three skill files every accountant request reads and the encoding pin. It carries no timestamp.

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
token-baseline: check ok, 476 files, 1427 sections
```

Canary: `../scripts/token-canary-test.sh` proves the gate in a throwaway copy. A swapped encoding file stops the run, a router grown past the request line of 12,000 `o200k_base` tokens fails the check and a reference file edited after the baseline write fails the check by name. The suite ends with `3 passed, 0 failed`.

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

Expected: `token-baseline: check ok, 476 files, 1427 sections`.

Score the routing corpus offline. Run from the repository root:

```bash
TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve
python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay
```

Expected: `route-replay: ok, 445 rows passed` and `route-replay: ok, 31 replay rows passed`, each followed by a `route-replay: output in <dir>` line that names the folder holding `results.csv` and `report.md`.

---

## 5. RELATED RESOURCES

| Document | Purpose |
|---|---|
| [`reports/README.md`](./reports/README.md) | Index of completed run folders and the storage rule |
| [`../manual-testing-playbook/manual-testing-playbook.md`](../manual-testing-playbook/manual-testing-playbook.md) | Candidate scenarios for a benchmark run |
| [`../scripts/README.md`](../scripts/README.md) | Token baseline, canary and the checkers that own the numbers |
