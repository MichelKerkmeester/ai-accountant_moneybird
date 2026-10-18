---
title: "scripts: Privacy Gate"
description: "The privacy gate that keeps personal and financial data out of this public repository, its test suite and its hook installer."
trigger_phrases:
  - "privacy gate scripts"
  - "privacy gate test suite"
  - "install privacy hooks"
---

# scripts: Privacy Gate

---

## 1. OVERVIEW

`scripts/` owns the privacy gate for this public repository. Git hooks and CI run it to block personal data, finance records and secrets before they reach the index, a commit message, a pushed commit or a pushed tag.

Current state:

- `privacy-gate.py` is the only scanner. The privacy hooks and the privacy-gate CI workflow call it, so a rule lives in one place.
- Findings are masked and never print the matched value.
- Staged mode reads its rules from `HEAD`. Push mode reads the rules and the gate code at the remote's commit and re-runs that copy. A local edit cannot widen the rules for its own commit or push.
- Every script in this folder is a gate file. A change to one needs `PRIVACY_GATE_CHANGE_APPROVED=1`, which only the Operator sets, and the line `Privacy-Gate-Change: approved` in the commit message.

---

## 2. ARCHITECTURE

```text
╭──────────────────────────────────────────────────────────────────╮
│                          PRIVACY GATE                            │
╰──────────────────────────────────────────────────────────────────╯

┌──────────────────┐      ┌──────────────────┐
│ install-hooks.sh │ ───▶ │ .githooks/*      │ ───┐
│ sets hooksPath   │      │ commit and push  │    │
└──────────────────┘      └──────────────────┘    ▼
                                         ┌──────────────────┐      ┌────────────────────┐
┌──────────────────┐                     │ privacy-gate.py  │ ───▶ │ .privacy-gate.json │
│ privacy-gate.yml │ ──────────────────▶ │ one scanner      │      │ .privacy-denylist  │
│ CI workflow      │                     └──────────────────┘      └────────────────────┘
└──────────────────┘                              ▲
                                                  │
┌──────────────────────┐                          │
│ privacy-gate-test.sh │ ─────────────────────────┘
│ throwaway repos      │
└──────────────────────┘

Dependency direction: hooks, CI and tests ───▶ privacy-gate.py ───▶ config and denylist
```

---

## 3. KEY FILES

| File | Responsibility |
|---|---|
| `privacy-gate.py` | The scanner. Checks blocked paths and names, file types, sizes, IBAN, BSN, VAT numbers, amounts, emails, author identities, secrets and denylist terms |
| `privacy-gate-test.sh` | Integration suite. Builds throwaway repositories and generates every sensitive value at runtime, so the suite itself scans clean |
| `install-hooks.sh` | Points `core.hooksPath` at `.githooks/`, makes the hooks executable and creates `.privacy-denylist` from the example when it is missing |

---

## 4. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Rules | `.privacy-gate.json` at the repository root holds every path, extension, allowlist and gate-file rule. The gate reads it from git, never from the working tree |
| Private terms | `.privacy-denylist` is git-ignored and holds the Operator's own names and terms. Only the Operator fills it |
| Imports | `privacy-gate.py` uses the Python standard library only and runs with `python3 -I` |
| Output | The gate prints the finding kind, the path, the line and a masked hint. It never prints a matched value |

Main flow for a push:

```text
╭──────────────────────────────────────────╮
│ git push                                 │
╰──────────────────────────────────────────╯
                  │
                  ▼
┌──────────────────────────────────────────┐
│ .githooks/pre-push passes the refs       │
└──────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────┐
│ privacy-gate.py --push reads the config  │
│ and gate code at the remote's commit     │
└──────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────┐
│ each pushed commit, message and tag is   │
│ scanned, gate-file changes need approval │
└──────────────────────────────────────────┘
                  │
                  ▼
╭──────────────────────────────────────────╮
│ exit 0 clean, 1 findings, 2 usage error  │
╰──────────────────────────────────────────╯
```

---

## 5. ENTRYPOINTS

| Entrypoint | Type | Purpose |
|---|---|---|
| `python3 -I scripts/privacy-gate.py --staged` | CLI | Scans the index. The `pre-commit` and `pre-merge-commit` hooks run it |
| `python3 -I scripts/privacy-gate.py --push <remote> [--trusted-code]` | CLI | Scans the commits a push sends, with refs on stdin. The `pre-push` hook runs it. `--trusted-code` marks the running copy as the remote's anchor copy, so the gate does not re-run it. The gate passes the flag itself when it re-runs that copy |
| `python3 -I scripts/privacy-gate.py --message <file>` | CLI | Scans a commit message before the commit exists. The `commit-msg` hook runs it |
| `python3 -I scripts/privacy-gate.py --answer <file> [--transcript <file>]` | CLI | Scans a drafted answer, and the context it was written from, before it is sent. Any hit blocks the answer. An amount passes only when the answer cites an amount-allowed reference that holds the same figure |
| `python3 -I scripts/privacy-gate.py --tree [--config-ref <rev>]` | CLI | Scans every tracked file at `HEAD`. `--config-ref <rev>` reads the rules from that revision instead of `HEAD` |
| `python3 -I scripts/privacy-gate.py --history [--config-ref <rev>]` | CLI | Scans every commit, message and tag in history. `--config-ref <rev>` reads the rules from that revision instead of `HEAD` |
| `python3 -I scripts/privacy-gate.py --self-test-patterns` | CLI | Checks the detection patterns against generated values |
| `bash scripts/install-hooks.sh` | CLI | Installs the hooks once per clone |

---

## 6. VALIDATION

Run from the repository root.

```bash
python3 -I scripts/privacy-gate.py --self-test-patterns
bash scripts/privacy-gate-test.sh
python3 -I scripts/privacy-gate.py --tree
```

Expected result: `self-test ok`, a final `Result:` line with 0 failed, and `privacy-gate: clean`. CI runs the same commands plus `--history` in `.github/workflows/privacy-gate.yml`.

---

## 7. RELATED

- [`../README.md`](../README.md) for the repository and its privacy rules
- [`../AGENTS.md`](../AGENTS.md) for the agent rules on gate files and approvals
- [`../.github/workflows/privacy-gate.yml`](../.github/workflows/privacy-gate.yml) for the CI run
- [`../sk-moneybird-accountant/scripts/README.md`](../sk-moneybird-accountant/scripts/README.md) for the plan kit scripts
