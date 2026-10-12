---
title: "scripts: Migration Plan Kit"
description: "Generates the migration plan kit from the phase references, creates the private migration workspace and tests both."
version: 1.0.0.0
trigger_phrases:
  - "generate plan kit"
  - "init migration workspace"
  - "plan kit test"
---

# scripts: Migration Plan Kit

---

## 1. OVERVIEW

`scripts/` owns the migration plan kit for the skill. It turns the phase references into templates and a tracked spec packet, and it copies those templates into the git-ignored workspace where real migration data lives.

Current state:

- `references/migration/` is the source. The generator writes `assets/migration/` and `specs/000-migration-template/` from it, and `--check` fails when they drift.
- Generated files hold placeholders only. Real finance data lives in `migration-workspace/` and in the copied spec packet, both git-ignored.
- `init-workspace.sh` never overwrites an existing file and refuses to run unless git ignores both targets.
- Output is byte-stable: sorted inputs, no timestamps and no randomness.
- All three files are gate files. A change needs the Operator's approval, as `../../scripts/README.md` describes.

---

## 2. ARCHITECTURE

```text
╭──────────────────────────────────────────────────────────────────╮
│                         MIGRATION PLAN KIT                       │
╰──────────────────────────────────────────────────────────────────╯

┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────────────┐
│ references/migration │ ───▶ │ generate-plan-kit.py │ ───▶ │ assets/migration/            │
│ phase references     │      │ --check finds drift  │      │ specs/000-migration-template │
└──────────────────────┘      └──────────────────────┘      └──────────────┬───────────────┘
                                                                           │
                                                                           ▼
                              ┌──────────────────────┐      ┌──────────────────────────────┐
                              │ init-workspace.sh    │ ───▶ │ migration-workspace/         │
                              │ copy, never overwrite│      │ specs/<NNN-slug>/ (ignored)  │
                              └──────────────────────┘      └──────────────────────────────┘

┌──────────────────────┐
│ plan-kit-test.sh     │ ───▶ runs both scripts in throwaway repositories
└──────────────────────┘

Dependency direction: references ───▶ generator ───▶ tracked templates ───▶ workspace copy
```

---

## 3. KEY FILES

| File | Responsibility |
|---|---|
| `generate-plan-kit.py` | Parses the phase references and the setup reference, renders the phase dashboard, the config template, the workspace folder list and one spec packet per phase, then writes them or checks them |
| `init-workspace.sh` | Creates `migration-workspace/` from `assets/migration/` and copies `specs/000-migration-template/` to `specs/<NNN-slug>/`, skipping every file that already exists |
| `plan-kit-test.sh` | Builds throwaway repositories, runs the generator and the workspace script, and checks the generated files, placeholders, links, refusals and repeat runs |
| `check-route-table.py` | Checks the task-type route table in `../SKILL.md`: markers, header, rows T1 to T9, budgets, tool routes, read-set paths, constants, margin overrides and signal source links |
| `route-table-test.sh` | Runs the route table checker on the real SKILL.md and on mutated copies, and expects every mutant to fail |
| `build-session-context.py` | Writes the git-ignored `session-context.json` from the runtime clock and a narrow migration projection, with `--check` and `--route-state` |
| `session-context-test.sh` | Runs the script against offline fixtures for the clock, the interactive flag, the allowlist, staleness and the post-cutover states |
| `build-reference-index.py` | Scans `../references/` and writes or checks the nav blocks, `../references/index.json`, the year README tables, the section 3 value rows and the leaf reachability report |
| `reference-index-test.sh` | Builds a fixture repository, runs the generator on it and on the real corpus, and checks the fence rules, drift detection, byte stability and the mutation cases |

---

## 4. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Source | Edit `references/migration/`, then regenerate. Never hand-edit a generated file |
| Generated output | `assets/migration/` and `specs/000-migration-template/` are tracked and hold placeholders only |
| Private output | `migration-workspace/` and `specs/<NNN-slug>/` are git-ignored. The scripts refuse a symlinked target and a target git does not ignore |
| Imports | The generator uses the Python standard library only and runs with `python3 -I`. The shell scripts run on Bash 3.2 |

---

## 5. ENTRYPOINTS

| Entrypoint | Type | Purpose |
|---|---|---|
| `python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py` | CLI | Regenerates the kit after a phase reference changed |
| `python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check` | CLI | Confirms the tracked kit matches the references, exit 1 on drift |
| `bash sk-moneybird-accountant/scripts/init-workspace.sh [--dry-run] [--spec-name <NNN-slug>]` | CLI | Creates the private workspace and the working spec packet |
| `bash sk-moneybird-accountant/scripts/plan-kit-test.sh` | CLI | Runs the kit test suite |

---

## 6. REFERENCE INDEX

`build-reference-index.py` keeps the generated text of the reference tree in step with the files that own it. It is offline and byte-stable. One pass over `references/` owns:

- The nav block after the H1 of every reference file over 51,200 bytes. The block lists the read parts, and every part ends at a heading line and stays at or under 51,200 bytes.
- `references/index.json`, one row per file with its byte count, line count and H2 sections. Structure only, no figures.
- The TOPIC FILES and HEADLINE FIGURES tables in the eight `references/YYYY/README.md` files.
- The generated year-figure rows in section 3 of `dutch-tax-rules.md`, each naming its owning file, year, Status and Check.
- The reachability check over the leaves in `leaf-manifest.json`.

Fence convention: a generated block sits between two marker lines that each stand alone. Each marker is an HTML comment holding the word GENERATED, the block id and start or end, separated by colons, as written by `build-reference-index.py`. The generator replaces only the bytes between a matched pair, so hand prose outside a pair stays as it was. An unmatched, nested or malformed marker stops the run with exit code 2. `--init` adds a missing pair at the anchor its block registers, and a pair added around bytes that are already correct keeps those bytes.

| Mode | Purpose |
|---|---|
| (no flag) | Writes every changed fence body and the index |
| `--check` | Recomputes every output in memory and reports each difference without writing, exit 1 on drift |
| `--init` | Inserts the empty fence pair of every missing block at its anchor, idempotent and writes no index |
| `--overlap` | Reports the headline values that section 3 restates in prose and how many no generated row owns, reads only |
| `--reachability` | Reports every manifest leaf that no routed folder, link or index entry reaches |

Measured overhead beside the gain: the nav blocks add 14,479 bytes and 365 lines across the 51 files, and `references/index.json` is about 96 KB. The gain: every large file can be read in parts that each stay within 51,200 bytes, and the restated section 3 values without an owner fell from 58 to 0.

---

## 7. VALIDATION

Run from the repository root.

```bash
python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check
bash sk-moneybird-accountant/scripts/plan-kit-test.sh
python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
bash sk-moneybird-accountant/scripts/reference-index-test.sh
```

Expected result: `generated files match`, `reference-index: ok`, and a final pass and fail count line with 0 failed for each test script. CI runs the plan kit scripts in `.github/workflows/plan-kit.yml`.

---

## 8. RELATED

- [`../references/migration/README.md`](../references/migration/README.md) for the phase references the generator reads
- [`../assets/migration/README.md`](../assets/migration/README.md) for the generated templates
- [`../../scripts/README.md`](../../scripts/README.md) for the privacy gate that guards these files
- [`../SKILL.md`](../SKILL.md) for how the skill uses the kit
