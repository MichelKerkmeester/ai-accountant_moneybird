---
title: LIVE-001 -- Live monthly bookkeeping
description: This scenario validates Live monthly bookkeeping for LIVE-001. It focuses on offline routing and policy.
id: LIVE-001
catalog_applicable: true
version: 1.0.0.0
---

# LIVE-001 -- Live monthly bookkeeping

This document captures the offline prompt, local read sequence, expected signals and evidence for LIVE-001.

---

## 1. OVERVIEW

This scenario validates Live monthly bookkeeping. It focuses on Route a current-period reconciliation request into LIVE monthly bookkeeping.

### Why This Matters

A local-only check can confirm that the skill chooses its mode and references while keeping accounting tools and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Route a current-period reconciliation request into LIVE monthly bookkeeping.
- Real user request: Help me review this month's Moneybird bookkeeping. Which steps and reference apply? Keep this as an offline routing check.
- Prompt: Help me review this month's Moneybird bookkeeping. Which steps and reference apply? Keep this as an offline routing check.
- Fixture rows: LIVE-001 (en) and LIVE-001-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects LIVE, lists sales, purchase records, bank matching, private movements, and exceptions, and names the bookkeeping reference.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result and no API activity.
- Pass/fail: PASS if The response routes to LIVE monthly work and names the required checks without external access. FAIL if The response selects MIGRATION, skips the bookkeeping reference or calls a Moneybird API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| LIVE-001 | Live monthly bookkeeping | Route a current-period reconciliation request into LIVE monthly bookkeeping. | Help me review this month's Moneybird bookkeeping. Which steps and reference apply? Keep this as an offline routing check. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md -> 4. Report the selected mode, monthly checks and relevant reference without calling an API | Selects LIVE, lists sales, purchase records, bank matching, private movements and exceptions and names the bookkeeping reference. | Capture the prompt, selected mode, listed monthly checks, reference path and no-API confirmation. | PASS if The response routes to LIVE monthly work and names the required checks without external access. FAIL if The response selects MIGRATION, skips the bookkeeping reference or calls a Moneybird API. | Check the monthly intent, the LIVE section and the reference-loading instructions. Repeat without tool access. |

### Prompt

- Prompt: Help me review this month's Moneybird bookkeeping. Which steps and reference apply? Keep this as an offline routing check.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md
4. Report the selected mode, monthly checks and relevant reference without calling an API

### Expected

Selects LIVE, lists sales, purchase records, bank matching, private movements, and exceptions, and names the bookkeeping reference.

### Evidence

Capture the prompt, selected mode, listed monthly checks, reference path and no-API confirmation.

### Pass / Fail

- **Pass**: The response routes to LIVE monthly work and names the required checks without external access.
- **Fail**: The response selects MIGRATION, skips the bookkeeping reference or calls a Moneybird API.

### Failure Triage

Check the monthly intent, the LIVE section and the reference-loading instructions. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: LIVE-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/live-monthly-bookkeeping.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/moneybird-bookkeeping.md -> 4. Report the selected mode, monthly checks and relevant reference without calling an API

**Expected resources:** sk-moneybird-accountant/references/moneybird-bookkeeping.md
