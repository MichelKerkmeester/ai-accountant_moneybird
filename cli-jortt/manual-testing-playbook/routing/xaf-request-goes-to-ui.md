---
title: "JRT-005 -- XAF request goes to the UI"
description: "This scenario validates XAF request goes to the UI for `JRT-005`. Its objective is to confirm an XAF request is routed to the operator and never sent to the API."
version: 1.0.0.0
---

# JRT-005 -- XAF request goes to the UI

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-005`.

---

## 1. OVERVIEW

This scenario validates XAF request goes to the UI for `JRT-005`. Its objective is to confirm an XAF request is routed to the operator and never sent to the API.

### Why This Matters

An invented XAF route would produce a file the migration cannot trust. The skill has to say plainly that only the Jortt UI makes one.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-005` and confirm the expected signals without contradictory evidence.

- Objective: Confirm an XAF request is routed to the operator and never sent to the API.
- Real user request: `Export the Jortt XAF auditfile for a year.`
- Prompt: `Export the Jortt XAF auditfile for a year.`
- Expected execution process: The agent loads the export reference, makes no API call and gives the operator the UI steps.
- Expected signals: Step 1: no `jortt-cli` call is made. Step 2: the answer says the API has no XAF endpoint, names `Boekhoudbot`, `Maak voor mij een auditfile` and the Beheerder requirement.
- Desired user-visible outcome: The agent explains the UI route and asks the operator to generate one file per year.
- Pass/fail: PASS if no API call is made and the operator is given the UI route, FAIL if the agent invents an API operation or claims it downloaded XAF.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Export the Jortt XAF auditfile for a year.`

### Commands

1. `agent: Route the request with SKILL.md and load references/exports-and-limits.md`
2. `agent: Answer with the Boekhoudbot steps for one XAF 4.0.3 file per year and the Beheerder requirement`

### Expected

- Step 1: no `jortt-cli` call is made.
- Step 2: the answer says the API has no XAF endpoint, names `Boekhoudbot`, `Maak voor mij een auditfile` and the Beheerder requirement.

### Evidence

The agent's final answer and a note that no tool call ran.

### Pass / Fail

- **Pass**: No API call is made and the operator is given the UI route.
- **Fail**: The agent invents an API operation or claims it downloaded XAF.

### Failure Triage

1. Check that `references/exports-and-limits.md` was loaded.
2. Check the XAF row of the routing table in `SKILL.md`.

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
| [`SKILL.md`](../../SKILL.md) | Operation-to-surface routing |
| [`references/exports-and-limits.md`](../../references/exports-and-limits.md) | XAF UI export route |

---

## 5. SOURCE METADATA

- Group: Routing
- Playbook ID: JRT-005
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `routing/xaf-request-goes-to-ui.md`
- Feature catalog entry: [`surfaces/surface-routing.md`](../../feature-catalog/surfaces/surface-routing.md)
