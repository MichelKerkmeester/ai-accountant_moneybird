---
title: "MBD-007 -- Bank file import goes to the UI"
description: "This scenario validates Bank file import goes to the UI for `MBD-007`. It focuses on the need to confirm that a CAMT.053 or MT940 import routes to the Moneybird UI."
version: 1.0.0.0
---

# MBD-007 -- Bank file import goes to the UI

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-007`.

---

## 1. OVERVIEW

This scenario validates Bank file import goes to the UI for `MBD-007`. It focuses on the need to confirm that a CAMT.053 or MT940 import routes to the Moneybird UI.

### Why This Matters

`financial_statements` accepts JSON mutations and is not a file upload route.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-007` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a CAMT.053 or MT940 import routes to the Moneybird UI.
- Real user request: `Import a CAMT.053 bank file into the pilot administration.`
- Prompt: `Which Moneybird surface imports a CAMT.053 or MT940 file?`
- Expected execution process: The agent answers from the skill without calling an API. The operator compares the answer with the routing table and the REST reference.
- Expected signals: The answer sends the operator to the Moneybird UI and describes `financial_statements` as a JSON mutation route.
- Desired user-visible outcome: The operator gets the UI path and no upload command runs.
- Pass/fail: PASS if the answer names the UI and does not send the file to `financial_statements`. FAIL if the file is sent to the JSON mutation route.
- Feature catalog: [Documented API traps](../../feature-catalog/api-knowledge/documented-api-traps.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Decide whether the scenario stays local or needs the operator for a live step.
3. Execute the deterministic steps exactly as written.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-007 | Bank file import goes to the UI | Confirm that a CAMT.053 or MT940 import routes to the Moneybird UI | `Which Moneybird surface imports a CAMT.053 or MT940 file?` | 1. `agent: answer the prompt` -> 2. `bash: rg -n "CAMT.053" ROUTER.md references/rest-api.md` | Step 1: a UI-only answer. Step 2: both sources name the UI route | The answer text and the matching source lines | PASS if the answer names the UI and does not send the file to `financial_statements`. FAIL if the file is sent to the JSON mutation route. | 1. Re-read the UI-only row in `ROUTER.md` section 2. 2. Re-read the limits in `references/rest-api.md`. 3. Check whether the answer loaded the REST reference |

### Command Block

Run the source check from the `cli-moneybird/` package root. Do not use a real bank file or call an API.

```bash
rg -n "CAMT.053" ROUTER.md references/rest-api.md
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-knowledge/documented-api-traps.md`](../../feature-catalog/api-knowledge/documented-api-traps.md) | Feature-catalog entry for Documented API traps |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`ROUTER.md`](../../ROUTER.md) | Operation routing table |
| [`references/rest-api.md`](../../references/rest-api.md) | UI-only limits |

---

## 5. SOURCE METADATA

- Group: Routing boundaries
- Playbook ID: MBD-007
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `routing/bank-file-import-goes-to-ui.md`
