---
title: "VAT-005 -- A VAT return correction on both sides of the boundary"
description: "This scenario validates the correction branch of the VAT return preparation procedure, where a correction below the boundary joins the next return and one above it follows the supplementary return (suppletie) route."
id: VAT-005
catalog_applicable: true
version: 1.0.0.0
---

# VAT-005 -- A VAT return (btw-aangifte) correction on both sides of the boundary

This document captures the offline prompt, local read sequence, expected signals and evidence for VAT-005.

---

## 1. OVERVIEW

This scenario validates the correction branch of the prepare-the-VAT-return route. It focuses on the two routes a correction can take and the review pack that names each one.

### Why This Matters

A correction at or below the boundary belongs in the next regular return while a correction above it follows the supplementary return (suppletie) route on top of the period history. Sending both the same way, or leaving the boundary to memory, hides a real correction. A local-only check confirms the branch without calling a service and without restating a figure the year file owns.

---

## 2. SCENARIO CONTRACT

- Objective: Route a quarter with corrections on both sides of the boundary to the procedure, name each route and stop before any filing action.
- Real user request: Prepare the VAT return for the fourth quarter of 2026. One correction from an earlier quarter is below the correction boundary and one is above it. Do not call an API.
- Prompt: Prepare the VAT return for the fourth quarter of 2026. One correction from an earlier quarter is below the correction boundary and one is above it. Do not call an API.
- Fixture rows: VAT-BRANCH-COR-01 (the boundary correction row) and vat-return-correction-boundary (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T10 route into the VAT return (btw-aangifte) procedure, read the correction routing, name the below-boundary and above-boundary routes, assemble the review pack and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T10. The read set loads [the VAT return procedure](../../references/vat-return/README.md) and [the 2026 VAT figures](../../references/tax-rules/2026/vat/figures.md). The answer names the next regular return for the correction below the boundary, the supplementary return route for the correction above it, the review pack blocks P1 to P9 and the Operator as the owner of both routes. The boundary itself comes from the year file and is never stated from memory. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the two correction routes, the review pack blocks and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T10, the procedure and the year figures load, the answer names the next regular return below the boundary and the supplementary return route above it, the pack blocks P1 to P9 are named, the Operator owns both routes and no API is called. FAIL if the correction below the boundary is sent to the supplementary return route, a pack block is absent, the boundary is stated from memory, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the VAT return for the fourth quarter of 2026. One correction from an earlier quarter is below the correction boundary and one is above it. Do not call an API.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py
4. Read sk-moneybird-accountant/references/vat-return/README.md, sk-moneybird-accountant/references/vat-return/year-end-and-corrections.md and sk-moneybird-accountant/references/tax-rules/2026/vat/figures.md
5. Name the next regular return for the correction below the boundary and the supplementary return route for the correction above it, assemble the review pack and stop before any filing action

### Expected

The check prints route-table: ok. The T10 row wins for the named VAT return (btw-aangifte). The procedure, the correction routing and the 2026 VAT figures load. The answer names the next regular return for the below-boundary correction, the supplementary return route for the above-boundary correction, the pack blocks P1 to P9 and the Operator. The boundary is read from the year file. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, both correction routes with their Operator ownership, the pack block list and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T10, both correction routes are named correctly, the pack blocks P1 to P9 are named, the Operator owns the routes and no API is called.
- **Fail**: The correction below the boundary is sent to the supplementary return route, a pack block is absent, the boundary is stated from memory, the answer states a filing action or an API is called.

### Failure Triage

Check the T10 row, the correction phrases and the T8 filing precedence in ROUTER.md section 2, then the VAT-BRANCH-COR-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/vat-return-preparation.md) | Current feature summary and source anchors. |
| [the VAT return procedure](../../references/vat-return/README.md) | The procedure this scenario tests. |
| [the year-end and correction rules](../../references/vat-return/year-end-and-corrections.md) | The two correction routes and their owners. |
| [the review pack contract](../../references/vat-return/review-pack.md) | The pack blocks P1 to P9 and the confirmation parts. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [ROUTER.md](../../ROUTER.md) | The T10 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The VAT-BRANCH-COR-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The vat-return-correction-boundary case. |

---

## 5. SOURCE METADATA

- Group: vat-and-tax-returns
- Playbook ID: VAT-005
- Canonical root source: manual-testing-playbook.md
- Feature file path: vat-and-tax-returns/vat-return-correction-boundary.md
