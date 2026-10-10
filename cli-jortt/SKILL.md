---
name: cli-jortt
description: Routes Jortt bookkeeping through jortt-cli over REST for read-only migration extraction.
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
version: 1.0.0.0
---

<!-- Keywords: jortt, jortt-cli, Jortt bookkeeping, Jortt extraction, Jortt REST API, Jortt invoices, Jortt expenses, Jortt receipts, Jortt bank transactions, Jortt XAF auditfile, accounting migration, Moneybird migration, source register -->

# Jortt Migration Skill

Read Jortt bookkeeping through its REST API and save repeatable extracts for a Moneybird migration. `jortt-cli` is the system's only API surface.

---

## 1. WHEN TO USE

### Activation Triggers

Use this skill when the user asks to:

- Extract Jortt customers, invoices, expenses, receipts, bank records or reports.
- Prepare source registers or evidence for a Jortt to Moneybird migration.
- Inspect a Jortt REST operation, download link or API response.
- Set up or diagnose `jortt-cli`.
- Check what the Jortt tooling can do or run its manual test scenarios.

### Keyword Triggers

- `jortt`, `jortt-cli` or Jortt bookkeeping
- Jortt invoices, expenses, receipts, bank transactions or VAT summaries
- Jortt extraction, auditfile, migration or source register
- `jortt-cli` operation slugs, scopes, paging or download links

### When NOT to Use

- Moneybird bookkeeping, imports or API calls belong to the sibling `cli-moneybird` skill.
- XAF auditfiles, annual accounts and filed VAT returns cannot come from the Jortt API. Ask the operator to use the Jortt UI.

---

## 2. SMART ROUTING

### Primary Detection Signal

The operation decides the route. Use `jortt-cli` for supported reads. UI-only tasks stay with the operator.

| Operation | Primary surface and command | Scope or route |
|---|---|---|
| Organization | `jortt-cli call get-the-organization-associated-with-the-api-credentials` or `jortt-cli whoami` | `organizations:read` |
| Customers | `jortt-cli call list-customers --all --out customers.json` | `customers:read` |
| Invoices | `jortt-cli call list-invoices-v3 --all --out invoices.json` | `invoices:read`. Fetch every page then filter locally because there is no date filter. |
| Invoice download | `jortt-cli call download-invoice-pdf --id INVOICE_ID --raw` then `jortt-cli fetch SIGNED_URL --out invoice.pdf` | `invoices:read` |
| Expenses | `jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json` | `expenses:read` |
| Receipts and inbox | `jortt-cli call list-receipts --scope in_inbox --all --out receipts-inbox.json` | `receipts:read` |
| Receipt download | `jortt-cli call download-url-for-a-receipt --id RECEIPT_ID --raw` then `jortt-cli fetch SIGNED_URL --out receipt.pdf` | `receipts:read` |
| Bank accounts | `jortt-cli call list-bank-accounts-v3 --out bank-accounts.json` | `financing:read` |
| Bank transactions | `jortt-cli call list-bank-transactions-v3 --id BANK_ACCOUNT_ID --all --out bank-transactions.json` | `financing:read` |
| Ledger account categories | `jortt-cli call list-cost-ledger-accounts`, `jortt-cli call list-income-ledger-accounts`, `jortt-cli call list-balance-ledger-accounts` or `jortt-cli call list-invoice-ledger-accounts` | Scope follows each operation in `jortt-cli describe`. |
| Payroll journal entries | `jortt-cli call list-loonjournaalposten --year YYYY --out payroll-journal.json` | `payroll:read` is not in the default scope list. |
| Profit and loss | `jortt-cli call profit-and-loss-report --year YYYY --out profit-and-loss.json` | `reports:read` |
| Balance | `jortt-cli call balance-report --year YYYY --out balance.json` | `reports:read` |
| VAT period summary | `jortt-cli call dashboard-btw --out vat-summary.json` | `reports:read`. This is a summary, not the filed return. |
| Attachment download | `jortt-cli call download-url-for-attachments --id ATTACHMENT_ID --name FILE_NAME --raw` then `jortt-cli fetch SIGNED_URL --out attachment.bin` | `organizations:read` |
| Labels | `jortt-cli call list-labels --out labels.json` | `organizations:read` |
| Projects | `jortt-cli call list-projects --all --out projects.json` | `invoices:read` |
| Data question | Use the smallest `jortt-cli` read that answers the question. State the API limit when no route exists. | Select and describe the matching operation, then request only the needed records. |
| XAF auditfile | Jortt UI: `Boekhoudbot` then `Maak voor mij een auditfile`. A Beheerder generates one XAF 4.0.3 file per year. | Ask the operator. The API has no XAF route. |
| Annual accounts | Jortt UI: `Rapporten > Jaarrekening`, one year at a time. | Ask the operator. |
| Filed VAT returns | Download through the Jortt UI. | Ask the operator. There is no filed-return API endpoint. |
| General ledger export | No API or UI export exists. | Unavailable. Do not label another report as a general ledger. |

All relative `--out` names resolve inside `<Accountant root>/migration-workspace/`, which is gitignored. A command without `--out` prints the response to stdout. Use `--out` for migration extracts.

### Resource Domains

The router discovers markdown at call time from three local trees and one root document.

- `references/` holds the CLI, REST, export and troubleshooting guidance.
- `feature-catalog/` holds the current-state inventory of every CLI command, safety gate and surface.
- `manual-testing-playbook/` holds the operator scenarios that validate that behavior.
- `INSTALL-GUIDE.md` is the one routable root document. It carries setup and rollback.

### Resource Loading Levels

| Level | When to load | Resources |
|---|---|---|
| ALWAYS | Every Jortt task | This file |
| CONDITIONAL | REST extraction or scope question | `references/rest-api.md` and `references/cli.md` |
| CONDITIONAL | UI export or API limit | `references/exports-and-limits.md` |
| CONDITIONAL | Capability question or manual test run | `feature-catalog/feature-catalog.md` or `manual-testing-playbook/manual-testing-playbook.md` |
| ON_DEMAND | Setup or error | `INSTALL-GUIDE.md` and `references/troubleshooting.md` |

### Detection Order

1. Route UI-only export requests to the operator guidance before trying an API operation.
2. Route ordinary record extraction to `jortt-cli` and load the matching API reference.
3. Send Moneybird-side work to the sibling `cli-moneybird` skill.
4. Load troubleshooting guidance when the user reports a failure.

### Smart Router Pseudocode

```python
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent
RESOURCE_BASES = (
    SKILL_ROOT / "references",
    SKILL_ROOT / "feature-catalog",
    SKILL_ROOT / "manual-testing-playbook",
)
ROOT_DOCS = ("INSTALL-GUIDE.md",)
AMBIGUITY_DELTA = 1

INTENT_MODEL = {
    "CLI_EXTRACT": {"weight": 6, "keywords": ["extract", "export", "list expenses", "invoices", "receipts", "bank transactions", "source register", "--all"]},
    "CLI_WRITE": {"weight": 5, "keywords": ["create in jortt", "update jortt", "delete jortt", "send invoice", "write operation"]},
    "EXPORT_UI": {"weight": 6, "keywords": ["xaf", "auditfile", "annual accounts", "filed vat return", "jaarrekening"]},
    "INSTALL": {"weight": 5, "keywords": ["install jortt-cli", "configure jortt", "jortt_client_id"]},
    "TROUBLESHOOT": {"weight": 6, "keywords": ["401", "invalid_scope", "403", "429", "422", "exit 3", "exit 4", "exit 5", "needs authentication", "expired link"]},
    "FEATURE_LOOKUP": {"weight": 4, "keywords": ["feature catalog", "what can jortt-cli do", "jortt-cli capabilities", "which jortt commands"]},
    "MANUAL_TEST": {"weight": 4, "keywords": ["manual test", "testing playbook", "test scenario", "jrt-"]},
}

RESOURCE_MAP = {
    "CLI_EXTRACT": ["references/rest-api.md", "references/cli.md"],
    "CLI_WRITE": ["references/cli.md", "references/troubleshooting.md"],
    "EXPORT_UI": ["references/exports-and-limits.md"],
    "INSTALL": ["INSTALL-GUIDE.md", "references/cli.md"],
    "TROUBLESHOOT": ["references/troubleshooting.md"],
    "FEATURE_LOOKUP": ["feature-catalog/feature-catalog.md"],
    "MANUAL_TEST": ["manual-testing-playbook/manual-testing-playbook.md", "feature-catalog/feature-catalog.md"],
}

UNKNOWN_FALLBACK_CHECKLIST = [
    "Confirm whether the request is a REST extract, UI export, setup task or error",
    "Ask for an operation name or expected output when the request does not identify the resource",
    "Keep the work read-only unless the operator names one write operation",
    "Do not load a default reference when no intent scores",
]


def discover_markdown_resources():
    docs = []
    for base in RESOURCE_BASES:
        if base.exists():
            docs.extend(path for path in base.rglob("*.md") if path.is_file())
    docs.extend(SKILL_ROOT / name for name in ROOT_DOCS if (SKILL_ROOT / name).is_file())
    return {path.relative_to(SKILL_ROOT).as_posix() for path in docs}


def _guard_in_skill(relative_path):
    resolved = (SKILL_ROOT / relative_path).resolve()
    resolved.relative_to(SKILL_ROOT)
    if resolved.suffix.lower() != ".md":
        raise ValueError("Only skill-local markdown resources are routable")
    return resolved.relative_to(SKILL_ROOT).as_posix()


def get_routing_key(request):
    return str(request or "").strip().lower()


def classify_intents(request):
    text = get_routing_key(request)
    scores = {intent: 0 for intent in INTENT_MODEL}
    for intent, config in INTENT_MODEL.items():
        for keyword in config["keywords"]:
            if keyword in text:
                scores[intent] += config["weight"]
    ranked = sorted(((score, intent) for intent, score in scores.items() if score), reverse=True)
    if len(ranked) > 1 and ranked[0][0] - ranked[1][0] <= AMBIGUITY_DELTA:
        return ranked[:2]
    return ranked[:1]


def route_resources(request):
    inventory = discover_markdown_resources()
    ranked = classify_intents(request)
    if not ranked:
        return {"intent": "UNKNOWN_FALLBACK", "resources": [], "checklist": UNKNOWN_FALLBACK_CHECKLIST}
    loaded, seen = [], set()
    for _score, intent in ranked:
        for relative_path in RESOURCE_MAP[intent]:
            guarded = _guard_in_skill(relative_path)
            if guarded in inventory and guarded not in seen:
                load(guarded)
                loaded.append(guarded)
                seen.add(guarded)
    return {"intents": [intent for _score, intent in ranked], "resources": loaded}
```

---

## 3. HOW IT WORKS

### Surface Comparison

| Surface | Best use | Output and limits |
|---|---|---|
| `jortt-cli` | Repeatable API reads, paging, downloads and full OpenAPI operation coverage | Primary. Writes require `--allow-write` plus the operation scope. |
| Jortt UI | XAF, annual accounts and filed VAT returns | Operator-only exports. XAF requires a Beheerder and is generated per year. |

### CLI Extraction Path

1. Run `jortt-cli spec info`. If no local spec exists, use `jortt-cli spec update` when network access is allowed.
2. Run `jortt-cli whoami`. A successful check reports HTTP 200 and top-level field names only.
3. Run `jortt-cli ops --tag TAG` to find an operation. Use `jortt-cli describe SLUG` to confirm its path, scope and parameters.
4. Extract with `jortt-cli call SLUG ... --all --out FILE`. The CLI follows next links and merges list data into one array.
5. Read the saved artifact only from `migration-workspace/`. Stdout reports the HTTP status and item count or top-level keys.

### Output Location

All saved extracts and downloads belong under `AI Systems/Moneybird Accountant/migration-workspace/`. That directory is gitignored. Never write extracted records into this skill, tracked documentation or another service. This skill does not use Code Mode.

### Command Quick Reference

| Goal | Command |
|---|---|
| Check CLI | `jortt-cli --version` |
| Inspect spec | `jortt-cli spec info` |
| Refresh spec | `jortt-cli spec update` |
| Check organization | `jortt-cli whoami` |
| List expense operations | `jortt-cli ops --tag expenses` |
| Describe filters | `jortt-cli describe list-expenses` |
| Extract one VAT year | `jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json` |
| Check token metadata | `jortt-cli token status` |
| Diagnose offline | `bash scripts/doctor.sh` |

Use relative output names under `migration-workspace/`. Keep `--allow-write` off for migration extraction.

---

## 4. RULES

### ✅ ALWAYS

- Keep migration calls read-only and use only scopes required for the selected extraction.
- Use `--all` for paged list operations. Treat an empty array as a valid result.
- Save extracts with `--out` inside `migration-workspace/` and fetch signed links promptly.
- Respect the 10 requests per second limit and the 100 item page limit.
- Run `--dry-run` before a write. Confirm the exact operation, body and target with the operator.
- Mark behavior absent from the local facts as `UNVERIFIED`.
- Ask the operator for XAF and other UI-only documents.

### ❌ NEVER

- Never add a `:write` scope, pass `--allow-write` or choose `Read and write` on consent without the operator's explicit instruction for that one operation.
- Never write extracted data outside `migration-workspace/`.
- Never paste personal financial data into tracked files, commits or prompts to other services.
- Never touch `AI Systems/Moneybird Accountant/personal database`.
- Never treat a VAT summary as a filed return or another report as a general ledger export.

### ⚠️ ESCALATE IF

- A requested operation needs a scope that the key does not have.
- The user requests a write, a broad scope change or `Read and write` consent.
- An API response conflicts with the local spec or the migration plan.
- A 422, unexplained empty page or incomplete next-link chain could change the source register.
- The task needs an XAF auditfile, annual accounts or a filed VAT return.

---

## 5. REFERENCES

### Core References

- [`references/cli.md`](references/cli.md) covers CLI installation, flags, scopes and exit codes.
- [`references/rest-api.md`](references/rest-api.md) contains all operation slugs, filters, paging notes and extraction recipes.
- [`references/exports-and-limits.md`](references/exports-and-limits.md) covers UI exports and API limits.
- [`references/troubleshooting.md`](references/troubleshooting.md) maps local and API errors to next steps.
- [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) gives setup and rollback steps.

### Inventory and Testing

- [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) lists every current CLI command, safety gate and surface with source anchors.
- [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) indexes operator scenarios and links each one to its catalog entry.

### Reference Loading Notes

Load only the reference that matches the current intent. Use the REST catalogue for operation selection. Use troubleshooting when a CLI command or API call fails. The UI export reference is required before answering XAF or filed-return requests. `SMART ROUTING` stays the authority for loading rules.

---

## 6. SUCCESS CRITERIA

### Extraction Completion Checklist

A Jortt extraction is ready for migration review when:

- ✅ `bash scripts/doctor.sh` completes its offline checks.
- ✅ `jortt-cli whoami` returns HTTP 200 and only field names.
- ✅ A paged list finishes through `_links.next.href` and produces a valid JSON array inside `migration-workspace/`.
- ✅ The operator has supplied UI-only files when the migration phase requires them.

### Validation Success

- ✅ `cli/jortt-cli/tests/run-tests.sh` passes against the local Swagger file.
- ✅ The manual testing playbook scenarios that apply to the change report `PASS`.

A successful local test does not prove a live account connection. Report live status only after current API evidence.

---

## 7. INTEGRATION POINTS

### Migration Plan

The migration plan index is [migration/README.md](../sk-moneybird-accountant/references/migration/README.md). The source CLI supports the inventory and source collection in Phases 0 to 2. Its records feed independent reconstruction, cross-reconciliation, anomaly review and mapping work in Phases 3 to 6. Pilot and historical writes begin later in the migration plan and belong to the Moneybird workflow. This skill does not authorize those writes.

### Sibling System

Use [`../cli-moneybird/`](../cli-moneybird/) for Moneybird API calls, imports and target-side verification. Jortt is the source system. Moneybird is the target system.

### Credentials and Outputs

Copy the local `.env.example` to `.env` and fill the Jortt client values from `app.jortt.nl` API keys. Keep `JORTT_SCOPES` read-only for migration extraction. The CLI reads `.env` or the file selected by `JORTT_ENV_FILE`. The `.env` file is gitignored.

### External Tools

- **Bash, curl and jq:** required by `jortt-cli`. `cli/jortt-cli/setup.sh` checks them and prints a symlink command.

---

## 8. REFERENCES AND RELATED RESOURCES

The router discovers reference, catalog and playbook docs at call time. Start with `references/cli.md` and `references/rest-api.md`, then load task-specific resources according to Section 2.

Scripts: `scripts/doctor.sh` for the offline doctor and `cli/jortt-cli/setup.sh` for the CLI prerequisite check.

Related skills: `cli-moneybird` for target-side Moneybird work.

Install guide: [INSTALL-GUIDE.md](INSTALL-GUIDE.md) for credentials, CLI setup and rollback.
