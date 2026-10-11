---
title: MIG-005 -- Migration agent route
description: Validates summaries-only agent routing, independent checks, and safe draft recovery without service calls.
id: MIG-005
catalog_applicable: true
version: 1.0.0.0
---

# MIG-005 -- Migration agent route

This scenario checks local migration routing and journal rules without reading accounting records or calling an external service.

---

## 1. OVERVIEW

The scenario confirms that migration sub-goals use the M12 seat route and that an unverified draft cannot resume into a gate.

### Why This Matters

A local-only check verifies route and journal behavior while keeping accounting tools, network calls, and private finance data untouched.

## 2. SCENARIO CONTRACT

- Objective: Route one migration work unit through M12 and recover safely from an AGENT_DRAFTED state.
- Real user request: I am in migration Phase 7 and the last agent journal state is AGENT_DRAFTED. What should happen next? Do not read records or call an API.
- Prompt: I am in migration Phase 7 and the last agent journal state is AGENT_DRAFTED. What should happen next? Do not read records or call an API.
- Expected execution process: Read the project bootstrap and skill, then read only the migration index, Phase 7 contract, and shared mechanisms. Do not use network access, accounting APIs, private finance data, or a live agent dispatch.
- Expected signals: Names the Agent runner, Implementer, Verifier, Final reviewer, and separate Migration Writer seats. States that agent payloads contain summaries only, record-level checks run locally, AGENT_DRAFTED is not verified, and the draft returns to verification before any gate. Preserves Operator approval before a write and reports no API call.
- Desired user-visible outcome: A concise route and resume decision with the controlling reference paths and no service call.
- Pass/fail: PASS if AGENT_DRAFTED returns to verification, the seats and data boundary are correct, and no service call is made. FAIL if the draft is treated as verified or a service call occurs.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and skill.
2. Read references/migration/README.md.
3. Read references/migration/phases-6-to-9.md and references/migration/shared-mechanisms.md.
4. Report the M12 route, the verified-state resume rule, and the no-call status.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-005 | Migration agent route | Route a Phase 7 work unit from an unverified draft state. | I am in migration Phase 7 and the last agent journal state is AGENT_DRAFTED. What should happen next? Do not read records or call an API. | 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-6-to-9.md -> 5. Read references/migration/shared-mechanisms.md -> 6. Report the seat route, data policy, recovery point, Operator approvals, and no-call status | Uses the M12 seats, summaries-only payloads, local record checks, verification restart, and Operator approval before writes | Capture prompt, references, named seats, privacy boundary, resume rule, and no-call status | PASS if the draft returns to verification and no service call occurs. FAIL if the draft is applied or gated before verification, or a service call occurs. | Check M3 and M12 in shared-mechanisms.md, then repeat the offline route. |

### Prompt

- Prompt: I am in migration Phase 7 and the last agent journal state is AGENT_DRAFTED. What should happen next? Do not read records or call an API.

### Commands

1. Read AI Systems/Moneybird Accountant/AGENTS.md
2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md
3. Read references/migration/README.md
4. Read references/migration/phases-6-to-9.md
5. Read references/migration/shared-mechanisms.md
6. Report the seats, data boundary, resume point, Operator approval, and API-free status

### Expected

The Agent runner coordinates the Implementer, Verifier, Final reviewer, and separate Migration Writer seat. The Implementer and Verifier receive summaries only. Local scripts perform record-level work. AGENT_DRAFTED is not verified and restarts at verification. No write proceeds without Verifier PASS and Operator approval. No service is called.

### Evidence

Capture the prompt, the three references, the seat mapping, data boundary, resume point, Operator approval rule, and a record that no service call occurred.

### Pass / Fail

- **Pass**: Correctly routes through M12, restarts an AGENT_DRAFTED item at verification, and makes no service call.
- **Fail**: Treats AGENT_DRAFTED as verified, skips the seat boundary, or calls a service.

### Failure Triage

Check the migration index, Phase 7 contract, M3 journal states, and M12 work-unit loop. Repeat the scenario offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-agent-route.md) | M12 behavior and plan anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AI Systems/Moneybird Accountant/AGENTS.md | Defines entry route and privacy boundaries. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Selects MIGRATION and loads M12. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/shared-mechanisms.md | Defines M3 and M12. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-6-to-9.md | Defines Phase 7 gates and owner tags. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-005
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/migration-agent-route.md

**Exact command sequence:** 1. Read AI Systems/Moneybird Accountant/AGENTS.md -> 2. Read AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md -> 3. Read references/migration/README.md -> 4. Read references/migration/phases-6-to-9.md -> 5. Read references/migration/shared-mechanisms.md -> 6. Report the seat route, data policy, recovery point, Operator approvals, and no-call status

**Expected resources:** AI Systems/Moneybird Accountant/AGENTS.md, SKILL.md, references/migration/README.md, references/migration/phases-6-to-9.md, references/migration/shared-mechanisms.md

---
