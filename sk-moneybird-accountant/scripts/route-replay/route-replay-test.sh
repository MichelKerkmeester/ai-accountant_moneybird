#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE REPLAY TEST
# ───────────────────────────────────────────────────────────────
# Tests route-replay.py resolve mode on a temp copy of the skill.
# Usage: route-replay-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, missing skill files or a missing encoding cache
#
# WHY: the harness is only trustworthy when a clean corpus passes, a deleted
# routed path stops the run and a broken twin or an injected date changes
# nothing about the numbers. This suite proves each of those on a copy, so the
# real skill tree stays untouched.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$(dirname "$SCRIPT_DIR")")
HARNESS="$SCRIPT_DIR/route-replay.py"
CORPUS="$SCRIPT_DIR/routing-gold.json"

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: route-replay-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi
REPO_SRC=$(dirname "$(dirname "$SKILL_SRC")")
if [[ ! -f "$HARNESS" ]]; then
    printf 'error: missing route-replay.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$CORPUS" ]]; then
    printf 'error: missing routing-gold.json next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_SRC/SKILL.md" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. ENCODING CACHE
# ───────────────────────────────────────────────────────────────

CACHE_DIR="${TIKTOKEN_CACHE_DIR:-}"
if [[ -z "$CACHE_DIR" ]]; then
    for candidate in "$REPO_SRC/../tiktoken-cache" "$REPO_SRC/tiktoken-cache" "$HOME/.cache/tiktoken"; do
        if [[ -d "$candidate" ]]; then
            CACHE_DIR=$(cd "$candidate" && pwd -P)
            break
        fi
    done
fi
if [[ -z "$CACHE_DIR" || ! -d "$CACHE_DIR" ]]; then
    printf 'error: no encoding cache. Set TIKTOKEN_CACHE_DIR to the pinned cache folder.\n' >&2
    exit 2
fi
export TIKTOKEN_CACHE_DIR="$CACHE_DIR"

# ───────────────────────────────────────────────────────────────
# 3. TEMP COPY AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/route-replay-test.XXXXXX") || exit 2
COPY="$TMP_ROOT/sk-moneybird-accountant"
cp -R "$SKILL_SRC" "$COPY" || exit 2
COPY_HARNESS="$COPY/scripts/route-replay/route-replay.py"
COPY_CORPUS="$COPY/scripts/route-replay/routing-gold.json"

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS
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

# Run one command and compare its exit code with the expected one
# Args:
#   $1 - Check description
#   $2 - Expected exit code
#   $3... - Command and arguments to run
check_exit() {
    local description="$1"
    local expected="$2"
    shift 2
    "$@" >"$TMP_ROOT/last.log" 2>&1
    local status=$?
    if [[ "$status" -eq "$expected" ]]; then
        pass "$description"
    else
        fail "$description (exit $status, expected $expected)"
        sed -n '1,5p' "$TMP_ROOT/last.log"
    fi
}

# Run one command without a token cache and compare its exit code
# Args:
#   $1 - Check description
#   $2 - Expected exit code
#   $3... - Command and arguments to run
check_exit_no_cache() {
    local description="$1"
    local expected="$2"
    shift 2
    env TIKTOKEN_CACHE_DIR= "$@" >"$TMP_ROOT/last.log" 2>&1
    local status=$?
    if [[ "$status" -eq "$expected" ]]; then
        pass "$description"
    else
        fail "$description (exit $status, expected $expected)"
        sed -n '1,5p' "$TMP_ROOT/last.log"
    fi
}

# ───────────────────────────────────────────────────────────────
# 5. CLEAN RUN
# ───────────────────────────────────────────────────────────────

OUT_CLEAN="$TMP_ROOT/out-clean"
check_exit "the clean corpus resolves with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_CLEAN"

if [[ -f "$OUT_CLEAN/results.csv" ]]; then
    pass "the clean run writes results.csv"
else
    fail "the clean run writes results.csv"
fi
if [[ -f "$OUT_CLEAN/report.md" ]]; then
    pass "the clean run writes report.md"
else
    fail "the clean run writes report.md"
fi

if grep -q '^scenario_id,lang,split,gold_mode,gold_task_type,score,verdict,reason,tokens_loaded$' "$OUT_CLEAN/results.csv" 2>/dev/null; then
    pass "results.csv carries the fixed column order"
else
    fail "results.csv carries the fixed column order"
fi
if grep -q '^- held-out route accuracy:' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md carries a held-out accuracy line"
else
    fail "report.md carries a held-out accuracy line"
fi
if grep -q '^\- Dutch parity:' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md carries the Dutch parity result"
else
    fail "report.md carries the Dutch parity result"
fi
if grep -q 'Answer quality: unscored' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md marks answer quality as unscored"
else
    fail "report.md marks answer quality as unscored"
fi

FROZEN_FLOOR="$(sed -n 's/^- `FALLBACK_FLOOR = \([0-9.]*\)`, frozen on the calibration split\.$/\1/p' "$COPY/SKILL.md")"
if [[ -n "$FROZEN_FLOOR" ]] && grep -q "Fallback floor: $FROZEN_FLOOR\." "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "the report states the frozen fallback floor"
else
    fail "the report states the frozen fallback floor"
fi
if grep -q 'Fallback floor: calibration: pending' "$OUT_CLEAN/report.md" 2>/dev/null; then
    fail "the report leaves the fallback floor pending"
else
    pass "the report leaves the fallback floor pending"
fi

# ───────────────────────────────────────────────────────────────
# 6. DATED RUNS
# ───────────────────────────────────────────────────────────────

OUT_DATED_A="$TMP_ROOT/out-dated-a"
OUT_DATED_B="$TMP_ROOT/out-dated-b"
SOURCE_DATE_EPOCH=111 python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_DATED_A" >"$TMP_ROOT/last.log" 2>&1
status_a=$?
SOURCE_DATE_EPOCH=222 python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_DATED_B" >"$TMP_ROOT/last.log" 2>&1
status_b=$?
if [[ "$status_a" -eq 0 && "$status_b" -eq 0 ]]; then
    pass "two dated runs both exit 0"
else
    fail "two dated runs both exit 0 (exit $status_a and $status_b)"
fi
if cmp -s "$OUT_DATED_A/results.csv" "$OUT_DATED_B/results.csv"; then
    pass "two dated runs give byte-identical results.csv"
else
    fail "two dated runs give byte-identical results.csv"
fi
if cmp -s "$OUT_DATED_A/report.md" "$OUT_DATED_B/report.md"; then
    pass "two dated runs give byte-identical report.md"
else
    fail "two dated runs give byte-identical report.md"
fi

# ───────────────────────────────────────────────────────────────
# 7. CORPUS AND CACHE REFUSALS
# ───────────────────────────────────────────────────────────────

printf '{"rows": []}' >"$TMP_ROOT/empty.json"
check_exit "an empty corpus exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$TMP_ROOT/empty.json" --out "$TMP_ROOT/out-empty"

check_exit_no_cache "a missing encoding cache exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-nocache"

# ───────────────────────────────────────────────────────────────
# 8. DELETED ROUTED PATH
# ───────────────────────────────────────────────────────────────

DELETED="$COPY/references/purchase-invoices.md"
mv "$DELETED" "$TMP_ROOT/purchase-invoices.bak"
check_exit "a deleted routed path exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-deleted"
if grep -q 'missing routed path: references/purchase-invoices.md' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the connectivity gate names the missing path"
else
    fail "the connectivity gate names the missing path"
fi
mv "$TMP_ROOT/purchase-invoices.bak" "$DELETED"

# ───────────────────────────────────────────────────────────────
# 9. TWIN MISMATCH
# ───────────────────────────────────────────────────────────────

python3 - "$COPY_CORPUS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("parityOf"):
        row["gold_task_type"] = "T6"
        break
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a twin mismatch exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-twin"
if grep -q 'parity mismatch' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the twin mismatch names the pair"
else
    fail "the twin mismatch names the pair"
fi

# ───────────────────────────────────────────────────────────────
# 9B. FILE CLAIMS
# ───────────────────────────────────────────────────────────────

# A claim the revision cannot meet fails the row, never the whole run
CLAIMS_CORPUS="$TMP_ROOT/claims-gold.json"
cp "$CORPUS" "$CLAIMS_CORPUS" || exit 2
python3 - "$CLAIMS_CORPUS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("expected_claims"):
        row["expected_claims"][0]["text"] = "claim that no scored file holds"
        break
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a claim the revision does not meet exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$CLAIMS_CORPUS" --out "$TMP_ROOT/out-claims"
if grep -q 'claims not met' "$TMP_ROOT/out-claims/results.csv" 2>/dev/null; then
    pass "the unmet claim names the claim"
else
    fail "the unmet claim names the claim"
fi

# ───────────────────────────────────────────────────────────────
# 10. REPLAY MODE
# ───────────────────────────────────────────────────────────────

# A run-owned copy keeps the source corpus untouched
REPLAY_CORPUS="$TMP_ROOT/replay-gold.json"
cp "$CORPUS" "$REPLAY_CORPUS" || exit 2
REPO_ROOT="$(dirname "$SKILL_SRC")"
GUARD="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/moneybird-guard"
STUB="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/tests/stub-moneybird-cli"
OUT_REPLAY="$TMP_ROOT/out-replay"

check_exit "the refusal and hostile rows replay with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --out "$OUT_REPLAY"

if grep -q '^scenario_id,lang,split,gold_mode,gold_task_type,score,verdict,reason,tokens_loaded,command,expected_exit,actual_exit$' "$OUT_REPLAY/results.csv" 2>/dev/null; then
    pass "the replay results.csv carries the command and exit columns"
else
    fail "the replay results.csv carries the command and exit columns"
fi

# Every refusal row must return the exit code the corpus records
if python3 - "$OUT_REPLAY/results.csv" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
bad = [row["scenario_id"] for row in rows if row["expected_exit"] != row["actual_exit"]]
if bad:
    print("exit mismatch: %s" % ", ".join(bad))
    raise SystemExit(1)
if len(rows) < 31:
    print("only %d replay rows" % len(rows))
    raise SystemExit(1)
print("%d replay rows return their recorded exit code" % len(rows))
PY
then
    pass "every refusal row returns its recorded exit code"
else
    fail "every refusal row returns its recorded exit code"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

if grep -q '^HOSTILE-H1,' "$OUT_REPLAY/results.csv" 2>/dev/null && [[ "$(grep -c '^HOSTILE-' "$OUT_REPLAY/results.csv" || true)" -eq 22 ]]; then
    pass "all 22 hostile invoice cases replay"
else
    fail "all 22 hostile invoice cases replay"
fi

# A stub path that does not exist is a usage error, never a pass
check_exit "a broken stub path exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$TMP_ROOT/no-such-stub" --out "$TMP_ROOT/out-broken"
if grep -q 'stub not found' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the broken stub path is named"
else
    fail "the broken stub path is named"
fi

# Replay needs no ambient credential, proxy or cache variable
env -i PATH="$PATH" HOME="$TMP_ROOT/home" python3 -I "$COPY_HARNESS" --mode replay \
    --corpus "$REPLAY_CORPUS" --guard "$GUARD" --stub "$STUB" --out "$TMP_ROOT/out-cleared" \
    >"$TMP_ROOT/last.log" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "replay passes in a cleared environment with no network variables"
else
    fail "replay passes in a cleared environment with no network variables (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

# A covers filter keeps only the tagged rows
OUT_COVERS="$TMP_ROOT/out-covers"
check_exit "a covers filter scores the tagged replay rows" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --covers 006/REQ-002 --out "$OUT_COVERS"
if [[ "$(grep -c '^REFUSE-9-' "$OUT_COVERS/results.csv" 2>/dev/null || true)" -eq 2 ]] && \
   [[ "$(grep -vc '^scenario_id' "$OUT_COVERS/results.csv" 2>/dev/null || true)" -eq 2 ]]; then
    pass "the covers filter keeps exactly the tagged rows"
else
    fail "the covers filter keeps exactly the tagged rows"
fi
check_exit "an unknown covers value exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --covers 999/REQ-999 --out "$TMP_ROOT/out-unknown"

# A row whose recorded exit no longer matches fails the run
python3 - "$REPLAY_CORPUS" "$TMP_ROOT/replay-mutant.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("id") == "REFUSE-3-01":
        row["expected_exit"] = 8
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a wrong expected exit fails the replay" 1 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$TMP_ROOT/replay-mutant.json" \
    --guard "$GUARD" --stub "$STUB" --out "$TMP_ROOT/out-mutant"
if grep -q 'REFUSE-3-01' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the wrong expected exit names the row"
else
    fail "the wrong expected exit names the row"
fi

# A revision run scores the worktree of that commit and removes it again
check_exit "a revision run scores the worktree of HEAD" 0 \
    python3 -I "$HARNESS" --mode resolve --rev HEAD --corpus "$CORPUS" --out "$TMP_ROOT/out-rev"

# ───────────────────────────────────────────────────────────────
# 11. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
