---
title: "MIG-007 -- Jortt to Moneybird mapping"
description: "This scenario validates the T2 migration concept route and the Jortt to Moneybird mapping traps for MIG-007."
id: MIG-007
catalog_applicable: true
version: 1.0.0.0
---

# MIG-007 -- Jortt to Moneybird mapping

This document captures the offline prompt, local read sequence, expected signals and evidence for MIG-007.

---

## 1. OVERVIEW

This scenario validates the T2 migration concept route. It focuses on mapping a Jortt concept by accounting purpose and tax treatment and on the source-export traps the mapping depends on.

### Why This Matters

A category name can match across Jortt and Moneybird while the ledger account or the VAT treatment differs. Mapping by label alone creates a wrong opening balance or a duplicated posting that a later phase cannot reconcile. A local-only check confirms the route without reading records or calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a Jortt concept question to the mapping reference and name the export traps.
- Real user request: Which Jortt category should my software costs map to in Moneybird, and which export traps should I check? Do not call an API.
- Prompt: Which Jortt category should my software costs map to in Moneybird, and which export traps should I check? Do not call an API.
- Fixture rows: MIG-007 and its Dutch twin MIG-007-nl in routing-gold.json.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access, accounting APIs or private finance data.
- Expected signals: Selects MIGRATION, routes the mapping question through the T2 migration concept row, names sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md as the read set, maps by accounting purpose and tax treatment rather than by matching labels, names the attachments, asset list and category and opening balance traps, does not advance a phase and reports no API call.
- Desired user-visible outcome: A concise route report with the selected mode, the mapping rule, the named traps, the reference path and the API-free status.
- Pass/fail: PASS if the mapping reference is named, the mapping rule and the three export traps are correct, no phase advances and no API is called. FAIL if a category is mapped by label alone, a trap is skipped, an unmapped field is invented or an API is called.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-007 | Jortt to Moneybird mapping | Route a Jortt concept question to the mapping reference and name the export traps. | Which Jortt category should my software costs map to in Moneybird, and which export traps should I check? Do not call an API. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md -> 4. Report the mapping rule, the export traps and the API-free status | Selects MIGRATION, uses the T2 migration concept row, maps by accounting purpose and tax treatment, names the attachment, asset list and category and opening balance traps, keeps the phase unchanged and makes no API call. | Capture the prompt, the selected route, the reference path, the mapping rule, the named traps and the no-call status. | PASS if the mapping reference is named, the mapping rule and the three export traps are correct, no phase advances and no API is called. FAIL if a category is mapped by label alone, a trap is skipped, an unmapped field is invented or an API is called. | Check the T2 row in the Task-Type Table, then sections 2 and 3 of the mapping reference. Repeat offline. |

### Prompt

- Prompt: Which Jortt category should my software costs map to in Moneybird, and which export traps should I check? Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md
4. Report the mapping rule, the export traps and the API-free status

### Expected

Selects MIGRATION, uses the T2 migration concept row, maps by accounting purpose and tax treatment, names the attachment, asset list and category and opening balance traps, keeps the phase unchanged and makes no API call.

### Evidence

Capture the prompt, the selected route, the reference path, the mapping rule, the named traps and the no-call status.

### Pass / Fail

- **Pass**: The mapping reference is named, the mapping rule and the three export traps are correct, no phase advances and no API is called.
- **Fail**: A category is mapped by label alone, a trap is skipped, an unmapped field is invented or an API is called.

### Failure Triage

Check the T2 row in the Task-Type Table, then sections 2 and 3 of the mapping reference. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/jortt-to-moneybird-mapping.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Routes a migration concept request through the T2 row. |
| sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md | Defines the concept mapping, the export traps and the migration checks. |
| sk-moneybird-accountant/references/migration/README.md | Places the mapping guide in the phase route. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-007
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/jortt-to-moneybird-mapping.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md -> 4. Report the mapping rule, the export traps and the API-free status

**Expected resources:** sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md
