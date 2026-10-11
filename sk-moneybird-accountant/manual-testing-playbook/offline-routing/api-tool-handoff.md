---
title: API-001 -- CLI tool handoff
description: This scenario validates CLI tool handoff for API-001. It focuses on offline routing and policy.
id: API-001
catalog_applicable: true
version: 1.0.0.0
---

# API-001 -- CLI tool handoff

This document captures the offline prompt, local read sequence, expected signals, and evidence for API-001.

---

## 1. OVERVIEW

This scenario validates CLI tool handoff. It focuses on Route Jortt reads and Moneybird reads or writes through their owning sibling skills.

### Why This Matters

A local-only check can confirm that the skill chooses its mode and references while keeping accounting tools and private finance data untouched.

---

## 2. SCENARIO CONTRACT

- Objective: Route Jortt reads and Moneybird reads or writes through their owning sibling skills.
- Real user request: I need a read from Jortt and a gated write in Moneybird. Which CLI and sibling skills own those actions? Do not execute either action.
- Prompt: I need a read from Jortt and a gated write in Moneybird. Which CLI and sibling skills own those actions? Do not execute either action.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting CLIs.
- Expected signals: Names jortt-cli for read-only Jortt work and moneybird-guard for Moneybird work, sets MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions, preserves the gate and approval rule, and executes nothing.
- Desired user-visible outcome: A concise route report with selected mode, reference paths, boundary result, and no CLI activity.
- Pass/fail: PASS if the CLI routes are correct, Moneybird write approval is retained, and no action is executed. FAIL if Jortt write access is suggested, a Moneybird write bypasses moneybird-guard or the gate, or an API call occurs.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without using a CLI.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| API-001 | CLI tool handoff | Route Jortt reads and Moneybird reads or writes through their owning sibling skills. | I need a read from Jortt and a gated write in Moneybird. Which CLI and sibling skills own those actions? Do not execute either action. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/jortt-to-moneybird-mapping.md -> 4. Name jortt-cli for the Jortt read and moneybird-guard for the Moneybird read or write -> 5. Confirm that no CLI action was executed | Names jortt-cli for read-only Jortt work and moneybird-guard for Moneybird work, sets MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions, preserves the gate and approval rule, and executes nothing. | Capture the prompt, each tool handoff, the write gate, and confirmation that no CLI call occurred. | PASS if the CLI routes are correct, Moneybird write approval is retained, and no action is executed. FAIL if Jortt write access is suggested, a Moneybird write bypasses moneybird-guard or the gate, or an API call occurs. | Check the system boundaries, then the relevant sibling skill links. Repeat with API tools unavailable. |

### Prompt

- Prompt: I need a read from Jortt and a gated write in Moneybird. Which CLI and sibling skills own those actions? Do not execute either action.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/migration/jortt-to-moneybird-mapping.md
4. Name jortt-cli for the Jortt read and moneybird-guard for the Moneybird read or write
5. Confirm that no CLI action was executed

### Expected

Names jortt-cli for read-only Jortt work and moneybird-guard for Moneybird work, sets MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions, preserves the gate and approval rule, and executes nothing.

### Evidence

Capture the prompt, each tool handoff, the write gate, and confirmation that no CLI call occurred.

### Pass / Fail

- **Pass**: the CLI routes are correct, Moneybird write approval is retained, and no action is executed.
- **Fail**: Jortt write access is suggested, a Moneybird write bypasses moneybird-guard or the gate, or an API call occurs.

### Failure Triage

Check the system boundaries, then the relevant sibling skill links. Repeat with API tools unavailable.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/api-tool-handoff.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Defines mode and reference routing |
| AI Systems/Moneybird Accountant/AGENTS.md | Defines project bootstrap and privacy rules |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: API-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/api-tool-handoff.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/jortt-to-moneybird-mapping.md -> 4. Name jortt-cli for the Jortt read and moneybird-guard for the Moneybird read or write -> 5. Confirm that no CLI action was executed

**Expected resources:** references/migration/jortt-to-moneybird-mapping.md
