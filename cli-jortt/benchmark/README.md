---
title: "cli-jortt Benchmark Artifacts"
description: "Benchmark inputs and future reports for the Jortt extraction and routing skill."
trigger_phrases:
  - "cli-jortt benchmark"
  - "Jortt skill benchmark"
importance_tier: important
contextType: general
version: 1.0.0.0
---

# cli-jortt Benchmark Artifacts

> Benchmark material for the Jortt extraction and routing skill. No benchmark runs have been recorded yet.

---

## 1. OVERVIEW

A benchmark run can score the skill against the manual scenarios, CLI contract and request routing. Keep the prompts and expected outcomes stable so later runs can be compared. A run must not copy extracted bookkeeping records into the report.

No runs have been performed. Do not report a score or verdict until a dated run folder exists.

---

## 2. STRUCTURE

```text
benchmark/
+-- README.md             # This overview
`-- reports/              # Curated index of future run folders
    `-- README.md
```

| Path | Contents |
|---|---|
| [`reports/`](reports/) | Curated index of future run folders |
| [`../manual-testing-playbook/manual-testing-playbook.md`](../manual-testing-playbook/manual-testing-playbook.md) | Scenario inputs for a manual review |
| [`../cli/jortt-cli/tests/run-tests.sh`](../cli/jortt-cli/tests/run-tests.sh) | Offline deterministic CLI checks |
