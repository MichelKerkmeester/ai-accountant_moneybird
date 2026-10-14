---
title: Topic file split
description: Holds every year topic as four part files and the general topics as 13 files, and proves with a hashed manifest that no part drifted after the split.
trigger_phrases:
  - Topic file split
  - split-topic-files.py
  - split-manifest.json
  - figures rules examples notes parts
  - general topic files
version: 1.0.0.0
---

# Topic file split (split-topic-files.py)

## 1. OVERVIEW

Holds every year topic as four part files and the general topics as 13 files, and proves with a hashed manifest that no part drifted after the split.

Each of the 96 year topics under `references/tax-rules/{year}/` is a folder of `figures.md`, `rules.md`, `examples.md` and `notes.md`, and the general topics of `dutch-tax-rules.md` sit in `references/tax-rules/general/`. A read opens one part instead of a whole topic, so no reference file is over the 15,000-token line.

---

## 2. HOW IT WORKS

### Parts and citations

Every topic file shared the same eight H2 sections, so each splits the same way: sections 1 and 2 into `figures.md`, 3 into `rules.md`, 4 into `examples.md` and 5 to 8 into `notes.md`. Each part opens with a header that names the topic, the part, its three siblings and the year README. A citation names a part: a `path:line` citation points at the part that holds the line, a `path#anchor` citation at the part that carries the heading and a bare topic path at `figures.md`.

### Drift check

`references/tax-rules/split-manifest.json` records a normalized body hash and a header hash for every part and one hash over the kept entry file. The normalization ignores rebased links and generated fences, so a changed sentence, value, status tag, URL or header line fails `--check` while a regenerated block does not. `check-route-table.py` runs the check, so CI fails on a drifted part. A hand-edited part is restored with `git checkout`, because the original files are gone after the split.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/split-topic-files.py` | Script | Plans, writes and checks the split and remaps every citation. |
| `sk-moneybird-accountant/references/tax-rules/split-manifest.json` | Shared | Holds the part hashes, the entry hash and the line map. |
| `sk-moneybird-accountant/references/tax-rules/general/` | Shared | Holds the 13 general topic files. |
| `sk-moneybird-accountant/scripts/check-route-table.py` | Script | Runs the split check beside the route table check. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/split-topic-files-test.sh` | Automated test | Proves each drift mutant, the citation remap and a byte-stable second write on a fixture repository. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the route table check, and with it the split check, on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/topic-file-split.md

Related references:
- [reference-index-and-year-changes.md](reference-index-and-year-changes.md) - The generator that writes the index and the fences the split check ignores.
- [year-rollover-runbook.md](year-rollover-runbook.md) - The runbook that refreshes the year files.
