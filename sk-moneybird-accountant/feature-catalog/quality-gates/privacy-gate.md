---
title: Privacy gate
description: Blocks personal or finance data in the tracked tree, a commit message and a pushed range before it leaves the machine.
trigger_phrases:
  - Privacy gate
  - scripts/privacy-gate.py
  - staged privacy check
  - push privacy check
  - privacy gate change approval
version: 1.0.0.0
---

# Privacy gate (privacy-gate.py)

## 1. OVERVIEW

Blocks personal or finance data in the tracked tree, a commit message and a pushed range before it leaves the machine.

`scripts/privacy-gate.py` scans the index, the tree at a given revision, the history, one commit message or a drafted answer before it is sent. Findings are masked and never contain the matched value. The rules, the denylist terms and the allowed paths live in `.privacy-gate.json` and the hooks in `.githooks/` call the gate before a commit and a push.

---

## 2. HOW IT WORKS

The staged mode checks the git identity that a new commit would record, and the history and push modes check the author and committer of every scanned commit. A finding names its file and line but not the value. The answer mode scans a drafted answer and its loaded context against the amount rule, which allows a public figure only when the cited reference holds it.

A commit that changes a gate file needs the approval variable only the Operator sets and the commit message carries the approval trailer. The test suite proves every pattern and mode on fixtures, including a split IBAN, a fullwidth digit sequence, a gate change without the trailer and a push range read from the remote tip.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `scripts/privacy-gate.py` | Script | Scans the index, the tree, the history, a commit message or a drafted answer. |
| `.privacy-gate.json` | Shared | Holds the rules, the denylist terms and the allowed paths. |
| `.githooks/pre-commit` | Script | Runs the staged check before a commit. |
| `.githooks/pre-push` | Script | Runs the push check before a push. |
| `scripts/install-hooks.sh` | Script | Installs the hooks and reports the expected core.hooksPath. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `scripts/privacy-gate-test.sh` | Automated test | Proves every pattern and mode on fixtures, including a split IBAN and a gate change without the trailer. |
| `.github/workflows/privacy-gate.yml` | Test harness | Runs the self test, the tree check, the history check and the suite. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/privacy-gate.md

Related references:
- [repository-ci-gates.md](repository-ci-gates.md) - The workflows that run this gate.
- [../bookkeeping-and-migration/migration-data-privacy.md](../bookkeeping-and-migration/migration-data-privacy.md) - The skill-level privacy rule.
