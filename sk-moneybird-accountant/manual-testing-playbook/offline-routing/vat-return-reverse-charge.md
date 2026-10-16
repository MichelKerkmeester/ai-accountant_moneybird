---
title: "VAT-002 -- A VAT return quarter with a reverse-charged purchase"
description: "This scenario validates the reverse-charge branch of the VAT return preparation procedure, the rubriek 2a step and the stop before any filing action."
id: VAT-002
catalog_applicable: true
version: 1.0.0.0
---

# VAT-002 -- A VAT return (btw-aangifte) quarter with a reverse-charged purchase

This document captures the offline prompt, local read sequence, expected signals and evidence for VAT-002.

---

## 1. OVERVIEW

This scenario validates the reverse-charge branch of the prepare-the-VAT-return route. It focuses on the purchase line derivation, the rubriek 2a step and the review pack.

### Why This Matters

A reverse-charged purchase moves VAT between the purchase line and the return sections (rubrieken) without a supplier VAT charge. A missed 2a line or a deduction that is treated as automatic changes the payable amount, so this branch needs its own offline proof. A local-only check confirms the branch without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a reverse-charge quarter to the procedure, derive the rubriek 2a line from the purchase line and stop before any filing action.
- Real user request: Prepare the VAT return for the second quarter of 2026. One purchase is reverse-charged. Do not call an API.
- Prompt: Prepare the VAT return for the second quarter of 2026. One purchase is reverse-charged. Do not call an API.
- Fixture rows: VAT-BRANCH-RC-01 (the reverse-charge row) and vat-return-reverse-charge (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T10 route into the VAT return (btw-aangifte) procedure, read the section (rubriek) rules, derive the 2a line from the purchase line and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T10. The read set loads [the VAT return procedure](../../references/vat-return/README.md) and [the 2026 VAT figures](../../references/tax-rules/2026/vat/figures.md). The answer names the reverse charge purchase, the rubriek 2a line, the review pack blocks P1 to P9 and the Operator as the owner of the filing route. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the 2a derivation, the review pack blocks and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T10, the procedure and the year figures load, the answer names the reverse charge purchase and the 2a line, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called. FAIL if the reverse charge is missed, a pack block is absent, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the VAT return for the second quarter of 2026. One purchase is reverse-charged. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/vat-return/README.md, sk-moneybird-accountant/references/vat-return/return-boxes.md and sk-moneybird-accountant/references/tax-rules/2026/vat/figures.md
5. Derive the 2a line from the reverse-charged purchase line, assemble the review pack and stop before any filing action

### Expected

The check prints route-table: ok. The T10 row wins for the named VAT return (btw-aangifte). The procedure, the section (rubriek) rules and the 2026 VAT figures load. The answer names the reverse charge purchase, the rubriek 2a line, the pack blocks P1 to P9 and the Operator. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the 2a derivation, the pack block list and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T10, the reverse charge purchase and the 2a line are named, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called.
- **Fail**: The reverse charge is missed, the 2a line is absent, a pack block is absent, the answer states a filing action or an API is called.

### Failure Triage

Check the T10 row, the T4 conditional read terms and the T8 filing precedence in SKILL.md section 2, then the VAT-BRANCH-RC-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/vat-return-preparation.md) | Current feature summary and source anchors. |
| [the VAT return procedure](../../references/vat-return/README.md) | The procedure this scenario tests. |
| [the section (rubriek) table](../../references/vat-return/return-boxes.md) | The 2a line and the reverse-charge derivation. |
| [the review pack contract](../../references/vat-return/review-pack.md) | The pack blocks P1 to P9 and the confirmation parts. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [SKILL.md](../../SKILL.md) | The T10 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The VAT-BRANCH-RC-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The vat-return-reverse-charge case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: VAT-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/vat-return-reverse-charge.md
