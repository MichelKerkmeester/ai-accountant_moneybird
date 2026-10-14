---
title: "PACK-001 -- The yearly overview pack"
description: "This scenario validates the yearly overview preparation route, the auditfile-first order, the equity-continuity check, the exception list and the prepared-not-filed stop."
id: PACK-001
catalog_applicable: false
version: 1.0.0.0
---

# PACK-001 -- The yearly overview pack

This document captures the offline prompt, local read sequence, expected signals and evidence for PACK-001.

---

## 1. OVERVIEW

This scenario validates the T11 prepare-the-yearly-overview route. It focuses on the ordered close steps, the auditfile evidence gate, the equity-continuity check, the exception list and the stop before the jaarafsluiting.

### Why This Matters

A jaarafsluiting before the auditfile export can strip the profit and loss data from the auditfile, so the order is itself evidence. The equity check and the exception list carry the judgement rows the Operator owns. A local-only check confirms the route without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a yearly overview request to the procedure, run the auditfile-first gate, check the equity and the exception list and stop before the jaarafsluiting.
- Real user request: Prepare the yearly overview for 2026 and show the review pack before the jaarafsluiting. Do not call an API.
- Prompt: Prepare the yearly overview for 2026 and show the review pack before the jaarafsluiting. Do not call an API.
- Fixture rows: PACK-YEARLY-01 (the yearly overview pack row) and yearly-overview-pack (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T11 route into the yearly overview procedure, export the auditfile before any closing action, run the close checks, tie the opening balance, run the equity-continuity check, assemble the pack with the exception list and stop before the jaarafsluiting. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T11. The read set loads [the yearly overview procedure](../../references/yearly-overview/README.md) and the year figures the route needs. The answer names the auditfile export before any closing action, the balance, the profit and loss account, the fiscal reconciliation, the three-column hand-off, the equity-continuity check, the exception list and the Operator as the owner of the closing actions. The pack reports prepared and does not state that anything was filed. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the pack blocks, the auditfile order, the equity check, the exception list and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T11, the auditfile export stands before the jaarafsluiting, the equity-continuity check and the exception list are present, the pack reports prepared with the Operator as the owner of the closing actions and no API is called. FAIL if the order is reversed, the equity check or the exception list is missing, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the yearly overview for 2026 and show the review pack before the jaarafsluiting. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/yearly-overview/README.md, sk-moneybird-accountant/references/yearly-overview/preparation-checklist.md and sk-moneybird-accountant/references/yearly-overview/fiscal-reconciliation.md
5. Export the auditfile first, run the close checks and the equity-continuity check, assemble the pack with the exception list and stop before the jaarafsluiting

### Expected

The check prints route-table: ok. The T11 row wins for the named yearly overview. The procedure, the preparation checklist and the fiscal reconciliation load. The answer names the auditfile export before any closing action, the balance, the profit and loss account, the fiscal reconciliation, the three-column hand-off, the equity-continuity check, the exception list and the Operator. The pack reports prepared. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the auditfile order, the equity check, the exception list with its owners and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T11, the auditfile-first order holds, the equity-continuity check and the exception list are present, the pack reports prepared, the Operator owns the closing actions and no API is called.
- **Fail**: The order is reversed, the equity check or the exception list is missing, the answer states a filing action, the pack claims a completed close or an API is called.

### Failure Triage

Check the T11 row and the T8 filing precedence in SKILL.md section 2, then the PACK-YEARLY-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [the yearly overview procedure](../../references/yearly-overview/README.md) | The procedure this scenario tests. |
| [the preparation checklist](../../references/yearly-overview/preparation-checklist.md) | The auditfile-first gate, the close checks, the equity check and the exception list. |
| [the fiscal reconciliation](../../references/yearly-overview/fiscal-reconciliation.md) | The reconciliation template, the three-column hand-off and the prepared-not-filed stop. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [SKILL.md](../../SKILL.md) | The T11 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The PACK-YEARLY-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The yearly-overview-pack case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: PACK-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/yearly-overview-pack.md
