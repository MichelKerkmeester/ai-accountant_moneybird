---
title: "MBD-006 -- Attachment routes through the CLI"
description: "This scenario validates that invoice attachment work uses the guarded CLI and requires write confirmation."
version: 1.0.0.0
---

# MBD-006 -- Attachment routes through the CLI

This document captures the user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-006`.

---

## 1. OVERVIEW

This scenario validates that invoice attachment work uses the guarded CLI and requires write confirmation.

### Why This Matters

An attachment changes a Moneybird record. The guard must preview the route and hold the write until it is confirmed.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-006` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that invoice attachment work uses `moneybird-guard` with `--confirm-write`.
- Real user request: `Which Moneybird command attaches a PDF to an invoice in the pilot administration?`
- Prompt: `Which guarded CLI command attaches a PDF to an invoice in the pilot administration?`
- Expected execution process: The agent answers from the skill without uploading anything. The operator compares the answer with the routing table and migration recipe.
- Expected signals: The answer names a `moneybird-guard --confirm-write --approval "$APPROVAL_REF" ... attachment` command and identifies the pilot administration.
- Desired user-visible outcome: The operator receives the guarded command pattern and knows that the write needs approval.
- Pass/fail: PASS if the answer routes through the guarded CLI with `--confirm-write`, `--approval` and the pilot administration. FAIL if it proposes a direct CLI write or runs an upload.
- Feature catalog: [Write confirmation lock](../../feature-catalog/write-guard/write-confirmation-lock.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Answer from the routing table and migration recipe.
3. Do not run a write or upload a file.
4. Compare the answer with the expected command pattern.
5. Return a concise final answer.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-006 | Attachment routes through the CLI | Confirm that invoice attachment work uses the guarded CLI and requires confirmation | `Which guarded CLI command attaches a PDF to an invoice in the pilot administration?` | 1. `agent: answer the prompt` -> 2. `bash: rg -n "attachment" ROUTER.md references/migration-recipes.md` | Step 1: a guarded attachment command with `--confirm-write` and the pilot administration. Step 2: both sources describe the guarded CLI route | The answer and matching source lines | PASS if the answer routes through the guard with confirmation and names the pilot administration. FAIL if it proposes a direct CLI write or runs an upload. | 1. Re-read the operation table in `ROUTER.md` section 2. 2. Re-read the attachment recipe in `references/migration-recipes.md`. 3. Confirm no upload command ran |

### Command Block

Run the source check from the `cli-moneybird/` package root. Do not use a real or test file.

```bash
rg -n "attachment" ROUTER.md references/migration-recipes.md
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/write-confirmation-lock.md`](../../feature-catalog/write-guard/write-confirmation-lock.md) | Feature-catalog entry for write confirmation |

### Implementation Anchors

| File | Role |
|---|---|
| [`ROUTER.md`](../../ROUTER.md) | Operation routing table |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Guarded attachment recipe |

---

## 5. SOURCE METADATA

- Group: Routing boundaries
- Playbook ID: MBD-006
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `routing/attachment-through-cli.md`
