---
title: "STATE-001 -- Session context and year resolution"
description: "This scenario validates the session context builder and the year and post-cutover resolution for STATE-001."
id: STATE-001
catalog_applicable: true
version: 1.0.0.0
---

# STATE-001 -- Session context and year resolution

This document captures the offline prompt, local read sequence, expected signals and evidence for STATE-001.

---

## 1. OVERVIEW

This scenario validates the session context and the year resolver. It focuses on the year order, the post-cutover states and the offline suite that proves both.

### Why This Matters

Every figure answer uses a tax year and every LIVE route uses a post-cutover state. A wrong or borrowed year presents a stale figure as current, and a wrong state loads the wrong cycle files. A local-only check confirms the resolver without reading records or calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route an explicit-year question through the year resolver and report the post-cutover state rules.
- Real user request: My question is about my 2024 return but the session clock says a later year. How do you decide which tax year to use, and how do you know the migration state? Keep this as an offline check.
- Prompt: My question is about my 2024 return but the session clock says a later year. How do you decide which tax year to use, and how do you know the migration state? Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The session context suite generates its fixtures at run time.
- Expected execution process: Read the project bootstrap and skill, then the year and state reference, then run the offline session context suite on its generated fixtures. Do not use network access, accounting APIs or private finance data.
- Expected signals: Names session-context.json at the repository root as the router input and states that it is git-ignored. Names the four-step year order: an explicit year in the request, the period under review, the return-year mapping, then the clock year. Uses the explicit 2024 return year before the clock year and reports the year key return_coverage. Names the five post-cutover states and says only monitoring_active and monitoring_lapsed_phase22_open load the recurring-cycle files. The suite reports 34 passed with 0 failed.
- Desired user-visible outcome: A concise route report with the resolved year, its year key, the named post-cutover state and the suite result.
- Pass/fail: PASS if the year order, the explicit-year precedence, the state names and the suite result are correct and no external service is called. FAIL if the clock year overrides the explicit year, a state name is invented, a recurring-cycle file loads outside monitoring or a service is called.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Read the year and state reference.
3. Run the session context suite.
4. Compare the resolver order and the state list with the expected signals.
5. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| STATE-001 | Session context and year resolution | Route an explicit-year question through the year resolver and report the post-cutover state rules. | My question is about my 2024 return but the session clock says a later year. How do you decide which tax year to use, and how do you know the migration state? Keep this as an offline check. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/year-and-state.md -> 4. Run bash sk-moneybird-accountant/scripts/session-context-test.sh -> 5. Report the year order, the post-cutover states and the suite result | Names the four-step year order and the git-ignored session-context.json input, resolves 2024 as the explicit return year with the return_coverage key, names the five post-cutover states, states the recurring-cycle load rule and reports the suite result 34 passed and 0 failed. | Capture the prompt, the year order, the resolved year and key, the state names, the suite result and the no-call status. | PASS if the year order, the explicit-year precedence, the state names and the suite result are correct and no external service is called. FAIL if the clock year overrides the explicit year, a state name is invented, a recurring-cycle file loads outside monitoring or a service is called. | Check the year order in section 2, the refusal states in section 3 and the state list in section 4 of the year and state reference, then rerun the suite. Repeat offline. |

### Prompt

- Prompt: My question is about my 2024 return but the session clock says a later year. How do you decide which tax year to use, and how do you know the migration state? Keep this as an offline check.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/tax-rules/year-and-state.md
4. Run bash sk-moneybird-accountant/scripts/session-context-test.sh
5. Report the year order, the post-cutover states and the suite result

### Expected

Names the four-step year order and the git-ignored session-context.json input, resolves 2024 as the explicit return year with the return_coverage key, names the five post-cutover states, states the recurring-cycle load rule and reports the suite result 34 passed and 0 failed.

### Evidence

Capture the prompt, the year order, the resolved year and key, the state names, the suite result and the no-call status.

### Pass / Fail

- **Pass**: The year order, the explicit-year precedence, the state names and the suite result are correct and no external service is called.
- **Fail**: The clock year overrides the explicit year, a state name is invented, a recurring-cycle file loads outside monitoring or a service is called.

### Failure Triage

Check the year order in section 2, the refusal states in section 3 and the state list in section 4 of the year and state reference, then rerun the suite. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/reference-and-state/session-context-and-year-state.md) | Current feature summary and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Routes the resolved year and state through the Task-Type Table. |
| sk-moneybird-accountant/references/tax-rules/year-and-state.md | Holds the year resolver, the refusal states and the post-cutover predicate. |
| sk-moneybird-accountant/references/routing-signals.md | Names the signal sources and tie mechanics the router reads. |
| sk-moneybird-accountant/scripts/build-session-context.py | Writes and checks the session context and prints the route state. |
| sk-moneybird-accountant/scripts/session-context-test.sh | Runs the builder against offline fixtures for the clock, the allowlist, staleness and the post-cutover states. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: STATE-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/session-context-and-year-state.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/tax-rules/year-and-state.md -> 4. Run bash sk-moneybird-accountant/scripts/session-context-test.sh -> 5. Report the year order, the post-cutover states and the suite result

**Expected resources:** sk-moneybird-accountant/references/tax-rules/year-and-state.md, sk-moneybird-accountant/scripts/session-context-test.sh
