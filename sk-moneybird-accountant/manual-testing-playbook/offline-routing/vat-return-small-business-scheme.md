---
title: "VAT-003 -- A KOR quarter with a reverse-charged purchase"
description: "This scenario validates the KOR quarter branch of the VAT return preparation procedure, where the exemption applies and a reverse-charged purchase still reports."
id: VAT-003
catalog_applicable: false
version: 1.0.0.0
---

# VAT-003 -- A KOR quarter with a reverse-charged purchase

This document captures the offline prompt, local read sequence, expected signals and evidence for VAT-003.

---

## 1. OVERVIEW

This scenario validates the KOR quarter branch of the prepare-the-VAT-return route. It focuses on the exemption, the surviving reverse-charge reporting and the review pack.

### Why This Matters

The small-business scheme is an exemption, not a reduction. A KOR participant with a reverse-charged purchase still has a reporting duty for the shifted VAT, so a branch that treats the KOR as a stop would drop a real return line. A local-only check confirms the branch without calling a service.

---

## 2. SCENARIO CONTRACT

- Objective: Route a KOR quarter with a reverse-charged purchase to the procedure, keep the shifted VAT in the return and stop before any filing action.
- Real user request: Prepare the VAT return for the third quarter of 2026. The small-business scheme (KOR) applies and one purchase is reverse-charged. Do not call an API.
- Prompt: Prepare the VAT return for the third quarter of 2026. The small-business scheme (KOR) applies and one purchase is reverse-charged. Do not call an API.
- Fixture rows: VAT-BRANCH-KOR-01 (the KOR row) and vat-return-small-business-quarter (the eval case).
- Expected execution process: Read the project bootstrap and the skill, run the route table check, follow the T10 route into the VAT return procedure, apply the KOR rules, keep the reverse-charged line in the return and stop before any filing action. Do not use network access, accounting APIs or private finance data.
- Expected signals: The check prints route-table: ok. The route record names LIVE and T10. The read set loads [the VAT return procedure](../../references/vat-return/README.md) and [the 2026 VAT figures](../../references/tax-rules/2026/vat/figures.md). The answer names the KOR, the surviving reverse charge line, the review pack blocks P1 to P9 and the Operator as the owner of the filing route. The administration reads run through moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1.
- Desired user-visible outcome: A concise route report with the winning row, the loaded paths, the KOR treatment, the reverse charge line, the review pack blocks and the API-free status.
- Pass/fail: PASS if the request routes LIVE and T10, the procedure and the year figures load, the answer names the KOR and the surviving reverse charge line, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called. FAIL if the KOR is treated as a stop that drops the shifted VAT, a pack block is absent, the answer states a filing action or an API is called.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: Prepare the VAT return for the third quarter of 2026. The small-business scheme (KOR) applies and one purchase is reverse-charged. Do not call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
4. Read sk-moneybird-accountant/references/vat-return/README.md, sk-moneybird-accountant/references/vat-return/return-boxes.md and sk-moneybird-accountant/references/tax-rules/2026/vat/figures.md
5. Apply the KOR rules, keep the reverse-charged line in the return, assemble the review pack and stop before any filing action

### Expected

The check prints route-table: ok. The T10 row wins for the named VAT return. The procedure, the rubriek rules and the 2026 VAT figures load. The answer names the KOR, the reverse charge purchase that still reports, the pack blocks P1 to P9 and the Operator. No accounting API is called.

### Evidence

Capture the check output, the selected row, the loaded paths, the KOR treatment, the reverse charge line, the pack block list and the no-call status.

### Pass / Fail

- **Pass**: The request routes LIVE and T10, the KOR and the surviving reverse charge line are named, the pack blocks P1 to P9 are named, the Operator owns the filing route and no API is called.
- **Fail**: The KOR is treated as a stop that drops the shifted VAT, a pack block is absent, the answer states a filing action or an API is called.

### Failure Triage

Check the T10 row and the T8 filing precedence in SKILL.md section 2, then the VAT-BRANCH-KOR-01 row in [the routing corpus](../../scripts/route-replay/routing-gold.json). Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [the VAT return procedure](../../references/vat-return/README.md) | The procedure this scenario tests. |
| [the rubriek table](../../references/vat-return/return-boxes.md) | The KOR and reverse-charge rules. |
| [the review pack contract](../../references/vat-return/review-pack.md) | The pack blocks P1 to P9 and the confirmation parts. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [SKILL.md](../../SKILL.md) | The T10 row, its read set and the filing precedence. |
| [routing-gold.json](../../scripts/route-replay/routing-gold.json) | The VAT-BRANCH-KOR-01 row this scenario mirrors. |
| [evals.json](../../evals/evals.json) | The vat-return-small-business-quarter case. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: VAT-003
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/vat-return-small-business-scheme.md
