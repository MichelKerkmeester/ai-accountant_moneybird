---
title: SRC-PDF-01 -- PDF source list
description: This scenario validates the PDF source reader for SRC-PDF-01. It focuses on offline routing and policy.
id: SRC-PDF-01
catalog_applicable: true
version: 1.0.0.0
---

# SRC-PDF-01 -- PDF source list

This document captures the offline prompt, local read sequence, expected signals and evidence for SRC-PDF-01.

---

## 1. OVERVIEW

This scenario validates the PDF source reader. It focuses on routing a request about the PDF-only sources to the source library and on listing the readable rows offline.

### Why This Matters

A PDF row is only as good as the text layer behind it. An agent that downloads a source during an offline check, or that claims a PDF confirms a figure from a list, presents an unchecked claim as sourced. The list mode proves the route and the rows without a network call.

---

## 2. SCENARIO CONTRACT

- Objective: Route a request about the PDF-only sources to the source library guide and list the readable rows offline.
- Real user request: Which PDF-only sources can you read, and how do you read one? Keep this as an offline routing check.
- Prompt: Which PDF-only sources can you read, and how do you read one? Keep this as an offline routing check.
- Fixture rows: SRC-PDF-01 (English) and SRC-PDF-01-nl (Dutch twin).
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references and run only the offline list command. Do not use network access or accounting APIs.
- Expected signals: Names the source library reference, runs `python3 -I sk-moneybird-accountant/scripts/read-pdf-source.py --list`, reports the `pdf-needs-reader` access value, states that the reader reads the text layer only and keeps the HTML page and the Operator as the fallbacks for an extraction with no text.
- Desired user-visible outcome: A concise route report with the reference path, the reader, the url and title per row and no network or API activity.
- Pass/fail: PASS if The response routes to the source library, runs the offline list, names the `pdf-needs-reader` access and the text-layer limit and makes no download. FAIL if The response downloads a PDF, reads the whole index, guesses a URL, claims a PDF confirms a figure or calls an accounting API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Run the offline list command.
4. Compare the observed route to the expected signals.
5. Record a concise verdict and evidence without a download or an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| SRC-PDF-01 | PDF source reader | Route a request about the PDF-only sources to the source library and list the readable rows offline. | Which PDF-only sources can you read, and how do you read one? Keep this as an offline routing check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read section 2 of sk-moneybird-accountant/references/tax-rules/source-library.md -> 4. Run python3 -I sk-moneybird-accountant/scripts/read-pdf-source.py --list -> 5. Report the reference, the rows, the access method and the absence of network activity | Names the source library reference, runs the offline list, reports the `pdf-needs-reader` access value, states that the reader reads the text layer only and keeps the HTML page and the Operator as the fallbacks. | Capture the prompt, reference path, list command, one url and title row and no-network confirmation. | PASS if The response routes to the source library, runs the offline list, names the `pdf-needs-reader` access and the text-layer limit and makes no download. FAIL if The response downloads a PDF, reads the whole index, guesses a URL, claims a PDF confirms a figure or calls an accounting API. | Check the bootstrap's step 2 pointer to the Task-Type Table, the T5 tax figure row of the Task-Type Table in the skill's `ROUTER.md` and section 2 of the reference. Repeat without tool access. |

### Prompt

- Prompt: Which PDF-only sources can you read, and how do you read one? Keep this as an offline routing check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read section 2 of sk-moneybird-accountant/references/tax-rules/source-library.md
4. Run `python3 -I sk-moneybird-accountant/scripts/read-pdf-source.py --list`
5. Report the reference, the rows, the access method and the absence of network activity

### Expected

Names the source library reference, runs the offline list, reports the `pdf-needs-reader` access value, states that the reader reads the text layer only and keeps the HTML page and the Operator as the fallbacks for an extraction with no text.

### Evidence

Capture the prompt, reference path, list command, one url and title row and no-network confirmation.

### Pass / Fail

- **Pass**: The response routes to the source library, runs the offline list, names the `pdf-needs-reader` access and the text-layer limit and makes no download.
- **Fail**: The response downloads a PDF, reads the whole index, guesses a URL, claims a PDF confirms a figure or calls an accounting API.

### Failure Triage

Check the bootstrap's step 2 pointer to the Task-Type Table, the T5 tax figure row of the Task-Type Table in the skill's `ROUTER.md` and section 2 of the reference. Repeat without tool access.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/reference-and-state/pdf-source-reader.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/ROUTER.md | Defines mode and reference routing |
| sk-moneybird-accountant/references/tax-rules/source-library.md | States the access table whose `pdf-needs-reader` row names the reader |
| sk-moneybird-accountant/assets/source-library.json | Holds one row per source with its access result |
| sk-moneybird-accountant/scripts/read-pdf-source.py | Lists the readable rows and reads one indexed PDF through pdftotext |
| sk-moneybird-accountant/scripts/read-pdf-source-test.sh | Proves the list mode and the read paths offline |
| AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: tax-guidance-and-sources
- Playbook ID: SRC-PDF-01
- Canonical root source: manual-testing-playbook.md
- Feature file path: tax-guidance-and-sources/pdf-source-list.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read section 2 of sk-moneybird-accountant/references/tax-rules/source-library.md -> 4. Run python3 -I sk-moneybird-accountant/scripts/read-pdf-source.py --list -> 5. Report the reference, the rows, the access method and the absence of network activity

**Expected resources:** sk-moneybird-accountant/references/tax-rules/source-library.md
