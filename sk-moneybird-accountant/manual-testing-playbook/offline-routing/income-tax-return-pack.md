---
title: "PACK-002 -- The income tax return pack"
description: "This scenario validates the income tax return preparation route, the pack blocks, the Operator input list with a status per item, the VIA comparison sheet, the dated per-asset register, the labelled residual unknowns and the prepared-not-filed stop."
id: PACK-002
catalog_applicable: true
version: 1.0.0.0
---

# PACK-002 -- The income tax return (aangifte inkomstenbelasting) pack

This document captures the offline prompt, local read sequence, expected signals and evidence for PACK-002.

---

## 1. OVERVIEW

This scenario validates the T12 prepare-the-income-tax-return route. It focuses on the ordered cross-year procedure, the Operator input list, the VIA comparison sheet, the per-asset register and the residual unknowns that stay labelled.

### Why This Matters

An income tax return (aangifte inkomstenbelasting) is assembled from administration reads plus Operator facts. A field that no source settles must stay labelled instead of being filled from memory, and every item must carry a disposition. A local-only check confirms the route without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route an income tax return (aangifte inkomstenbelasting) request to the procedure, assemble the pack blocks, list the Operator inputs with a status per item and keep every residual unknown labelled.
- Real user request: Prepare my income tax return for 2026 and show the review pack with every open input. Do not call an API.
- Prompt: Prepare my income tax return for 2026 and show the review pack with every open input. Do not call an API.
- Fixture rows: PACK-INCOME-01 (the income tax pack row) and income-tax-return-pack (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T12 route into the income tax return procedure, resolve the return year, run the steps and evidence gates, assemble the review pack, the Operator input list, the VIA comparison sheet and the dated per-asset register, and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T12. The read set loads [the income tax return procedure](../../references/income-tax-return/README.md), [the 2026 year README](../../references/tax-rules/2026/README.md) and the year figures the route needs. The answer names the pack blocks P1 to P9, the confirmation parts C1 to C3, the deduction chain block, the VIA comparison sheet block, the residual unknowns block and the Operator input list with one disposition per item, namely supplied, reconciled, confirmed, not applicable or unresolved. The dated per-asset register carries its order, payment and in-use dates. Every residual unknown stays labelled unresolved with what would settle it and no figure is filled from memory. The pack states prepared, not filed. The Operator owns the filing and payment. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the pack blocks, the Operator input list, the comparison sheet, the per-asset register, the labelled residual unknowns and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T12, the pack blocks and confirmation parts are present, every Operator input carries a status, the comparison sheet and the per-asset register are present, every residual unknown stays labelled, the pack states prepared and not filed, the Operator owns the filing and payment and no API is called. FAIL if an input has no status, an unresolved field is stated as settled, a pack block is missing, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare my income tax return for 2026 and show the review pack with every open input. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/income-tax-return/README.md, sk-moneybird-accountant/references/income-tax-return/procedure.md and sk-moneybird-accountant/references/income-tax-return/operator-inputs.md
5. Assemble the review pack with the Operator input list, the VIA comparison sheet, the dated per-asset register and the labelled residual unknowns, then stop before any filing action

### Expected

The check prints route-table: ok. The T12 row wins for the named income tax return (aangifte inkomstenbelasting). The procedure, the Operator inputs and the register load. The answer names the pack blocks P1 to P9, the confirmation parts C1 to C3, the deduction chain block, the VIA comparison sheet block, the residual unknowns block and the Operator input list with a status per item, namely supplied, reconciled, confirmed, not applicable or unresolved. The dated per-asset register carries its order, payment and in-use dates and every residual unknown stays labelled unresolved. The pack states prepared, not filed. The Operator owns the filing and payment. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the pack block list, the Operator input statuses, the comparison sheet, the per-asset register and the labelled residual unknowns.

### Pass / Fail

- **Pass**: The request routes LIVE and T12, the pack blocks and confirmation parts are present, every input carries a status, the comparison sheet and the per-asset register are present, the residual unknowns stay labelled, the pack states prepared and not filed, the Operator owns the filing and payment and no API is called.
- **Fail**: An input has no status, an unresolved field is stated as settled, a pack block is missing, the answer states a filing action or an API is called.

### Failure Triage

Check the T12 row and the T8 filing precedence in ROUTER.md section 2, then the PACK-INCOME-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/income-tax-return-preparation.md) | Current feature summary and source anchors. |
| [the income tax return procedure](../../references/income-tax-return/README.md) | The procedure this scenario tests. |
| [the ordered procedure](../../references/income-tax-return/procedure.md) | The steps, the evidence gates and the review pack differences. |
| [the Operator inputs](../../references/income-tax-return/operator-inputs.md) | The input list and the disposition vocabulary. |
| [the investment and claim register](../../references/income-tax-return/investment-and-claim-register.md) | The dated per-asset register. |
| [the risks and open points](../../references/income-tax-return/risks-and-open-points.md) | The residual unknowns with their unresolved label. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [ROUTER.md](../../ROUTER.md) | The T12 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The PACK-INCOME-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The income-tax-return-pack case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: PACK-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/income-tax-return-pack.md
