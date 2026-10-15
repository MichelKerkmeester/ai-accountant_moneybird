# Moneybird Accountant

[![GitHub Stars](https://img.shields.io/github/stars/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&logo=github&color=fce566&labelColor=222222)](https://github.com/MichelKerkmeester/ai-accountant_moneybird/stargazers)
[![License](https://img.shields.io/github/license/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&color=7bd88f&labelColor=222222)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/MichelKerkmeester/ai-accountant_moneybird?style=for-the-badge&color=5ad4e6&labelColor=222222)](https://github.com/MichelKerkmeester/ai-accountant_moneybird/commits/main)

> Like it? https://buymeacoffee.com/michelkerkmeester

---

## 1. 📝 SUMMARY

Moneybird Accountant is an AI bookkeeping assistant for Moneybird. You open the folder in a terminal agent such as Claude Code, and the agent reads `AGENTS.md` and works as your bookkeeping assistant. It knows Dutch tax rules, uses guarded command line tools to read from and write to Moneybird, and has a migration mode for bringing your history over from another tool.

It is built for a Dutch sole trader (ZZP) today. The tool and the market are separate parts, so you can adapt it to another bookkeeping tool or another country by swapping those parts. Section 7 shows which files to change.

The assistant prepares and explains. It never files a return and never gives final tax advice. You or your bookkeeper decide, and it flags every judgement call.

**What's inside**

- **A bookkeeping skill** - `sk-moneybird-accountant/` works out the task, loads only the reference it needs and keeps every tax decision with you
- **Dutch tax knowledge** - rules, figures, examples and notes per tax year from 2020 to 2027, with a source cited for each claim
- **A guarded Moneybird client** - `cli-moneybird/` holds `moneybird-guard`, which previews every call and blocks any write you have not approved
- **A migration mode** - a read-only Jortt client in `cli-jortt/` and a 23-phase plan that moves your history into Moneybird, one checked step at a time
- **A privacy gate** - stops names, amounts, account numbers and other personal data from reaching a commit or an outside model
- **Offline checks** - the tools and the skill are tested without an accounting login

---

## 2. 💼 WHAT IT HELPS WITH

| Task | What the assistant does |
|---|---|
| **Monthly or quarterly review** | Checks the bank, unmatched items and open invoices in Moneybird and lists what needs your attention |
| **Purchase invoices and receipts** | Explains how to book them, with Dutch VAT, reverse-charged VAT or a private-use share |
| **Fixed assets** | Decides with you whether a purchase is an asset and works out depreciation, the VAT revision period and disposal |
| **VAT return** | Prepares one period for your review, with each return box traced back to the books |
| **Yearly close** | Prepares the yearly overview with a fiscal reconciliation and a printable bilingual pack |
| **Income tax return** | Prepares the figures and lists the inputs only you can give, so you or your bookkeeper can file |
| **Tax questions** | Answers general ZZP questions with the tax year and the source |

Ask in English or Dutch. A request to file, submit, pay or lock a period is refused, and the assistant explains what you need to do yourself.

---

## 3. 🗺️ HOW IT WORKS

Each request starts at the project contract. The skill then loads only the reference that fits the task. A CLI skill joins only when a tool action is needed.

```text
Your request
  -> AGENTS.md sets identity and boundaries
  -> sk-moneybird-accountant/SKILL.md picks the task type
  -> one matching bookkeeping, tax or migration reference loads
  -> cli-moneybird or cli-jortt owns any command
  -> local evidence and your review close the work
```

### Two modes

| Mode | Use it for |
|---|---|
| **LIVE** | Day-to-day bookkeeping in Moneybird, from the monthly review to the yearly close |
| **MIGRATION** | Moving historical records from Jortt into Moneybird |

The routes are written in one place, the Task-Type Table in section 2 of [`sk-moneybird-accountant/SKILL.md`](sk-moneybird-accountant/SKILL.md). If the task is unclear, the assistant asks one question instead of guessing. It takes the tax year from the system clock before it uses any rate or threshold, never from a date written in a document.

---

## 4. 🚀 QUICK START

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
| Jortt CLI tests | `Result: 26 passed, 0 failed` |
| Moneybird doctor | `Doctor is read-only. Credential files were checked for presence only.` |
| Moneybird guard tests | `Pass: 58  Fail: 0` |

The Jortt tests need a local copy of the Jortt API description. If the cache file is missing, run `jortt-cli spec update` once with network access, then run the tests again. The Moneybird tests use a local stub.

### First use

Open the folder in a terminal agent that reads `AGENTS.md`. Then ask:

```text
Help me review my current Moneybird bookkeeping.
```

For historical work, name the migration task or the last gate that passed. If the mode or phase is unclear, the assistant asks before it picks a route.

---

## 5. 🇳🇱 DUTCH TAX KNOWLEDGE

The tax knowledge lives in [`references/tax-rules/`](sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md). Each tax year from 2020 to 2027 has its own folder, and each topic in it has four files: figures, rules, examples and notes. Topics cover VAT, income tax, business deductions, costs and the car, investments, the health insurance contribution, pensions, box 2 and box 3, the private company and the work relationship.

- **Claims cite their source.** The [source library](sk-moneybird-accountant/references/tax-rules/source-library.md) lists each external source by authority.
- **Changes are tracked per year.** Each year folder records what changed and why.
- **Open questions stay open.** Where the sources disagree or are missing, the reference says so rather than guessing.

Three procedures turn that knowledge into a prepared deliverable: the [VAT return](sk-moneybird-accountant/references/vat-return/README.md), the [yearly overview](sk-moneybird-accountant/references/yearly-overview/README.md) and the [income tax return](sk-moneybird-accountant/references/income-tax-return/README.md). Each one ends with a pack for your review, not a filing.

---

## 6. 🛤️ MIGRATION MODE

Migration mode moves your historical records from Jortt into Moneybird. It reads Jortt through a client that cannot write, rebuilds and checks each year locally and only then writes to Moneybird, batch by batch, after your approval.

The plan has 23 gated phases. Each phase has an owner, an evidence trail and a numeric exit gate, and a failed gate blocks everything after it.

| Phases | Stage |
|---:|---|
| 0 to 2 | Set up the safety controls and the workspace, then collect the source records and missing evidence |
| 3 to 5 | Rebuild each source locally, link the evidence and scan for gaps and risks |
| 6 to 8 | Map records to Moneybird, prove one pilot write, then migrate period by period |
| 9 to 15 | Reconcile VAT, prove each year against the bank, filed returns and annual accounts, test it with an independent review and lock it |
| 16 to 18 | Run the current year in parallel, freeze Jortt and switch to live Moneybird with your approval |
| 19 to 22 | Run the regular reviews, then monitor and decide whether to keep or cancel Jortt |

Record-level work stays on your machine. Outside models only see filtered summaries with record names replaced by aliases. The [migration index](sk-moneybird-accountant/references/migration/README.md) has every phase, and the [shared mechanisms](sk-moneybird-accountant/references/migration/shared-mechanisms.md) define the twelve controls that apply across them.

### Start a migration

Create your private working folder from the plan kit once:

```bash
bash sk-moneybird-accountant/scripts/init-workspace.sh
```

This builds the git-ignored `migration-workspace/` with every folder the plan uses, a `MIGRATION_CONFIG.json` with each field marked `PENDING` and a phase dashboard. It also copies the spec-kit template packet `specs/000-migration-template/` to the git-ignored `specs/001-migration/`: a phase parent plus one Level 3 packet per phase, each with a spec, plan, tasks, acceptance criteria, decision record, implementation summary and nested goal. Fill the bracketed placeholders with your own context as you work each phase. The script never overwrites a file you already filled in, so you can run it again safely. Add `--spec-name 002-my-books` to pick another packet name and `--dry-run` to see what it would create.

---

## 7. 🔁 ADAPTING TO ANOTHER TOOL OR MARKET

The assistant is built from parts with one job each. The routing, the human decision boundary, the privacy gate and the evidence workflow do not depend on Moneybird or on Dutch tax. To move to another tool or country, you replace the parts that do.

**Another bookkeeping tool**

- Replace `cli-moneybird/` with a CLI skill for your tool's API. Keep the guard pattern: a preview of every call, a read-only lock and a write that needs an approval reference.
- Rewrite the booking guidance in [`moneybird-bookkeeping.md`](sk-moneybird-accountant/references/moneybird-bookkeeping.md) and the booking steps in the purchase invoice, mixed-use cost and fixed asset references.

**Another migration source**

- Replace `cli-jortt/` with a read-only client for the tool you are leaving.
- Rewrite the [mapping reference](sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md). The 23 phases and their controls stay as they are.

**Another country**

- Replace `references/tax-rules/` with your country's rules, one folder per year and per topic, with a source for every claim.
- Rewrite the three preparation procedures for your country's returns.
- Update the routing signals in the Task-Type Table and in [`routing-signals.md`](sk-moneybird-accountant/references/routing-signals.md) for the words your users type.

The offline checks then show what still points at the old tool or market: broken links, route rows without a reference and gold routing cases that no longer resolve.

---

## 8. 🔒 SAFETY AND PRIVACY

- **Jortt is read-only.** `jortt-cli` uses read scopes only and refuses every non-GET call. There is no write path for an agent. XAF auditfiles, annual accounts and filed VAT returns come from you, through the Jortt UI.
- **Every Moneybird call goes through `moneybird-guard`.** Read sessions set `MONEYBIRD_GUARD_READ_ONLY=1`. The guard then blocks every non-GET call before it reaches the official CLI.
- **A write needs five things.** A passed phase gate, your approval, a flushed `WRITE_INTENT` journal entry, `--confirm-write` and `--approval <ref>` naming that entry. The guard checks the reference against the run journal, needs the writer session and never falls back to the reader session. A production batch also needs your approval for that batch and `--production`.
- **Migration data stays in `migration-workspace/`.** Git ignores it. Both CLIs refuse to save output anywhere else.
- **A private finance folder stays unread.** The assistant never lists, searches or opens it. The one exception is a single file you name during a migration phase.
- **A privacy gate guards every commit and push.** `scripts/privacy-gate.py` blocks a commit or push that adds a path from the private folders, a file type outside the allowlist, a binary or a large file, or content that looks like an IBAN, a BSN, a Dutch VAT ID, an email address, a long ID number, a home-folder path, a euro amount outside the tax references, a secret, or a term from your local `.privacy-denylist`. It reports where, never the value. A commit that changes a gate file needs you to set `PRIVACY_GATE_CHANGE_APPROVED=1` for that commit and the commit message to carry the trailer `Privacy-Gate-Change: approved`. A GitHub Action reruns it over the whole history on every push.
- **Tax decisions stay with you.** The assistant explains general rules with their year and source. It does not file returns and does not present a case-specific conclusion as final.

## 9. 🧪 CHECKS

The doctors are offline by default. The Jortt tests check the CLI contract against a local API description. The Moneybird tests use a stub, so the guard is proven without calling Moneybird. The skill side adds checks for the route table, the links and the generated references. [scripts/README.md](sk-moneybird-accountant/scripts/README.md) owns the full command list with the output each one prints.

| Check | What it covers |
|---|---|
| `cli-jortt/scripts/doctor.sh` | Local tools, whether `jortt-cli` is available, which Jortt settings are set and the API description cache |
| `cli-jortt/cli/jortt-cli/tests/run-tests.sh` | Operation slugs, parameter checks, the write gate, the scope gate, the output boundary, summary output and redacted errors |
| `cli-moneybird/scripts/doctor.sh` | Local tools, the pinned official CLI, config folders and whether credential files and settings exist |
| `cli-moneybird/cli/moneybird-cli/tests/run-tests.sh` | Period warning, write confirmation, the pilot gate, the approval check, the writer session, the read-only lock, delete caution, the output boundary, summary output and logins |
| `cli-moneybird/scripts/exit-code-parity.sh` | The guard exit codes against the exit table, the troubleshooting rows and the skill keywords, in both directions |
| `sk-moneybird-accountant/scripts/check-route-table.py` | The task-type route table with its marked read sets, plus the skill word check, the split-topic manifest and the carry-forward outline check |
| `sk-moneybird-accountant/scripts/check-fragments.py` | Every relative link and section anchor in the skill family |
| `sk-moneybird-accountant/scripts/build-reference-index.py --check`, `token-baseline.py --check` and `build-source-library.py --check` | The generated reference index, the pinned token baseline and the source library |
| `sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve` and `--mode replay` | The routing gold rows for every task type |
| The offline suite set under `sk-moneybird-accountant/scripts/` | The route table, route replay, reference index, regression trailer, session context, source library, token canary, write contract, hardening matrix, hostile invoice set, evals and fragment checks |
| `sk-moneybird-accountant/scripts/plan-kit-test.sh` | Phase packet generation, the drift check, workspace and packet setup, no-overwrite and the refusals |
| `scripts/privacy-gate-test.sh` | Every privacy-gate rule, that no blocked value is ever printed, the commit, merge and push modes, and the gate change trailer |
| Manual testing playbooks | Offline routing and guard scenarios in each skill folder, plus operator-approved live Jortt reads and one live Moneybird pilot write |

A passing local test does not prove a live connection. For Jortt, `jortt-cli whoami` returning HTTP 200 is that proof. For Moneybird, `bash cli-moneybird/scripts/doctor.sh --live` reports the administrations check with your approval.

## 10. 🗂️ REPOSITORY STRUCTURE

```text
.
├── .env.example                          local configuration template, no credentials
├── .githooks/                            privacy gate before commit, merge and push, forwards to your global hooks
├── .github/workflows/                    runs the privacy gate, plan kit and skill health checks on every push
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
├── specs/000-migration-template/        spec-kit phase packets with placeholders, copied for your migration
└── sk-moneybird-accountant/
    ├── README.md                         skill guide
    ├── SKILL.md                          mode router and operating contract
    ├── assets/migration/                 plan kit: config, dashboard, journal and the packet doc templates
    ├── assets/yearly-overview/           the bilingual yearly overview HTML template
    ├── evals/                            the graded routing and preparation cases
    ├── feature-catalog/                  what the skill does today
    ├── manual-testing-playbook/          offline routing scenarios
    ├── references/tax-rules/             the tax knowledge base, one folder per year and topic
    ├── references/vat-return/            the VAT return preparation procedure
    ├── references/yearly-overview/       the yearly overview preparation procedure
    ├── references/income-tax-return/     the income tax return preparation procedure
    ├── references/migration/             the migration plan, its phases and the shared controls
    ├── references/                       the bookkeeping, invoice, asset and routing guides
    └── scripts/                          plan kit generator, workspace setup, checks and their tests
```

Both CLI skills and the main skill also carry a `changelog/` and a `benchmark/` folder for release notes and run reports.

## 11. ❓ FAQ

**Q: Can the assistant file my VAT or income tax return?**

No. You or your bookkeeper review and file every return. The assistant prepares the evidence.

**Q: Do I need to migrate to use it?**

No. LIVE mode covers day-to-day bookkeeping, the VAT return, the yearly close and one-off questions without a migration.

**Q: Does an outside model see my records?**

No. Record-level checks run on your machine. Outside seats receive filtered summaries only.

**Q: Can I run the tests without an accounting login?**

Yes. The Moneybird tests use a stub and the Jortt tests use a local API description. Neither calls an accounting API.

**Q: Does a passing test prove my API connection works?**

No. A connection needs separate current evidence from the relevant CLI. The default doctors and tests make no accounting API calls.

**Q: Does it work outside the Netherlands?**

Not as it ships. The tax knowledge covers the Dutch sole-trader system. Section 7 lists the parts to replace for another country.

---

## 12. 🔧 TROUBLESHOOTING

**`jortt-cli` is not found**

The CLI is not on your `PATH`. Run `bash cli-jortt/cli/jortt-cli/setup.sh` and apply the symlink command it prints.

**The Jortt tests say `JORTT_OPENAPI_FILE` is missing**

The local API description is absent. Run `jortt-cli spec update` with network access, then run the tests again.

**A Moneybird list leaves out older records**

Moneybird lists default to the current year. Pass an explicit period, such as `--filter period:YYYY`. For a complete bulk read, use the `sync` and `sync_fetch` actions.

**A Moneybird read looks unchanged after a write**

The API can return cached data. Do not repeat the write. Check the write's own response, then confirm the record in a later synchronization read.

**The guard blocks a write**

Exit 3 means `--confirm-write` is missing. Exit 4 means the target is not the pilot and `--production` is missing. Exit 6 means `MONEYBIRD_GUARD_READ_ONLY=1` is set. Keep that lock for read-only work. Exit 7 means the writer configuration folder is missing. Exit 8 means `--approval` is missing or its reference is not in the run journal. Review the preview first, and write only after your approval.

**You need a Jortt auditfile or a filed return**

The Jortt API does not provide them. Download them yourself from the Jortt UI.

## 13. 📚 RELATED DOCUMENTS

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

- **[→ Dutch Tax](sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md)** - how the rules work across years, plus one folder per tax year from 2020 to 2027 and a folder per topic with figures, rules, examples and notes, BV and box 2 included
- **[→ Reference Library](sk-moneybird-accountant/references/README.md)** - the generated landing page for the reference tree, one row per year folder and per reference file
- **[→ Moneybird Bookkeeping](sk-moneybird-accountant/references/moneybird-bookkeeping.md)** - accounting treatment for common events
- **[→ Purchase Invoices](sk-moneybird-accountant/references/purchase-invoices.md)** - booking purchase invoices, receipts and orders, with Dutch VAT or reverse-charged VAT
- **[→ Mixed-Use Costs](sk-moneybird-accountant/references/mixed-use-costs.md)** - a cost used partly privately, its business share, its VAT split and its Moneybird booking
- **[→ Fixed Assets](sk-moneybird-accountant/references/fixed-assets.md)** - when a purchase is an asset, depreciation, the VAT revision period and disposal
- **[→ VAT Return Preparation](sk-moneybird-accountant/references/vat-return/README.md)** - the procedure that prepares one VAT period for Operator review, with the rubriek table, the derivation map and the review pack
- **[→ Yearly Overview Preparation](sk-moneybird-accountant/references/yearly-overview/README.md)** - the procedure that prepares the yearly close for Operator review, with the auditfile gate, the fiscal reconciliation and the hand-off
- **[→ Income Tax Return Preparation](sk-moneybird-accountant/references/income-tax-return/README.md)** - the procedure that prepares one income tax return for Operator review, with the Operator inputs, the claim register and the open points
- **[→ Yearly Overview Template](sk-moneybird-accountant/assets/yearly-overview/yearly-overview-template.html)** - the bilingual printable layout of the prepared pack, with a braced placeholder for every value
- **[→ Source Library](sk-moneybird-accountant/references/tax-rules/source-library.md)** - every external source the skills cite, by authority, with how an agent can reach it
- **[→ Jortt to Moneybird Mapping](sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md)** - concept matches and migration traps

---

## 14. 📄 LICENSE

This project uses the [MIT License](LICENSE).
