---
title: Reference entry surfaces
description: Publishes the generated reference landing page, the key figure item index, the answer surface field and labels and the sourced term glosses.
trigger_phrases:
  - reference landing page
  - reference entry surfaces
  - key figure item index
  - answerSurface
version: 1.0.0.0
---

# Reference entry surfaces

## 1. OVERVIEW

Publishes the generated reference landing page, the key figure item index, the answer surface field and labels and the sourced term glosses.

`build-reference-index.py` writes every surface in one run over the reference tree. The surfaces exist so a reader reaches a figure row, a section or a file without reading a whole section and so every claim about the tree is checked rather than asserted.

---

## 2. HOW IT WORKS

### The landing page and the item index

`references/README.md` is a generated landing page with three per-group blocks, one for the year groups, one for the tax-rule top-level files and one for the migration files. Every row comes from the frontmatter description of the file it names, so one regeneration picks up a new file or a changed description.

Every value table on the new layout carries a generated item index between a `GENERATED:key-figure-index` marker pair, with one row per value row of the table. A reader scans the index and opens the one row it needs.

### The index fields and the labels

Every file record in `references/index.json` carries an `answerSurface` object with the keys `section`, `rows` and `tokens`. A file with no value table records an empty section and zero rows instead of a promise it cannot keep. Every reference markdown file carries a `nav_label` frontmatter field, so the folder lists and the landing page show a stable label.

### The term glosses

`assets/term-map.json` holds one row per Dutch term that appears in a generated table, with the English gloss a reader sees on first use and the source the owning year file cites for it. `build-source-library.py` checks the map, so a term without a source does not land.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/build-reference-index.py` | Script | Writes the landing page, the item index, the `answerSurface` records and the `nav_label` field check in one run. |
| `sk-moneybird-accountant/references/README.md` | Shared | The generated landing page with the three per-group blocks. |
| `sk-moneybird-accountant/references/index.json` | Shared | Holds one record per reference file with its `answerSurface` object. |
| `sk-moneybird-accountant/assets/term-map.json` | Shared | One row per Dutch term with its English gloss and the source the owning year file cites. |
| `sk-moneybird-accountant/scripts/build-source-library.py` | Script | Checks the frontmatter field set and the sourced term map entries. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/reference-index-test.sh` | Automated test | Proves the item index holds one row per value row and the `answerSurface` schema and values on fixture repositories. |
| `sk-moneybird-accountant/scripts/source-library-test.sh` | Automated test | Proves the frontmatter field set and the term map checks: a glossed term with no row, a `source_file` that names no file and one that lacks the term. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the reference index check and the source library check on push and pull request. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/reference-entry-surfaces.md

Related references:
- [reference-index-and-year-changes.md](reference-index-and-year-changes.md) - The generator whose run also writes these surfaces.
- [tax-knowledge-base.md](tax-knowledge-base.md) - The tree these surfaces describe.
