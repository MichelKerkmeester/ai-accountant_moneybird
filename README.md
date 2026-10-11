# Moneybird Accountant - Jortt to Moneybird Migration & Bookkeeping

[![GitHub Stars](https://img.shields.io/github/stars/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&logo=github&color=fce566&labelColor=222222)](https://github.com/MichelKerkmeester/ai-accountant_moneybird/stargazers)
[![License](https://img.shields.io/github/license/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&color=7bd88f&labelColor=222222)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&color=5ad4e6&labelColor=222222)](https://github.com/MichelKerkmeester/ai-accountant_moneybird/commits/main)

> Like it? https://buymeacoffee.com/michelkerkmeester

&nbsp;

## 1. 📝 SUMMARY

Moneybird Accountant is a folder you open in a terminal agent. The agent reads `AGENTS.md` and becomes a bookkeeping and migration assistant for a Dutch sole trader (ZZP). It has two jobs. It moves your historical records from Jortt to Moneybird, and it supports the books you keep in Moneybird afterwards.

It organizes evidence and explains general Dutch ZZP rules. It never files a return and never gives final tax advice. You or your bookkeeper decide, and the assistant flags every judgement call.

**What's inside**

- **A skill** - `sk-moneybird-accountant/` picks the mode, loads the right phase or bookkeeping reference and keeps the human decision boundary
- **A Jortt reader** - `cli-jortt/` holds `jortt-cli`, a read-only command line client that pages through the Jortt API and saves extracts into a local workspace
- **A guarded Moneybird client** - `cli-moneybird/` holds `moneybird-guard`, a wrapper around the official Moneybird CLI that previews every call and blocks writes you have not approved
- **A 23-phase migration plan** - each phase has an owner, an evidence trail and a numeric exit gate
- **Offline checks** - 11 Jortt contract tests and 13 Moneybird guard tests run without an accounting login

&nbsp;

## 2. 🗺️ OVERVIEW

### How a request flows

Each request starts at the project contract. The skill then loads only the reference that fits the task. A CLI skill joins only when a tool action is needed.

```text
Your request
  -> AGENTS.md sets identity and boundaries
  -> sk-moneybird-accountant/SKILL.md picks MIGRATION or LIVE
  -> one matching phase or bookkeeping reference loads
  -> cli-jortt or cli-moneybird owns any command
  -> local evidence and your review close the work
```

The skill keeps the workflow in one place. The two CLI skills own API details, setup and command safety. That split keeps Jortt extraction read-only and stops Moneybird writes from bypassing the guard.

### Two modes

| Mode | Use it for | Start with |
|---|---|---|
| **MIGRATION** | Moving historical Jortt records into Moneybird | The [migration index](sk-moneybird-accountant/references/migration/README.md), the matching phase file and the [shared mechanisms](sk-moneybird-accountant/references/migration/shared-mechanisms.md) |
| **LIVE** | A monthly or quarterly review, a yearly close or a one-off ZZP question | The [Moneybird bookkeeping reference](sk-moneybird-accountant/references/moneybird-bookkeeping.md) and the [tax reference](sk-moneybird-accountant/references/zzp-tax-and-vat.md) |

If the mode is unclear, the assistant asks one question instead of guessing a phase or a tax year. It checks the current tax year before it uses any rate or threshold. Tax decisions and return filing stay with the Operator or a bookkeeper.

&nbsp;

## 3. 🚀 QUICK START

### Clone and configure

```bash
git clone https://github.com/MichelKerkmeester/ai-accountant_moneybird.git
cd ai-accountant_moneybird
cp .env.example .env
```

Fill in `.env` on your machine only. Git ignores `.env` and `.env.writer`. Never paste a credential into a prompt or a document.

Then switch on the privacy gate and add your own private terms:

```bash
bash scripts/install-hooks.sh
```

This points Git at the repo's `.githooks/` and creates `.privacy-denylist`. Put your name variants, client and supplier names, IBANs, KvK, VAT and BSN numbers, address and email there, one per line. Git ignores that file and it stays on your machine.

### Install the two CLIs

Follow the [Jortt install guide](cli-jortt/INSTALL-GUIDE.md) and the [Moneybird install guide](cli-moneybird/INSTALL-GUIDE.md). Each guide covers setup, verification and rollback.

### Check the setup

Run these from the repository root. None of them calls Jortt or Moneybird.

```bash
bash cli-jortt/scripts/doctor.sh
JORTT_OPENAPI_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json" \
  bash cli-jortt/cli/jortt-cli/tests/run-tests.sh
bash cli-moneybird/scripts/doctor.sh
bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
```

| Check | Last line you should see |
|---|---|
| Jortt doctor | `Mode: offline. No network calls were made.` |
| Jortt CLI tests | `Result: 11 passed, 0 failed` |
| Moneybird doctor | `Doctor is read-only. Credential files were checked for presence only.` |
| Moneybird guard tests | `Pass: 13  Fail: 0` |

The Jortt tests need a local copy of the Jortt API description. If the cache file is missing, run `jortt-cli spec update` once with network access, then run the tests again. The Moneybird tests use a local stub.

### First use

Open the folder in a terminal agent that reads `AGENTS.md`. Then ask:

```text
Help me review my current Moneybird bookkeeping.
```

For historical work, name the migration task or the last gate that passed. If the mode or phase is unclear, the assistant asks before it picks a route.

&nbsp;

## 4. 🛤️ MIGRATION PLAN

The migration index lists 23 gated phases. Each phase starts from the last verified exit gate. A failed or unverified gate blocks everything that depends on it.

| Phase | Purpose |
|---:|---|
| 0 | Set up the safety controls, the workspace and the tool routes. |
| 1 | Inventory the source records and record independent totals. |
| 2 | Collect missing evidence and seed the archive. |
| 3 | Rebuild each source in its own register. |
| 4 | Link the evidence into one canonical record set. |
| 5 | Scan for gaps, risks and anomalies. |
| 6 | Map approved records to supported Moneybird objects. |
| 7 | Prove the controlled pilot write and its read-back. |
| 8 | Migrate approved historical records period by period. |
| 9 | Reconcile VAT for every assigned period. |
| 10 | Prove each year against the ledger, bank, documents, filed VAT and annual accounts. |
| 11 | Cross-check commercial results against filed income-tax figures. |
| 12 | Prove balance continuity between years and keep open-item tracking. |
| 13 | Try to falsify each year with an independent Red Team review. |
| 14 | Lock a verified year and seal its evidence. |
| 15 | Repeat the yearly steps from the oldest year to the newest. |
| 16 | Run the current-year parallel mirror and prepare the cutover. |
| 17 | Freeze Jortt and prove the archive is complete and restorable. |
| 18 | Switch to live Moneybird after reconciliation and your go-live approval. |
| 19 | Run the monthly review. |
| 20 | Run the VAT-period review. |
| 21 | Run the yearly close. |
| 22 | Finish monitoring, recheck the archive and record your decision on Jortt. |

Phases 19 to 21 repeat after the switch in Phase 18. Phase 22 runs once. Jortt stays active until Phase 22 passes and you record whether to keep or cancel it.

### The phase contract

Every phase uses the same 11 fields: goal, nested sub-goals with measurable checks, entry criteria, inputs, owner-tagged actions, tool route, outputs and evidence, numeric exit gate, stop conditions, rollback or compensation and resume rule.

Owner tags show who acts. `[Operator]` is a step only a human performs. `[AI]` is a step the agent performs within its listed tools. `[Operator + AI]` is a step the agent prepares and the Operator approves or performs.

### Shared mechanisms

Twelve controls apply across the phases. The [shared mechanisms reference](sk-moneybird-accountant/references/migration/shared-mechanisms.md) defines them.

| Mechanism | What it controls |
|---|---|
| M1 | Versioned register schemas and complete source manifests |
| M2 | Stable local write keys and uncertain write outcomes |
| M3 | An append-only run journal, approvals and crash resume |
| M4 | Evidence, privacy and session boundaries |
| M5 | Moneybird rate limits and recovery |
| M6 | The Moneybird trial or package window through writes and verification |
| M7 | Numeric thresholds and exception ownership |
| M8 | Jortt paging and source request evidence |
| M9 | One status dashboard for all 23 phases |
| M10 | Separate reader and writer sessions |
| M11 | Recovery from each stop state |
| M12 | External agent seats with local record processing |

The [control framework](sk-moneybird-accountant/references/migration/control-framework.md) defines the roles, risk levels, exception fields and dashboard states.

&nbsp;

## 5. 🤖 EXTERNAL AGENT ROUTE

M12 splits the work across seats so no single agent drafts, checks and approves its own output. These are the Operator's defaults. The plan defines the route, and Phase 0 builds it: the Implementer drafts the Agent runner, the Verifier checks it, and the sandbox and boundary canaries must pass before any agent work on real data starts. Phase 0 also records the defaults in the migration configuration.

| Seat | Default and role |
|---|---|
| **Agent runner** | A local deterministic runner. It builds briefs, runs local sessions, filters and scans text, writes journal events and updates the dashboard. It never books a record. |
| **Implementer** | DeepSeek V4.1 Flash through the Pi CLI. It drafts scripts, schemas and templates from approved summaries, with tools, extensions, skills, context files and sessions switched off. |
| **Verifier** | GPT-6 Luna through the Codex CLI. It runs independent checks and sees no record-level content. Tool-enabled checks need a read-only sandbox inside a proven OS boundary. |
| **Final reviewer** | Claude, in the session that runs the skill. It reviews each phase once every work unit has passed verification or has an Operator decision. |
| **Migration Writer** | Claude in a separate writer session. It makes the approved Moneybird writes through `moneybird-guard`. No seat sees the token. |
| **Operator** | You. You approve the configuration and each batch, review high-risk records locally and keep the tax, filing and cutover decisions. |

External seats receive typed, allowlisted summaries with opaque record aliases and approved aggregate counts. The exact payload is scanned before every dispatch. Names, amounts, IBANs, addresses, emails, descriptions, invoice numbers, IDs and source payloads never leave your machine.

&nbsp;

## 6. 🔒 SAFETY AND PRIVACY

- **Jortt is read-only.** `jortt-cli` uses read scopes only and refuses any write without `--allow-write` and the matching scope. XAF auditfiles, annual accounts and filed VAT returns come from you, through the Jortt UI.
- **Every Moneybird call goes through `moneybird-guard`.** Read sessions set `MONEYBIRD_GUARD_READ_ONLY=1`. The guard then blocks every non-GET call before it reaches the official CLI.
- **A write needs four things.** A passed phase gate, your approval, a flushed `WRITE_INTENT` journal entry and `--confirm-write`. A production batch also needs your approval for that batch and `--production`.
- **Migration data stays in `migration-workspace/`.** Git ignores it. Both CLIs refuse to save output anywhere else.
- **A private finance folder stays unread.** The assistant never lists, searches or opens it. The one exception is a single file you name during a migration phase.
- **A privacy gate guards every commit and push.** `scripts/privacy-gate.py` blocks a commit or push that adds a path from the private folders, a file type outside the allowlist, a binary or a large file, or content that looks like an IBAN, a BSN, a Dutch VAT ID, an email address, a long ID number, a home-folder path, a euro amount outside the tax references, a secret, or a term from your local `.privacy-denylist`. It reports where, never the value. A GitHub Action reruns it over the whole history on every push.
- **Tax decisions stay with you.** The assistant explains general rules with their year and source. It does not file returns and does not present a case-specific conclusion as final.

&nbsp;

## 7. 🧪 CHECKS

The doctors are offline by default. The Jortt tests check the CLI contract against a local API description. The Moneybird tests use a stub, so the guard is proven without calling Moneybird.

| Check | What it covers |
|---|---|
| `cli-jortt/scripts/doctor.sh` | Local tools, whether `jortt-cli` is available, which Jortt settings are set and the API description cache |
| `cli-jortt/cli/jortt-cli/tests/run-tests.sh` | Operation slugs, parameter checks, the write gate, the scope gate and the output boundary |
| `cli-moneybird/scripts/doctor.sh` | Local tools, the pinned official CLI, config folders and whether credential files and settings exist |
| `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh` | Period warning, write confirmation, the pilot gate, the read-only lock, delete caution, the output boundary and logins |
| `scripts/privacy-gate-test.sh` | Every privacy-gate rule, that no blocked value is ever printed, and the commit and push modes |
| Manual testing playbooks | Offline routing and guard scenarios in each skill folder, with one live Moneybird scenario that needs your approval |

A passing local test does not prove a live connection. For Jortt, `jortt-cli whoami` returning HTTP 200 is that proof. For Moneybird, `bash cli-moneybird/scripts/doctor.sh --live` reports the administrations check with your approval.

&nbsp;

## 8. 🗂️ REPOSITORY STRUCTURE

```text
.
├── .env.example                          local configuration template, no credentials
├── .githooks/                            privacy gate before commit and push, forwards to your global hooks
├── .github/workflows/privacy-gate.yml    reruns the privacy gate over the history on every push
├── .gitignore                            keeps secrets and private work data out of Git
├── .privacy-denylist.example             template for your local list of private terms
├── .privacy-gate.json                    privacy-gate allowlists and blocked paths
├── AGENTS.md                             entry point, boundaries and privacy rules
├── LICENSE                               MIT license
├── cli-jortt/
│   ├── INSTALL-GUIDE.md                  Jortt CLI setup and rollback
│   ├── README.md                         Jortt tool overview
│   ├── SKILL.md                          Jortt routing and read controls
│   ├── cli/jortt-cli/                    the read-only client, its libraries and tests
│   ├── references/                       CLI, REST, export and troubleshooting guides
│   ├── scripts/doctor.sh                 offline Jortt diagnostics
│   ├── feature-catalog/                  what the package does today
│   └── manual-testing-playbook/          operator scenarios
├── cli-moneybird/
│   ├── INSTALL-GUIDE.md                  official CLI setup and rollback
│   ├── README.md                         Moneybird tool overview
│   ├── SKILL.md                          guarded reads and gated writes
│   ├── cli/moneybird-cli/                setup script, moneybird-guard and stub tests
│   ├── references/                       API, command, recipe and recovery guides
│   ├── scripts/doctor.sh                 read-only local diagnostics
│   ├── feature-catalog/                  what the package does today
│   └── manual-testing-playbook/          operator scenarios
├── scripts/                              privacy gate, its tests and the hook installer
└── sk-moneybird-accountant/
    ├── README.md                         skill guide
    ├── SKILL.md                          mode router and operating contract
    ├── feature-catalog/                  what the skill does today
    ├── manual-testing-playbook/          offline routing scenarios
    └── references/                       migration plan, tax, mapping and bookkeeping guides
```

Both CLI skills and the main skill also carry a `changelog/` and a `benchmark/` folder for release notes and run reports.

&nbsp;

## 9. ❓ FAQ

**Q: Can the assistant file my VAT or income-tax return?**

No. You or your bookkeeper review and file every return. The assistant prepares the evidence.

**Q: Does an outside model see my records?**

No. Record-level checks run on your machine. Outside seats receive filtered summaries only.

**Q: Can I run the tests without an accounting login?**

Yes. The Moneybird tests use a stub and the Jortt tests use a local API description. Neither calls an accounting API.

**Q: Does a passing test prove my API connection works?**

No. A connection needs separate current evidence from the relevant CLI. The default doctors and tests make no accounting API calls.

**Q: Can I use it for current bookkeeping only?**

Yes. LIVE mode covers monthly, quarterly and yearly review and one-off ZZP questions without a migration.

**Q: Does it work outside the Netherlands?**

No. It covers the Dutch sole-trader tax system only.

&nbsp;

## 10. 🔧 TROUBLESHOOTING

**`jortt-cli` is not found**

The CLI is not on your `PATH`. Run `bash cli-jortt/cli/jortt-cli/setup.sh` and apply the symlink command it prints.

**The Jortt tests say `JORTT_OPENAPI_FILE` is missing**

The local API description is absent. Run `jortt-cli spec update` with network access, then run the tests again.

**A Moneybird list leaves out older records**

Moneybird lists default to the current year. Pass an explicit period, such as `--filter period:YYYY`. For a complete bulk read, use the `sync` and `sync_fetch` actions.

**A Moneybird read looks unchanged after a write**

The API can return cached data. Do not repeat the write. Check the write's own response, then confirm the record in a later synchronization read.

**The guard blocks a write**

Exit 3 means `--confirm-write` is missing. Exit 4 means the target is not the pilot and `--production` is missing. Exit 6 means `MONEYBIRD_GUARD_READ_ONLY=1` is set. Keep that lock for read-only work. Review the preview first, and write only after your approval.

**You need a Jortt auditfile or a filed return**

The Jortt API does not provide them. Download them yourself from the Jortt UI.

&nbsp;

## 11. 📚 RELATED DOCUMENTS

**System guides**

- **[→ Project Contract](AGENTS.md)** - routing, privacy boundaries and tool ownership
- **[→ Core Skill](sk-moneybird-accountant/SKILL.md)** - mode selection and the matching workflow
- **[→ Skill README](sk-moneybird-accountant/README.md)** - the bookkeeping and migration skill in detail
- **[→ Jortt Tool Skill](cli-jortt/SKILL.md)** - Jortt CLI operations and source extraction
- **[→ Moneybird Tool Skill](cli-moneybird/SKILL.md)** - guarded Moneybird CLI operations

**Migration plan**

- **[→ Migration Index](sk-moneybird-accountant/references/migration/README.md)** - phase gates and their reference files
- **[→ Overview and Setup](sk-moneybird-accountant/references/migration/overview-and-setup.md)** - workspace layout and the required configuration
- **[→ Shared Mechanisms](sk-moneybird-accountant/references/migration/shared-mechanisms.md)** - M1 to M12 and the tool route contract
- **[→ Control Framework](sk-moneybird-accountant/references/migration/control-framework.md)** - roles, risk, exceptions and dashboard states

**Bookkeeping references**

- **[→ Dutch Tax and VAT](sk-moneybird-accountant/references/zzp-tax-and-vat.md)** - year-specific figures with their sources
- **[→ Moneybird Bookkeeping](sk-moneybird-accountant/references/moneybird-bookkeeping.md)** - accounting treatment for common events
- **[→ Jortt to Moneybird Mapping](sk-moneybird-accountant/references/jortt-to-moneybird-mapping.md)** - concept matches and migration traps

&nbsp;

## 12. 📄 LICENSE

This project uses the [MIT License](LICENSE).
