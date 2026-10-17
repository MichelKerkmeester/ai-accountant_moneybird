---
title: Write contract check
description: Checks every write-contract restatement in the bootstrap and skill files against the one canonical contract.
trigger_phrases:
  - Write contract check
  - write-contract-check.py
  - canonical write contract
  - guard exit codes
  - payload_digest
version: 1.0.0.0
---

# Write contract check (write-contract-check.py)

## 1. OVERVIEW

Checks every write-contract restatement in the bootstrap and skill files against the one canonical contract.

`references/migration/shared-mechanisms.md` owns the canonical gate tokens, exit codes and read-back sentence. `scripts/write-contract-check.py` parses those canonical parts and then checks each restatement in `AGENTS.md`, `ROUTER.md` and `cli-moneybird/SKILL.md` on its own, and the pointer lines of `SKILL.md`.

---

## 2. HOW IT WORKS

The checker reads each restatement file on its own, so a gate token or a rule that leaves `ROUTER.md` fails even while `SKILL.md` still names it. It confirms that the pointer anchor resolves, that every gate token appears, that a flag named on a pointer line belongs to the canonical set, that the two named rules for evidence and idempotency are present and that no exit outside the canonical set is named. No line may define read-back differently from the canonical sentence. The guard's own die codes must stay a subset of the canonical set. `SKILL.md` only points at the contract, so it is checked for its pointer, its pointer line flags, its exits and its read-back line.

A clean run prints one ok line. The test suite seeds the divergences the contract review found and requires each seeded copy to fail and name its file and a missing root is refused.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/write-contract-check.py` | Script | Parses the canonical contract and every restatement and fails on drift. |
| `sk-moneybird-accountant/references/migration/shared-mechanisms.md` | Shared | Owns the canonical gate tokens, exit codes and read-back sentence. |
| `cli-moneybird/SKILL.md` | Shared | Holds one restatement of the contract. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Holds the accountant restatement of the contract. |
| `sk-moneybird-accountant/SKILL.md` | Shared | Points at the contract from its migration and write steps. |
| `AGENTS.md` | Shared | Holds the project safety line and the pointer for guarded writes. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/write-contract-test.sh` | Automated test | Seeds a missing flag, a missing pointer, a forbidden pointer flag, a token and a rule gone from `ROUTER.md` only, a missing rule, a missing exit and a second read-back sentence and requires each to fail. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the check and the suite on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/write-contract-check.md

Related references:
- [fragment-link-check.md](fragment-link-check.md) - The sibling link drift check.
- [regression-trailer-check.md](regression-trailer-check.md) - Guards a change to the contract file.
