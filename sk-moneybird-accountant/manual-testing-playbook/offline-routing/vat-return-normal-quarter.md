---
title: "VAT-001 -- The normal VAT return quarter"
description: "This scenario validates the normal-quarter branch of the VAT return preparation procedure, the review pack blocks it names and the stop before any filing action."
id: VAT-001
catalog_applicable: false
version: 1.0.0.0
---

# VAT-001 -- The normal VAT return quarter

This document captures the offline prompt, local read sequence, expected signals and evidence for VAT-001.

---

## 1. OVERVIEW

This scenario validates the normal-quarter branch of the prepare-the-VAT-return route. It focuses on the review pack blocks, the ordered checks and the refusal to file.

### Why This Matters

A quarter without a reverse-charged purchase, a KOR case or a year-end settlement is the base branch every other branch extends. A missing pack block or a claimed filing action on this branch would travel into every other branch. A local-only check confirms the branch without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a normal-quarter VAT return request to the procedure, assemble the review pack and stop before any filing action.
- Real user request: Prepare the VAT return for the first quarter of 2026. Do not call an API.
- Prompt: Prepare the VAT return for the first quarter of 2026. Do not call an API.
- Fixture rows: VAT-BRANCH-Q1-01 (the normal quarter row) and vat-return-normal-quarter (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T10 route into the VAT return procedure, run the ordered checks, assemble the review pack and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T10. The read set loads [the VAT return procedure](../../references/vat-return/README.md) and [the 2026 VAT figures](../../references/tax-rules/2026/vat/figures.md). The answer names the review pack blocks P1 to P9, reports the period as prepared and names the Operator as the owner of the filing route. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the review pack blocks, the exception list state and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T10, the procedure and the year figures load, the answer names the pack blocks P1 to P9, the answer reports prepared and the Operator owns the filing route, and no API is called. FAIL if a preparation path is missing, a pack block is absent, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the VAT return for the first quarter of 2026. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/vat-return/README.md and sk-moneybird-accountant/references/tax-rules/2026/vat/figures.md
5. Assemble the review pack blocks P1 to P9 and stop before any filing action

### Expected

The check prints route-table: ok. The T10 row wins for the named VAT return. The procedure and the 2026 VAT figures load. The answer names the pack blocks P1 to P9, reports prepared and keeps the filing route with the Operator. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the pack block list, the prepared statement and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T10, the procedure and the year figures load, the pack blocks P1 to P9 are named, the answer reports prepared, the Operator owns the filing route and no API is called.
- **Fail**: A preparation path is missing, a pack block is absent, the answer states a filing action or an API is called.

### Failure Triage

Check the T10 row and the T8 filing precedence in SKILL.md section 2, then the VAT-BRANCH-Q1-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [the VAT return procedure](../../references/vat-return/README.md) | The procedure this scenario tests. |
| [the review pack contract](../../references/vat-return/review-pack.md) | The pack blocks P1 to P9 and the confirmation parts. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [SKILL.md](../../SKILL.md) | The T10 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The VAT-BRANCH-Q1-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The vat-return-normal-quarter case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: VAT-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/vat-return-normal-quarter.md
