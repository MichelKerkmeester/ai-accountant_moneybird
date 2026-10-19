---
title: External source library
description: Lists every external source the skill family cites, with its authority and how an agent can reach it, so a figure can be traced to the page that states it.
trigger_phrases:
  - External source library
  - where does this figure come from
  - official tax source
  - build-source-library.py
version: 1.0.0.0
---

# External source library

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Lists every external source the skill family cites, with its authority and how an agent can reach it, so a figure can be traced to the page that states it.

The guide groups the sources by authority and names the most-cited statutes, Dutch Tax and Customs Administration (Belastingdienst) pages, parliamentary documents and Moneybird help pages. The generated index holds one row per cited source with its access result, digest and citing files. The guide itself owns those lists and any dead-link record.

---

## 2. HOW IT WORKS

The agent reads the guide, then greps the index for a host, a topic or a citing file instead of reading it whole. Each row's access value says how to reach the source: a web page through WebFetch, a law page through WebFetch only, a PDF that needs a PDF reader, an archive copy no agent can fetch, a dead link or a tool endpoint that only the CLI skills may call. A figure still comes from the year file that cites the source, with that file's Check tag. The builder regenerates the index from the markdown without any network call and keeps the recorded access results.

The builder also checks the reference frontmatter field set and the sourced term map in `assets/term-map.json`, where every row carries the English gloss a reader sees on first use and the source the owning year file cites. A row fails when its `source_file` does not hold the term or its source.

`--apply-report` leaves a blocked row and a transport error row unchanged and prints `N unreachable rows left unchanged`. `--watch` exits 1 when every URL it fetched failed or was blocked and prints `the watch could not check N of M watched URLs`, so a quiet exit never hides an outage.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/tax-rules/source-library.md | Shared | Groups the sources by authority and explains how to reach each access class. |
| sk-moneybird-accountant/assets/source-library.json | Shared | Holds one row per cited source with its access result and citing files. |
| sk-moneybird-accountant/scripts/build-source-library.py | Shared | Builds the index from the markdown, checks it for drift and checks the frontmatter field set with the sourced term map. |
| sk-moneybird-accountant/assets/term-map.json | Shared | Holds one row per Dutch term with its English gloss and the source the owning year file cites. |
| sk-moneybird-accountant/assets/source-watchlist.json | Shared | Lists the publication series the monthly watch checks for changes. |
| sk-moneybird-accountant/assets/source-watch-state.json | Shared | Records the last answer per watched URL, so a page that goes live is reported. |
| sk-moneybird-accountant/references/tax-rules/year-rollover.md | Shared | Holds the 1 January runbook, the release calendar and its owner. |
| sk-moneybird-accountant/SKILL.md | Shared | Loads the source library when a figure needs its source checked. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/scripts/source-library-test.sh | Automated test | Proves the builder on a fixture repository and checks the real index. |
| sk-moneybird-accountant/manual-testing-playbook/tax-guidance-and-sources/source-lookup.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/external-source-library.md

Related references:
- [year-specific-zzp-guidance.md](year-specific-zzp-guidance.md) - Related workflow behavior.
- [operator-tax-boundary.md](operator-tax-boundary.md) - Related workflow behavior.
