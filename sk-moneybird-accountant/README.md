---
title: sk-moneybird-accountant
description: Bookkeeping and Jortt to Moneybird migration guidance for a Dutch sole trader.
trigger_phrases:
  - help me migrate my jortt bookkeeping into moneybird
  - review my monthly moneybird bookkeeping
  - check the vat for this quarter
  - what is the current dutch zzp mileage rate
  - how should i book this business expense in moneybird
  - help me prepare a year-end bookkeeping review
  - explain the jortt to moneybird mapping
  - help me review a dutch sole trader yearly close
version: 1.0.0.0
---

# sk-moneybird-accountant

> Guides a Dutch sole trader through the Jortt to Moneybird migration and the bookkeeping that follows, with evidence at every step and a human on every tax decision.

The skill picks one of two modes. MIGRATION moves historical records through gated phases. LIVE handles the current books. This README shows where the skill sends each request and which tool owns each command.

---

## 1. AT A GLANCE

| Aspect | Guide |
|---|---|
| **Modes** | MIGRATION and LIVE |
| **Source route** | `cli-jortt` reads Jortt through `jortt-cli` |
| **Target route** | `cli-moneybird` reads and writes Moneybird through `moneybird-guard` |
| **Working evidence** | Records, journals and reports stay in the ignored `migration-workspace/` |
| **Human decisions** | The Operator or a bookkeeper owns tax judgement, filing and cutover |

---

## 2. OVERVIEW

### What it does

The skill routes historical Jortt work by phase and gate. It also reviews the current books in Moneybird and answers general Dutch ZZP bookkeeping questions. It organizes evidence and explains general rules. It does not file returns, and it does not make a final tax decision that depends on your personal facts.

### How a request flows

```text
Request
  -> AGENTS.md sets identity and boundaries
  -> SKILL.md picks MIGRATION or LIVE and routes the topic
  -> the matching reference defines the workflow
  -> a CLI skill owns any Jortt or Moneybird command
  -> local evidence is checked and the Operator reviews the decisions
```

Read [the project contract](../AGENTS.md) first, then [SKILL.md](SKILL.md). The skill loads only the references that match the request. It hands Jortt operations to [cli-jortt](../cli-jortt/SKILL.md) and Moneybird operations to [cli-moneybird](../cli-moneybird/SKILL.md).

### Operating boundary

Jortt access is read-only. Moneybird calls go through `moneybird-guard`. Reader sessions set `MONEYBIRD_GUARD_READ_ONLY=1`, which blocks every non-GET call before it reaches the official CLI. A write needs the writer configuration, the phase gate, Operator approval, `--confirm-write` and `--approval <ref>` for a flushed `WRITE_INTENT` journal entry. A write to a non-pilot administration also needs `--production`.

---

## 3. QUICK START

### Prepare the tools

From the repository root, follow the [Jortt install guide](../cli-jortt/INSTALL-GUIDE.md) and the [Moneybird install guide](../cli-moneybird/INSTALL-GUIDE.md). Copy `.env.example` to `.env` and fill it in locally. Keep credentials out of prompts and tracked files.

Then run the offline checks. None of them calls an accounting API.

```bash
bash cli-jortt/scripts/doctor.sh
JORTT_OPENAPI_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json" \
  bash cli-jortt/cli/jortt-cli/tests/run-tests.sh
bash cli-moneybird/scripts/doctor.sh
bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
```

The Jortt tests need the local API description. The Moneybird tests use a stub. A passing run does not prove live credentials, service access or a reconciled ledger.

### Ask for something

Open the folder in a terminal agent that reads `AGENTS.md`, then ask in plain words:

```text
Help me migrate my Jortt bookkeeping into Moneybird. I passed the Phase 3 gate.
Review my monthly Moneybird bookkeeping.
What is the current Dutch ZZP mileage rate?
```

For historical work, name the migration phase or the last gate that passed. The skill asks for a missing mode or phase before it picks a route.

---

## 4. MODES AND ROUTING

| Mode | Use it for |
|---|---|
| **MIGRATION** | Moving historical Jortt records into Moneybird |
| **LIVE** | A monthly, VAT-period or yearly review, or a one-off ZZP question |

Topic routes live in one place, the Task-Type Table in `SKILL.md` section 2. This README does not repeat them.

Check the current tax year before you use any rate or threshold. The [Dutch tax rules](references/dutch-tax-rules.md) explain each rule and route to the year folder, such as [2024](references/2024/README.md), where every topic has its own sourced file. The [Moneybird bookkeeping reference](references/moneybird-bookkeeping.md) covers the accounting treatment of common events. The [Jortt to Moneybird mapping](references/migration/jortt-to-moneybird-mapping.md) lists concept matches and migration traps. Exports the Jortt API does not provide come from you, through the Jortt UI.

---

## 5. MIGRATION PLAN

The [migration index](references/migration/README.md) lists 23 phases. A phase starts only when its entry criteria are met. A failed exit gate stops everything that depends on it until the issue is fixed and verified.

| Phases | Covers | Phase file |
|---|---|---|
| 0 to 2 | Safety setup, source inventory and archive seeding | [phases-0-to-2.md](references/migration/phases-0-to-2.md) |
| 3 to 5 | Independent reconstruction, cross-reconciliation and anomaly review | [phases-3-to-5.md](references/migration/phases-3-to-5.md) |
| 6 to 9 | Mapping, the pilot, historical writes by period and VAT verification | [phases-6-to-9.md](references/migration/phases-6-to-9.md) |
| 10 to 16 | Year-end checks, continuity, year locks and cutover preparation | [phases-10-to-16.md](references/migration/phases-10-to-16.md) |
| 17 to 18 | Source freeze and archive proof, then the switch to live Moneybird | [phases-17-to-18.md](references/migration/phases-17-to-18.md) |
| 19 to 21 | The recurring monthly, VAT-period and yearly reviews | [phases-19-to-21.md](references/migration/phases-19-to-21.md) |
| 22 | Completion and your decision on Jortt | [phase-22-completion.md](references/migration/phase-22-completion.md) |

Phases 19 to 21 start when Phase 18 passes. Phase 22 runs once, after the monitoring period. Jortt stays active until Phase 22 passes and you record whether to keep or cancel it.

Every phase uses the same 11 fields: goal, nested sub-goals with measurable checks, entry criteria, inputs, owner-tagged actions, tool route, outputs and evidence, numeric exit gate, stop conditions, rollback or compensation and resume rule.

Twelve shared mechanisms, M1 to M12, apply across the phases. They cover write keys, the run journal, privacy, rate limits, the Moneybird access window, exceptions, reader and writer sessions, stop recovery and the external agent route. The [shared mechanisms reference](references/migration/shared-mechanisms.md) defines each one. The [control framework](references/migration/control-framework.md) defines roles, exceptions and dashboard states.

---

## 6. EXTERNAL AGENT ROUTE

M12 splits migration work across separate seats. These are the Operator's defaults. Phase 0 builds the Agent runner, records the defaults and proves the sandbox and boundary before any agent work on real data starts.

| Seat | Default responsibility |
|---|---|
| **Agent runner** | Runs local briefs, filtering, scans, journal events, dashboard updates and the local deterministic payload assembler that builds each Moneybird request payload from the frozen inputs and approved mapping tables. It never books a record. |
| **Implementer** | Drafts scripts and templates from approved summaries, with tools and extensions off. |
| **Verifier** | Checks the work independently and sees no record-level content. Tool-enabled checks need a proven read-only sandbox and OS boundary. |
| **Final reviewer** | Reviews each phase once every work unit has passed verification or has an Operator decision. It sees filtered summaries, verdicts, gate results and alias-level evidence only. |
| **Migration Writer** | Runs `moneybird-guard --confirm-write --approval <ref>` against the assembled payload file, in a separate session. It never reads or composes payload content. The guard's summary output keeps the response body out of the writer session. |
| **Operator** | Owns the configuration, high-risk review, approvals, filing and cutover. |

The seats receive typed, allowlisted summaries with schemas, field names, phase and record-class labels, opaque record aliases, HMAC hashes, approved aggregate counts, status, approval references and evidence paths. No seat receives record-level content. In agent-facing output, a count from 1 to 9 appears as `<10`. Zero stays `0`. The exact payload is scanned before every dispatch. Source records and record-level evidence stay on your machine.

---

## 7. WORKSPACE AND EVIDENCE

The ignored `migration-workspace/` holds migration inputs, manifests, registers, run journals, reports and archived evidence. Both CLIs refuse to save an extract anywhere else.

The plan kit creates it. Run `bash sk-moneybird-accountant/scripts/init-workspace.sh` from the repository root once. It builds every workspace and AgentDesk folder and copies the templates from [assets/migration/](assets/migration/README.md): `MIGRATION_CONFIG.json` with each field marked `PENDING`, a phase dashboard and a run-journal event template. It also copies the spec-kit template packet `specs/000-migration-template/` to the git-ignored `specs/001-migration/`, one Level 3 packet with a nested goal per phase, with bracketed placeholders you fill with your own context. It never overwrites a file you already filled in. `scripts/generate-plan-kit.py` builds the template packet from the phase references, and its `--check` mode fails when a packet doc drifts from its reference.

Each phase records its inputs, owner actions, tool route, outputs and exit evidence. You review the result of every phase and approve each gated Moneybird write. Read-only Moneybird sessions keep `MONEYBIRD_GUARD_READ_ONLY=1` set.

---

## 8. FEATURE CATALOG AND PLAYBOOK

The [feature catalog](feature-catalog/feature-catalog.md) lists what the skill does today, with source references and validation anchors. The [manual testing playbook](manual-testing-playbook/manual-testing-playbook.md) holds the offline routing scenarios. They check local routing and policy and make no Jortt, Moneybird, web or tax authority call.

---

## 9. FAQ

**Q: Can the assistant file a return?**

No. You or your bookkeeper review and file every return.

**Q: Can an outside model see my source records?**

No. Record-level checks run on your machine. Outside seats receive filtered summaries only.

**Q: Can I test the tools without an accounting login?**

Yes. The Moneybird tests use a stub. The Jortt tests use the local API description and make no API call.

**Q: Does a passing local test prove a live connection?**

No. A connection needs separate, current evidence from the relevant CLI.

---

## 10. TROUBLESHOOTING

| What you see | Likely cause | Next step |
|---|---|---|
| `jortt-cli` is not found | The CLI is not on your `PATH` | Follow the [Jortt install guide](../cli-jortt/INSTALL-GUIDE.md). |
| The Jortt tests cannot find their API description | The local cache is missing | Run `jortt-cli spec update` with network access, then run the tests again. |
| Moneybird results leave out older records | The API defaults to the current year | Add an explicit period. Use synchronization for a complete bulk read. |
| A Moneybird read looks unchanged after a write | The API can return cached data | Do not repeat the write. Confirm it in a later synchronization read. |
| A Moneybird write is blocked | The read-only lock or the write gate is active | Keep the lock for reader work. For migration, stop and follow the phase approval route. |

---

## 11. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [Project contract](../AGENTS.md) | Request routing and safety boundaries |
| [Core skill](SKILL.md) | Mode selection and the matching workflow |
| [Migration index](references/migration/README.md) | Phases and their grouped files |
| [Control framework](references/migration/control-framework.md) | Roles, exceptions and dashboard states |
| [Jortt tool skill](../cli-jortt/SKILL.md) | Jortt reads and source extraction |
| [Moneybird tool skill](../cli-moneybird/SKILL.md) | Guarded Moneybird operations |
| [Dutch tax rules](references/dutch-tax-rules.md) | How each rule works across years, source conflicts, gaps and record duties |
| [Tax year folders](references/2024/README.md) | One folder per tax year 2020 to 2027 with a file per topic: BTW, income tax, Zvw, entrepreneur deductions, investments, costs and car, box 3, box 2, BV, pension, work relationship and procedure |
| [Bookkeeping reference](references/moneybird-bookkeeping.md) | Common Moneybird accounting events |
| [Purchase invoice reference](references/purchase-invoices.md) | Booking purchase invoices, receipts and orders, with the VAT rate per case |
| [Source library](references/source-library.md) | Every external source the skills cite, by authority, with access notes and a generated index |
