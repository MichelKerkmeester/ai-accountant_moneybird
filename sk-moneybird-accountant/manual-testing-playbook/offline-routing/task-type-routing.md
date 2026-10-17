---
title: "TASK-001 -- Task type routing"
description: "This scenario validates the Task-Type Table tie rule and the route record for TASK-001."
id: TASK-001
catalog_applicable: true
version: 1.0.0.0
---

# TASK-001 -- Task type routing

This document captures the offline prompt, local read sequence, expected signals and evidence for TASK-001.

---

## 1. OVERVIEW

This scenario validates the Task-Type Table. It focuses on a near tie between the purchase invoice (inkoopfactuur) row and the tax figure row and on the route record every answer carries.

### Why This Matters

The table decides the tool route, the read set and the token budget. A near tie that is resolved silently, or a route that loads the wrong reference, answers from the wrong frame and spends the wrong budget. A local-only check confirms the tie rule without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a deduction question through the task-type tie rule and report the route record.
- Real user request: Is my home phone subscription a deduction in 2026? Do not call an API.
- Prompt: Is my home phone subscription a deduction in 2026? Do not call an API.
- Fixture rows: TIE-T4-T5-01 (the T5-over-T4 tie row).
- Expected execution process: Read the project bootstrap and skill, run the route table check, then read only the routed year files. Do not use network access, accounting APIs or private finance data.
- Expected signals: The route table check prints route-table: ok. The tax figure row T5 wins over the purchase invoice (inkoopfactuur) row T4 because a tax figure is asked and no invoice is named. The resolver uses the explicit year 2026, loads the 2026 README and routes to the costs-and-car topic file its KEY FIGURES section names, does not load the purchase invoice or mixed-use references, keeps the CLI action row additive and reports the route record with type T5.
- Desired user-visible outcome: A concise route report with the winning row, the tie rule, the loaded paths, the token budget key and the API-free status.
- Pass/fail: PASS if the T5 row wins, the tie rule is named, the routed year file and topic section are correct, the invoice references stay unloaded and no API is called. FAIL if the invoice row wins, an unrouted reference is loaded, the route record is missing or an API is called.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the route table check.
3. Follow the routed year-file sequence.
4. Compare the observed route and the route record to the expected signals.
5. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| TASK-001 | Task type routing | Route a deduction question through the task-type tie rule and report the route record. | Is my home phone subscription a deduction in 2026? Do not call an API. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check -> 4. Read sk-moneybird-accountant/references/tax-rules/2026/README.md and the costs-and-car topic file its KEY FIGURES section names -> 5. Report the winning row, the tie rule, the loaded paths, the budget key and the route record | The check prints route-table: ok. T5 wins over T4, the explicit year 2026 resolves, the year README and the costs-and-car key figures load, the invoice references stay unloaded, T7 stays additive and the route record names T5. | Capture the check output, the selected row, the tie rule, the loaded paths, the token budget key and the no-call status. | PASS if the T5 row wins, the tie rule is named, the routed year file and topic section are correct, the invoice references stay unloaded and no API is called. FAIL if the invoice row wins, an unrouted reference is loaded, the route record is missing or an API is called. | Check the T4, T5 and T7 rows and the tie rules in ROUTER.md section 2, then the TIE-T4-T5-01 row in the routing corpus. Repeat offline. |

### Prompt

- Prompt: Is my home phone subscription a deduction in 2026? Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/tax-rules/2026/README.md and the costs-and-car topic file its KEY FIGURES section names
5. Report the winning row, the tie rule, the loaded paths, the budget key and the route record

### Expected

The check prints route-table: ok. T5 wins over T4, the explicit year 2026 resolves, the year README and the costs-and-car key figures load, the invoice references stay unloaded, T7 stays additive and the route record names T5.

### Evidence

Capture the check output, the selected row, the tie rule, the loaded paths, the token budget key and the no-call status.

### Pass / Fail

- **Pass**: The T5 row wins, the tie rule is named, the routed year file and topic section are correct, the invoice references stay unloaded and no API is called.
- **Fail**: The invoice row wins, an unrouted reference is loaded, the route record is missing or an API is called.

### Failure Triage

Check the T4, T5 and T7 rows and the tie rules in ROUTER.md section 2, then the TIE-T4-T5-01 row in the routing corpus. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/task-type-routing.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/ROUTER.md | Defines the Task-Type Table, the tie rules, the abstain margin and the route record. |
| sk-moneybird-accountant/scripts/check-route-table.py | Checks the table, the router block and the intent-signal drift. |
| sk-moneybird-accountant/scripts/route-replay/routing-gold.json | Holds the TIE-T4-T5-01 tie row this scenario mirrors. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: TASK-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/task-type-routing.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check -> 4. Read sk-moneybird-accountant/references/tax-rules/2026/README.md and the costs-and-car topic file its KEY FIGURES section names -> 5. Report the winning row, the tie rule, the loaded paths, the budget key and the route record

**Expected resources:** sk-moneybird-accountant/references/tax-rules/2026/README.md, sk-moneybird-accountant/references/tax-rules/2026/costs-and-car/figures.md#2-key-figures
