---
title: "Period filter warning"
description: "A list read without a period: filter still runs but warns that Moneybird defaults lists to period:this_year."
trigger_phrases:
  - "period filter warning"
  - "moneybird period filter warning"
  - "period this_year default"
  - "moneybird list older years"
version: 1.0.0.0
---

# Period filter warning (--filter period:)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

A list read without a period: filter still runs but warns that Moneybird defaults lists to period:this_year.

A list can succeed and still miss every older year. The warning makes that silent default visible at the moment the read runs.

---

## 2. HOW IT WORKS

For a GET whose arguments include `list`, the guard looks for a `--filter` value that contains `period:`, in either the `--filter period:YYYY` or the `--filter=period:YYYY` form. Without one it prints a stderr warning that Moneybird lists default to `period:this_year` and then runs the read anyway. With an explicit period the warning stays silent. The guard does not add a period on its own, so the operator chooses the year.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Detects list reads without a period filter |
| [`references/rest-api.md`](../../references/rest-api.md) | Shared | Documents the default period and the verification reads |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | A list warns and a list with a period does not |
| [MBD-005](../../manual-testing-playbook/reads/period-filter-warning.md) | Manual playbook | Operator check of both list forms |

---

## 4. SOURCE METADATA

- Group: Reads And Saved Output
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reads-and-saved-output/period-filter-warning.md`

Related references:
- [output-guard.md](output-guard.md) - Saves the records a verification read returns
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
