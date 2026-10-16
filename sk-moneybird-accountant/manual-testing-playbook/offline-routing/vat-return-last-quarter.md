---
title: "VAT-004 -- The last VAT return quarter of the year"
description: "This scenario validates the last-quarter branch of the VAT return preparation procedure and the four year-end settlements S1 to S4 it runs before the review pack."
id: VAT-004
catalog_applicable: true
version: 1.0.0.0
---

# VAT-004 -- The last VAT return (btw-aangifte) quarter of the year

This document captures the offline prompt, local read sequence, expected signals and evidence for VAT-004.

---

## 1. OVERVIEW

This scenario validates the last-quarter branch of the prepare-the-VAT-return route. It focuses on the four year-end settlements, the review pack and the stop before any filing action.

### Why This Matters

The final period of a calendar year carries settlements for private use (privégebruik), the business car, the taxed and exempt turnover (vrijgestelde omzet) split and the BUA correction. A branch that skips them sends an incomplete final return, so each settlement needs its own offline proof. A local-only check confirms the branch without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a final-quarter VAT return (btw-aangifte) request to the procedure, run the four settlements and stop before any filing action.
- Real user request: Prepare the VAT return for the last quarter of 2026 and run the year-end settlements before the pack. Do not call an API.
- Prompt: Prepare the VAT return for the last quarter of 2026 and run the year-end settlements before the pack. Do not call an API.
- Fixture rows: VAT-BRANCH-YE-01 (the last-quarter row) and vat-return-last-quarter (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T10 route into the VAT return procedure, run the four settlements S1 to S4, assemble the review pack and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T10. The read set loads [the VAT return procedure](../../references/vat-return/README.md) and [the 2026 VAT figures](../../references/tax-rules/2026/vat/figures.md). The answer names the four settlements S1 to S4, the review pack blocks P1 to P9 and the Operator as the owner of the filing route. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the settlement list, the review pack blocks and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T10, the procedure and the year figures load, the answer names S1 to S4, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called. FAIL if a settlement is missing, a pack block is absent, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the VAT return for the last quarter of 2026 and run the year-end settlements before the pack. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/vat-return/README.md, sk-moneybird-accountant/references/vat-return/year-end-and-corrections.md and sk-moneybird-accountant/references/tax-rules/2026/vat/figures.md
5. Run the settlements S1 to S4, assemble the review pack and stop before any filing action

### Expected

The check prints route-table: ok. The T10 row wins for the named VAT return (btw-aangifte). The procedure, the year-end rules and the 2026 VAT figures load. The answer names the four settlements S1 to S4, the pack blocks P1 to P9 and the Operator. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the settlement list with its owner tags, the pack block list and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T10, the settlements S1 to S4 are named, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called.
- **Fail**: A settlement is missing, a pack block is absent, the answer states a filing action or an API is called.

### Failure Triage

Check the T10 row and the T8 filing precedence in SKILL.md section 2, then the VAT-BRANCH-YE-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/vat-return-preparation.md) | Current feature summary and source anchors. |
| [the VAT return procedure](../../references/vat-return/README.md) | The procedure this scenario tests. |
| [the year-end and correction rules](../../references/vat-return/year-end-and-corrections.md) | The settlements S1 to S4 and the correction routing. |
| [the review pack contract](../../references/vat-return/review-pack.md) | The pack blocks P1 to P9 and the confirmation parts. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [SKILL.md](../../SKILL.md) | The T10 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The VAT-BRANCH-YE-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The vat-return-last-quarter case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: VAT-004
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/vat-return-last-quarter.md
