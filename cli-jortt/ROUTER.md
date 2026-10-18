---
title: Jortt CLI Router
description: Stage two routing of the Jortt CLI packet. The hub SKILL.md picks this packet, this file routes inside it and SKILL.md holds its contract.
trigger_phrases:
  - "jortt cli router"
  - "jortt cli smart routing"
importance_tier: important
contextType: general
version: 1.0.0.0
router_state: active
skill_pointer: SKILL.md
---

# Jortt CLI Router

## 1. OVERVIEW

This file holds the routing of the Jortt CLI packet: the operation table, the resource domains and loading levels, the detection order and the router pseudocode. The hub [`SKILL.md`](../SKILL.md) picks this packet, this file routes inside it and [`SKILL.md`](SKILL.md) holds the packet's contract.

---

## 2. SMART ROUTING

### Primary Detection Signal

The operation decides the route. Use `jortt-cli` for supported reads. UI-only tasks stay with the operator.

| Operation | Primary surface and command | Scope or route |
|---|---|---|
| Organization | `jortt-cli call get-the-organization-associated-with-the-api-credentials` or `jortt-cli whoami` | `organizations:read` |
| Customers | `jortt-cli call list-customers --all --out customers.json` | `customers:read` |
| Invoices | `jortt-cli call list-invoices-v3 --all --out invoices.json` | `invoices:read`. Fetch every page then filter locally because there is no date filter. |
| Invoice download | `jortt-cli call download-invoice-pdf --id INVOICE_ID --out download-url.json`, read the signed URL from the saved file, then `jortt-cli fetch SIGNED_URL --out invoice.pdf` | `invoices:read` |
| Expenses | `jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json` | `expenses:read` |
| Receipts and inbox | `jortt-cli call list-receipts --scope in_inbox --all --out receipts-inbox.json` | `receipts:read` |
| Receipt download | `jortt-cli call download-url-for-a-receipt --id RECEIPT_ID --out download-url.json`, read the signed URL from the saved file, then `jortt-cli fetch SIGNED_URL --out receipt.pdf` | `receipts:read` |
| Bank accounts | `jortt-cli call list-bank-accounts-v3 --out bank-accounts.json` | `financing:read` |
| Bank transactions | `jortt-cli call list-bank-transactions-v3 --id BANK_ACCOUNT_ID --all --out bank-transactions.json` | `financing:read` |
| Ledger account categories | `jortt-cli call list-cost-ledger-accounts`, `jortt-cli call list-income-ledger-accounts`, `jortt-cli call list-balance-ledger-accounts` or `jortt-cli call list-invoice-ledger-accounts` | Scope follows each operation in `jortt-cli describe`. |
| Payroll journal entries | `jortt-cli call list-loonjournaalposten --year YYYY --out payroll-journal.json` | `payroll:read` is not in the default scope list. |
| Profit and loss | `jortt-cli call profit-and-loss-report --year YYYY --out profit-and-loss.json` | `reports:read` |
| Balance | `jortt-cli call balance-report --year YYYY --out balance.json` | `reports:read` |
| VAT period summary | `jortt-cli call dashboard-btw --out vat-summary.json` | `reports:read`. This is a summary, not the filed return. |
| Attachment download | `jortt-cli call download-url-for-attachments --id ATTACHMENT_ID --name FILE_NAME --out download-url.json`, read the signed URL from the saved file, then `jortt-cli fetch SIGNED_URL --out attachment.bin` | `organizations:read` |
| Labels | `jortt-cli call list-labels --out labels.json` | `organizations:read` |
| Projects | `jortt-cli call list-projects --all --out projects.json` | `invoices:read` |
| Data question | Use the smallest `jortt-cli` read that answers the question. State the API limit when no route exists. | Select and describe the matching operation, then request only the needed records. |
| XAF auditfile | Jortt UI: `Boekhoudbot` then `Maak voor mij een auditfile`. An administrator (Beheerder) generates one XAF 4.0.3 file per year. | Ask the operator. The API has no XAF route. |
| Annual accounts (jaarrekening) | Jortt UI: `Rapporten > Jaarrekening`, one year at a time. | Ask the operator. |
| Filed VAT returns | Download through the Jortt UI. | Ask the operator. There is no filed-return API endpoint. |
| General ledger (grootboek) export | No API or UI export exists. | Unavailable. Do not label another report as a general ledger. |
| Jortt write (create, update, delete or send) | None. `jortt-cli` refuses every non-GET call with exit 3. | Refuse, even on Operator request, and hand the change to the Operator for the Jortt UI. |
| Full record body in the terminal | None. `--print-body` is refused with exit 2 in an agent session. | Use `--out` and read the saved file under `migration-workspace/`. |

All relative `--out` names resolve inside `<Accountant root>/migration-workspace/`, which is gitignored. A command without `--out` prints a summary, not the record content. Use `--out` for migration extracts.

### Resource Domains

The router discovers markdown at call time from three local trees and one root document.

- `references/` holds the CLI, REST, export and troubleshooting guidance.
- `feature-catalog/` holds the current-state inventory of every CLI command, safety gate and surface.
- `manual-testing-playbook/` holds the operator scenarios that validate that behavior.
- `INSTALL-GUIDE.md` is the one routable root document. It carries setup and rollback.

### Resource Loading Levels

| Level | When to load | Resources |
|---|---|---|
| ALWAYS | Every Jortt task | `SKILL.md` and this file |
| CONDITIONAL | REST extraction or scope question | `references/rest-api.md` and `references/cli.md` |
| CONDITIONAL | UI export or API limit | `references/exports-and-limits.md` |
| CONDITIONAL | Capability question or manual test run | `feature-catalog/feature-catalog.md` or `manual-testing-playbook/manual-testing-playbook.md` |
| ON_DEMAND | Setup or error | `INSTALL-GUIDE.md` and `references/troubleshooting.md` |

### Detection Order

1. Refuse a Jortt write or a `--print-body` request before any CLI call.
2. Route UI-only export requests to the operator guidance before trying an API operation.
3. Route ordinary record extraction to `jortt-cli` and load the matching API reference.
4. Send Moneybird-side work to the sibling `cli-moneybird` skill.
5. Load troubleshooting guidance when the user reports a failure.

### Smart Router Pseudocode

The intents map requests to resources. REFUSED loads `references/troubleshooting.md` and stops, because Jortt is read-only and record bodies stay out of the terminal.

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
    "REFUSED": {"weight": 7, "keywords": ["create in jortt", "update jortt", "delete jortt", "send invoice", "write operation", "print-body"]},
    "EXPORT_UI": {"weight": 6, "keywords": ["xaf", "auditfile", "annual accounts", "filed vat return", "jaarrekening"]},
    "INSTALL": {"weight": 5, "keywords": ["install jortt-cli", "configure jortt", "jortt_client_id"]},
    "TROUBLESHOOT": {"weight": 6, "keywords": ["401", "invalid_scope", "403", "429", "422", "exit 1", "exit 2", "exit 3", "exit 4", "exit 5", "exit 6", "needs authentication", "expired link"]},
    "FEATURE_LOOKUP": {"weight": 4, "keywords": ["feature catalog", "what can jortt-cli do", "jortt-cli capabilities", "which jortt commands"]},
    "MANUAL_TEST": {"weight": 4, "keywords": ["manual test", "testing playbook", "test scenario", "jrt-"]},
}

RESOURCE_MAP = {
    "CLI_EXTRACT": ["references/rest-api.md", "references/cli.md"],
    "REFUSED": ["references/troubleshooting.md"],
    "EXPORT_UI": ["references/exports-and-limits.md"],
    "INSTALL": ["INSTALL-GUIDE.md", "references/cli.md"],
    "TROUBLESHOOT": ["references/troubleshooting.md"],
    "FEATURE_LOOKUP": ["feature-catalog/feature-catalog.md"],
    "MANUAL_TEST": ["manual-testing-playbook/manual-testing-playbook.md", "feature-catalog/feature-catalog.md"],
}

UNKNOWN_FALLBACK_CHECKLIST = [
    "Confirm whether the request is a REST extract, UI export, setup task or error",
    "Ask for an operation name or expected output when the request does not identify the resource",
    "Keep the work read-only. Jortt has no write path for an agent",
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
