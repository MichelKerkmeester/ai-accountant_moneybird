#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE TEST
# ───────────────────────────────────────────────────────────────
# Tests check-route-table.py against the real SKILL.md and mutated copies.
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
WORD_CHECKER="$SCRIPT_DIR/check-skill-words.py"
SKILL_MD="$SKILL_DIR/SKILL.md"
SIGNALS_MD="$SKILL_DIR/references/routing-signals.md"
GRAPH_METADATA="$SKILL_DIR/graph-metadata.json"

if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-route-table.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$WORD_CHECKER" ]]; then
    printf 'error: missing scripts/check-skill-words.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_MD" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
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
# The symlink mutant needs a link inside the real skill folder, because the checker resolves read paths there
SYMLINK_PATH="$SKILL_DIR/references/route-table-test-alias.md"

# Remove the temp root and the mutant symlink on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
    if [[ -L "$SYMLINK_PATH" ]]; then
        rm -f "$SYMLINK_PATH"
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
#   $1 - Check description
pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

# Record a failing check and print its report line
# Args:
#   $1 - Check description
fail() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
}

# Run the checker against a mutated SKILL.md copy expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Markdown copy to check
mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --skill-md "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a mutated signals file expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Signals file copy to check
signals_mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --signals "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a drifted markdown copy expected to exit 1 and name a text
# Args:
#   $1 - Check name
#   $2 - Markdown copy to check
#   $3 - Text the failure report must name
drift_mutant() {
    local name="$1"
    local file="$2"
    local marker="$3"
    python3 -I "$CHECKER" --skill-md "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]] && grep -qF "$marker" "$TMP_ROOT/out.txt"; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a mutated graph metadata file expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Graph metadata copy to check
metadata_mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --graph-metadata "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a drifted graph metadata copy expected to exit 1 and name a text
# Args:
#   $1 - Check name
#   $2 - Graph metadata copy to check
#   $3 - Text the failure report must name
metadata_drift_mutant() {
    local name="$1"
    local file="$2"
    local marker="$3"
    python3 -I "$CHECKER" --graph-metadata "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]] && grep -qF "$marker" "$TMP_ROOT/out.txt"; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a mutated calibration file expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Calibration file copy to check
calibration_mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --calibration "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# ───────────────────────────────────────────────────────────────
# 4. REAL SKILL MARKDOWN
# ───────────────────────────────────────────────────────────────

python3 -I "$CHECKER" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "real SKILL.md and routing-signals.md pass"
else
    fail "real SKILL.md and routing-signals.md pass"
    cat "$TMP_ROOT/out.txt"
fi

# The generated router block must read the session context and hold no old level name
ROUTER_SECTION=$(sed -n '/^### Smart Router Pseudocode/,/^### Migration Phase Routing/p' "$SKILL_MD")
if grep -qF 'session-context.json' <<<"$ROUTER_SECTION" \
    && ! grep -qiE 'zzp question|cli action|live bookkeeping|resource loading levels' <<<"$ROUTER_SECTION" \
    && ! grep -qF 'migration-workspace' <<<"$ROUTER_SECTION"; then
    pass "router block reads the session context and drops the old level names"
else
    fail "router block reads the session context and drops the old level names"
fi

# ───────────────────────────────────────────────────────────────
# 5. MUTANTS
# ───────────────────────────────────────────────────────────────

copy() {
    cp "$SKILL_MD" "$TMP_ROOT/SKILL.md"
    printf '%s\n' "$TMP_ROOT/SKILL.md"
}

# Blank the budget cell of the T1 row
sed 's/| `tok:T1` | Beats T2/|  | Beats T2/' "$(copy)" >"$TMP_ROOT/m-budget.md"
mutant "budget cell blanked" "$TMP_ROOT/m-budget.md"

# Empty the Dutch cell of the T2 row
sed 's/`migratie`, `overzetten`, `historische administratie`, `categorie`, `valkuil`, `welke rekening` \| mapping/ \| mapping/' "$(copy)" >"$TMP_ROOT/m-dutch.md"
mutant "Dutch cell emptied" "$TMP_ROOT/m-dutch.md"

# Delete the T9 row
sed '/^| T9 | onboarding |/d' "$(copy)" >"$TMP_ROOT/m-row.md"
mutant "T9 row deleted" "$TMP_ROOT/m-row.md"

# Point a read path at a file that does not exist
sed 's|references/purchase-invoices\.md|references/purchase-invoices-missing.md|' "$(copy)" >"$TMP_ROOT/m-path.md"
mutant "read path missing" "$TMP_ROOT/m-path.md"

# Point a read path outside the skill folder
sed 's|`references/purchase-invoices\.md`|`../AGENTS.md`|' "$(copy)" >"$TMP_ROOT/m-path-escape.md"
drift_mutant "read path escapes the skill folder" "$TMP_ROOT/m-path-escape.md" "row T4 read path escapes the skill folder"

# Point a read path at a file that is not markdown
sed 's|`references/purchase-invoices\.md`|`references/index.json`|' "$(copy)" >"$TMP_ROOT/m-path-nonmd.md"
drift_mutant "read path is not markdown" "$TMP_ROOT/m-path-nonmd.md" "row T4 read path is not markdown"

# Name a read path outside backticks, which the generated read set would drop
sed 's|`references/purchase-invoices\.md`|references/purchase-invoices.md|' "$(copy)" >"$TMP_ROOT/m-path-bare.md"
drift_mutant "read path not backticked" "$TMP_ROOT/m-path-bare.md" "row T4 read path is not backticked"

# Name an absolute read path outside backticks
sed 's|`references/purchase-invoices\.md`|/tmp/purchase-invoices.md|' "$(copy)" >"$TMP_ROOT/m-path-bare-abs.md"
drift_mutant "absolute read path not backticked" "$TMP_ROOT/m-path-bare-abs.md" "row T4 read path is not backticked"

# Name a read path with an uppercase extension outside backticks
sed 's|`references/purchase-invoices\.md`|references/purchase-invoices.MD|' "$(copy)" >"$TMP_ROOT/m-path-bare-upper.md"
drift_mutant "uppercase read path not backticked" "$TMP_ROOT/m-path-bare-upper.md" "row T4 read path is not backticked"

# Name a UNC read path and two other document extensions outside backticks
sed 's|`references/purchase-invoices\.md`|//server/share/README.md|' "$(copy)" >"$TMP_ROOT/m-path-bare-unc.md"
drift_mutant "UNC read path not backticked" "$TMP_ROOT/m-path-bare-unc.md" "row T4 read path is not backticked"
sed 's|`references/purchase-invoices\.md`|references/purchase-invoices.rst|' "$(copy)" >"$TMP_ROOT/m-path-bare-rst.md"
drift_mutant "rst read path not backticked" "$TMP_ROOT/m-path-bare-rst.md" "row T4 read path is not backticked"
sed 's|`references/purchase-invoices\.md`|references/purchase-invoices.mdx|' "$(copy)" >"$TMP_ROOT/m-path-bare-mdx.md"
drift_mutant "mdx read path not backticked" "$TMP_ROOT/m-path-bare-mdx.md" "row T4 read path is not backticked"

# Point a read path at a markdown-named symlink to a file that is not markdown
ln -s index.json "$SYMLINK_PATH"
sed 's|`references/purchase-invoices\.md`|`references/route-table-test-alias.md`|' "$(copy)" >"$TMP_ROOT/m-path-symlink.md"
drift_mutant "read path is a markdown symlink to a non-markdown file" "$TMP_ROOT/m-path-symlink.md" "row T4 read path is not markdown"
rm -f "$SYMLINK_PATH"

# Remove the ROUTE_MARGIN line
sed '/ROUTE_MARGIN/d' "$(copy)" >"$TMP_ROOT/m-margin.md"
mutant "ROUTE_MARGIN line removed" "$TMP_ROOT/m-margin.md"

# Route the T2 row to a tool skill the table does not define
sed 's/| mapping, category, which account, trap | `none` |/| mapping, category, which account, trap | `cli-notion` |/' "$(copy)" >"$TMP_ROOT/m-route.md"
mutant "T2 tool route unknown" "$TMP_ROOT/m-route.md"

# Delete the T6 margin override bullet
sed '/^- Margin override T6:/d' "$(copy)" >"$TMP_ROOT/m-override-gone.md"
mutant "T6 override bullet deleted" "$TMP_ROOT/m-override-gone.md"

# Give the T6 override bullet a value that is neither default nor a number
sed 's/^- Margin override T6: `default`$/- Margin override T6: `abc`/' "$(copy)" >"$TMP_ROOT/m-override-value.md"
mutant "T6 override set to abc" "$TMP_ROOT/m-override-value.md"

# Give the T2 margin override bullet a type the table does not allow
sed 's/^- Margin override T2: `default`$/- Margin override T7: `default`/' "$(copy)" >"$TMP_ROOT/m-override-type.md"
mutant "override bullet names T7" "$TMP_ROOT/m-override-type.md"

# Remove the Ties and Abstain heading
sed '/^### Ties and Abstain$/d' "$(copy)" >"$TMP_ROOT/m-tie-heading.md"
mutant "Ties and Abstain heading removed" "$TMP_ROOT/m-tie-heading.md"

# Drop the pointer line that names the signal sources file
sed '/Signal sources, the `tok:Tn` keys and their Belastingdienst pages: `references\/routing-signals\.md`\./d' "$(copy)" >"$TMP_ROOT/m-pointer.md"
mutant "signal sources pointer removed" "$TMP_ROOT/m-pointer.md"

# ───────────────────────────────────────────────────────────────
# 6. SIGNALS FILE MUTANTS
# ───────────────────────────────────────────────────────────────

# Copy the signals file to a temp path so the original stays untouched
cp "$SIGNALS_MD" "$TMP_ROOT/routing-signals.md"

# Remove every source line from the signals file
sed '/^- /d' "$TMP_ROOT/routing-signals.md" >"$TMP_ROOT/m-signals-lines.md"
signals_mutant "signal source lines removed" "$TMP_ROOT/m-signals-lines.md"

# Drop the belastingdienst link from the administration terms source line
sed 's|: https://www\.belastingdienst\.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/|: missing|' "$TMP_ROOT/routing-signals.md" >"$TMP_ROOT/m-signals-link.md"
signals_mutant "belastingdienst link removed" "$TMP_ROOT/m-signals-link.md"

# Delete the whole signals file by pointing the checker at an absent path
signals_mutant "signals file deleted" "$TMP_ROOT/no-such-routing-signals.md"

# ───────────────────────────────────────────────────────────────
# 7. CALIBRATION MUTANTS
# ───────────────────────────────────────────────────────────────

CALIBRATION="$SKILL_DIR/assets/route-calibration.json"

# Build one mutant record per mismatch from the real record
python3 - "$CALIBRATION" "$TMP_ROOT" <<'PY'
import json
import os
import sys

source = sys.argv[1]
target = sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    data = json.load(handle)

def copy():
    return json.loads(json.dumps(data))

margin = copy()
margin["route_margin"] = 0.5
with open(os.path.join(target, "cal-margin.json"), "w", encoding="utf-8") as handle:
    json.dump(margin, handle, indent=2)
floor = copy()
floor["fallback_floor"] = 0.85
with open(os.path.join(target, "cal-floor.json"), "w", encoding="utf-8") as handle:
    json.dump(floor, handle, indent=2)
rate = copy()
rate["held_out"] = dict(data["held_out"], false_abstain_rate=0.5)
with open(os.path.join(target, "cal-rate.json"), "w", encoding="utf-8") as handle:
    json.dump(rate, handle, indent=2)
sweep_gone = copy()
sweep_gone.pop("sweep", None)
with open(os.path.join(target, "cal-sweep-gone.json"), "w", encoding="utf-8") as handle:
    json.dump(sweep_gone, handle, indent=2)
sweep_beheaded = copy()
sweep_beheaded["sweep"]["candidates"] = [
    candidate for candidate in sweep_beheaded["sweep"]["candidates"]
    if candidate["floor"] != data["fallback_floor"]
]
with open(os.path.join(target, "cal-sweep-beheaded.json"), "w", encoding="utf-8") as handle:
    json.dump(sweep_beheaded, handle, indent=2)
sweep_off = copy()
sweep_off["sweep"]["candidates"][0]["false_abstains"] = 3
with open(os.path.join(target, "cal-sweep-off.json"), "w", encoding="utf-8") as handle:
    json.dump(sweep_off, handle, indent=2)
sweep_frozen = copy()
sweep_frozen["calibration"] = dict(data["calibration"], route_matches=31)
with open(os.path.join(target, "cal-sweep-frozen.json"), "w", encoding="utf-8") as handle:
    json.dump(sweep_frozen, handle, indent=2)
sweep_twin = copy()
sweep_twin["sweep"]["candidates"].append(dict(data["sweep"]["candidates"][0]))
with open(os.path.join(target, "cal-sweep-twin.json"), "w", encoding="utf-8") as handle:
    json.dump(sweep_twin, handle, indent=2)
PY

calibration_mutant "calibration margin differs from the table" "$TMP_ROOT/cal-margin.json"
calibration_mutant "calibration floor differs from the table" "$TMP_ROOT/cal-floor.json"
calibration_mutant "calibration false-abstain rate above the cap" "$TMP_ROOT/cal-rate.json"
calibration_mutant "calibration file deleted" "$TMP_ROOT/no-such-calibration.json"
calibration_mutant "calibration sweep missing" "$TMP_ROOT/cal-sweep-gone.json"
calibration_mutant "calibration chosen floor not swept" "$TMP_ROOT/cal-sweep-beheaded.json"
calibration_mutant "calibration sweep rate disagrees with its counts" "$TMP_ROOT/cal-sweep-off.json"
calibration_mutant "calibration frozen block differs from the sweep" "$TMP_ROOT/cal-sweep-frozen.json"
calibration_mutant "calibration sweep holds a duplicate floor" "$TMP_ROOT/cal-sweep-twin.json"

# A table that states values the record does not match fails the check
python3 - "$(copy)" "$TMP_ROOT/m-table-margin.md" "$TMP_ROOT/m-table-floor.md" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(text.replace("ROUTE_MARGIN = 0.25", "ROUTE_MARGIN = 0.50"))
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    handle.write(text.replace("- `FALLBACK_FLOOR = 0.5`, frozen on the calibration split.", "- `FALLBACK_FLOOR = 0.85`, frozen on the calibration split."))
PY
mutant "table margin differs from the record" "$TMP_ROOT/m-table-margin.md"
mutant "table floor differs from the record" "$TMP_ROOT/m-table-floor.md"

# ───────────────────────────────────────────────────────────────
# 7. ROUTER BLOCK DRIFT
# ───────────────────────────────────────────────────────────────

# Edit one table signal cell and leave the generated block stale
sed 's/| mapping, category, which account, trap |/| mapping, category, which account, traps |/' "$(copy)" >"$TMP_ROOT/m-signal-drift.md"
drift_mutant "table signal changed without regeneration" "$TMP_ROOT/m-signal-drift.md" "row T2"

# Hand edit one line inside the generated block
sed 's/raise ValueError("local markdown only")/raise ValueError("markdown only")/' "$(copy)" >"$TMP_ROOT/m-hand-edit.md"
mutant "hand edit inside the router block" "$TMP_ROOT/m-hand-edit.md"

# Drop one multi-word table signal from the intent list
python3 - "$GRAPH_METADATA" "$TMP_ROOT/m-intent.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["intent_signals"] = [signal for signal in data["intent_signals"] if signal != "migration phase"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
metadata_mutant "intent signal missing from the list" "$TMP_ROOT/m-intent.json"

# Drop one curated advisor signal from the intent list
python3 - "$GRAPH_METADATA" "$TMP_ROOT/m-curated.json" <<'PY'
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
metadata_drift_mutant "curated advisor signal missing from the list" "$TMP_ROOT/m-curated.json" "help me review a dutch sole trader yearly close"

# ───────────────────────────────────────────────────────────────
# 8. WRITE MODE STABILITY
# ───────────────────────────────────────────────────────────────

# Build a throwaway skill copy that holds the script, the markdown, the
# metadata and the reference tree the write mode guards
WRITE_COPY="$TMP_ROOT/write-copy"
mkdir -p "$WRITE_COPY/scripts"
cp "$CHECKER" "$WRITE_COPY/scripts/check-route-table.py"
cp "$SKILL_MD" "$WRITE_COPY/SKILL.md"
cp "$GRAPH_METADATA" "$WRITE_COPY/graph-metadata.json"
cp -R "$SKILL_DIR/references" "$WRITE_COPY/references"

# Seed one table change so the first write has work to do in both files
sed 's/| mapping, category, which account, trap |/| mapping, category, which account, mapping trap |/' "$WRITE_COPY/SKILL.md" >"$TMP_ROOT/write-seed.md"
cp "$TMP_ROOT/write-seed.md" "$WRITE_COPY/SKILL.md"

python3 -I "$WRITE_COPY/scripts/check-route-table.py" --write >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]] && grep -qF "router block: written" "$TMP_ROOT/out.txt" && grep -qF "intent signals: added 1" "$TMP_ROOT/out.txt"; then
    pass "a table change regenerates the block and the signal list"
else
    fail "a table change regenerates the block and the signal list"
    cat "$TMP_ROOT/out.txt"
fi
first_skill=$(cksum "$WRITE_COPY/SKILL.md")
first_metadata=$(cksum "$WRITE_COPY/graph-metadata.json")

python3 -I "$WRITE_COPY/scripts/check-route-table.py" --write >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "second write in a temp copy exits 0"
else
    fail "second write in a temp copy exits 0"
fi
second_skill=$(cksum "$WRITE_COPY/SKILL.md")
second_metadata=$(cksum "$WRITE_COPY/graph-metadata.json")
if [[ "$first_skill" == "$second_skill" && "$first_metadata" == "$second_metadata" ]]; then
    pass "a second write leaves both files byte-identical"
else
    fail "a second write leaves both files byte-identical"
fi

# ───────────────────────────────────────────────────────────────
# 9. WORD CHECK ENFORCEMENT
# ───────────────────────────────────────────────────────────────

# The check runs the sibling word check, so this mutant lives in a throwaway
# repository copy and the real tree stays untouched
WORD_COPY="$TMP_ROOT/word-copy"
mkdir -p "$WORD_COPY/sk-moneybird-accountant/scripts" "$WORD_COPY/cli-moneybird" "$WORD_COPY/cli-jortt"
cp "$CHECKER" "$WORD_COPY/sk-moneybird-accountant/scripts/check-route-table.py"
cp "$WORD_CHECKER" "$WORD_COPY/sk-moneybird-accountant/scripts/check-skill-words.py"
cp "$SKILL_MD" "$WORD_COPY/sk-moneybird-accountant/SKILL.md"
cp "$GRAPH_METADATA" "$WORD_COPY/sk-moneybird-accountant/graph-metadata.json"
cp -R "$SKILL_DIR/references" "$WORD_COPY/sk-moneybird-accountant/references"
cp -R "$SKILL_DIR/assets" "$WORD_COPY/sk-moneybird-accountant/assets"
cp "$REPO_ROOT/cli-moneybird/SKILL.md" "$WORD_COPY/cli-moneybird/SKILL.md"
cp "$REPO_ROOT/cli-jortt/SKILL.md" "$WORD_COPY/cli-jortt/SKILL.md"
WORD_CHECKER_COPY="$WORD_COPY/sk-moneybird-accountant/scripts/check-route-table.py"

# The untouched copy proves the word check is wired and passes on its own
python3 -I "$WORD_CHECKER_COPY" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'check-skill-words: ' "$TMP_ROOT/out.txt"; then
    pass "the repository copy runs the word check and passes"
else
    fail "the repository copy runs the word check and passes"
    cat "$TMP_ROOT/out.txt"
fi

# Grow one sibling SKILL.md past the hard ceiling, so only the word check fails
python3 -I - "$WORD_COPY/cli-jortt/SKILL.md" <<'PY'
import sys

with open(sys.argv[1], "a", encoding="utf-8") as handle:
    handle.write("\n" + "\n".join(["word"] * 1700) + "\n")
PY

python3 -I "$WORD_CHECKER_COPY" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'check-skill-words: cli-jortt/SKILL.md' "$TMP_ROOT/out.txt" \
    && grep -qF 'fail above 4,000' "$TMP_ROOT/out.txt"; then
    pass "a SKILL.md above the hard ceiling fails the route table check"
else
    fail "a SKILL.md above the hard ceiling fails the route table check"
    cat "$TMP_ROOT/out.txt"
fi

# ───────────────────────────────────────────────────────────────
# 10. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
