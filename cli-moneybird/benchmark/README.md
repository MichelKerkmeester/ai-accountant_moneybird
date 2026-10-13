---
title: "cli-moneybird Benchmark Artifacts"
description: "Benchmark inputs and run reports for cli-moneybird, kept beside the skill they measure."
trigger_phrases:
  - "cli-moneybird benchmark"
  - "cli-moneybird benchmark artifacts"
importance_tier: "important"
contextType: "general"
version: 1.0.0.0
---

# cli-moneybird Benchmark Artifacts

> Inputs and reports for benchmarking `cli-moneybird`, kept beside the skill they measure.

---

## 1. OVERVIEW

This folder holds the benchmark inputs and the completed run reports for `cli-moneybird`. No benchmark runs have been recorded yet.

Future runs should evaluate whether an agent chooses the guarded CLI for API work, respects the read-only lock, confirmation and pilot gates, routes unsupported actions to the UI and verifies reads with explicit periods. Use the scenarios in the manual testing playbook as candidate prompts, and do not include live financial records or credentials in a report.

---

## 2. STRUCTURE

```text
benchmark/
+-- README.md      # This guide
`-- reports/       # One folder per run, indexed by reports/README.md
```

| Path | Contents |
|---|---|
| [`reports/`](./reports/) | One folder per run, indexed by `reports/README.md` |

---

## 3. USAGE EXAMPLES

Record each completed run in a dated folder under `reports/` and add it to that folder's index.

```text
benchmark/reports/<YYYY-MM-DD>--<subject>--<variant>/
```

The execution date names the folder. The index row names the folder, the runtime, the result, the verdict and the source packet.

---

## 4. RELATED RESOURCES

| Document | Purpose |
|---|---|
| [`reports/README.md`](./reports/README.md) | Index of completed run folders |
| [`../manual-testing-playbook/manual-testing-playbook.md`](../manual-testing-playbook/manual-testing-playbook.md) | Candidate scenarios for a benchmark run |
