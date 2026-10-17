---
title: Eval grader
description: Grades captured answers against the eval assertion blocks and writes the pass rates and the skill hash.
trigger_phrases:
  - Eval grader
  - run-evals.py
  - captured answer grading
  - eval assertion block
  - refusal false positive
version: 1.0.0.0
---

# Eval grader (run-evals.py)

## 1. OVERVIEW

Grades captured answers against the eval assertion blocks and writes the pass rates and the skill hash.

`scripts/run-evals.py --grade` reads a capture folder that holds `metadata.json`, one with-skill answer per case and one baseline answer per case. The cases and their assertion blocks live in `evals/evals.json`, each with a prompt, an expected route, required tokens and forbidden patterns.

---

## 2. HOW IT WORKS

The grader checks the required tokens and the forbidden patterns of every case. A required entry written as a list passes when any one of its alternative phrasings appears. Refusal markers match case-sensitively, so only the uppercase route class counts as a refusal and a marker is excused when a negation sits next to it in the same sentence. An amount or an identifier is never excused.

`grading.json` holds the per-case assertion rows and the always-pass count. `benchmark.json` holds the pass rate, the baseline pass rate, the refusal false-positive rate and the always-pass list. Both record the skill hash of `SKILL.md` plus every routed reference and the model id. No model judges an answer, so a pass means no listed contradiction appeared and a captured run still gets a read by the Operator or a reviewer.

The test suite builds capture fixtures for a compliant run, a broken answer, a refuse-everything run, a forbidden-pattern trip, another capture year, alternative phrasings and three skill snapshots.

The case set covers the five VAT branches, the yearly overview (jaaroverzicht) pack, the income tax return (aangifte inkomstenbelasting) pack and the tax-deliverable filing refusal. The refusal case fails an answer that claims the agent files, submits, pays or locks, so a prepare answer that reaches outside its boundary is caught.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/run-evals.py` | Script | Grades a capture folder and writes the grading and benchmark files. |
| `sk-moneybird-accountant/evals/evals.json` | Shared | Holds the eval cases, their expected routes and their assertion blocks. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | The routing behavior the eval cases measure. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/run-evals-test.sh` | Automated test | Builds capture fixtures for a compliant run, a broken answer, a refuse-everything run and the branch, pack and refusal cases. |
| `sk-moneybird-accountant/hardening-matrix.md` | Reference | Names the eval cases that cover the routing failure modes. |
| `.github/workflows/skill-health.yml` | Test harness | Parses the eval file and runs the grader suite. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/eval-grader.md

Related references:
- [route-replay-harness.md](route-replay-harness.md) - The offline corpus scorer.
- [hostile-invoice-set.md](hostile-invoice-set.md) - The other offline safety scorer.
