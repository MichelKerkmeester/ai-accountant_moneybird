---
title: Fragment link check
description: Resolves every relative link and fragment in the skill family and enforces the year-file section ids.
trigger_phrases:
  - Fragment link check
  - check-fragments.py
  - broken fragment link
  - year section ids
  - duplicate suffix slug
version: 1.0.0.0
---

# Fragment link check (check-fragments.py)

## 1. OVERVIEW

Resolves every relative link and fragment in the skill family and enforces the year-file section ids.

`scripts/check-fragments.py` reads the bootstrap, the README and the markdown of the three skill folders. It resolves every relative link path and matches each `path.md#fragment` against an anchor line or a GitHub-style heading slug in the target. External URLs, images and links inside fenced code blocks are skipped and the script makes no network call.

---

## 2. HOW IT WORKS

A fragment that matches only a duplicate-suffixed slug fails as `duplicate-suffix`, even when the target exists, because the suffix is not a stable address. An anchor-only link resolves inside the file that holds it.

In a year topic file the checker also reports a missing, unexpected, duplicate or out-of-order section id by name. The year README, the correction log and the change note are exempt from that rule, so only the topic files carry the fixed id set.

The twelve ordinal pointers in the top layer are fragment links the check resolves by path and heading slug. The last output line counts the links, the fragment links and the problems, and the exit code is 1 while a problem remains.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-fragments.py` | Script | Resolves link paths and fragments across the bootstrap, the README and the skill markdown. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Links the routed references the check resolves. |
| `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md` | Shared | Holds the pointer table to the general topic files a cross-year question is routed through. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/fragment-check-test.sh` | Automated test | Seeds a renamed heading, a renamed id, a missing file and a duplicate-suffix slug and proves each is caught, beside a topic part with a missing or misordered section id, a link into a nested topic part and a renamed heading in a copy of the real tree. |
| `sk-moneybird-accountant/manual-testing-playbook/quality-gates/fragment-link-check.md` | Manual playbook | Scenario GATE-003, the checker run over the skill family. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the check and the suite before every merge. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/fragment-link-check.md

Related references:
- [write-contract-check.md](write-contract-check.md) - The sibling drift check for the write contract.
- [../reference-and-state/reference-index-and-year-changes.md](../reference-and-state/reference-index-and-year-changes.md) - The generator whose anchors the check resolves.
