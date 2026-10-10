---
title: MODE-001 -- Migration phase routing
description: This scenario validates Migration phase routing for MODE-001. It focuses on offline routing and policy.
id: MODE-001
catalog_applicable: true
version: 1.0.0.0
---

# MODE-001 -- Migration phase routing

This document captures the offline prompt, local read sequence, expected signals, and evidence for MODE-001.

---

## 1. OVERVIEW

This scenario validates Migration phase routing. It focuses on Route a request at Phase 3 to the correct migration reference and gate.

### Why This Matters

A local-only check can confirm that the skill chooses its mode and references while keeping accounting tools and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Route a request at Phase 3 to the correct migration reference and gate.
- Real user request: I have passed Phase 2 and need to reconstruct the source records. Which migration reference and gate should I use? Do not access any accounting API.
- Prompt: I have passed Phase 2 and need to reconstruct the source records. Which migration reference and gate should I use? Do not access any accounting API.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects MIGRATION, Phase 3 to 5, the matching reference, and the control framework. Preserves owner tags and states that no API was called.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result, and no API activity.
- Pass/fail: PASS if All expected migration references are named, the owner tags and gate are preserved, and no API is called. FAIL if The skill selects LIVE, loads the wrong phase group, omits the gate or owner tags, or calls an API.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MODE-001 | Migration phase routing | Route a request at Phase 3 to the correct migration reference and gate. | I have passed Phase 2 and need to reconstruct the source records. Which migration reference and gate should I use? Do not access any accounting API. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-3-to-5.md -> 5. Read references/migration/control-framework.md -> 6. Report the selected phase group, owner tags, gate, and API-free status | Selects MIGRATION, Phase 3 to 5, the matching reference, and the control framework. Preserves owner tags and states that no API was called. | Capture the prompt, selected mode, phase group, gate reference, owner tags, and a record that no API call occurred. | PASS if All expected migration references are named, the owner tags and gate are preserved, and no API is called. FAIL if The skill selects LIVE, loads the wrong phase group, omits the gate or owner tags, or calls an API. | Check the mode signal, then the phase map, then the last passed gate, then the resource list. Repeat offline. |

### Prompt

- Prompt: I have passed Phase 2 and need to reconstruct the source records. Which migration reference and gate should I use? Do not access any accounting API.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/migration/README.md
4. Read references/migration/phases-3-to-5.md
5. Read references/migration/control-framework.md
6. Report the selected phase group, owner tags, gate, and API-free status

### Expected

Selects MIGRATION, Phase 3 to 5, the matching reference, and the control framework. Preserves owner tags and states that no API was called.

### Evidence

Capture the prompt, selected mode, phase group, gate reference, owner tags, and a record that no API call occurred.

### Pass / Fail

- **Pass**: All expected migration references are named, the owner tags and gate are preserved, and no API is called.
- **Fail**: The skill selects LIVE, loads the wrong phase group, omits the gate or owner tags, or calls an API.

### Failure Triage

Check the mode signal, then the phase map, then the last passed gate, then the resource list. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-phase-routing.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AI Systems/Moneybird Accountant/AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MODE-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/migration-phase-routing.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-3-to-5.md -> 5. Read references/migration/control-framework.md -> 6. Report the selected phase group, owner tags, gate, and API-free status

**Expected resources:** references/migration/README.md, references/migration/phases-3-to-5.md, references/migration/control-framework.md
