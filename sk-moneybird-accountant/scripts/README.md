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
| `token-baseline.py` | Counts every reference file and the named units in `o200k_base` and `cl100k_base`, writes or checks `../benchmark/token-baseline.json`, and refuses to run when a pinned encoding data file is missing or changed |
| `token-canary-test.sh` | Runs the car-question route, a whole-file mutant, a swapped-encoding mutant and a byte-only fixture in a throwaway copy |

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
| `TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py` | CLI | Re-measures the corpus and writes the baseline after a reference change |
| `TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check` | CLI | Confirms the baseline matches the corpus, exit 1 on drift |
| `TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/token-canary-test.sh` | CLI | Runs the token canary suite |

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

## 8. TOKEN BASELINE

`token-baseline.py` counts every markdown file under `../references/` in `o200k_base` and `cl100k_base`, whole file and per H2 section, and adds the named units, the overhead rows and the car route. `../benchmark/token-baseline.json` holds the result. The file holds paths and counts only, sorts its keys and carries no timestamp, so two runs produce the same bytes.

The read budget ladder, in tokens:

| Unit | Budget |
|---|---|
| One year README | 3,000 tokens |
| One section | 5,000 tokens |
| One full topic file | 15,000 tokens |
| `dutch-tax-rules.md` section 3 | 80,000 tokens, only behind a TOC jump |

The task-type table in `../SKILL.md` states every row budget from this ladder. The canary route reads the year README and one topic section, and its 8,000 `cl100k_base` ceiling is the first two ladder rows together.

The pin names the two encodings, the library version and the sha256 of each encoding data file:

| Encoding | Role | Cache file | Data sha256 |
|---|---|---|---|
| `o200k_base` | lead | `fb374d419588a4632f3f557e76b4b70aebbca790` | `446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d` |
| `cl100k_base` | second column | `9b5ad71b2ce5302211f9c61530b329a4922fc6a4` | `223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7` |

The library is `tiktoken` 0.11.0. The Operator chose `o200k_base` as the lead on 2026-10-12, with `cl100k_base` kept as a second column. Both encodings are proxies, so every count stands in for a model family and none is exact.

Offline rule: the two data files come from a seeded cache. Point `TIKTOKEN_CACHE_DIR` at it, for example `../tiktoken-cache` from the repository root. The run checks that each file exists and that its sha256 matches the pin before it loads an encoder. A missing file or a changed file stops the run with exit code 2. Nothing downloads an encoding.

Re-measure rule: re-measure on every reference change. Run `token-baseline.py` and commit the JSON with the change. A run with nothing to write ends with `baseline unchanged, 122 files, 917 sections`. `--check` recomputes every row in memory and names each drifted row, so a stale baseline fails the run. The final lines of a passing check:

```text
token-baseline: check ok, 122 files, 917 sections
token-baseline: unit car route proposed: 23004 bytes, o200k_base 6684, cl100k_base 7289
token-baseline: car route ratio: o200k_base 0.2814, cl100k_base 0.2846
```

The canary covers the 2026 car question on the KEY FIGURES route, which reads the year README and section 2 of `kosten-en-auto.md`. It asserts the proposed route stays at or under 35 percent of the current route and at or under the 8,000 token ceiling. Three mutants prove the gate: the proposed route pointed at the whole topic file, a cache that holds the lead encoding data under the second name, and a fixture that passes a four-bytes-per-token budget and fails the token budget. The measured route:

```text
route current: o200k_base 23750, cl100k_base 25608
route proposed: o200k_base 6684, cl100k_base 7289
route ratio: o200k_base 0.2814, cl100k_base 0.2846
```

The suite ends with `7 passed, 0 failed`.

---

## 9. VALIDATION

Run from the repository root.

```bash
python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check
bash sk-moneybird-accountant/scripts/plan-kit-test.sh
python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
bash sk-moneybird-accountant/scripts/reference-index-test.sh
python3 -I sk-moneybird-accountant/scripts/check-fragments.py
bash sk-moneybird-accountant/scripts/fragment-check-test.sh
TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check
TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/token-canary-test.sh
```

Expected result: `generated files match`, `reference-index: ok`, a `check-fragments` summary line with 0 problems, and a final pass and fail count line with 0 failed for each test script. CI runs the plan kit scripts in `.github/workflows/plan-kit.yml`. The fragment checks print `check-fragments: 1959 links, 159 fragment links, 0 problems` and `19 passed, 0 failed`. The token commands print `token-baseline: check ok, 122 files, 917 sections` and `7 passed, 0 failed`.

---

## 10. RELATED

- [`../references/migration/README.md`](../references/migration/README.md) for the phase references the generator reads
- [`../assets/migration/README.md`](../assets/migration/README.md) for the generated templates
- [`../../scripts/README.md`](../../scripts/README.md) for the privacy gate that guards these files
- [`../SKILL.md`](../SKILL.md) for how the skill uses the kit
