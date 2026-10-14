---
title: "scripts: Plan Kit, Checkers and Suites"
description: "Generates the migration plan kit, builds the session context, and owns the offline checkers and test suites that guard the skill's routes, references, tokens and writes."
version: 1.0.0.0
trigger_phrases:
  - "generate plan kit"
  - "init migration workspace"
  - "plan kit test"
  - "route table checker"
  - "token baseline"
---

# scripts: Plan Kit, Checkers and Suites

---

## 1. OVERVIEW

`scripts/` owns the migration plan kit, the session context builder and the offline checkers and test suites for the skill. The plan kit turns the phase references into templates and a tracked spec packet, and it copies those templates into the git-ignored workspace where real migration data lives. The checkers keep the route table, the reference index, the fragments, the token baseline and the write contract in step with the tree.

Current state:

- `references/migration/` is the source for the plan kit. The generator writes `assets/migration/` and `specs/000-migration-template/` from it, and `--check` fails when they drift.
- Generated files hold placeholders only. Real finance data lives in `migration-workspace/` and in the copied spec packet, both git-ignored.
- `init-workspace.sh` never overwrites an existing file and refuses to run unless git ignores both targets.
- Output is byte-stable: sorted inputs, no timestamps and no randomness.
- The plan-kit files `generate-plan-kit.py`, `init-workspace.sh` and `plan-kit-test.sh` are gate files. A change to one needs the Operator's approval, as `../../scripts/README.md` describes.
- Every checker and suite is offline. Only `build-source-library.py --check-links` and `--watch` make network calls, and the monthly job runs them.

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

## 3. DIRECTORY TREE

```text
scripts/
+-- README.md                     # This guide
+-- generate-plan-kit.py          # Renders the plan kit from the phase references
+-- init-workspace.sh             # Creates migration-workspace/ and copies the spec packet
+-- plan-kit-test.sh              # Plan kit suite
+-- build-session-context.py      # Writes session-context.json
+-- session-context-test.sh       # Session context suite
+-- check-route-table.py          # Route table and router block checker
+-- route-table-test.sh           # Route table suite
+-- build-reference-index.py      # Reference index and generated block builder
+-- reference-index-test.sh       # Reference index suite
+-- check-fragments.py            # Relative link and fragment checker
+-- fragment-check-test.sh        # Fragment suite
+-- split-topic-files.py          # Tax-rules topic file splitter
+-- split-topic-files-test.sh     # Topic file split suite
+-- token-baseline.py             # Token baseline writer and checker
+-- token-canary-test.sh          # Token canary suite
+-- check-hostile-invoice-set.py  # Hostile invoice case checker
+-- hostile-invoice-set-test.sh   # Hostile invoice suite
+-- write-contract-check.py       # Write contract drift checker
+-- write-contract-test.sh        # Write contract suite
+-- run-evals.py                  # Eval grader
+-- run-evals-test.sh             # Eval grader suite
+-- check-hardening-matrix.py     # Hardening matrix checker
+-- hardening-matrix-test.sh      # Hardening matrix suite
+-- check-regression-trailer.py   # Regression trailer checker
+-- regression-trailer-test.sh    # Regression trailer suite
+-- build-source-library.py       # External source index builder
+-- source-library-test.sh        # Source library suite
`-- route-replay/
    +-- route-replay.py           # Offline route scoring and guard replay
    +-- routing-gold.json         # Route fixture corpus
    `-- route-replay-test.sh      # Route replay suite
```

---

## 4. KEY FILES

| File | Responsibility |
|---|---|
| `generate-plan-kit.py` | Parses the phase references and the setup reference, renders the phase dashboard, the config template, the workspace folder list and one spec packet per phase, then writes them or checks them |
| `init-workspace.sh` | Creates `migration-workspace/` from `assets/migration/` and copies `specs/000-migration-template/` to `specs/<NNN-slug>/`, skipping every file that already exists |
| `plan-kit-test.sh` | Builds throwaway repositories, runs the generator and the workspace script, and checks the generated files, placeholders, links, refusals and repeat runs |
| `check-route-table.py` | Checks the task-type route table in `../SKILL.md`: markers, header, rows T1 to T12, budgets, tool routes, the read-set grammar, constants, margin overrides, signal source links and the documented gap ledger. Expands every read item over its year and map tokens, fails a missing required path or anchor and lists a missing conditional read. Compares the generated router block with the table row by row and the table's multi-word signals with `../graph-metadata.json`, and the `--write` mode regenerates both |
| `route-table-test.sh` | Runs the route table checker on the real SKILL.md and on mutated copies, and expects every mutant to fail. Covers the router block drift, the hand edit inside the block, the missing intent signal, the byte-stable second write, the read-set grammar, the two maps and the gap ledger rows |
| `build-session-context.py` | Writes the git-ignored `session-context.json` from the runtime clock and a narrow migration projection, with `--check` and `--route-state` |
| `session-context-test.sh` | Runs the script against offline fixtures for the clock, the interactive flag, the allowlist, staleness and the post-cutover states |
| `build-reference-index.py` | Scans `../references/` and writes or checks the nav blocks, `../references/index.json` with its gap ledger, the year README tables, the year-figure rows of the general topic files, the change note tables, `../references/tax-rules/year-changes.md` and the leaf reachability report |
| `reference-index-test.sh` | Builds a fixture repository, runs the generator on it and on the real corpus, and checks the fence rules, drift detection, byte stability, the change note mutants, the gap ledger mutants and the mutation cases |
| `check-fragments.py` | Resolves every relative link path and fragment in the skill family, matches a fragment against an `<a id>` line or a GitHub-style heading slug, rejects a duplicate-suffixed slug, and requires the section ids of every year topic file in order. A flat topic file carries all eight ids. A phase 003 split part carries its own subset: `figures.md` sections 1 and 2, `rules.md` section 3, `examples.md` section 4 and `notes.md` sections 5 to 8. The year README, the year changelog and the year change note are exempt |
| `fragment-check-test.sh` | Builds fixtures for a resolving slug, a renamed id, a renamed heading, a missing file, a duplicate-suffix slug, a year topic at any depth, a split topic part with one id removed and the year file exemptions, then runs the checker on the real corpus and on a throwaway copy with one renamed heading |
| `split-topic-files.py` | Splits the 96 year topic files into four part files, rewrites `../references/tax-rules/dutch-tax-rules.md` into `../references/tax-rules/general/`, remaps every citation of a split source and writes `../references/tax-rules/split-manifest.json`. The `--plan`, `--write` and `--check` modes stay offline and hash a normalized body |
| `split-topic-files-test.sh` | Builds a fixture repository and proves each failure mode: a hand-edited part, a hand-edited header, a hand-edited entry file, a returned original, an unmappable citation, a folder with fewer than four parts, a part over the token line, a rebased link, a generated fence in a header, a byte-stable second write and the remapped citation line |
| `token-baseline.py` | Counts every reference file and the named units in `o200k_base` and `cl100k_base`, writes or checks `../benchmark/token-baseline.json`, and refuses to run when a pinned encoding data file is missing or changed |
| `token-canary-test.sh` | Runs the car-question route, a whole-file mutant, a swapped-encoding mutant and a byte-only fixture in a throwaway copy |
| `check-hostile-invoice-set.py` | Checks the hostile invoice case set: 22 unique cases, a twin for every attack, declared braced placeholders, every rule applied to every string value, no literal IBAN, VAT id, amount or e-mail, no capitalized word run outside the declared `allowed_terms` and an expected verdict that matches the case kind. Scores a results file against the catch and false-positive thresholds |
| `hostile-invoice-set-test.sh` | Runs the checker on the real set and on seven seeded mutations. Scores results fixtures in both directions and refuses an incomplete results file |
| `write-contract-check.py` | Checks the write contract restatements in `AGENTS.md` and the two skill files against the canonical contract in `../references/migration/shared-mechanisms.md`: the pointer anchor, the gate tokens, the two named rules, the exit codes and the read-back sentence. The guard's own die codes must stay a subset of the canonical set |
| `write-contract-test.sh` | Runs the drift check on the real tree and on a clean copy, then seeds five divergences. Each one must fail and name its file, and a missing root is refused |
| `route-replay/route-replay.py` | Reads the phase map, the topic map and the weak signals from the skill, applies the filing precedence, scores the route fixture corpus offline in `resolve` mode and replays the refusal and hostile rows through the guard and the stub in `replay` mode, with a connectivity gate, a router snapshot hash, `--rev`, `--covers` and `results.csv` plus `report.md` output |
| `route-replay/routing-gold.json` | The route fixture corpus, version 2: one row per offline routing scenario, its Dutch twin, the gap, tie, tier, out-of-scope, follow-up, mixed, refusal and hostile rows, a preparation row and a filing row for each of T10 to T12, a two-turn row and an additive T7 row, with the calibration and held-out labels written before any tuning |
| `route-replay/route-replay-test.sh` | Runs the route replay on a temp copy of the skill and proves both modes, the deleted path, the twin mismatch, the unmet claim, a wrong expected exit, two dated runs, the filing precedence and the new report sections |
| `run-evals.py` | Grades captured with-skill and baseline answers against the assertion blocks in `../evals/evals.json` and writes `grading.json` and `benchmark.json` with the skill hash, the pass rates and the refusal false-positive rate |
| `run-evals-test.sh` | Builds capture fixtures for a compliant run, a broken answer, a refuse-everything run, a forbidden-pattern trip, another capture year, alternative phrasings and three skill snapshots |
| `../evals/evals.json` | The eval cases, each with a prompt, an expected route and an assertion block of required tokens and forbidden patterns |
| `check-hardening-matrix.py` | Parses `../hardening-matrix.md` and fails a P0 row with a missing test path or a case name that does not occur in that file |
| `hardening-matrix-test.sh` | Proves the matrix check on the real matrix and on copies with a removed P0 test path, a blank P0 cell and a renamed case |
| `../hardening-matrix.md` | One row per failure mode with a control, a test, an owner and a status, including the offline suites that now cover most rows |
| `check-regression-trailer.py` | Fails a commit range where a gate file changed with no registered test change and no `Regression-Test:` trailer |
| `regression-trailer-test.sh` | Builds fixture git repositories for the trailer check, including a deleted covering test, valid and invalid trailers, an unknown range and a missing root |
| `build-source-library.py` | Scans the skill family for external links and writes `../assets/source-library.json`, with `--check`, `--check-links`, `--apply-report`, `--watch`, `--check-calendar` and `--trace` modes |
| `source-library-test.sh` | Proves the index builder, the link check and the trace on fixture repositories, a fixture server on 127.0.0.1, and the real index |
| `../assets/route-calibration.json` | The frozen calibration record: the route margin, the fallback floor, the sweep over the calibration split and the held-out result |

---

## 5. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Source | Edit `references/migration/`, then regenerate. Never hand-edit a generated file |
| Generated output | `assets/migration/` and `specs/000-migration-template/` are tracked and hold placeholders only |
| Private output | `migration-workspace/` and `specs/<NNN-slug>/` are git-ignored. The scripts refuse a symlinked target and a target git does not ignore |
| Imports | The generator uses the Python standard library only and runs with `python3 -I`. The shell scripts run on Bash 3.2 |
| Fixture data | `route-replay/routing-gold.json`, `../evals/evals.json` and `../hardening-matrix.md` hold synthetic prompts and placeholders only, with no real name, amount, IBAN or administration id |
| Network | Only `build-source-library.py --check-links` and `--watch` make network calls, and they run in the scheduled job. Every other script and suite is offline |
| Token cache | Token counts read the pinned cache beside the repository. A missing cache folder or a changed data file exits 2 |

---

## 6. ENTRYPOINTS

| Entrypoint | Type | Purpose |
|---|---|---|
| `python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py` | CLI | Regenerates the kit after a phase reference changed |
| `python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check` | CLI | Confirms the tracked kit matches the references, exit 1 on drift |
| `bash sk-moneybird-accountant/scripts/init-workspace.sh [--dry-run] [--spec-name <NNN-slug>]` | CLI | Creates the private workspace and the working spec packet |
| `bash sk-moneybird-accountant/scripts/plan-kit-test.sh` | CLI | Runs the kit test suite |
| `TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py` | CLI | Re-measures the corpus and writes the baseline after a reference change |
| `TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check` | CLI | Confirms the baseline matches the corpus, exit 1 on drift |
| `TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/token-canary-test.sh` | CLI | Runs the token canary suite |
| `TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve` | CLI | Scores the route corpus offline and writes `results.csv` and `report.md` |
| `python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay` | CLI | Replays the refusal and hostile rows through the guard and the stub CLI |
| `TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | CLI | Runs the route replay suite |
| `python3 -I sk-moneybird-accountant/scripts/run-evals.py --grade <capture>` | CLI | Grades a captured run and writes `grading.json` and `benchmark.json` |
| `bash sk-moneybird-accountant/scripts/run-evals-test.sh` | CLI | Runs the eval grader suite |
| `python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py --check` | CLI | Checks the hardening matrix for complete rows and covered P0 tests |
| `bash sk-moneybird-accountant/scripts/hardening-matrix-test.sh` | CLI | Runs the hardening matrix suite |
| `python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range <base>..<head>` | CLI | Checks a commit range for gate changes without a covering test |
| `bash sk-moneybird-accountant/scripts/regression-trailer-test.sh` | CLI | Runs the regression trailer suite |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check` | CLI | Verifies the external source index offline |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-links` | CLI | Fetches every reachable source and prints the JSON report, for the scheduled job only |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --trace <file>:<line>` | CLI | Prints the index result for every URL on one citation line |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --apply-report <file>` | CLI | Writes a link report's results into the matching index rows, offline |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --watch` | CLI | Fetches the watched series and reports each change, for the scheduled job only |
| `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar` | CLI | Checks the year files' `checked_on` against the release calendar, offline |
| `bash sk-moneybird-accountant/scripts/source-library-test.sh` | CLI | Runs the source library suite |

---

## 7. REFERENCE INDEX

`build-reference-index.py` keeps the generated text of the reference tree in step with the files that own it. It is offline and byte-stable. One pass over `references/` owns:

- The nav block after the H1 of every reference file over 51,200 bytes. The block lists the read parts, and every part ends at a heading line and stays at or under 51,200 bytes. After the topic split no reference file is over that line, so no nav block is present today.
- The toc block, a generated section list after the read plan of a guide. The topic split moved the sections of `dutch-tax-rules.md` into `general/`, and the generator removes a read plan and section list a file no longer needs, so no toc block is present today.
- `references/index.json`, one row per file with its byte count, line count and H2 sections, plus a top-level `gaps` list copied from the Documented gaps table of `routing-signals.md` in table order. Structure only, no figures.
- The TOPIC FILES and HEADLINE FIGURES tables in the eight `references/tax-rules/YYYY/README.md` files.
- The generated year-figure rows in the ten general topic files under `references/tax-rules/general/`, each naming its owning file, year, Status and Check.
- One `changes` block in each `references/tax-rules/YYYY/changes.md`, one row per topic file with the section 5 bullet count, the first bullet cut to a snippet and the link to the section 5 anchor in that topic's `notes.md`.
- `references/tax-rules/year-changes.md` as a whole-file output, one H2 per year, newest first, with the path link to the year note and that note's authored bullets.
- The reachability check over the leaves in `leaf-manifest.json`.

Fence convention: a generated block sits between two marker lines that each stand alone. Each marker is an HTML comment holding the word GENERATED, the block id and start or end, separated by colons, as written by `build-reference-index.py`. The generator replaces only the bytes between a matched pair, so hand prose outside a pair stays as it was. An unmatched, nested or malformed marker stops the run with exit code 2. `--init` adds a missing pair at the anchor its block registers, and a pair added around bytes that are already correct keeps those bytes.

A year change note holds authored bullets in its "Unique to <year>" section and the generated block in its "All changes by topic" section. The overview is generated whole, so `--check` compares it byte for byte and a write replaces it. A hand edit inside the block or in the overview fails the check and names the file. The overview repeats the authored bullets of every note, and their topic links are rebased to the references root so they resolve from the overview.

`--check` applies three rules to the authored bullets of every note. A number in a bullet must occur as the same number in the linked section 5. The last link of a bullet must resolve to an existing file in the year folder and its `<a id="5-changes"></a>` line. A year note must hold five to ten authored bullets. Real failure lines:

```text
changes tax-rules/2026/changes.md bullet 3 number 99 not in inkomstenbelasting/notes.md#5-changes
changes tax-rules/2026/changes.md bullet 1 link btw/notes.md#6-in-the-books does not resolve
changes tax-rules/2026/changes.md 4 authored bullets, the band is 5 to 10
drift tax-rules/2026/changes.md changes
drift year-changes.md
```

A write run reports the files it moved, for example:

```text
reference-index: wrote tax-rules/2026/changes.md
reference-index: wrote tax-rules/year-changes.md
reference-index: wrote index.json
```

A nav block or a toc block over its budget fails `--check`. The budget of one file is the smaller of 1,200 bytes and 1 percent of that file's size. The fixed cap binds a large file, and the percentage cap binds a file just over the 51,200-byte limit.

| Mode | Purpose |
|---|---|
| (no flag) | Writes every changed fence body, the year change overview and the index |
| `--check` | Recomputes every output in memory and reports each difference without writing, exit 1 on drift, on a change note bullet failure or on a nav or toc block over its budget |
| `--init` | Inserts the empty fence pair of every missing block at its anchor, idempotent and writes no index |
| `--overlap` | Reports the headline values that the year topic files restate in prose and how many no generated row owns, reads only |
| `--reachability` | Reports every manifest leaf that no routed folder, link or index entry reaches |

Measured on the current tree: no file carries a nav block, `references/index.json` is about 149 KB and `--overlap` prints `overlap: restated 29 of 192, unowned 29`. Before the topic split the same report printed 58 of 192, all unowned.

---

## 8. SECTION IDS AND FRAGMENTS

Every year topic file under `references/tax-rules/YYYY/` carries eight id lines, one per numbered H2. An id line holds one year-free anchor and sits on the line after its heading, with a blank line between. The visible heading keeps the year. The eight ids and their order are fixed:

`1-overview`, `2-key-figures`, `3-how-it-works`, `4-worked-examples`, `5-changes`, `6-in-the-books`, `7-open-points`, `8-related-resources`

The local shape uses no `{#id}` heading form and no anchor line on an H3. A cross-year rule is reached through the General topics table in section 3 of `dutch-tax-rules.md`, which names its one file under `general/`, not by a fragment. H3 slugs repeat across some files, so a suffix such as `-1` is not a stable address.

`check-fragments.py` reads `AGENTS.md`, `README.md` and the markdown of the three skill folders. It resolves every relative link path, then it matches each `path.md#fragment` against an `<a id>` line or a GitHub-style heading slug in the target. An anchor-only link resolves inside the file that holds it. A fragment that matches only a duplicate-suffixed slug fails as `duplicate-suffix`, even when the target exists. External URLs, images and links inside fenced code blocks are skipped. The script makes no network call and its output is sorted. In a year topic file it also reports a missing, unexpected, duplicate or out-of-order id by name. A year topic file below `references/` is either a flat file directly in a year folder or one part of a topic folder directly under a year folder. The flat file carries all eight ids. The split parts carry a subset: `figures.md` sections 1 and 2, `rules.md` section 3, `examples.md` section 4 and `notes.md` sections 5 to 8. A year folder holds three files beside its topic files: `README.md`, `changelog.md` and `changes.md`. The checker applies the id rule to the topic files alone, so the correction log and the change note stay out of it.

`fragment-check-test.sh` proves both directions on a fixture repository. The fixtures carry a resolving slug link, a resolving anchor id, a renamed id, a renamed target heading, a missing file and a duplicate-suffix slug. Two more cases remove one id from a topic file and swap two ids. Two more cases prove that a year changelog and a year change note carry no section ids while the topic file beside them still does. A nested year topic below `references/` is held to its eight ids, and a split topic part is held to its subset, so one case removes a required anchor from `figures.md` and expects a missing-id problem. The suite then runs the checker on the real corpus and on a throwaway copy of the tree with one target heading renamed, and expects the copy to name the lost fragment. Every fixture lives under a temp root and the real tree is never written.

---

## 9. TOKEN BASELINE

`token-baseline.py` counts every markdown file under `../references/` in `o200k_base` and `cl100k_base`, whole file and per H2 section, and adds the named units, the overhead rows and the car route. `../benchmark/token-baseline.json` holds the result. The file holds paths and counts only, sorts its keys and carries no timestamp, so two runs produce the same bytes.

The read budget ladder, in tokens:

| Unit | Budget |
|---|---|
| One year README | 3,000 tokens |
| One section | 5,000 tokens |
| One full topic file or part | 15,000 tokens |

The task-type table in `../SKILL.md` states every row budget from this ladder. The canary route reads the year README and one topic section, and its 8,000 `cl100k_base` ceiling is the first two ladder rows together.

The pin names the two encodings, the library version and the sha256 of each encoding data file:

| Encoding | Role | Cache file | Data sha256 |
|---|---|---|---|
| `o200k_base` | lead | `fb374d419588a4632f3f557e76b4b70aebbca790` | `446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d` |
| `cl100k_base` | second column | `9b5ad71b2ce5302211f9c61530b329a4922fc6a4` | `223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7` |

The library is `tiktoken` 0.11.0. The Operator chose `o200k_base` as the lead on 2026-10-12, with `cl100k_base` kept as a second column. Both encodings are proxies, so every count stands in for a model family and none is exact.

Offline rule: the two data files come from a seeded cache. Point `TIKTOKEN_CACHE_DIR` at it, for example `../tiktoken-cache` from the repository root. The run checks that each file exists and that its sha256 matches the pin before it loads an encoder. A missing file or a changed file stops the run with exit code 2. Nothing downloads an encoding.

Re-measure rule: re-measure on every reference change. Run `token-baseline.py` and commit the JSON with the change. A run with nothing to write opens with the line `baseline unchanged, 444 files, 994 sections`, after the script name. `--check` recomputes every row in memory and names each drifted row, so a stale baseline fails the run. A passing check opens with the line `check ok, 444 files, 994 sections`, after the script name, prints one row per named unit and ends with:

```text
token-baseline: unit car route current: 84263 bytes, o200k_base 24620, cl100k_base 26474
token-baseline: unit car route proposed: 23411 bytes, o200k_base 6796, cl100k_base 7389
token-baseline: car route ratio: o200k_base 0.2760, cl100k_base 0.2791
```

The canary covers the 2026 car question on the KEY FIGURES route, which reads the year README and the `kosten-en-auto/figures.md` part. It asserts the proposed route stays at or under 35 percent of the current route and at or under the 8,000 token ceiling. Three mutants prove the gate: the proposed route pointed at the whole topic file, a cache that holds the lead encoding data under the second name, and a fixture that passes a four-bytes-per-token budget and fails the token budget. The measured route:

```text
route current: o200k_base 24620, cl100k_base 26474
route proposed: o200k_base 6796, cl100k_base 7389
route ratio: o200k_base 0.2760, cl100k_base 0.2791
```

The suite ends with `8 passed, 0 failed`.

---

## 10. HOSTILE INVOICE SET

`check-hostile-invoice-set.py` guards the untrusted-content rule with a scored corpus. `../assets/hostile-invoice-cases.json` holds 22 synthetic invoice cases: ten attacks, ten legitimate twins and two clean controls. The cases are synthetic, so no real invoice, supplier, bank account, VAT id or amount sits in the file.

The shape check proves the corpus: 22 unique cases, a twin for every attack, a declared placeholder in every braced token, every rule applied to every string value, no literal IBAN, VAT id, amount or e-mail, no capitalized word run outside the declared `allowed_terms` and an expected verdict that matches the case kind. An attack and its twin carry the same rule string, so a pair is never split across rules.

The score mode reads one verdict per case and compares the two rates with the Operator's thresholds: every attack must be refused and at most one of the twelve benign cases may be refused. A passing run prints:

```text
catch 10/10
false positives 1/12
verdict PASS
```

`hostile-invoice-set-test.sh` seeds the broken shapes the checker must catch: a missing twin, a literal amount, a duplicate id, an expected verdict that contradicts the kind, an unbraced placeholder, a name pair in a template and a name pair in a rule field. It then scores fixtures in both directions, including a run at the false-positive threshold and one above it. An incomplete results file is refused.

---

## 11. WRITE CONTRACT CHECK

`write-contract-check.py` guards the one canonical write contract. `../references/migration/shared-mechanisms.md` owns the canonical gate tokens, exit codes and read-back sentence, and `AGENTS.md`, `../SKILL.md` and `../../cli-moneybird/SKILL.md` keep one safety line and a pointer. The checker parses the canonical parts and then checks every restatement: the pointer anchor resolves, every gate token appears, a flag named on a pointer line belongs to the canonical set, the two named rules (evidence and idempotency) are present and no exit outside the canonical set is named. The ladder file must name every canonical exit. No line may define read-back differently from the canonical sentence. The guard's own die codes must stay a subset of the canonical set. A passing run prints:

```text
write-contract: ok
```

`write-contract-test.sh` seeds the divergences the contract review found: a safety line without `--confirm-write`, a missing pointer, a missing idempotency rule, a missing exit 9 and a second differing read-back sentence. Each seeded copy must fail the check and name its file. A missing root is refused. The suite ends with `Result: 9 passed, 0 failed`.

---

## 12. ROUTE REPLAY

`route-replay/route-replay.py` scores the route fixture corpus offline. In `resolve` mode it builds a router snapshot from the task-type table in `../SKILL.md` section 2, the constants in `../references/routing-signals.md` and the resource map. It reads `PHASE_FILES` and `TOPIC_FILES` from the generated router block and the weak signals from `../references/routing-signals.md` instead of keeping its own copy, and a T1 or T5 read resolves through those maps. A T1 request that names a phase reads its phase file without the migration index, which stays the fallback when no phase is named. When a T8 filing signal from the table matches, T8 wins over T10, T11 and T12, and the scorer keeps no filing list of its own. It prints the snapshot sha256, runs a connectivity gate over every routed path and scores each row for mode, task type, read set, expected facts and the token ceiling. In `replay` mode it runs `moneybird-guard` in test mode against the stub CLI and asserts the recorded command line and exit code of every refusal row and every hostile invoice case. Time, environment and absolute paths never enter an output. `--rev` scores a git worktree of one revision, `--covers` filters the rows by their tag, and `--corpus`, `--out`, `--guard` and `--stub` point at other inputs. Token counts read the pinned `o200k_base` cache and a missing or changed data file exits 2 before any download.

Output is `results.csv` and `report.md`. The CSV columns are `scenario_id`, `lang`, `split`, `gold_mode`, `gold_task_type`, `score`, `verdict`, `reason`, `tokens_loaded`, `t7` and `reads`, plus `command`, `expected_exit` and `actual_exit` in replay mode. `t7` marks a row whose prompt matches a T7 signal and `reads` counts the files the route loads. The report holds the route accuracy per language and per split, the abstain and false-abstain counts, the facts and tokens per row and the held-out result, plus four sections:

- Additive T7 assertion: every row that matches a T7 signal, with the route it kept. The additive CLI row never wins alone, so a T7 win fails the run.
- Per-type precision and recall: for T1 to T12, the correct routes over the rows routed to that type and over the rows whose gold type it is, with both denominators.
- Read counts: the files each row loads.
- Warning band sink: the rows whose winning gap sits in the warning band above the route margin. Telemetry only, the route never changes.

A passing resolve run over the full corpus prints:

```text
route-replay: ok, 75 rows passed
```

A passing replay run prints:

```text
route-replay: ok, 31 replay rows passed
```

`route-replay/route-replay-test.sh` copies the skill to a temp root and ends with `Result: 47 passed, 0 failed`. It proves the deleted routed path exits 2 and names the path, the twin mismatch and the unmet claim exit 1, a wrong expected exit fails the replay, an empty corpus and a missing cache exit 2, two dated runs give byte-identical `results.csv` and `report.md`, every term the resolver keeps for the T4 conditional reads is a T4 signal in the table, and a preparation turn followed by a filing turn routes T10 and then T8.

---

## 13. EVAL GRADER

`run-evals.py` grades a captured run against `../evals/evals.json`. The captured folder holds `metadata.json` with `model_id`, `captured_on` and an optional `skill_hash`, one `with-skill/<case id>.md` answer per case and one `baseline/<case id>.md` answer per case. The grader checks the required tokens and the forbidden patterns of every case. A required entry written as a list passes when any one of its alternative phrasings appears. Refusal markers match case-sensitively, so only the uppercase route class counts as a refusal. A marker does not count when `not`, `never`, `no longer` or a `n't` form sits up to four words before it in the same sentence, or when `does not`, `is not`, `was not`, `cannot`, `no longer` or `is inapplicable` follows it. A forbidden phrase is excused by the same preceding negation, so a correct answer may deny the act in its own words. An amount or an identifier is never excused. `grading.json` holds the per-case assertion rows and the always-pass count. `benchmark.json` holds the pass rate, the baseline pass rate, the refusal false-positive rate and the always-pass list. Both record the sha256 skill hash of `SKILL.md` plus every routed reference and the model id. A `{year}` token in a required value resolves to the year of the capture date. No model judges an answer, so the forbidden patterns catch the phrasings they list and not every paraphrase. A pass means no listed contradiction appeared, not that the answer is safe, and a captured run still gets a read by the Operator or a reviewer.

`../evals/evals.json` holds 23 cases, each with a prompt, an expected route and an assertion block of required tokens and forbidden patterns. The baseline is the previous skill snapshot. A grader run on the suite fixture capture, whose baseline answers carry none of the tokens, prints:

```text
run-evals: 23 cases, 23 with-skill passed, 0 baseline passed
run-evals: pass rate 1.0000, baseline pass rate 0.0000
run-evals: refusal false positives 0 of 16 benign cases
run-evals: always-pass assertions: 82
```

`run-evals-test.sh` builds the capture fixtures at run time and ends with `Result: 59 passed, 0 failed`.

---

## 14. HARDENING MATRIX

`check-hardening-matrix.py` reads `../hardening-matrix.md` and parses the table between its markers. Every row must name a failure mode, a priority, a control, a test, an owner and a status. A P0 row must name an existing test path as `path :: case name`, and the case name must occur in that file, so a deleted test or a renamed case fails the check. P1 and P2 rows with a missing test path are reported as notes. A passing run prints:

```text
hardening-matrix: ok (27 rows, 21 P0 rows)
```

`hardening-matrix-test.sh` builds fixture copies with one P0 test path removed, one P0 test cell blanked and one case string renamed. Every mutant exits 1 and names the row. The suite ends with `Result: 9 passed, 0 failed`.

---

## 15. REGRESSION TRAILER

`check-regression-trailer.py --range <base>..<head>` lists the range with `git rev-list` and then reads one commit at a time. The message comes from `git log -1` and the changed paths come from `git diff-tree` against the first parent, so a merge commit gets its paths and a message that holds a control character cannot move the boundary of the next commit. A commit that changes `AGENTS.md`, `cli-jortt/SKILL.md`, `cli-moneybird/SKILL.md`, `cli-moneybird/cli/moneybird-cli/moneybird-guard`, `sk-moneybird-accountant/SKILL.md` or `sk-moneybird-accountant/references/migration/shared-mechanisms.md` must add, modify or type-change a registered test in the same commit, or carry a `Regression-Test:` trailer naming a registered test that exists at that commit. A deleted path never counts as a test change. A rename reads as a deletion of its source and an addition of its destination, and a copy reads as an addition of its destination, so both paths of a rename or a copy reach the gate match. The registered set is read from the parent of the commit. It holds the test paths `../hardening-matrix.md` names and the test files the skill health workflow runs, read from its run lines. A named test registers only when it exists at the parent and at the commit, so a test created in the commit under check cannot cover it. A suite path that a name or a glob happens to match does not register. A passing range prints:

```text
regression-trailer: ok (0 commits scanned)
```

`regression-trailer-test.sh` builds fixture git repositories with signing and hooks off and ends with `Result: 43 passed, 0 failed`. It proves a gate change with no test and no trailer exits 1, the same change with a valid trailer exits 0, a deleted covering test does not register, and an unknown range or a missing root exits 2.

---

## 16. SOURCE LIBRARY

`build-source-library.py` scans `AGENTS.md`, `README.md` and the three skill folders for external links and writes `../assets/source-library.json`, one row per URL with its host, the citing files and its recorded access result. `--check` verifies the index offline and reports every cited URL missing from the index and every indexed URL no file cites. `--check-links` fetches every row a plain fetch can reach, reports `endpoint` and `webfetch-only` rows as skipped and never as failed, retries once and prints one JSON report with a summary and one row per URL. A row is ok only when the final answer after followed redirects is 2xx. `--trace <file>:<line>` prints the index row of every URL on one line with `access`, `http_status` and `checked_on`, and fails when a URL is dead, unchecked or missing from the index. Each readable row also keeps a `digest`, `retrieved_at`, an `etag` stored as a `sha256:` fingerprint, `last_modified` and, for a parliamentary document not yet published as a `kst` page, `kst_pending`, and a rebuild keeps them per URL. `--check` also fails on a cited `dead` row and on a `tweedekamer.nl/downloads/document?id=` citation whose row has no `kst_pending`. `--check-links` follows every redirect, 308 included, and counts a `blocked` answer (401, 403 or 429, a host refusing robots) and an error on a recorded `archive-not-fetchable` row apart from failures. `--apply-report <file>` writes a report's results into the index and never writes a blocked row as dead. `--watch` fetches the series in `../assets/source-watchlist.json`, compares ETag, Last-Modified and digest with the index or `../assets/source-watch-state.json`, and reports a changed series or a page that answers 200 after 404 with its citing files. `--check-calendar` reads `checked_on` from the year READMEs and `dutch-tax-rules.md` and fails when a current or future year predates the latest passed checkpoint in `../references/tax-rules/year-rollover.md`. Only `--check-links` and `--watch` make network calls, and they run in the monthly job, which reports a watch change or a stale year as an issue without failing.

A passing offline check prints `524 sources match the index`. A trace of one live citation line prints:

```text
sk-moneybird-accountant/references/tax-rules/2024/btw/figures.md:56
<the cited Belastingdienst URL> access=ok http_status=200 checked_on=2026-10-13
1 URLs, all usable
```

A quiet watch prints `no watched URL changed` and a current calendar prints `3 files current at the Prinsjesdag checkpoint (2026-09-15)`.

`source-library-test.sh` proves the index, the link check and the trace on fixture repositories, a fixture server on 127.0.0.1, and the real index, plus digests, the report write, the watch and its state, the calendar check, blocked hosts and dead or perishable citations. It ends with `130 passed, 0 failed`.

---

## 17. ROUTE CALIBRATION

`../assets/route-calibration.json` records the frozen routing constants that `../SKILL.md` section 2 and `../references/routing-signals.md` state. It holds `ROUTE_MARGIN = 0.25`, `FALLBACK_FLOOR = 0.5`, the sweep that chose the floor in steps of 0.05 from 0.0 to 0.5 over the 53 calibration rows of `routing-gold-v2-calibration-held-out` and the result over the 22 held-out rows. Both splits matched every row with no false abstains. Every swept floor ties on this split, because every winning score sits above 0.5, so the sweep does not discriminate and the tie break toward the higher floor returns the table's 0.5. `check-route-table.py` reads the frozen constants from this file by default and a passing run prints `route-table: ok`.

---

## 18. ROUTER BLOCK

`../SKILL.md` section 2 holds one router block between `<!-- router-block:start -->` and `<!-- router-block:end -->`, generated from the Task-Type Table by `check-route-table.py --write`. The block carries `INTENT_SIGNALS` per row from the Dutch and English signal cells, the read structures below from the read-set column, `UNKNOWN_FALLBACK_CHECKLIST` from the three fallback tiers, and the guard, existence-check and discovery helpers. Edit the table and rerun the mode, never the block by hand.

### Read-set grammar

A read-set cell holds read items in backticks, separated by prose that keeps the condition a reader needs. Each item is one mark, one path and an optional anchor, with no space:

- `!` marks a required read and `?` a conditional read. A backticked token without a mark, or a bare path outside backticks, fails the check. A cell of `-` means no reads.
- `@section-id` names a heading by its GitHub slug and is stripped before the path resolves.
- `{year}` expands over every four-digit folder under `../references/tax-rules/`.
- `{phase-file}` expands to every value of `PHASE_FILES` and `{topic-figures}` to every value of `TOPIC_FILES`.

A `!` item fails when any expansion is missing, so a `{year}` item must exist in every year folder. A missing `?` item prints `missing: <type> <path>` and never fails, which is how a row names a procedure README a later phase writes. An anchor fails when an existing file has no heading with that slug. A path that is absolute, climbs out of the skill folder or does not end in `.md` fails as `escapes the skill folder`.

### Generated structures

One entry per row, T1 to T12 in table order:

| Structure | Holds |
|---|---|
| `REQUIRED_READS` and `CONDITIONAL_READS` | The items of each mark as written, without the mark, with the tokens and anchors kept |
| `SECTION_TARGETS` | Per type, each anchored item's path mapped to its anchor |
| `PHASE_FILES` | Migration phase number to its file, parsed from the phase table in `../references/migration/README.md`: 23 phases, 0 to 22, over 7 files |
| `TOPIC_FILES` | Topic slug to its `figures.md` part at `2-key-figures`, one entry per topic folder: 12 topics |
| `RESOURCE_MAP` and `LOADING_LEVELS` | The union of both marks per type, anchors stripped, tokens kept |

### Gap ledger

The table under the heading `Documented gaps` in `../references/routing-signals.md` lists every deliverable whose procedure is not written yet, with the columns Topic, Owner, Coverage and Operator action. `build-reference-index.py` copies it into `../references/index.json` as the `gaps` list. Coverage is one of `covered`, `partial` and `gap`. The owner is a path inside the skill folder that a later phase may create, so both checks test the fields, not the file. A row with an empty owner, an unknown coverage or a repeated topic fails `check-route-table.py --check` and `build-reference-index.py --check`. The T8 documented-gap answer names the row's topic, owner and Operator action.

The same run appends every multi-word table signal to `../graph-metadata.json` `intent_signals` and never removes a hand-added entry. A first run prints:

```text
router block: written (SKILL.md)
intent signals: added 37 (graph-metadata.json)
```

A second run with no table change leaves both files byte-identical and prints:

```text
router block: unchanged (SKILL.md)
intent signals: unchanged (graph-metadata.json)
```

A malformed table exits 2 and writes neither file, and so does a malformed marker pair or an invalid `../graph-metadata.json`.

`--check` adds two drift checks to the table checks. A table cell that differs from the block exits 1 and names the row, a missing marker pair exits 1, and a table signal absent from `intent_signals` exits 1. Real failure lines:

```text
row T2: block entry differs from the table
router block differs from the table
router block end marker missing
intent signal missing from intent_signals: migration phase
```

`route-table-test.sh` proves the write mode and both drift checks. It ends with a pass line for a table change with no regeneration, a hand edit inside the block, a missing intent signal and a second write that leaves both files byte-identical.

---

## 19. VALIDATION

Run from the repository root.

```bash
python3 -I sk-moneybird-accountant/scripts/generate-plan-kit.py --check
bash sk-moneybird-accountant/scripts/plan-kit-test.sh
python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
bash sk-moneybird-accountant/scripts/reference-index-test.sh
python3 -I sk-moneybird-accountant/scripts/check-fragments.py
bash sk-moneybird-accountant/scripts/fragment-check-test.sh
python3 -I sk-moneybird-accountant/scripts/check-hostile-invoice-set.py --check
bash sk-moneybird-accountant/scripts/hostile-invoice-set-test.sh
python3 -I sk-moneybird-accountant/scripts/write-contract-check.py
bash sk-moneybird-accountant/scripts/write-contract-test.sh
TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check
TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/token-canary-test.sh
TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve
python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay
TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh
python3 -I sk-moneybird-accountant/scripts/run-evals.py --grade <capture>
bash sk-moneybird-accountant/scripts/run-evals-test.sh
python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py --check
bash sk-moneybird-accountant/scripts/hardening-matrix-test.sh
python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range <base>..<head>
bash sk-moneybird-accountant/scripts/regression-trailer-test.sh
python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check
bash sk-moneybird-accountant/scripts/source-library-test.sh
python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
bash sk-moneybird-accountant/scripts/route-table-test.sh
python3 -I sk-moneybird-accountant/scripts/check-skill-words.py
bash sk-moneybird-accountant/scripts/check-skill-words-test.sh
python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --check
bash sk-moneybird-accountant/scripts/split-topic-files-test.sh
```

Expected result: `166 generated files match`, `reference-index: ok`, a `check-fragments` summary line with 0 problems and a final pass and fail count line with 0 failed for each test script. CI runs the plan kit scripts in `.github/workflows/plan-kit.yml`. The fragment checks print `check-fragments: 4406 links, 391 fragment links, 0 problems` and `32 passed, 0 failed`. The hostile set commands print `hostile-invoice-set: ok, 22 cases, 10 attacks, 10 twins, 2 controls` and a final pass and fail count with 0 failed. The write contract commands print `write-contract: ok` and a final pass and fail count with 0 failed. The token commands print `token-baseline: check ok, 444 files, 994 sections` and `8 passed, 0 failed`. The route replay commands print `route-replay: ok, 75 rows passed` and `route-replay: ok, 31 replay rows passed`, and the suite ends with `Result: 47 passed, 0 failed`. The eval suite ends with `Result: 59 passed, 0 failed`. The hardening matrix check prints `hardening-matrix: ok (27 rows, 21 P0 rows)` and its suite ends with `Result: 9 passed, 0 failed`. The regression trailer suite ends with `Result: 43 passed, 0 failed`. The source library check prints `524 sources match the index` and its suite ends with `130 passed, 0 failed`. The route table commands print `route-table: ok` after one `missing:` line per absent conditional read, and the suite ends with `58 passed, 0 failed`. The split commands print `split-check: ok` and `Result: 12 passed, 0 failed`.

The word check prints one line per `SKILL.md` with its word count and its verdict. It warns above 3,000 words, exits 1 above 4,000 words and exits 2 with the path named when a file is missing or unreadable. `check-route-table.py` runs it, so the `skill-health` CI step enforces the budget, and `check-skill-words-test.sh` proves the 2,999-word, 3,001-word and 4,001-word bands. The walk skips hidden folders, `specs/`, `node_modules/` and the two private folders, so a backup copy of a retired skill inside a spec packet never counts.

---

## 20. TOPIC FILE SPLIT

`split-topic-files.py` splits each of the 96 year topic files under `../references/tax-rules/YYYY/` into a folder of four parts: `figures.md` with sections 1 and 2, `rules.md` with section 3, `examples.md` with section 4 and `notes.md` with sections 5 to 8. The same run rewrites `../references/tax-rules/dutch-tax-rules.md`, moves its ten section 3 topics and its cross-year H2 sections 4 to 6 into `../references/tax-rules/general/{slug}.md` and writes `../references/tax-rules/split-manifest.json`. The 13 general slugs are fixed by the privacy gate allowlist, and a computed slug outside that set stops the run with exit 2.

A part file is a derived header followed by the original section bytes. The header holds the frontmatter, an H1 that names the topic and the part, the year rule line copied verbatim and a pointer block to the three sibling parts and the year README. The body starts on the first H2 or H3 heading line after the frontmatter, so the manifest hash covers the knowledge bytes alone.

| Mode | Purpose |
|---|---|
| `--plan` | Prints one `source` row per topic file, one `part` row per part with its byte size and its o200k token count when the cached encoding is available, one `general` row and one `general-part` row per general file, and writes nothing. This is the default |
| `--write` | Plans every source, writes the four parts, removes each original with `git rm`, rewrites the entry file into the pointer table, remaps every citation of a split source and writes the manifest. A citation that cannot be mapped exits 1 and no byte is written |
| `--check` | Recomputes every part body, every part header, the entry file hash and the rejoin from the part files alone, compares each hash with the manifest, refuses a leftover original, refuses a folder with fewer than four parts, refuses a part over the 15,000 token line and reports every citation that still points at a split source. Reads only |

The manifest holds one row per split source with the source path, the normalized rejoin sha256 and one record per part with its path, its section numbers, its normalized body sha256, its header sha256 and its source line map. The header hash covers the derived header with every GENERATED fence and blank line removed, so the index generator may add or drop a nav fence while a hand edit to the header fails `--check`. The general record carries the same kind of hash for the whole entry file, so its kept sections and pointer table are guarded too. The manifest is version 3. Keys are sorted and rows are sorted by source, so a second `--write` with no source change writes no byte. The general record carries the same fields plus the heading of each part and the line map of the entry file.

The rejoin proof (REQ-002, amended on 2026-10-14) compares normalized bodies and never the raw bytes. The write rebases every relative link to the part's new folder depth and points a link at a split original to the part that now holds its target. The normalization removes the contents of every GENERATED fence and resolves every link target to its canonical repository path through the split map, so a rebased link and a regenerated fence do not change a hash while a changed sentence, value, status tag or URL does. `--check` applies the same normalization to the part files and prints one `rejoin ok` line per source, or a `drift <source> part <part>` line that names the file and the part, plus the leftovers and the unmapped citation count. A hand-edited part is restored with `git checkout` of that part: the source file is gone after the split, so `--write` cannot rebuild it and prints `nothing to split` while the manifest stands. A passing run ends with:

```text
rejoin ok sk-moneybird-accountant/references/tax-rules/2020/btw/figures.md (4 parts)
rejoin ok sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md (13 general parts)
leftovers: 0
unmapped citations: 0
split-check: ok
```

The citation remap scans every tracked markdown and JSON file outside `specs/`. A bare citation points at the folder's `figures.md`, a `path:line` citation points at the part that holds that line with its new line number and a `path#anchor` citation points at the part that carries that heading. A citation whose line, heading or file cannot be resolved aborts the run with exit 1 and names the citation before any byte is written. The scan leaves its own outputs and the files their own generators rewrite alone: `.privacy-gate.json`, `../references/index.json`, `../benchmark/token-baseline.json`, `../assets/source-library.json`, `../leaf-manifest.json` and `../references/tax-rules/split-manifest.json`.

`check-route-table.py` runs `--check` beside the word check, so the `skill-health` CI step fails on a drifted part, a leftover original or an unmapped citation. The suite itself is not yet a CI step, because the workflow is a gate file.

`split-topic-files-test.sh` builds a fixture repository with two year folders, three topic files, a guide whose 13 headings slug to the allowlist and one citing file with a bare, a line and an anchor citation. Twelve cases each print one pass line: a clean split passes `--check`, a hand-edited part fails and names the part, a hand-edited header fails and names the part, a hand-edited entry file fails, a generated fence added after the H1 does not fail, a returned original fails, an unmappable citation exits non-zero and writes nothing, a folder with fewer than four parts fails, a part pushed over the token line fails, a rebased link does not fail, a second `--write` changes no byte and the remapped citations land on the right part and line. The token case reports a noted pass when the cached o200k encoding is unavailable. Run it with:

```bash
TIKTOKEN_CACHE_DIR=<cache> bash sk-moneybird-accountant/scripts/split-topic-files-test.sh
```

It ends with `Result: 12 passed, 0 failed`.

---

## 21. RELATED

- [`../references/migration/README.md`](../references/migration/README.md) for the phase references the generator reads
- [`../assets/migration/README.md`](../assets/migration/README.md) for the generated templates
- [`../../scripts/README.md`](../../scripts/README.md) for the privacy gate that guards these files
- [`../SKILL.md`](../SKILL.md) for how the skill uses the kit
