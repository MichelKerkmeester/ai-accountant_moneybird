---
title: Reference index and year changes
description: Regenerates the reference nav blocks, the index, the year README tables and the year changes overview from the files that own them.
trigger_phrases:
  - Reference index and year changes
  - build-reference-index.py
  - generated reference nav block
  - year changes overview
  - references/index.json
version: 1.0.0.0
---

# Reference index and year changes (build-reference-index.py)

## 1. OVERVIEW

Regenerates the reference nav blocks, the index, the year README tables and the year changes overview from the files that own them.

`scripts/build-reference-index.py` keeps the generated text of the reference tree in step with the files that own it. A write run moves only the bytes between a matched marker pair, so hand prose outside a pair stays as it was and a check run recomputes every output in memory without writing.

---

## 2. HOW IT WORKS

### Generated outputs

One pass over `references/` owns the nav blocks in files over the byte limit, the section list in `dutch-tax-rules.md`, `references/index.json`, the topic and headline tables in every year README, the year-figure rows in section 3 of the rules file, the change block of every year note, the whole-file `references/year-changes.md` overview and the reachability report over the leaf manifest.

### Modes and fences

The default run writes every changed block. `--check` reports each difference and exits nonzero on drift, on a change-note bullet failure or on a nav or toc block over its byte budget. `--init` inserts a missing fence pair at its anchor, `--overlap` reports restated headline values that no generated row owns and `--reachability` reports every manifest leaf that no routed folder or reachable page reaches.

A generated block sits between two marker lines that each hold the word GENERATED, the block id and start or end. An unmatched, nested or malformed marker stops the run and output is byte-stable, so a reference edit cannot leave a half-generated tree.

### Year notes

A year change note holds authored bullets in its unique-to-the-year section and a generated block in its all-changes section. The check applies three rules to every authored bullet. A number must occur in the linked section. The last link must resolve to a year-folder file and its changes anchor. The note must hold a number of bullets inside the band the check enforces. The overview repeats those bullets and rebases their links to the references root.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/build-reference-index.py` | Script | Writes or checks every generated reference block and the reachability report. |
| `sk-moneybird-accountant/references/index.json` | Shared | Holds one structure-only row per reference file with its bytes, lines and H2 sections. |
| `sk-moneybird-accountant/references/year-changes.md` | Shared | Holds the generated overview of the year change notes. |
| `sk-moneybird-accountant/references/dutch-tax-rules.md` | Shared | Carries the generated section list and the section 3 value rows. |
| `sk-moneybird-accountant/leaf-manifest.json` | Shared | Names the leaves the reachability report checks. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/reference-index-test.sh` | Automated test | Proves the fence rules, drift detection, byte stability and the change-note mutants on fixtures and the real corpus. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the index check and its suite on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/reference-index-and-year-changes.md

Related references:
- [session-context-and-year-state.md](session-context-and-year-state.md) - The route-time context that reads the reference tree.
- [year-rollover-runbook.md](year-rollover-runbook.md) - The runbook that refreshes the year files.
