---
title: MODE-001 -- Migration phase routing
description: Validates recurring-phase routing and the one-time completion gate after cutover.
id: MODE-001
catalog_applicable: true
version: 1.0.0.0
---

# MODE-001 -- Migration phase routing

This document captures the offline prompt, local read sequence, expected signals, and evidence for MODE-001.

---

## 1. OVERVIEW

This scenario validates post-switch routing through recurring cycles and the one-time completion gate.

### Why This Matters

The phase map keeps live work, monitoring, and Jortt decommission in the correct order without using accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route recurring post-switch work and final completion to the current phase map.
- Real user request: I have passed Phase 18. Which phases repeat during monitoring, and when can Jortt be cancelled? Do not access any accounting API.
- Prompt: I have passed Phase 18. Which phases repeat during monitoring, and when can Jortt be cancelled? Do not access any accounting API.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting APIs.
- Expected signals: Selects MIGRATION, routes monthly, VAT-period, and yearly work to Phases 19 to 21 after Phase 18, routes completion to the one-time Phase 22 gate after monitoring, refuses early cancellation, preserves owner tags, and states that no API was called. Any tool route it names matches the route contract: jortt reads run through jortt-cli only, XAF and other Jortt exports are Operator UI tasks, Moneybird reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, a Moneybird write needs a passed gate, Operator approval, `--confirm-write` and `--approval <ref>` for a flushed `WRITE_INTENT`, plus `--production` for a production batch, and an HTTP 429 stops the call sequence for a guarded read-back before any retry.
- Desired user-visible outcome: A concise route report with selected phase range, reference paths, gate order, cancellation boundary, and API-free status.
- Pass/fail: PASS if recurring cycles, Phase 22, owner tags, and the cancellation boundary are correctly named and no API is called. FAIL if the old phase map is used, cancellation is permitted early, or an API is called.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the local phase map and phase references.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MODE-001 | Migration phase routing | Route recurring cycles and completion after Phase 18. | I have passed Phase 18. Which phases repeat during monitoring, and when can Jortt be cancelled? Do not access any accounting API. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-19-to-21.md -> 5. Read references/migration/phase-22-completion.md -> 6. Report recurring cycles, one-time gate, owner tags, and API-free status | Phases 19 to 21 recur after Phase 18. Phase 22 is one-time after monitoring and all required cycles. Jortt cancellation waits until the Operator records a decision after Phase 22. Any tool route named matches the route contract in shared-mechanisms.md. | Capture the prompt, phase references, recurrence rule, Phase 22 gate, owner tags, and a record that no API call occurred. | PASS if the current phase order and cancellation boundary are correct and no API is called. FAIL if the old map is used, cancellation is permitted early, or an API is called. | Check the last passed gate, then the execution-order phase map and resource list. Repeat offline. |

### Prompt

- Prompt: I have passed Phase 18. Which phases repeat during monitoring, and when can Jortt be cancelled? Do not access any accounting API.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/migration/README.md
4. Read references/migration/phases-19-to-21.md
5. Read references/migration/phase-22-completion.md
6. Report recurring cycles, one-time gate, owner tags, and API-free status

### Expected

Phases 19 to 21 recur after Phase 18. Phase 22 is one-time after monitoring and all required cycles. Jortt cancellation waits until the Operator records a decision after Phase 22. Any tool route named matches the route contract in shared-mechanisms.md.

### Evidence

Capture the prompt, phase references, recurrence rule, Phase 22 gate, owner tags, and a record that no API call occurred.

### Pass / Fail

- **Pass**: The current phase order and cancellation boundary are correct and no API is called.
- **Fail**: The old map is used, cancellation is permitted early, or an API is called.

### Failure Triage

Check the last passed gate, then the execution-order phase map and resource list. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-phase-routing.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines phase and reference routing. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/README.md | Defines execution order, recurrence, and old-to-new mapping. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-19-to-21.md | Defines recurring workflows. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phase-22-completion.md | Defines the one-time completion and decommission gate. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MODE-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/migration-phase-routing.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-19-to-21.md -> 5. Read references/migration/phase-22-completion.md -> 6. Report recurring cycles, one-time gate, owner tags, and API-free status

**Expected resources:** references/migration/README.md, references/migration/phases-19-to-21.md, references/migration/phase-22-completion.md
