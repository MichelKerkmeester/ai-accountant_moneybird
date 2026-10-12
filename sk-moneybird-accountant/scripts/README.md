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
| `check-fragments.py` | Resolves every relative link path and fragment in the skill family, matches a fragment against an `<a id>` line or a GitHub-style heading slug, rejects a duplicate-suffixed slug, and requires the eight section ids of every year topic file in order |
| `fragment-check-test.sh` | Builds fixtures for a resolving slug, a renamed id, a renamed heading, a missing file and a duplicate-suffix slug, then runs the checker on the real corpus and on a throwaway copy with one renamed heading |

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
- The toc block in `dutch-tax-rules.md`, a generated section list right after its read plan. It lists each H2 and subsections 3.1 to 3.10 with the line range of each on the final file, so a rule question can name one range instead of the whole file.
- `references/index.json`, one row per file with its byte count, line count and H2 sections. Structure only, no figures.
- The TOPIC FILES and HEADLINE FIGURES tables in the eight `references/YYYY/README.md` files.
- The generated year-figure rows in section 3 of `dutch-tax-rules.md`, each naming its owning file, year, Status and Check.
- The reachability check over the leaves in `leaf-manifest.json`.

Fence convention: a generated block sits between two marker lines that each stand alone. Each marker is an HTML comment holding the word GENERATED, the block id and start or end, separated by colons, as written by `build-reference-index.py`. The generator replaces only the bytes between a matched pair, so hand prose outside a pair stays as it was. An unmatched, nested or malformed marker stops the run with exit code 2. `--init` adds a missing pair at the anchor its block registers, and a pair added around bytes that are already correct keeps those bytes.

A nav block or a toc block over its budget fails `--check`. The budget of one file is the smaller of 1,200 bytes and 1 percent of that file's size. The fixed cap binds a large file such as `dutch-tax-rules.md`, and the percentage cap binds a file just over the 51,200-byte limit.

| Mode | Purpose |
|---|---|
| (no flag) | Writes every changed fence body and the index |
| `--check` | Recomputes every output in memory and reports each difference without writing, exit 1 on drift or on a nav or toc block over its budget |
| `--init` | Inserts the empty fence pair of every missing block at its anchor, idempotent and writes no index |
| `--overlap` | Reports the headline values that section 3 restates in prose and how many no generated row owns, reads only |
| `--reachability` | Reports every manifest leaf that no routed folder, link or index entry reaches |

Measured overhead beside the gain: the nav blocks add 14,479 bytes and 365 lines across the 51 files, and `references/index.json` is about 96 KB. The gain: every large file can be read in parts that each stay within 51,200 bytes, and the restated section 3 values without an owner fell from 58 to 0.

---

## 7. SECTION IDS AND FRAGMENTS

Every year topic file under `references/YYYY/` carries eight id lines, one per numbered H2. An id line holds one year-free anchor and sits on the line after its heading, with a blank line between. The visible heading keeps the year. The eight ids and their order are fixed:

`1-overview`, `2-key-figures`, `3-how-it-works`, `4-worked-examples`, `5-changes`, `6-in-the-books`, `7-open-points`, `8-related-resources`

The local shape uses no `{#id}` heading form and no anchor line on an H3. A rule inside section 3 is reached by its line range in the section list of `dutch-tax-rules.md`, not by a fragment. H3 slugs repeat across some files, so a suffix such as `-1` is not a stable address.

`check-fragments.py` reads `AGENTS.md`, `README.md` and the markdown of the three skill folders. It resolves every relative link path, then it matches each `path.md#fragment` against an `<a id>` line or a GitHub-style heading slug in the target. An anchor-only link resolves inside the file that holds it. A fragment that matches only a duplicate-suffixed slug fails as `duplicate-suffix`, even when the target exists. External URLs, images and links inside fenced code blocks are skipped. The script makes no network call and its output is sorted. In a year topic file it also reports a missing, unexpected, duplicate or out-of-order id by name.

`fragment-check-test.sh` proves both directions on a fixture repository. The fixtures carry a resolving slug link, a resolving anchor id, a renamed id, a renamed target heading, a missing file and a duplicate-suffix slug. Two more cases remove one id from a topic file and swap two ids. The suite then runs the checker on the real corpus and on a throwaway copy of the tree with one target heading renamed, and expects the copy to name the lost fragment. Every fixture lives under a temp root and the real tree is never written.

---

## 8. VALIDATION

Run from the repository root.

```bash
python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check
bash sk-moneybird-accountant/scripts/plan-kit-test.sh
python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
bash sk-moneybird-accountant/scripts/reference-index-test.sh
python3 -I sk-moneybird-accountant/scripts/check-fragments.py
bash sk-moneybird-accountant/scripts/fragment-check-test.sh
```

Expected result: `generated files match`, `reference-index: ok`, a `check-fragments` summary line with 0 problems, and a final pass and fail count line with 0 failed for each test script. CI runs the plan kit scripts in `.github/workflows/plan-kit.yml`. The last two commands print `check-fragments: 1958 links, 159 fragment links, 0 problems` and `19 passed, 0 failed`.

---

## 9. RELATED

- [`../references/migration/README.md`](../references/migration/README.md) for the phase references the generator reads
- [`../assets/migration/README.md`](../assets/migration/README.md) for the generated templates
- [`../../scripts/README.md`](../../scripts/README.md) for the privacy gate that guards these files
- [`../SKILL.md`](../SKILL.md) for how the skill uses the kit
