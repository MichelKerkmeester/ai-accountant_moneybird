---
title: Income tax return risks and open points
description: The five residual unknowns behind an income tax return preparation, each labelled unresolved with the page or check that would settle it, and the agreement between the 2025 investment status row and its section note.
trigger_phrases:
  - income tax return open points
  - income tax return residual risks
  - unresolved tax values
  - IB-aangifte open punten
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Income tax return risks and open points

**Rule:** Every row below is labelled `unresolved` and names the page or check that would settle it. An unresolved item is never a rule and never a computation basis. It stays labelled in the pack and the year file that owns it keeps its own status tag. Every rule path is a link into the year files under `references/tax-rules/`.

---

## 1. OVERVIEW

The list holds the residual unknowns the 019 research left after the merging. Each one is a value or a publication that no fetched primary page settles for the resolved year. The pack carries the list, the Operator sees each item with the source that would settle it, and a later run moves a row to a settled state only with that source.

The list is deliberately small. A value the year file already marks `UNVERIFIED`, `proposed` or `unknown` is not repeated here, because the year file owns that label. This file owns the unknowns that span years or that no year file can settle alone.

---

## 2. THE FIVE RESIDUAL UNKNOWNS

| ID | Unknown | Status | What would settle it |
|---|---|---|---|
| R1 | The year-less RVO maxima, namely the maximum amount per asset and per applicant, the RVO test for a vehicle counting as new and the statement about the combined MIA and Vamil benefit | `unresolved` | A year-specific RVO page that prints each maximum and the year it belongs to. The rows are in [Investeringen 2025 notes](../tax-rules/2025/investeringen/notes.md) and [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md). |
| R2 | The derived starters' willekeurige afschrijving cap | `unresolved` | A Belastingdienst or RVO page that prints the cap as a number for the resolved year. The reading and the label are in [Investeringen 2025 figures](../tax-rules/2025/investeringen/figures.md) and [Investeringen 2025 notes](../tax-rules/2025/investeringen/notes.md). |
| R3 | The undated werkruimte publication for an owned home | `unresolved` | A dated Belastingdienst publication or case law on the owned-home workspace rule. The row is in [Kosten en auto 2025 notes](../tax-rules/2025/kosten-en-auto/notes.md). |
| R4 | The massaal-bezwaar decision date on the belastingrente rate | `unresolved` | A published date for the collective decisions. The row is in [Procedure 2025 notes](../tax-rules/2025/procedure/notes.md). |
| R5 | The 2027 bill status | `unresolved` | The Staatsblad publication of the adopted 2027 law. The status layers are in [the 2027 year README](../tax-rules/2027/README.md) and [Dutch tax rules](../tax-rules/dutch-tax-rules.md). |

Each row keeps its `unresolved` label until the named source arrives. The year the return covers decides which year file the row links, and the 2027 row stays open until the publication lands.

---

## 3. THE 2025 STARTERS CAP STATUS AGREEMENT

The 2025 cap row and its section note agree on one value and one status. The row in [Investeringen 2025 figures](../tax-rules/2025/investeringen/figures.md) marks the cap `UNVERIFIED`, and the open-points section in [Investeringen 2025 notes](../tax-rules/2025/investeringen/notes.md) marks the same reading `UNVERIFIED` and names the page that would settle it. Neither line claims a printed primary page, so the pair agrees.

The agreement settles the 019 REC-11 tension. The cap stays in row R2 as an `unresolved` item and is never presented as a printed rate.

---

## 4. THE RULE FOR AN OPEN POINT

- An `unresolved` item is never a computation basis.
- It never becomes a rule and it is never filled from memory.
- It stays labelled in the pack with its owner and the page or check that would settle it.
- A settled item moves out of the unresolved state with the evidence and the date recorded in its [operator inputs](operator-inputs.md) row.
- A value that the year file marks `UNVERIFIED`, `proposed` or `unknown` keeps that status in the year file and is refused with `value_not_settled` per [year and state resolution](../tax-rules/year-and-state.md).

---

## 5. RELATED RESOURCES

- [README](README.md) for the boundary and the shared disposition vocabulary.
- [Procedure](procedure.md) for the stop rules and the evidence gates that consume this list.
- [Operator inputs](operator-inputs.md) for the rows that carry a disposition.
- [Investment and claim register](investment-and-claim-register.md) for the per-asset evidence shape.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing and the status rules.
- [The 2025 year README](../tax-rules/2025/README.md), [the 2026 year README](../tax-rules/2026/README.md) and [the 2027 year README](../tax-rules/2027/README.md) for the year folders.
