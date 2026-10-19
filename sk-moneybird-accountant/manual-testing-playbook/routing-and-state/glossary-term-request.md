---
title: GLOSS-001 -- Glossary term request
description: This scenario validates Glossary term request for GLOSS-001. It focuses on offline routing and policy.
id: GLOSS-001
catalog_applicable: true
version: 1.0.0.0
---

# GLOSS-001 -- Glossary term request

This document captures the offline prompt, local read sequence, expected signals and evidence for GLOSS-001.

---

## 1. OVERVIEW

This scenario validates Glossary term request. It focuses on Route a request that asks what a Dutch term means to the glossary file of the topic its route loads.

### Why This Matters

A local-only check can confirm that a term request reads the one small glossary file it needs, and that a request that asks no meaning reads none.

---

## 2. SCENARIO CONTRACT

- Objective: Route a request that asks what a Dutch term means to the glossary file of the topic its route loads.
- Real user request: What is the business mileage rate for the current tax year, and what does kilometervergoeding mean in English?
- Prompt: What is the business mileage rate for the current tax year, and what does kilometervergoeding mean in English?
- Fixture rows: GLOSS-001 (English) and GLOSS-001-nl (Dutch twin) on the tax figure route, GLOSS-002 (English) and GLOSS-002-nl (Dutch twin) on the purchase invoice (inkoopfactuur) route, and GLOSS-003 (English), a figure request that asks no meaning.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Loads the figures part of the topic, then the glossary router, that topic's glossary file and `general.md` for the year README, and gives the English name with the Dutch in brackets.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result and no API activity.
- Pass/fail: PASS if The route reads `references/glossary/README.md`, `references/glossary/costs-and-car.md` and `references/glossary/general.md` and names the term as "mileage allowance (kilometervergoeding)". FAIL if The route reads no glossary file, reads a glossary file of a topic it did not load or reads one for a request that asks no meaning.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GLOSS-001 | Glossary term request | Route a request that asks what a Dutch term means to the glossary file of the topic its route loads. | What is the business mileage rate for the current tax year, and what does kilometervergoeding mean in English? | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md -> 4. Read sk-moneybird-accountant/references/glossary/README.md, sk-moneybird-accountant/references/glossary/costs-and-car.md and sk-moneybird-accountant/references/glossary/general.md -> 5. Report the selected row, the reads and the English name | Loads the figures part of the topic, then the glossary router, that topic's glossary file and `general.md` for the year README, and gives the English name with the Dutch in brackets. | Capture the prompt, the read list and the glossary row cited. | PASS if The route reads the router, the costs-and-car glossary and `general.md` and names "mileage allowance (kilometervergoeding)". FAIL if The route reads no glossary file, the wrong topic's glossary or a glossary for a request that asks no meaning. | Check the term request words in the resolver and the topic of each read. Repeat with only local documents. |

### Prompt

- Prompt: What is the business mileage rate for the current tax year, and what does kilometervergoeding mean in English?

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md
4. Read sk-moneybird-accountant/references/glossary/README.md, sk-moneybird-accountant/references/glossary/costs-and-car.md and sk-moneybird-accountant/references/glossary/general.md
5. Report the selected row, the reads and the English name

### Expected

Loads the figures part of the topic, then the glossary router, that topic's glossary file and `general.md` for the year README, and gives the English name with the Dutch in brackets.

### Evidence

Capture the prompt, the read list and the glossary row cited.

### Pass / Fail

- **Pass**: The route reads the router, the costs-and-car glossary and `general.md` and names "mileage allowance (kilometervergoeding)".
- **Fail**: The route reads no glossary file, the wrong topic's glossary or a glossary for a request that asks no meaning.

### Failure Triage

Check the term request words in the resolver and the topic of each read. Repeat with only local documents.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/reference-and-state/glossary-router.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/ROUTER.md | States the glossary read rule |
| sk-moneybird-accountant/references/glossary/README.md | Lists the category files and the placement rule |
| sk-moneybird-accountant/scripts/route-replay/routing-gold.json | Holds the seventeen GLOSS rows |

---


## 5. SOURCE METADATA

- Group: routing-and-state
- Playbook ID: GLOSS-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: routing-and-state/glossary-term-request.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/YYYY/README.md and sk-moneybird-accountant/references/tax-rules/YYYY/costs-and-car/figures.md -> 4. Read sk-moneybird-accountant/references/glossary/README.md, sk-moneybird-accountant/references/glossary/costs-and-car.md and sk-moneybird-accountant/references/glossary/general.md -> 5. Report the selected row, the reads and the English name

**Expected resources:** sk-moneybird-accountant/references/glossary/README.md, sk-moneybird-accountant/references/glossary/costs-and-car.md and sk-moneybird-accountant/references/glossary/general.md after the topic figures part
