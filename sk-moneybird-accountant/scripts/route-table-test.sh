#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE TEST
# ───────────────────────────────────────────────────────────────
# Tests check-route-table.py against the real ROUTER.md and mutated copies.
# Usage: route-table-test.sh
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the checker is only trustworthy when it accepts the real files and
# rejects every drift this suite introduces. This suite proves both.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
# WHY: the sed scripts hold backticks and dollar signs that must stay literal, so they use single quotes.
# shellcheck disable=SC2016
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
SKILL_DIR=$(dirname "$SCRIPT_DIR")
REPO_ROOT=$(dirname "$SKILL_DIR")
CHECKER="$SCRIPT_DIR/check-route-table.py"
SKILL_MD="$SKILL_DIR/SKILL.md"
ROUTER_MD="$SKILL_DIR/ROUTER.md"
SIGNALS_MD="$SKILL_DIR/references/routing-signals.md"
GRAPH_METADATA="$SKILL_DIR/graph-metadata.json"

if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-route-table.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_MD" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$ROUTER_MD" ]]; then
    printf 'error: missing ROUTER.md in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$SIGNALS_MD" ]]; then
    printf 'error: missing references/routing-signals.md in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$GRAPH_METADATA" ]]; then
    printf 'error: missing graph-metadata.json in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$REPO_ROOT/cli-moneybird/SKILL.md" ]] || [[ ! -f "$REPO_ROOT/cli-jortt/SKILL.md" ]]; then
    printf 'error: missing a sibling SKILL.md in the repository\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/route-table-test.XXXXXX") || exit 2

# The checker reads the files beside its own folder, so every mutant lives in
# a throwaway copy of the repository and the real tree stays untouched
COPY_ROOT="$TMP_ROOT/repo-copy"
COPY_SKILL="$COPY_ROOT/sk-moneybird-accountant"
COPY_CHECKER="$COPY_SKILL/scripts/check-route-table.py"
COPY_ROUTER="$COPY_SKILL/ROUTER.md"
COPY_SIGNALS="$COPY_SKILL/references/routing-signals.md"
COPY_METADATA="$COPY_SKILL/graph-metadata.json"

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 3. TEST HELPERS
# ───────────────────────────────────────────────────────────────

passed=0
failed=0

# Record a passing check and print its report line
# Args:
#   $1 - Check name
pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

# Record a failing check and print its report line
# Args:
#   $1 - Check name
fail() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
}

# Put the real router, signals file and graph metadata back into the copy
restore_copy() {
    cp "$ROUTER_MD" "$COPY_ROUTER"
    cp "$SIGNALS_MD" "$COPY_SIGNALS"
    cp "$GRAPH_METADATA" "$COPY_METADATA"
}

# Run the copied checker after one edit to the copied tree, expect exit 1 and
# put the copy back afterwards
# Args:
#   $1 - Check name
#   $2 - Text the failure report must name, optional
mutant() {
    local name="$1"
    local marker="${2:-}"
    python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]] && { [[ -z "$marker" ]] || grep -qF "$marker" "$TMP_ROOT/out.txt"; }; then
        pass "$name"
    else
        fail "$name"
        cat "$TMP_ROOT/out.txt"
    fi
    restore_copy
}

# ───────────────────────────────────────────────────────────────
# 4. REAL SKILL MARKDOWN
# ───────────────────────────────────────────────────────────────

python3 -I "$CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "real ROUTER.md and routing-signals.md pass"
else
    fail "real ROUTER.md and routing-signals.md pass"
    cat "$TMP_ROOT/out.txt"
fi

# WHY: a selector that never reads the bootstrap sees only the description and
# the activation triggers, so both must name the three yearly deliverables.
SKILL_HEAD=$(sed -n '1,/^### Activation Triggers/{/^description:/p;}' "$SKILL_MD")
TRIGGERS=$(sed -n '/^### Activation Triggers/,/^### /p' "$SKILL_MD")
selector_ok=1
for phrase in 'VAT return' 'yearly overview' 'income tax return'; do
    grep -qiF "$phrase" <<<"$SKILL_HEAD" || selector_ok=0
    grep -qiF "$phrase" <<<"$TRIGGERS" || selector_ok=0
done
if [[ "$selector_ok" -eq 1 ]]; then
    pass "the description and the activation triggers name the VAT return, the yearly overview and the income tax return"
else
    fail "the description and the activation triggers name the VAT return, the yearly overview and the income tax return"
fi

# ───────────────────────────────────────────────────────────────
# 5. REPOSITORY COPY
# ───────────────────────────────────────────────────────────────

# Build a throwaway repository that holds the checker, the router, the
# metadata, the reference tree and the hub files the checker reads
mkdir -p "$COPY_SKILL/scripts" "$COPY_ROOT/cli-moneybird" "$COPY_ROOT/cli-jortt"
cp "$CHECKER" "$COPY_CHECKER"
cp "$SCRIPT_DIR/token-baseline.py" "$COPY_SKILL/scripts/token-baseline.py"
cp "$SKILL_MD" "$COPY_SKILL/SKILL.md"
cp "$ROUTER_MD" "$COPY_ROUTER"
cp "$GRAPH_METADATA" "$COPY_METADATA"
cp -R "$SKILL_DIR/references" "$COPY_SKILL/references"
cp "$REPO_ROOT/cli-moneybird/SKILL.md" "$COPY_ROOT/cli-moneybird/SKILL.md"
cp "$REPO_ROOT/cli-jortt/SKILL.md" "$COPY_ROOT/cli-jortt/SKILL.md"
cp "$REPO_ROOT/cli-moneybird/ROUTER.md" "$COPY_ROOT/cli-moneybird/ROUTER.md"
cp "$REPO_ROOT/cli-jortt/ROUTER.md" "$COPY_ROOT/cli-jortt/ROUTER.md"
for hub_file in SKILL.md mode-registry.json hub-router.json; do
    cp "$REPO_ROOT/$hub_file" "$COPY_ROOT/$hub_file"
done

# The untouched copy must pass, or every mutant below could fail for the wrong reason
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'route-table: ok' "$TMP_ROOT/out.txt"; then
    pass "the untouched repository copy passes"
else
    fail "the untouched repository copy passes"
    cat "$TMP_ROOT/out.txt"
fi

# ───────────────────────────────────────────────────────────────
# 6. ROUTER MUTANTS
# ───────────────────────────────────────────────────────────────

# Blank the budget cell of the T1 row
sed 's/| `tok:T1` | Beats T2/|  | Beats T2/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "budget cell blanked"

# Empty the Dutch cell of the T2 row
sed 's/`migratie`, `overzetten`, `historische administratie`, `categorie`, `valkuil`, `welke rekening` \| migrate, mapping/ \| migrate, mapping/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "Dutch cell emptied"

# Delete the T9 row
sed '/^| T9 | onboarding |/d' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "T9 row deleted"

# Point a read path outside the skill folder
sed 's|`!references/purchase-invoices\.md`|`!../AGENTS.md`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read path escapes the skill folder" "row T4 read path escapes the skill folder"

# Point a read path at a file that is not markdown
sed 's|`!references/purchase-invoices\.md`|`!references/index.json`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read path is not markdown" "row T4 read path is not markdown"

# Name a read path outside backticks, which the generated read set would drop
sed 's|`!references/purchase-invoices\.md`|!references/purchase-invoices.md|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read path not backticked" "row T4 read path is not backticked"

# Point a read path at a markdown-named symlink to a file that is not markdown
SYMLINK_PATH="$COPY_SKILL/references/route-table-test-alias.md"
ln -s index.json "$SYMLINK_PATH"
sed 's|`!references/purchase-invoices\.md`|`!references/route-table-test-alias.md`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read path is a markdown symlink to a non-markdown file" "row T4 read path is not markdown"
rm -f "$SYMLINK_PATH"

# Point a required read at a file that does not exist, which must fail
sed 's|`!references/migration/shared-mechanisms\.md`|`!references/migration/shared-mechanisms-missing.md`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "required read path missing" "row T1 read path missing: references/migration/shared-mechanisms-missing.md"

# Name a section anchor the target file does not hold
sed 's|`!references/migration/jortt-to-moneybird-mapping\.md`|`!references/migration/jortt-to-moneybird-mapping.md@no-such-heading`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read anchor missing" "row T2 read anchor not found"

# Drop the mark from a backticked read path
sed 's|`!references/purchase-invoices\.md`|`references/purchase-invoices.md`|' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "read item without a mark" "row T4 read item is not marked with ! or ?"

# Remove the ROUTE_MARGIN line
sed '/ROUTE_MARGIN/d' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "ROUTE_MARGIN line removed"

# List the weak signal btw as a T10 signal
sed 's/^| T10 | prepare the VAT return | `/| T10 | prepare the VAT return | `btw`, `/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "a row that lists a weak signal fails" "T10 lists the weak signal btw"

# Change the margin in the router alone
sed 's/`ROUTE_MARGIN = 0.25`/`ROUTE_MARGIN = 0.3`/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "ROUTE_MARGIN differs from the signal sources file" "route margin 0.3 differs from the signal sources file"

# Route the T2 row to a tool skill the table does not define
sed 's/| migrate, mapping, category, which account, trap | `none` |/| migrate, mapping, category, which account, trap | `cli-notion` |/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "T2 tool route unknown"

# Drop the pointer line that names the signal sources file
sed '/Signal sources, the `tok:Tn` keys and their Belastingdienst pages: `references\/routing-signals\.md`\./d' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "signal sources pointer removed"

# A ROUTER.md that drops the glossary read rule fails
sed 's#`references/glossary/README.md`#the glossary#' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "a ROUTER.md without the glossary read rule fails" "the glossary read rule is missing"

# ───────────────────────────────────────────────────────────────
# 7. SIGNALS FILE MUTANTS
# ───────────────────────────────────────────────────────────────

# Remove every source line from the signals file
sed '/^- /d' "$SIGNALS_MD" >"$COPY_SIGNALS"
mutant "signal source lines removed"

# Drop the belastingdienst link from the administration terms source line
sed 's|: https://www\.belastingdienst\.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/|: missing|' "$SIGNALS_MD" >"$COPY_SIGNALS"
mutant "belastingdienst link removed"

# Delete the whole signals file
rm -f "$COPY_SIGNALS"
mutant "signals file deleted"

# The Documented gaps table of the real signals file is the ledger under test,
# so each mutant breaks one of its rows.

# Empty the owner cell of the first ledger row
sed 's|references/vat-return/README.md| |' "$SIGNALS_MD" >"$COPY_SIGNALS"
mutant "gap row without an owner"

# Give every ledger row a coverage value outside the allowed set. The rows may all be
# covered by now, so match either value and refuse a mutant that changed nothing
sed -E 's/\| (gap|covered) \|/| unknown |/' "$SIGNALS_MD" >"$COPY_SIGNALS"
if cmp -s "$SIGNALS_MD" "$COPY_SIGNALS"; then
    fail "gap coverage mutant changed nothing"
fi
mutant "gap row with an unknown coverage"

# Repeat a topic in the ledger
sed 's/| yearly-overview |/| vat-return |/' "$SIGNALS_MD" >"$COPY_SIGNALS"
mutant "gap ledger with a repeated topic"

# ───────────────────────────────────────────────────────────────
# 8. ROUTER BLOCK DRIFT
# ───────────────────────────────────────────────────────────────

# Edit one table signal cell and leave the generated block stale
sed 's/| migrate, mapping, category, which account, trap |/| migrate, mapping, category, which account, traps |/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "table signal changed without regeneration" "row T2"

# Hand edit one line inside the generated block
sed 's/raise ValueError("local markdown only")/raise ValueError("markdown only")/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "hand edit inside the router block"

# Hand edit one row inside the generated REQUIRED_READS structure
python3 - "$ROUTER_MD" "$COPY_ROUTER" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    lines = handle.read().splitlines()
out = []
inside = False
for line in lines:
    if line == "REQUIRED_READS = {":
        inside = True
    elif inside and line == "}":
        inside = False
    elif inside and line.startswith('    "T2":'):
        line = '    "T2": ["references/migration/jortt-to-moneybird-mapping.md", "references/routing-signals.md"],'
    out.append(line)
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write("\n".join(out) + "\n")
PY
mutant "hand edit inside REQUIRED_READS" "row T2"

# Drop one multi-word table signal from the intent list
python3 - "$GRAPH_METADATA" "$COPY_METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["intent_signals"] = [signal for signal in data["intent_signals"] if signal != "migration phase"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
mutant "intent signal missing from the list" "migration phase"

# Drop one curated advisor signal from the intent list
python3 - "$GRAPH_METADATA" "$COPY_METADATA" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["intent_signals"] = [
    signal for signal in data["intent_signals"]
    if signal != "help me review a dutch sole trader yearly close"
]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
mutant "curated advisor signal missing from the list" "help me review a dutch sole trader yearly close"

# ───────────────────────────────────────────────────────────────
# 9. WRITE MODE STABILITY
# ───────────────────────────────────────────────────────────────

# Build a throwaway skill copy that holds the script, the router, the
# metadata and the reference tree the write mode guards
WRITE_COPY="$TMP_ROOT/write-copy"
mkdir -p "$WRITE_COPY/scripts"
cp "$CHECKER" "$WRITE_COPY/scripts/check-route-table.py"
cp "$SCRIPT_DIR/token-baseline.py" "$WRITE_COPY/scripts/token-baseline.py"
cp "$ROUTER_MD" "$WRITE_COPY/ROUTER.md"
cp "$GRAPH_METADATA" "$WRITE_COPY/graph-metadata.json"
cp -R "$SKILL_DIR/references" "$WRITE_COPY/references"

# Seed one table change so the first write has work to do in both files
sed 's/| migrate, mapping, category, which account, trap |/| migrate, mapping, category, which account, mapping trap |/' "$WRITE_COPY/ROUTER.md" >"$TMP_ROOT/write-seed.md"
cp "$TMP_ROOT/write-seed.md" "$WRITE_COPY/ROUTER.md"

python3 -I "$WRITE_COPY/scripts/check-route-table.py" --write >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]] && grep -qF "router block: written" "$TMP_ROOT/out.txt" && grep -qF "intent signals: added 1" "$TMP_ROOT/out.txt"; then
    pass "a table change regenerates the block and the signal list"
else
    fail "a table change regenerates the block and the signal list"
    cat "$TMP_ROOT/out.txt"
fi
first_skill=$(cksum "$WRITE_COPY/ROUTER.md")
first_metadata=$(cksum "$WRITE_COPY/graph-metadata.json")

python3 -I "$WRITE_COPY/scripts/check-route-table.py" --write >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "second write in a temp copy exits 0"
else
    fail "second write in a temp copy exits 0"
fi
second_skill=$(cksum "$WRITE_COPY/ROUTER.md")
second_metadata=$(cksum "$WRITE_COPY/graph-metadata.json")
if [[ "$first_skill" == "$second_skill" && "$first_metadata" == "$second_metadata" ]]; then
    pass "a second write leaves both files byte-identical"
else
    fail "a second write leaves both files byte-identical"
fi

# A router without its block markers is refused, because the write has no
# heading to fall back on and must not guess where the block belongs
sed -e '/^<!-- router-block:start -->$/d' -e '/^<!-- router-block:end -->$/d' "$WRITE_COPY/ROUTER.md" >"$TMP_ROOT/write-nomarkers.md"
cp "$TMP_ROOT/write-nomarkers.md" "$WRITE_COPY/ROUTER.md"
python3 -I "$WRITE_COPY/scripts/check-route-table.py" --write >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]] \
    && grep -qF "router block start marker missing" "$TMP_ROOT/out.txt" \
    && grep -qF "router block end marker missing" "$TMP_ROOT/out.txt" \
    && cmp -s "$TMP_ROOT/write-nomarkers.md" "$WRITE_COPY/ROUTER.md"; then
    pass "a write refuses a router without its block markers and leaves it unchanged"
else
    fail "a write refuses a router without its block markers and leaves it unchanged"
    cat "$TMP_ROOT/out.txt"
fi

# ───────────────────────────────────────────────────────────────
# 10. READ SET AND GLOSSARY CASES ON THE REPOSITORY COPY
# ───────────────────────────────────────────────────────────────

# A conditional read that names an absent file is recorded and never fails.
# The copy needs a write run first so the generated block matches the cell.
python3 - "$COPY_ROUTER" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
text = text.replace("`?references/mixed-use-costs.md`", "`?references/mixed-use-costs-missing.md`")
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write(text)
PY
python3 -I "$COPY_CHECKER" --write >"$TMP_ROOT/out.txt" 2>&1
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'missing: T4 references/mixed-use-costs-missing.md' "$TMP_ROOT/out.txt"; then
    pass "an absent conditional read is reported and passes"
else
    fail "an absent conditional read is reported and passes"
    cat "$TMP_ROOT/out.txt"
fi
restore_copy

# The year token expands over the year folders under references/tax-rules, so
# a missing year README is a read-set problem. A root-only listing would find
# no year folder and pass.
YEAR_README="$COPY_SKILL/references/tax-rules/2020/README.md"
mv "$YEAR_README" "$TMP_ROOT/year-readme.bak"
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
mv "$TMP_ROOT/year-readme.bak" "$YEAR_README"
if [[ "$status" -eq 1 ]] \
    && grep -qF 'row T3 read path missing: references/tax-rules/2020/README.md' "$TMP_ROOT/out.txt"; then
    pass "a missing year README under tax-rules fails the read-set check"
else
    fail "a missing year README under tax-rules fails the read-set check"
    cat "$TMP_ROOT/out.txt"
fi

# A required map expansion must exist in every year folder, so a topic
# figures file missing from one year fails.
YEAR_FIGURES="$COPY_SKILL/references/tax-rules/2020/vat/figures.md"
mv "$YEAR_FIGURES" "$TMP_ROOT/year-figures.bak"
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
mv "$TMP_ROOT/year-figures.bak" "$YEAR_FIGURES"
if [[ "$status" -eq 1 ]] \
    && grep -qF 'row T5 read path missing: references/tax-rules/2020/vat/figures.md' "$TMP_ROOT/out.txt"; then
    pass "a topic figures file missing from one year folder fails"
else
    fail "a topic figures file missing from one year folder fails"
    cat "$TMP_ROOT/out.txt"
fi

# The glossary read rule needs a glossary file for every topic folder, so a
# missing topic file fails.
GLOSSARY_COPY="$COPY_SKILL/references/glossary"
mv "$GLOSSARY_COPY/vat.md" "$TMP_ROOT/glossary-vat.bak"
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
mv "$TMP_ROOT/glossary-vat.bak" "$GLOSSARY_COPY/vat.md"
if [[ "$status" -eq 1 ]] \
    && grep -qF 'missing glossary file: references/glossary/vat.md' "$TMP_ROOT/out.txt"; then
    pass "a topic glossary file missing from the folder fails"
else
    fail "a topic glossary file missing from the folder fails"
    cat "$TMP_ROOT/out.txt"
fi

# Every category file must be linked from the router, so an unlinked file fails
printf '# Extra\n' >"$GLOSSARY_COPY/extra.md"
python3 -I "$COPY_CHECKER" >"$TMP_ROOT/out.txt" 2>&1
status=$?
rm -f "$GLOSSARY_COPY/extra.md"
if [[ "$status" -eq 1 ]] \
    && grep -qF 'glossary router does not link: references/glossary/extra.md' "$TMP_ROOT/out.txt"; then
    pass "a glossary file the router does not link fails"
else
    fail "a glossary file the router does not link fails"
    cat "$TMP_ROOT/out.txt"
fi

# ───────────────────────────────────────────────────────────────
# 11. HUB AND ROW RULE CASES ON THE REPOSITORY COPY
# ───────────────────────────────────────────────────────────────

# The hub check reads the repository root, so each hub mutant edits the
# throwaway copy of the repository and restores it before the next case.

mv "$COPY_ROOT/hub-router.json" "$TMP_ROOT/hub-router.bak"
mutant "a missing hub file fails" "missing hub file: hub-router.json"
mv "$TMP_ROOT/hub-router.bak" "$COPY_ROOT/hub-router.json"

cp "$COPY_ROOT/mode-registry.json" "$TMP_ROOT/registry.bak"
sed 's/"packet": "cli-jortt"/"packet": "cli-absent"/' "$TMP_ROOT/registry.bak" >"$COPY_ROOT/mode-registry.json"
mutant "a registry packet with no folder fails" "registry packet has no SKILL.md: cli-absent"
sed 's/"default": false/"default": true/' "$TMP_ROOT/registry.bak" >"$COPY_ROOT/mode-registry.json"
mutant "a registry with two default packets fails" "needs exactly one default mode, found 3"
cp "$TMP_ROOT/registry.bak" "$COPY_ROOT/mode-registry.json"

cp "$COPY_ROOT/hub-router.json" "$TMP_ROOT/hub-router.bak"
sed 's/"defaultMode": "accountant"/"defaultMode": "cli-jortt"/' "$TMP_ROOT/hub-router.bak" >"$COPY_ROOT/hub-router.json"
mutant "a stage one default that is not the registry default fails" "defaultMode cli-jortt is not the registry default accountant"
cp "$TMP_ROOT/hub-router.bak" "$COPY_ROOT/hub-router.json"

cp "$COPY_ROOT/cli-jortt/SKILL.md" "$TMP_ROOT/jortt-skill.bak"
printf '\n<!-- router-block:start -->\n' >>"$COPY_ROOT/cli-jortt/SKILL.md"
mutant "a router left in a packet SKILL.md fails" "packet SKILL.md embeds a router: cli-jortt/SKILL.md"
cp "$TMP_ROOT/jortt-skill.bak" "$COPY_ROOT/cli-jortt/SKILL.md"

mv "$COPY_ROOT/cli-jortt/ROUTER.md" "$TMP_ROOT/jortt-router.bak"
mutant "a packet without a ROUTER.md fails" "packet has no router: cli-jortt/ROUTER.md"
sed 's/^router_state: active$/router_state: draft/' "$TMP_ROOT/jortt-router.bak" >"$COPY_ROOT/cli-jortt/ROUTER.md"
mutant "a packet ROUTER.md that is not active fails" "cli-jortt/ROUTER.md frontmatter lacks: router_state: active"
cp "$TMP_ROOT/jortt-router.bak" "$COPY_ROOT/cli-jortt/ROUTER.md"
python3 -I - "$TMP_ROOT/jortt-router.bak" "$COPY_ROOT/cli-jortt/ROUTER.md" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
closing = text.index("\n---\n", 4) + len("\n---\n")
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(text[:closing])
PY
mutant "a packet ROUTER.md emptied to its frontmatter fails" "cli-jortt/ROUTER.md lacks its routing section, intent model or resource map"
cp "$TMP_ROOT/jortt-router.bak" "$COPY_ROOT/cli-jortt/ROUTER.md"

cp "$COPY_ROOT/SKILL.md" "$TMP_ROOT/hub-skill.bak"
sed 's#(cli-jortt/ROUTER.md)#(cli-jortt/README.md)#g' "$TMP_ROOT/hub-skill.bak" >"$COPY_ROOT/SKILL.md"
mutant "a hub SKILL.md that drops a packet router link fails" "hub SKILL.md does not link the packet router: cli-jortt/ROUTER.md"
cp "$TMP_ROOT/hub-skill.bak" "$COPY_ROOT/SKILL.md"

mkdir -p "$COPY_ROOT/cli-extra"
printf -- '---\nname: cli-extra\n---\n' >"$COPY_ROOT/cli-extra/SKILL.md"
mutant "a packet folder missing from the registry fails" "packet folder is not in mode-registry.json: cli-extra"
rm -rf "$COPY_ROOT/cli-extra"

sed 's/"packetSkillName": "cli-jortt"/"packetSkillName": "cli-wrong"/' "$TMP_ROOT/registry.bak" >"$COPY_ROOT/mode-registry.json"
mutant "a registry packetSkillName that differs from the SKILL.md name fails" "registry packetSkillName of cli-jortt does not match its SKILL.md name"
python3 -I - "$TMP_ROOT/registry.bak" "$COPY_ROOT/mode-registry.json" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(text.replace('"packetKind": "tool"', '"packetKind": "bogus"', 1))
PY
mutant "a registry packetKind outside the two kinds fails" "registry packetKind of cli-moneybird is bogus, expected tool"
cp "$TMP_ROOT/registry.bak" "$COPY_ROOT/mode-registry.json"

# WHY: the resolver depends on three row rules and the budget keys on the
# ladder, so dropping any of them must fail by name.
sed 's/full file 15,000\./full file 16,000./' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "a ladder number that differs from its sources fails" "ladder value 16000 differs from the signal sources file"
sed 's/Additive and never wins alone/Additive and wins alone/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "a T7 row that may win alone fails" "T7 on tie cell lacks: never wins alone"
sed 's/Loses to every typed row/Beats every typed row/' "$ROUTER_MD" >"$COPY_ROUTER"
mutant "a T9 row that beats a typed row fails" "T9 on tie cell lacks: Loses to every typed row"
python3 -I - "$ROUTER_MD" "$COPY_ROUTER" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
start = text.index("| T8 |")
cell = text.index("| `none` |", start)
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(text[:cell] + "| `cli-moneybird` |" + text[cell + len("| `none` |"):])
PY
mutant "a T8 row that names a tool route fails" "T8 tool route must be"

cp "$COPY_ROOT/hub-router.json" "$TMP_ROOT/hub-router.bak"
python3 -I - "$TMP_ROOT/hub-router.bak" "$COPY_ROOT/hub-router.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["signals"]["cli-jortt"] = []
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
mutant "an empty stage one signal list for a non-default mode fails" "hub-router.json signals for cli-jortt are empty and it is not the default"
python3 -I - "$TMP_ROOT/hub-router.bak" "$COPY_ROOT/hub-router.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["signals"]["cli-jortt"] = "jortt-cli"
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
mutant "a stage one signal value that is not a list fails" "hub-router.json signals for cli-jortt are not a list of phrases"
cp "$TMP_ROOT/hub-router.bak" "$COPY_ROOT/hub-router.json"

# ───────────────────────────────────────────────────────────────
# 12. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
