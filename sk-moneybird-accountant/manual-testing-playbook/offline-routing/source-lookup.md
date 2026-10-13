---
title: TAX-003 -- Source lookup
description: This scenario validates External source library for TAX-003. It focuses on offline routing and policy.
id: TAX-003
catalog_applicable: true
version: 1.0.0.0
---

# TAX-003 -- Source lookup

This document captures the offline prompt, local read sequence, expected signals, and evidence for TAX-003.

---

## 1. OVERVIEW

This scenario validates External source library. It focuses on routing a request for the official source of a rule to the source library and its index.

### Why This Matters

A figure is only as good as the page behind it. An agent that cannot find the source, or that cites a dead or unreachable page, presents an unchecked claim as sourced. A local-only check confirms the route without touching accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route a request for the official VAT law text to the source library and its index.
- Real user request: Where is the official text of the Dutch VAT law, and how do I read the article on reverse charge? Keep this as an offline routing check.
- Prompt: Where is the official text of the Dutch VAT law, and how do I read the article on reverse charge? Keep this as an offline routing check.
- Fixture rows: TAX-003 (en) and TAX-003-nl (nl twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Names the source library reference, finds Wet op de omzetbelasting 1968 under BWBR0002629 in the statute table, says the access value is webfetch-only, advises asking WebFetch for one article or reading on with an offset, and greps the index instead of reading it whole.
- Desired user-visible outcome: A concise route report with the reference path, the law and its identifier, the access method, and no network or API activity.
- Pass/fail: PASS if The response routes to the source library, names BWBR0002629 and the WebFetch-only access method, and greps the index. FAIL if The response reads the whole index, guesses a URL, fetches a page during the offline check, or calls an accounting API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| TAX-003 | External source library | Route a request for the official VAT law text to the source library and its index. | Where is the official text of the Dutch VAT law, and how do I read the article on reverse charge? Keep this as an offline routing check. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/source-library.md -> 4. Grep assets/source-library.json for BWBR0002629 -> 5. Report the reference, the law, the access method and the absence of network activity | Names the source library reference, finds Wet op de omzetbelasting 1968 under BWBR0002629 in the statute table, says the access value is webfetch-only, advises asking WebFetch for one article or reading on with an offset, and greps the index instead of reading it whole. | Capture the prompt, reference path, law identifier, access value and no-network confirmation. | PASS if The response routes to the source library, names BWBR0002629 and the WebFetch-only access method, and greps the index. FAIL if The response reads the whole index, guesses a URL, fetches a page during the offline check, or calls an accounting API. | Check the bootstrap's step 2 pointer to the Task-Type Table, the T5 tax figure row of the Task-Type Table in the skill and section 2 of the reference. Repeat without tool access. |

### Prompt

- Prompt: Where is the official text of the Dutch VAT law, and how do I read the article on reverse charge? Keep this as an offline routing check.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/source-library.md
4. Grep assets/source-library.json for BWBR0002629
5. Report the reference, the law, the access method and the absence of network activity

### Expected

Names the source library reference, finds Wet op de omzetbelasting 1968 under BWBR0002629 in the statute table, says the access value is webfetch-only, advises asking WebFetch for one article or reading on with an offset, and greps the index instead of reading it whole.

### Evidence

Capture the prompt, reference path, law identifier, access value and no-network confirmation.

### Pass / Fail

- **Pass**: The response routes to the source library, names BWBR0002629 and the WebFetch-only access method, and greps the index.
- **Fail**: The response reads the whole index, guesses a URL, fetches a page during the offline check, or calls an accounting API.

### Failure Triage

Check the bootstrap's step 2 pointer to the Task-Type Table, the T5 tax figure row of the Task-Type Table in the skill and section 2 of the reference. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/external-source-library.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/source-library.md | Groups the sources and explains each access class |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/assets/source-library.json | Holds one row per source with its access result |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/assets/source-watchlist.json | Lists the publication series the monthly watch checks |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/year-rollover.md | Holds the rollover runbook and the release calendar |
| AI Systems/Moneybird Accountant/AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: TAX-003
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/source-lookup.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/source-library.md -> 4. Grep assets/source-library.json for BWBR0002629 -> 5. Report the reference, the law, the access method and the absence of network activity

**Expected resources:** references/source-library.md
