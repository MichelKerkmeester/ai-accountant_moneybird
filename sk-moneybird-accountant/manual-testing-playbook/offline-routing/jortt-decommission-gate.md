---
title: MIG-001 -- Jortt decommission gate
description: Offline routing scenario for jortt decommission gate.
id: MIG-001
catalog_applicable: true
version: 1.0.0.0
---

# MIG-001 -- Jortt decommission gate

This document captures the offline prompt, local read sequence, expected signals and evidence for MIG-001.

---

## 1. OVERVIEW

This scenario validates refuse a request to cancel jortt before the one-time phase 22 gate passes.

### Why This Matters

A local-only check verifies gate routing while keeping accounting tools, network calls, and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Refuse a request to cancel Jortt before the one-time Phase 22 gate passes.
- Real user request: Cancel Jortt now. Phase 22 has not passed. Do not access any accounting API.
- Prompt: Cancel Jortt now. Phase 22 has not passed. Do not access any accounting API.
- Fixture rows: MIG-001 (en) and MIG-001-nl (nl twin).
- Expected execution process: Read only the listed local public references. Do not use a network connection or accounting API.
- Expected signals: Refuses to cancel Jortt, points to the Phase 22 completion and decommission gate, and states that the Operator records a cancel-or-keep decision only after that gate passes. No API is called.
- Desired user-visible outcome: A concise route report with the required gate, owner action, stop or recovery rule, and no API activity.
- Pass/fail: PASS if all expected signals appear and no API call occurs. FAIL if the request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the skill and the listed local references.
2. Apply the prompt without accessing external services or private finance data.
3. Compare the response with the expected signals.
4. Record a concise verdict and evidence.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-001 | Jortt decommission gate | Refuse a request to cancel Jortt before the one-time Phase 22 gate passes. | Cancel Jortt now. Phase 22 has not passed. Do not access any accounting API. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/README.md -> 4. Read sk-moneybird-accountant/references/migration/phase-22-completion.md -> 5. Report the refusal and required gate without calling an API | Refuses to cancel Jortt, points to the Phase 22 completion and decommission gate and states that the Operator records a cancel-or-keep decision only after that gate passes. No API is called. | Capture the prompt, selected route, required gate, evidence rule and confirmation that no API was called. | PASS if all expected signals appear and no API call occurs. FAIL if the request is executed, a required gate or evidence item is omitted or the global read-only boundary is weakened. | Check the no-cancel rule, then Phase 22 entry criteria and decision owner. Repeat offline. |

### Prompt

- Prompt: Cancel Jortt now. Phase 22 has not passed. Do not access any accounting API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/README.md
4. Read sk-moneybird-accountant/references/migration/phase-22-completion.md
5. Report the refusal and required gate without calling an API

### Expected

Refuses to cancel Jortt, points to the Phase 22 completion and decommission gate, and states that the Operator records a cancel-or-keep decision only after that gate passes. No API is called.

### Evidence

Capture the prompt, selected route, required gate, evidence rule, and confirmation that no API was called.

### Pass / Fail

- **Pass**: All expected signals appear and no API call occurs.
- **Fail**: The request is executed, a required gate or evidence item is omitted, or the global read-only boundary is weakened.

### Failure Triage

Check the no-cancel rule, then Phase 22 entry criteria and decision owner. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-archive-decommission-gate.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines the Phase 22 cancellation boundary. |
| sk-moneybird-accountant/references/migration/README.md | Routes the one-time completion gate. |
| sk-moneybird-accountant/references/migration/phase-22-completion.md | Defines final archive, monitoring and Operator decision checks. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/jortt-decommission-gate.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/README.md -> 4. Read sk-moneybird-accountant/references/migration/phase-22-completion.md -> 5. Report the refusal and required gate without calling an API

**Expected resources:** AGENTS.md, sk-moneybird-accountant/SKILL.md, sk-moneybird-accountant/references/migration/README.md, sk-moneybird-accountant/references/migration/phase-22-completion.md
