---
title: "JRT-006 -- Moneybird request is deferred"
description: "This scenario validates Moneybird request is deferred for `JRT-006`. Its objective is to confirm a target-side Moneybird operation is handed to the sibling skill without a Jortt call."
version: 1.0.0.0
---

# JRT-006 -- Moneybird request is deferred

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-006`.

---

## 1. OVERVIEW

This scenario validates Moneybird request is deferred for `JRT-006`. Its objective is to confirm a target-side Moneybird operation is handed to the sibling skill without a Jortt call.

### Why This Matters

Jortt is the source and Moneybird the target. Mixing the two would let a source tool attempt target-side work.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-006` and confirm the expected signals without contradictory evidence.

- Objective: Confirm a target-side Moneybird operation is handed to the sibling skill without a Jortt call.
- Real user request: `Create the imported invoice in Moneybird and verify it.`
- Prompt: `Create the imported invoice in Moneybird and verify it.`
- Expected execution process: The agent recognizes target-side work and hands it to the sibling skill.
- Expected signals: Step 1: no `jortt-cli` call is made. Step 2: the answer names Moneybird as the target and defers to the sibling skill.
- Desired user-visible outcome: The agent hands off the request without calling Jortt.
- Pass/fail: PASS if the request is deferred to the Moneybird skill, FAIL if the Jortt CLI is used for target-side work.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Create the imported invoice in Moneybird and verify it.`

### Commands

1. `agent: Route the request with SKILL.md`
2. `agent: Hand the Moneybird import and verification to the cli-moneybird skill`

### Expected

- Step 1: no `jortt-cli` call is made.
- Step 2: the answer names Moneybird as the target and defers to the sibling skill.

### Evidence

The agent's final answer and a note that no Jortt tool call ran.

### Pass / Fail

- **Pass**: The request is deferred to the Moneybird skill.
- **Fail**: The Jortt CLI is used for target-side work.

### Failure Triage

1. Check the When NOT to Use list in `SKILL.md`.
2. Check the Sibling System entry under Integration Points in `SKILL.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/surfaces/surface-routing.md`](../../feature-catalog/surfaces/surface-routing.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`SKILL.md`](../../SKILL.md) | System routing boundary |

---

## 5. SOURCE METADATA

- Group: Routing
- Playbook ID: JRT-006
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `routing/moneybird-request-deferred.md`
- Feature catalog entry: [`feature-catalog/surfaces/surface-routing.md`](../../feature-catalog/surfaces/surface-routing.md)
