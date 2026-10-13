---
title: "MBD-015 -- Read step contract"
description: "This scenario validates the Read Step Contract for `MBD-015`. It focuses on the need to confirm that a guarded read states its lock, its explicit period and its completeness proof before it reports a count."
version: 1.0.0.0
---

# MBD-015 -- Read step contract

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-015`.

---

## 1. OVERVIEW

This scenario validates the Read Step Contract for `MBD-015`. It focuses on the need to confirm that a guarded read states its lock, its explicit period and its completeness proof before it reports a count.

### Why This Matters

A list read can succeed and still be incomplete. An omitted period, a capped endpoint and a cached GET each make a partial answer look whole, so the answer must name how it proves completeness.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-015` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that the agent names the read-only lock, an explicit period, the paging and dedupe proof, the caps route and the GET-only retry rule for a guarded list read.
- Real user request: `Tell me how you make sure a Moneybird list read is complete before you report its count.`
- Prompt: `Walk me through how you prove a Moneybird list read is complete before you report a count.`
- Expected execution process: The agent answers from `SKILL.md` section 3 and `references/rest-api.md` without printing records, and the operator compares the answer with the source lines the command block returns.
- Expected signals: The answer names the read-only lock, an explicit period on every list, paging until a short page, dedupe by record id with the count recorded against its period, synchronization for a capped endpoint and the GET-only retry that waits for `Retry-After`. The source check lists the contract and the paging rule.
- Desired user-visible outcome: The operator sees that a reported count carries a period and a completeness proof rather than a raw success message.
- Pass/fail: PASS if the answer names the lock, the explicit period, the paging and dedupe proof, the synchronization route for caps and the GET-only retry rule. The sources must agree. FAIL if the answer treats a list without a period as complete, prints record content or proposes a non-GET retry.
- Feature catalog: [Read step contract](../../feature-catalog/reads-and-saved-output/read-step-contract.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Answer from the Read Step Contract and the REST reference without running a read that prints records.
3. Execute the source check exactly as written.
4. Compare the answer with the expected signals.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-015 | Read step contract | Confirm that the agent names the lock, the explicit period, the paging and dedupe proof, the caps route and the GET-only retry rule | `Walk me through how you prove a Moneybird list read is complete before you report a count.` | 1. `agent: answer the prompt` -> 2. `bash: rg -n "Read Step Contract\|explicit period\|short page\|dedupe\|Retry-After" SKILL.md references/rest-api.md` | Step 1: the answer names the read-only lock, an explicit period, paging until a short page, dedupe by record id, the count with its period, synchronization for caps and the GET-only retry. Step 2: the sources show the contract, the paging rule and the retry rule | The answer text and the matching source lines | PASS if the answer names the lock, the explicit period, the paging and dedupe proof, the synchronization route for caps and the GET-only retry rule. The sources must agree. FAIL if the answer treats a list without a period as complete, prints record content or proposes a non-GET retry. | 1. Re-read `SKILL.md` section 3 Read Step Contract. 2. Re-read the paging and retry rules in `references/rest-api.md`. 3. Confirm no read printed record content |

### Command Block

Run the source check from the `cli-moneybird/` package root. Do not run a real read and do not set a token.

```bash
rg -n "Read Step Contract|explicit period|short page|dedupe|Retry-After" SKILL.md references/rest-api.md
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/reads-and-saved-output/read-step-contract.md`](../../feature-catalog/reads-and-saved-output/read-step-contract.md) | Feature-catalog entry for the Read Step Contract |
| [`feature-catalog/reads-and-saved-output/period-filter-warning.md`](../../feature-catalog/reads-and-saved-output/period-filter-warning.md) | Feature-catalog entry for the period rule inside the contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`SKILL.md`](../../SKILL.md) | Owns the Read Step Contract in section 3 |
| [`references/rest-api.md`](../../references/rest-api.md) | Paging, caps and retry detail |
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Enforces the read-only lock and the period warning |

---

## 5. SOURCE METADATA

- Group: Reads and saved output
- Playbook ID: MBD-015
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `reads/read-step-contract.md`
