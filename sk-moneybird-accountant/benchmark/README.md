---
title: sk-moneybird-accountant Benchmark Artifacts
description: Offline routing benchmark structure for the sk-moneybird-accountant skill.
trigger_phrases:
  - sk-moneybird-accountant benchmark
  - offline bookkeeping routing review
importance_tier: normal
contextType: general
version: 1.0.0.0
---

# sk-moneybird-accountant Benchmark Artifacts

This folder stores evidence from completed offline routing runs for the bookkeeping and migration skill.

---

## 1. OVERVIEW

Use the manual playbook scenarios to assess mode selection, reference routing, tool handoffs, tax boundaries, and privacy behavior. A run must not call Jortt, Moneybird, web, or tax authority APIs.

---

## 2. LAYOUT

| Path | Contents |
|---|---|
| [reports/](./reports/) | One folder per completed run, indexed by reports/README.md |

The manual scenario corpus is in manual-testing-playbook/. The corpus is an input and is not rewritten by a run.
