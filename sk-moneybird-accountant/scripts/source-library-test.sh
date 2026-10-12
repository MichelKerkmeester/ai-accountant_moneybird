#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE LIBRARY TEST
# ───────────────────────────────────────────────────────────────
# Tests build-source-library.py against fixture repositories and the real one.
# Usage: source-library-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the index is only trustworthy when --check catches every drift and a
# rewrite never drops a recorded access result. This suite proves both.
# WHY: the link check and the trace run against a fixture server on 127.0.0.1,
# so the suite never touches the network.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND SKILL VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: source-library-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

BUILDER="$SKILL_SRC/scripts/build-source-library.py"
if [[ ! -f "$BUILDER" ]]; then
    printf 'error: missing scripts/build-source-library.py in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/source-library-test.XXXXXX") || exit 2
SERVER_PID=""

# Stop the fixture server and remove the temp root on exit
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS AND FIXTURE BUILDERS
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

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Run a command as a check and record whether it passes
# Args:
#   $1 - Check description
#   $2... - Command and arguments to run
assert() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Build a fixture repository with the builder and a few cited sources
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fake_repo() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references" "$root/cli-jortt" "$root/cli-moneybird" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nSee https://www.belastingdienst.nl/a and ![b](https://img.shields.io/x).\n' \
        >"$root/AGENTS.md" || return 1
    printf '# Rules\n\nThe [VAT page](https://www.belastingdienst.nl/b). Token: https://app.jortt.nl/oauth.\n' \
        >"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf '# Guide\n\nhttps://example.org/only-in-guide\n' \
        >"$root/sk-moneybird-accountant/references/source-library.md" || return 1
    return 0
}

# Run the builder inside a fixture repository
# Args:
#   $1 - Repository root
#   $2... - Extra builder arguments
# Returns:
#   The builder exit status, with output in $TMP_ROOT/out.txt
run_builder() {
    local root="$1"
    shift
    python3 -I "$root/sk-moneybird-accountant/scripts/build-source-library.py" "$@" >"$TMP_ROOT/out.txt" 2>&1
}

# Print one field of one indexed source
# Args:
#   $1 - Repository root
#   $2 - Source URL
#   $3 - Field name
# Returns:
#   0, printing the value or an empty line
index_field() {
    python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["sources"]}
print(rows.get(sys.argv[2], {}).get(sys.argv[3], ""))
' "$1/sk-moneybird-accountant/assets/source-library.json" "$2" "$3" 2>/dev/null
}

# Record an access result for one indexed source in a fixture index
# Args:
#   $1 - Repository root
#   $2 - Source URL
#   $3 - Access value
#   $4 - HTTP status or - for none
#   $5 - Check date or - for none
# Returns:
#   0 when the index was updated, 1 when it fails
set_index_access() {
    python3 -I - "$1/sk-moneybird-accountant/assets/source-library.json" "$2" "$3" "$4" "$5" <<'PY'
import json
import sys

path, url, access, status, checked_on = sys.argv[1:6]
data = json.load(open(path))
for row in data["sources"]:
    if row["url"] == url:
        row["access"] = access
        row["http_status"] = None if status == "-" else int(status)
        row["checked_on"] = None if checked_on == "-" else checked_on
open(path, "w").write(json.dumps(data))
PY
}

# Print one field of one row of the last link report
# Args:
#   $1 - Source URL
#   $2 - Field name
# Returns:
#   0, printing the value or an empty line
link_field() {
    python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["rows"]}
print(rows.get(sys.argv[2], {}).get(sys.argv[3], ""))
' "$TMP_ROOT/out.txt" "$1" "$2" 2>/dev/null
}

# Print one counter of the last link report
# Args:
#   $1 - Summary key
# Returns:
#   0, printing the value or an empty line
link_summary() {
    python3 -I -c '
import json, sys
print(json.load(open(sys.argv[1]))["summary"].get(sys.argv[2], ""))
' "$TMP_ROOT/out.txt" "$1" 2>/dev/null
}

# Wait until a TCP port on 127.0.0.1 accepts a connection
# Args:
#   $1 - Port number
# Returns:
#   0 when the port answers, 1 when it never does
wait_for_port() {
    python3 -I - "$1" <<'PY'
import socket
import sys
import time

for _ in range(100):
    try:
        with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=0.5):
            sys.exit(0)
    except OSError:
        time.sleep(0.1)
sys.exit(1)
PY
}

# Start a fixture server on a free local port and record that port
# Args:
#   $1 - Document root to serve
# Returns:
#   0 when the server answers, 1 when it does not start
start_fixture_server() {
    local docroot="$1" waited=0
    python3 -I - "$docroot" "$TMP_ROOT/agent.log" >"$TMP_ROOT/server.port" 2>"$TMP_ROOT/server.err" <<'PY' &
import functools
import http.server
import socketserver
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    """Serve the document root, one redirecting path and one logged path."""

    def do_GET(self):
        """Answer a redirect, log the user agent, then serve the file."""
        if self.path == "/redirect.html":
            self.send_response(302)
            self.send_header("Location", "/live.html")
            self.end_headers()
            return
        if self.path == "/loop-a.html":
            self.send_response(302)
            self.send_header("Location", "/loop-b.html")
            self.end_headers()
            return
        if self.path == "/loop-b.html":
            self.send_response(302)
            self.send_header("Location", "/loop-a.html")
            self.end_headers()
            return
        if self.path == "/no-location.html":
            self.send_response(302)
            self.end_headers()
            return
        if self.path == "/moved.html":
            self.send_response(301)
            self.send_header("Location", "/missing.html")
            self.end_headers()
            return
        if self.path == "/agent.html":
            with open(sys.argv[2], "a", encoding="utf-8") as handle:
                handle.write("%s\n" % self.headers.get("User-Agent", ""))
        super().do_GET()

    def log_message(self, fmt, *args):
        """Keep the fixture server quiet."""


class Server(socketserver.TCPServer):
    allow_reuse_address = True


handler = functools.partial(Handler, directory=sys.argv[1])
server = Server(("127.0.0.1", 0), handler)
print(server.server_address[1], flush=True)
server.serve_forever()
PY
    SERVER_PID=$!
    while [[ ! -s "$TMP_ROOT/server.port" ]]; do
        if [[ "$waited" -ge 100 ]]; then
            return 1
        fi
        sleep 0.1
        waited=$((waited + 1))
    done
    wait_for_port "$(cat "$TMP_ROOT/server.port")"
}

# Build a fixture repository whose citations point at the fixture server
# Args:
#   $1 - Repository root to create
#   $2 - Port the fixture server listens on
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_link_repo() {
    local root="$1" port="$2" number
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nLive page: http://127.0.0.1:%s/live.html\nDead page: http://127.0.0.1:%s/missing.html\n' \
        "$port" "$port" >"$root/AGENTS.md" || return 1
    printf 'Redirect page: http://127.0.0.1:%s/redirect.html\nAgent page: http://127.0.0.1:%s/agent.html\n' \
        "$port" "$port" >"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf 'Loop page: http://127.0.0.1:%s/loop-a.html\nNo location page: http://127.0.0.1:%s/no-location.html\nMoved page: http://127.0.0.1:%s/moved.html\n' \
        "$port" "$port" "$port" >>"$root/sk-moneybird-accountant/references/rules.md" || return 1
    {
        for number in 1 2 3 4 5 6 7 8 9 10; do
            printf 'Endpoint %s: https://api.jortt.nl/endpoint-%s\n' "$number" "$number"
        done
    } >>"$root/sk-moneybird-accountant/references/rules.md" || return 1
    return 0
}

# ───────────────────────────────────────────────────────────────
# 5. CHECKS
# ───────────────────────────────────────────────────────────────

REPO="$TMP_ROOT/repo"
INDEX="$REPO/sk-moneybird-accountant/assets/source-library.json"

group "write"
if make_fake_repo "$REPO"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
assert "write exits 0" run_builder "$REPO"
assert "index is valid JSON" python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$INDEX"
assert "cited page is indexed" grep -q 'belastingdienst.nl/a"' "$INDEX"
assert "badge is not indexed" bash -c "! grep -q img.shields.io '$INDEX'"
assert "guide links are not scanned" bash -c "! grep -q only-in-guide '$INDEX'"
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b title)" = "VAT page" ]]; then
    pass "link text becomes the title"
else
    fail "link text becomes the title"
fi
if [[ "$(index_field "$REPO" https://app.jortt.nl/oauth access)" = "endpoint" ]]; then
    pass "OAuth address is an endpoint"
else
    fail "OAuth address is an endpoint"
fi
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/a access)" = "unchecked" ]]; then
    pass "new source starts unchecked"
else
    fail "new source starts unchecked"
fi

group "check"
assert "check passes after a write" run_builder "$REPO" --check
printf '\nNew: https://wetten.overheid.nl/BWBR0000001\n' >>"$REPO/sk-moneybird-accountant/references/rules.md"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^missing: https://wetten.overheid.nl/BWBR0000001' "$TMP_ROOT/out.txt"; then
    pass "check reports a newly cited source"
else
    fail "check reports a newly cited source"
fi
run_builder "$REPO" >/dev/null
printf '# Bootstrap\n' >"$REPO/AGENTS.md"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^uncited: https://www.belastingdienst.nl/a' "$TMP_ROOT/out.txt"; then
    pass "check reports a source no file cites"
else
    fail "check reports a source no file cites"
fi
run_builder "$REPO" >/dev/null

group "access results"
python3 -I -c '
import json, sys
path = sys.argv[1]
data = json.load(open(path))
for row in data["sources"]:
    if row["url"] == "https://www.belastingdienst.nl/b":
        row.update(access="ok", http_status=200, checked_on="2026-01-01")
open(path, "w").write(json.dumps(data))
' "$INDEX"
assert "rewrite after a recorded check exits 0" run_builder "$REPO"
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b access)" = "ok" ]] \
    && [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b checked_on)" = "2026-01-01" ]]; then
    pass "rewrite keeps the recorded access result"
else
    fail "rewrite keeps the recorded access result"
fi
sed -i.bak 's/"access":"ok"/"access":"fine"/' "$INDEX"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q "^unknown access 'fine'" "$TMP_ROOT/out.txt"; then
    pass "check rejects an unknown access value"
else
    fail "check rejects an unknown access value"
fi

group "link check"
DOCROOT="$TMP_ROOT/docroot"
mkdir -p "$DOCROOT"
printf '<html><body>fixture live page</body></html>\n' >"$DOCROOT/live.html"
printf '<html><body>fixture agent page</body></html>\n' >"$DOCROOT/agent.html"
LINK_REPO="$TMP_ROOT/link-repo"
LINK_INDEX="$LINK_REPO/sk-moneybird-accountant/assets/source-library.json"
if start_fixture_server "$DOCROOT"; then
    pass "fixture server starts"
else
    fail "fixture server starts"
fi
PORT=$(cat "$TMP_ROOT/server.port" 2>/dev/null || true)
LIVE_URL="http://127.0.0.1:$PORT/live.html"
DEAD_URL="http://127.0.0.1:$PORT/missing.html"
REDIRECT_URL="http://127.0.0.1:$PORT/redirect.html"
AGENT_URL="http://127.0.0.1:$PORT/agent.html"
LOOP_URL="http://127.0.0.1:$PORT/loop-a.html"
NO_LOCATION_URL="http://127.0.0.1:$PORT/no-location.html"
MOVED_URL="http://127.0.0.1:$PORT/moved.html"
if make_link_repo "$LINK_REPO" "$PORT"; then
    pass "link fixture repository builds"
else
    fail "link fixture repository builds"
fi
assert "link fixture write exits 0" run_builder "$LINK_REPO"
cp "$LINK_INDEX" "$TMP_ROOT/index.before"
run_builder "$LINK_REPO" --check-links
status=$?
if [[ "$status" -eq 1 ]]; then
    pass "link check exits 1 on a dead page"
else
    fail "link check exits 1 on a dead page"
fi
if python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$TMP_ROOT/out.txt" 2>/dev/null; then
    pass "link report is valid JSON"
else
    fail "link report is valid JSON"
fi
if [[ "$(link_summary skipped)" = "10" ]] && [[ "$(link_summary endpoints_skipped)" = "10" ]]; then
    pass "link report skips 10 endpoint rows"
else
    fail "link report skips 10 endpoint rows"
fi
endpoint_check=$(python3 -I -c '
import json, sys
report = json.load(open(sys.argv[1]))
endpoints = [r for r in report["rows"] if r.get("recorded_access") == "endpoint"]
print(len(endpoints) == 10 and all(r["result"] == "skipped" for r in endpoints) and report["summary"]["failures"] == 4)
' "$TMP_ROOT/out.txt" 2>/dev/null)
if [[ "$endpoint_check" = "True" ]]; then
    pass "endpoint rows are never failures"
else
    fail "endpoint rows are never failures"
fi
cited_check=$(python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["rows"]}
print(rows[sys.argv[2]]["cited_by"] == ["AGENTS.md"])
' "$TMP_ROOT/out.txt" "$LIVE_URL" 2>/dev/null)
if [[ "$cited_check" = "True" ]]; then
    pass "link report names the citing file"
else
    fail "link report names the citing file"
fi
if [[ "$(link_field "$LIVE_URL" result)" = "ok" ]] && [[ "$(link_field "$LIVE_URL" http_status)" = "200" ]]; then
    pass "live page reports HTTP 200"
else
    fail "live page reports HTTP 200"
fi
if [[ "$(link_field "$DEAD_URL" result)" = "dead" ]] && [[ "$(link_field "$DEAD_URL" http_status)" = "404" ]]; then
    pass "dead page reports HTTP 404"
else
    fail "dead page reports HTTP 404"
fi
if [[ "$(link_field "$REDIRECT_URL" result)" = "ok" ]] \
    && [[ "$(link_field "$REDIRECT_URL" http_status)" = "200" ]]; then
    pass "redirected page reports its final status"
else
    fail "redirected page reports its final status"
fi
if [[ "$(link_field "$LOOP_URL" result)" = "redirect" ]] \
    && [[ "$(link_field "$LOOP_URL" http_status)" = "302" ]]; then
    pass "redirect loop is not ok"
else
    fail "redirect loop is not ok"
fi
if [[ "$(link_field "$NO_LOCATION_URL" result)" = "redirect" ]] \
    && [[ "$(link_field "$NO_LOCATION_URL" http_status)" = "302" ]]; then
    pass "302 without a location is not ok"
else
    fail "302 without a location is not ok"
fi
if [[ "$(link_field "$MOVED_URL" result)" = "dead" ]] \
    && [[ "$(link_field "$MOVED_URL" http_status)" = "404" ]]; then
    pass "301 to a missing page is not ok"
else
    fail "301 to a missing page is not ok"
fi
if [[ "$(link_summary redirects)" = "2" ]] && [[ "$(link_summary dead)" = "2" ]]; then
    pass "unfollowed redirects are counted apart from dead pages"
else
    fail "unfollowed redirects are counted apart from dead pages"
fi
if [[ "$(link_field "$AGENT_URL" result)" = "ok" ]] && grep -q '^Mozilla/5.0' "$TMP_ROOT/agent.log" 2>/dev/null; then
    pass "link check sends a browser-like user agent"
else
    fail "link check sends a browser-like user agent"
fi
if cmp -s "$LINK_INDEX" "$TMP_ROOT/index.before"; then
    pass "link check leaves the index unchanged"
else
    fail "link check leaves the index unchanged"
fi

group "trace"
run_builder "$LINK_REPO" --trace AGENTS.md:3
status=$?
if [[ "$status" -eq 1 ]] && grep -q 'access=unchecked' "$TMP_ROOT/out.txt"; then
    pass "trace fails on an unchecked row"
else
    fail "trace fails on an unchecked row"
fi
set_index_access "$LINK_REPO" "$LIVE_URL" ok 200 2026-01-01
set_index_access "$LINK_REPO" "$DEAD_URL" dead 404 2026-01-01
run_builder "$LINK_REPO" --trace AGENTS.md:3
status=$?
if [[ "$status" -eq 0 ]] && grep -q 'access=ok http_status=200 checked_on=2026-01-01' "$TMP_ROOT/out.txt"; then
    pass "trace passes on a live row"
else
    fail "trace passes on a live row"
fi
run_builder "$LINK_REPO" --trace AGENTS.md:4
status=$?
if [[ "$status" -eq 1 ]] && grep -q 'access=dead' "$TMP_ROOT/out.txt"; then
    pass "trace fails on a dead row"
else
    fail "trace fails on a dead row"
fi
printf 'Extra page: http://127.0.0.1:%s/extra.html\n' "$PORT" >>"$LINK_REPO/AGENTS.md"
run_builder "$LINK_REPO" --trace AGENTS.md:5
status=$?
if [[ "$status" -eq 1 ]] && grep -q 'access=missing' "$TMP_ROOT/out.txt"; then
    pass "trace fails on a URL outside the index"
else
    fail "trace fails on a URL outside the index"
fi
run_builder "$LINK_REPO" --trace AGENTS.md
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "trace rejects an argument without a line number"
else
    fail "trace rejects an argument without a line number"
fi

group "real skill"
assert "the skill's own index matches its sources" python3 -I "$BUILDER" --check

# ───────────────────────────────────────────────────────────────
# 6. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
