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
# WHY: the digest, the entity tag fingerprint, the watch report, the report
# writer, the dead and perishable checks and the calendar check each need their
# own fixture, so every case runs in a temp repository.
# WHY: the link check, the digest and the watch mode run against a fixture
# server on 127.0.0.1, so the suite never touches the network.
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
        "$root/sk-moneybird-accountant/references/tax-rules" "$root/cli-jortt" "$root/cli-moneybird" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nSee https://www.belastingdienst.nl/a and ![b](https://img.shields.io/x).\n' \
        >"$root/AGENTS.md" || return 1
    printf '# Rules\n\nThe [VAT page](https://www.belastingdienst.nl/b). Token: https://app.jortt.nl/oauth.\n' \
        >"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf '# Guide\n\nhttps://example.org/only-in-guide\n' \
        >"$root/sk-moneybird-accountant/references/tax-rules/source-library.md" || return 1
    return 0
}

# Build a fixture repository whose citation sits in a nested reference file
# The walk is depth-agnostic at the base commit, so this fixture guards that
# behavior instead of proving a fix.
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_nested_repo() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references/tax-rules/2025/vat" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nSee https://www.belastingdienst.nl/a.\n' >"$root/AGENTS.md" || return 1
    printf '# Figures\n\nRate: [deep page](https://wetten.overheid.nl/BWBR0000002)\n' \
        >"$root/sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md" || return 1
    printf '# Scope\n\nSee [scope page](https://wetten.overheid.nl/BWBR0000003)\n' \
        >"$root/sk-moneybird-accountant/references/tax-rules/2025/vat/scope.md" || return 1
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

# Print the exact index line that holds one URL
# Args:
#   $1 - Repository root
#   $2 - Source URL
# Returns:
#   0, printing the entry line or an empty line
index_row() {
    python3 -I - "$1/sk-moneybird-accountant/assets/source-library.json" "$2" <<'PY'
import json
import sys

needle = '"url":' + json.dumps(sys.argv[2], ensure_ascii=False)
with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        if needle in line:
            sys.stdout.write(line)
            break
PY
}

# Print one field of one URL entry in a watch state file
# Args:
#   $1 - State file
#   $2 - Source URL
#   $3 - Field name
# Returns:
#   0, printing the value or an empty line
state_field() {
    python3 -I -c '
import json, sys
value = json.load(open(sys.argv[1]))["urls"].get(sys.argv[2], {}).get(sys.argv[3])
print("" if value is None else value)
' "$1" "$2" "$3" 2>/dev/null
}

# Tell whether a state file is sorted, indented by two and newline terminated
# Args:
#   $1 - State file
# Returns:
#   0 when the bytes match the canonical form, 1 otherwise
state_is_stable() {
    python3 -I - "$1" <<'PY'
import json
import sys

text = open(sys.argv[1], encoding="utf-8").read()
data = json.loads(text)
sys.exit(0 if text == json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n" else 1)
PY
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

# Merge extra fields into one indexed source in a fixture index
# Args:
#   $1 - Repository root
#   $2 - Source URL
#   $3 - JSON object with the fields to merge
# Returns:
#   0 when the index was updated
set_index_fields() {
    python3 -I - "$1/sk-moneybird-accountant/assets/source-library.json" "$2" "$3" <<'PY'
import json
import sys

path, url, fields = sys.argv[1:4]
data = json.load(open(path))
for row in data["sources"]:
    if row["url"] == url:
        row.update(json.loads(fields))
open(path, "w").write(json.dumps(data))
PY
}

# Print the sha256 digest of one file's raw bytes
# Args:
#   $1 - File path
# Returns:
#   0, printing the hex digest
file_digest() {
    python3 -I -c '
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
' "$1"
}

# Tell whether every stored field of one index row survived a rewrite
# Args:
#   $1 - Repository root
#   $2 - Source URL
# Returns:
#   0 when every stored field is intact, 1 otherwise
keeps_stored_fields() {
    python3 -I - "$1/sk-moneybird-accountant/assets/source-library.json" "$2" <<'PY'
import json
import sys

path, url = sys.argv[1:3]
row = next(r for r in json.load(open(path))["sources"] if r["url"] == url)
wanted = {
    "access": "ok",
    "http_status": 200,
    "checked_on": "2026-01-02",
    "digest": "a" * 64,
    "retrieved_at": "2026-01-02",
    "etag": "etag-v1",
    "last_modified": "Mon, 01 Jan 2026 00:00:00 GMT",
    "kst_pending": "kst-37022-3",
}
sys.exit(0 if all(row.get(key) == value for key, value in wanted.items()) else 1)
PY
}

# Print one field of one row of a JSON report
# Args:
#   $1 - Report file
#   $2 - Source URL
#   $3 - Field name
# Returns:
#   0, printing the value or an empty line
report_field() {
    python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["rows"]}
print(rows.get(sys.argv[2], {}).get(sys.argv[3], "") or "")
' "$1" "$2" "$3" 2>/dev/null
}

# Print one field of one row of the last link report
# Args:
#   $1 - Source URL
#   $2 - Field name
# Returns:
#   0, printing the value or an empty line
link_field() {
    report_field "$TMP_ROOT/out.txt" "$1" "$2"
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

# Write a fixture markdown file whose frontmatter carries a checked_on date
# Args:
#   $1 - File path
#   $2 - ISO date, or - for no stamp
# Returns:
#   0 when the file was written
write_stamped_readme() {
    local path="$1" stamp="$2"
    mkdir -p "$(dirname "$path")" || return 1
    {
        printf '%s\n' '---'
        printf 'title: "Fixture file"\n'
        if [[ "$stamp" != "-" ]]; then
            printf 'checked_on: %s\n' "$stamp"
        fi
        printf '%s\n' '---' '' '# Fixture'
    } >"$path"
}

# Write a fixture rollover runbook with one row per checkpoint
# Args:
#   $1 - File path
# Returns:
#   0 when the file was written
write_runbook() {
    cat >"$1" <<'MD'
# Year rollover

| Checkpoint | Date | Refresh |
|---|---|---|
| Prinsjesdag | 2026-09-15 | Year files |
| Tweede Kamer vote | 2026-11-12 | Proposed rows |
| Eerste Kamer vote | 2026-12-15 | Proposed rows |
| December indexation | 2026-12-31 | Figures |
| February reconciliation | 2027-02-15 | Year files |
MD
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
import hashlib
import http.server
import os
import socketserver
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    """Serve the document root, a few redirecting paths and tagged files."""

    def do_GET(self):
        """Answer a redirect, tag a file, log the user agent, then serve."""
        if self.path.startswith("/tag/"):
            self.send_tagged(os.path.basename(self.path))
            return
        if self.path.startswith("/weak/"):
            self.send_weak_tagged(os.path.basename(self.path))
            return
        if self.path.startswith("/pdf/"):
            self.send_pdf(os.path.basename(self.path))
            return
        if self.path == "/redirect.html":
            self.send_response(302)
            self.send_header("Location", "/live.html")
            self.end_headers()
            return
        if self.path == "/permanent.html":
            self.send_response(308)
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
        if self.path == "/refused.html":
            self.send_error(403)
            return
        if self.path == "/throttled.html":
            self.send_error(429)
            return
        if self.path == "/error.html":
            self.send_error(500)
            return
        if self.path == "/agent.html":
            with open(sys.argv[2], "a", encoding="utf-8") as handle:
                handle.write("%s\n" % self.headers.get("User-Agent", ""))
        super().do_GET()

    def send_tagged(self, name):
        """Serve one document root file with an entity tag and a fixed date."""
        path = os.path.join(sys.argv[1], name)
        if not os.path.isfile(path):
            self.send_error(404)
            return
        with open(path, "rb") as handle:
            body = handle.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("ETag", '"%s"' % hashlib.sha256(body).hexdigest()[:16])
        self.send_header("Last-Modified", "Mon, 12 Oct 2026 00:00:00 GMT")
        self.end_headers()
        self.wfile.write(body)

    def send_weak_tagged(self, name):
        """Serve one page with a weak entity tag read from a sidecar file."""
        path = os.path.join(sys.argv[1], name)
        tag_path = path + ".tag"
        if not os.path.isfile(path) or not os.path.isfile(tag_path):
            self.send_error(404)
            return
        with open(path, "rb") as handle:
            body = handle.read()
        with open(tag_path, "r", encoding="utf-8") as handle:
            tag = handle.read().strip()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("ETag", 'W/"%s"' % tag)
        self.send_header("Last-Modified", "Mon, 12 Oct 2026 00:00:00 GMT")
        self.end_headers()
        self.wfile.write(body)

    def send_pdf(self, name):
        """Serve one document root file as an application/pdf response."""
        path = os.path.join(sys.argv[1], name)
        if not os.path.isfile(path):
            self.send_error(404)
            return
        with open(path, "rb") as handle:
            body = handle.read()
        self.send_response(200)
        self.send_header("Content-Type", "application/pdf")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

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
    printf 'Redirect page: http://127.0.0.1:%s/redirect.html\nPermanent redirect page: http://127.0.0.1:%s/permanent.html\nAgent page: http://127.0.0.1:%s/agent.html\n' \
        "$port" "$port" "$port" >"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf 'Loop page: http://127.0.0.1:%s/loop-a.html\nNo location page: http://127.0.0.1:%s/no-location.html\nMoved page: http://127.0.0.1:%s/moved.html\n' \
        "$port" "$port" "$port" >>"$root/sk-moneybird-accountant/references/rules.md" || return 1
    {
        for number in 1 2 3 4 5 6 7 8 9 10; do
            printf 'Endpoint %s: https://api.jortt.nl/endpoint-%s\n' "$number" "$number"
        done
    } >>"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf 'Tag page: http://127.0.0.1:%s/tag/tagged.html\nNorm A: http://127.0.0.1:%s/norm-a.html\nNorm B: http://127.0.0.1:%s/norm-b.html\nPdf page: http://127.0.0.1:%s/pdf/sample.pdf\n' \
        "$port" "$port" "$port" "$port" >>"$root/sk-moneybird-accountant/references/rules.md" || return 1
    return 0
}

# Build a fixture repository whose citations all point at the fixture server
# Args:
#   $1 - Repository root to create
#   $2 - Port the fixture server listens on
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_watch_repo() {
    local root="$1" port="$2"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references/tax-rules" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nLive page: http://127.0.0.1:%s/live.html\n' \
        "$port" >"$root/AGENTS.md" || return 1
    printf '# Alpha\n\nAlpha series: http://127.0.0.1:%s/tag/alpha.html\n' \
        "$port" >"$root/sk-moneybird-accountant/references/alpha.md" || return 1
    printf '# Beta\n\nBeta series: http://127.0.0.1:%s/tag/beta.html\n' \
        "$port" >"$root/sk-moneybird-accountant/references/beta.md" || return 1
    printf '# Guide\n\nhttp://127.0.0.1:%s/norm-a.html\n' \
        "$port" >"$root/sk-moneybird-accountant/references/tax-rules/source-library.md" || return 1
    return 0
}

# Build a fixture repository whose one citation points at one URL
# Args:
#   $1 - Repository root to create
#   $2 - URL to cite
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_single_url_repo() {
    local root="$1" url="$2"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nUnreachable page: %s\n' "$url" >"$root/AGENTS.md" || return 1
    return 0
}

# Build a fixture repository with the top-layer field set, one glossed figures
# file and one sourced term-map row
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_frontmatter_repo() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references/tax-rules/2025/vat" \
        "$root/cli-jortt" "$root/cli-moneybird" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    cat >"$root/AGENTS.md" <<'MD'
---
title: "Fixture bootstrap"
description: "Fixture bootstrap for the field-set cases."
nav_label: "Bootstrap"
---

# Fixture bootstrap
MD
    cat >"$root/cli-jortt/SKILL.md" <<'MD'
---
name: cli-jortt
description: Fixture Jortt skill.
allowed-tools: [Bash, Read]
version: 1.0.0.0
nav_label: "Jortt CLI"
---

# Jortt
MD
    cat >"$root/cli-moneybird/SKILL.md" <<'MD'
---
name: cli-moneybird
description: Fixture Moneybird skill.
allowed-tools: [Bash, Read]
version: 1.0.0.0
nav_label: "Moneybird CLI"
---

# Moneybird
MD
    cat >"$root/sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md" <<'MD'
---
title: "BTW 2025: Figures"
description: "Fixture VAT figures for the gloss cases."
nav_label: "BTW"
---

# BTW 2025: Figures

## 1. KEY FIGURES

<!-- GENERATED:key-figure-index:start -->
| Item | row |
|---|---|
| Aangifte (return) filing | 1 |
<!-- GENERATED:key-figure-index:end -->

| Item | Value | Status | Check | Source |
|---|---|---|---|---|
| Aangifte filing | 21% | enacted | Verified | https://www.belastingdienst.nl/a |
MD
    cat >"$root/sk-moneybird-accountant/assets/term-map.json" <<'MD'
{
  "generated_by": "sk-moneybird-accountant/assets/term-map.json",
  "terms": [
    {
      "gloss": "return",
      "source": "https://www.belastingdienst.nl/a",
      "source_file": "references/tax-rules/2025/vat/figures.md",
      "term": "Aangifte"
    }
  ]
}
MD
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

# Case: the guide's count table agrees with the index, and a stale cell fails
GUIDE_REPO="$TMP_ROOT/guide-repo"
cp -R "$REPO" "$GUIDE_REPO" || exit 2
GUIDE_FILE="$GUIDE_REPO/sk-moneybird-accountant/references/tax-rules/source-library.md"
cat >"$GUIDE_FILE" <<'MD'
| Measure | Count |
|---|---|
| Sources | 3 |
| Readable as a web page | 0 |
| Readable through WebFetch only | 0 |
| PDF, downloads but needs a PDF reader | 0 |
| Archive copy an agent cannot fetch | 0 |
| Dead link | 0 |
| Tool endpoint, not a source | 1 |
| Added after the last access check | 2 |
MD
assert "check passes when the guide count table matches the index" run_builder "$GUIDE_REPO" --check
sed -i.bak 's/| Sources | 3 |/| Sources | 4 |/' "$GUIDE_FILE"
run_builder "$GUIDE_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^guide count: Sources states 4 but the index holds 3' "$TMP_ROOT/out.txt"; then
    pass "check reports a guide count that disagrees with the index"
else
    fail "check reports a guide count that disagrees with the index"
fi
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

# WHY: the walk is depth-agnostic at the base commit, so the nested fixture
# guards that behavior instead of proving a fix.
group "nested walk"
NEST_REPO="$TMP_ROOT/nested-repo"
NEST_FILE="sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md"
NEST_TOPIC="sk-moneybird-accountant/references/tax-rules/2025/vat/"
NEST_URL="https://wetten.overheid.nl/BWBR0000002"
NEST_NOTE="sk-moneybird-accountant/references/tax-rules/2025/vat/scope.md"
NEST_NOTE_URL="https://wetten.overheid.nl/BWBR0000003"
if make_nested_repo "$NEST_REPO"; then
    pass "nested fixture repository builds"
else
    fail "nested fixture repository builds"
fi
assert "nested citation write exits 0" run_builder "$NEST_REPO"
nested_cited=$(python3 -I - "$NEST_REPO/sk-moneybird-accountant/assets/source-library.json" "$NEST_URL" "$NEST_TOPIC" <<'PY'
import json
import sys

rows = {row["url"]: row for row in json.load(open(sys.argv[1]))["sources"]}
print(rows.get(sys.argv[2], {}).get("cited_by") == [sys.argv[3]])
PY
)
if [[ "$nested_cited" = "True" ]]; then
    pass "a split part citation names its topic folder"
else
    fail "a split part citation names its topic folder"
fi
note_cited=$(python3 -I - "$NEST_REPO/sk-moneybird-accountant/assets/source-library.json" "$NEST_NOTE_URL" "$NEST_NOTE" <<'PY'
import json
import sys

rows = {row["url"]: row for row in json.load(open(sys.argv[1]))["sources"]}
print(rows.get(sys.argv[2], {}).get("cited_by") == [sys.argv[3]])
PY
)
if [[ "$note_cited" = "True" ]]; then
    pass "a nested citation outside the part names names its file"
else
    fail "a nested citation outside the part names names its file"
fi
assert "check passes on the nested fixture" run_builder "$NEST_REPO" --check
set_index_access "$NEST_REPO" "$NEST_URL" ok 200 2026-01-01
run_builder "$NEST_REPO" --trace "$NEST_FILE:3"
status=$?
if [[ "$status" -eq 0 ]] && grep -q 'access=ok http_status=200 checked_on=2026-01-01' "$TMP_ROOT/out.txt"; then
    pass "trace resolves a citation at depth"
else
    fail "trace resolves a citation at depth"
fi
set_index_access "$NEST_REPO" "$NEST_URL" dead 404 2026-01-01
run_builder "$NEST_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^dead cited: $NEST_URL cited by: $NEST_TOPIC" "$TMP_ROOT/out.txt"; then
    pass "a dead nested citation still exits 1"
else
    fail "a dead nested citation still exits 1"
fi
set_index_access "$NEST_REPO" "$NEST_URL" ok 200 2026-01-01
run_builder "$NEST_REPO" --trace "sk-moneybird-accountant/references/tax-rules/2025/vat/missing.md:1"
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'no such file in this repository' "$TMP_ROOT/out.txt"; then
    pass "trace rejects a missing nested file"
else
    fail "trace rejects a missing nested file"
fi
rm "$NEST_REPO/$NEST_FILE"
run_builder "$NEST_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q "^uncited: $NEST_URL" "$TMP_ROOT/out.txt"; then
    pass "a removed nested file leaves its source uncited"
else
    fail "a removed nested file leaves its source uncited"
fi

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
printf '<html><body>tagged fixture page</body></html>\n' >"$DOCROOT/tagged.html"
printf '<html><head><style>p{color:red}</style><script>var x=1;</script></head><body>Fiets <p>Fiets &amp; kar</p></body></html>\n' >"$DOCROOT/norm-a.html"
printf '<div>\n  Fiets\n  <span>Fiets</span>\n  <script>x()</script>\n  &amp; kar\n</div>\n' >"$DOCROOT/norm-b.html"
printf '<html><body>alpha fixture page</body></html>\n' >"$DOCROOT/alpha.html"
printf '<html><body>beta fixture page</body></html>\n' >"$DOCROOT/beta.html"
printf '<html><body>gamma fixture page</body></html>\n' >"$DOCROOT/gamma.html"
printf '<html><body>nested fixture page</body></html>\n' >"$DOCROOT/nested.html"
printf '%%PDF-1.4\nplaceholder fixture bytes\n%%%%EOF\n' >"$DOCROOT/sample.pdf"
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
NESTED_URL="http://127.0.0.1:$PORT/nested.html"
REDIRECT_URL="http://127.0.0.1:$PORT/redirect.html"
PERMANENT_URL="http://127.0.0.1:$PORT/permanent.html"
AGENT_URL="http://127.0.0.1:$PORT/agent.html"
LOOP_URL="http://127.0.0.1:$PORT/loop-a.html"
NO_LOCATION_URL="http://127.0.0.1:$PORT/no-location.html"
MOVED_URL="http://127.0.0.1:$PORT/moved.html"
TAG_URL="http://127.0.0.1:$PORT/tag/tagged.html"
NORM_A_URL="http://127.0.0.1:$PORT/norm-a.html"
NORM_B_URL="http://127.0.0.1:$PORT/norm-b.html"
PDF_URL="http://127.0.0.1:$PORT/pdf/sample.pdf"
if make_link_repo "$LINK_REPO" "$PORT"; then
    pass "link fixture repository builds"
else
    fail "link fixture repository builds"
fi
assert "link fixture write exits 0" run_builder "$LINK_REPO"
mkdir -p "$LINK_REPO/sk-moneybird-accountant/references/tax-rules/2025/vat"
printf '# Figures\n\nNested page: %s\n' "$NESTED_URL" >"$LINK_REPO/$NEST_FILE"
run_builder "$LINK_REPO" >/dev/null
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
nested_cited_check=$(python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["rows"]}
print(rows[sys.argv[2]]["cited_by"] == [sys.argv[3]])
' "$TMP_ROOT/out.txt" "$NESTED_URL" "$NEST_TOPIC" 2>/dev/null)
if [[ "$nested_cited_check" = "True" ]]; then
    pass "link report names a split part by its topic folder"
else
    fail "link report names a split part by its topic folder"
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
if [[ "$(link_field "$PERMANENT_URL" result)" = "ok" ]] \
    && [[ "$(link_field "$PERMANENT_URL" http_status)" = "200" ]]; then
    pass "a 308 redirect reports its final 200"
else
    fail "a 308 redirect reports its final 200"
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

group "blocked"
BLOCKED_REPO="$TMP_ROOT/blocked-repo"
REFUSED_URL="http://127.0.0.1:$PORT/refused.html"
THROTTLED_URL="http://127.0.0.1:$PORT/throttled.html"
if make_single_url_repo "$BLOCKED_REPO" "$REFUSED_URL"; then
    pass "blocked fixture repository builds"
else
    fail "blocked fixture repository builds"
fi
run_builder "$BLOCKED_REPO" >/dev/null
run_builder "$BLOCKED_REPO" --check-links
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(link_summary blocked)" = "1" ]] \
    && [[ "$(link_summary failures)" = "0" ]] \
    && [[ "$(link_field "$REFUSED_URL" result)" = "blocked" ]] \
    && [[ "$(link_field "$REFUSED_URL" http_status)" = "403" ]]; then
    pass "a refused page reports blocked and does not fail"
else
    fail "a refused page reports blocked and does not fail"
fi
printf '# Bootstrap\n\nThrottled page: %s\n' "$THROTTLED_URL" >"$BLOCKED_REPO/AGENTS.md"
run_builder "$BLOCKED_REPO" >/dev/null
run_builder "$BLOCKED_REPO" --check-links
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(link_summary blocked)" = "1" ]] \
    && [[ "$(link_summary failures)" = "0" ]] \
    && [[ "$(link_field "$THROTTLED_URL" result)" = "blocked" ]] \
    && [[ "$(link_field "$THROTTLED_URL" http_status)" = "429" ]]; then
    pass "a throttled page reports blocked and does not fail"
else
    fail "a throttled page reports blocked and does not fail"
fi
printf '# Bootstrap\n\nMissing page: %s\n' "$DEAD_URL" >"$BLOCKED_REPO/AGENTS.md"
run_builder "$BLOCKED_REPO" >/dev/null
run_builder "$BLOCKED_REPO" --check-links
status=$?
if [[ "$status" -eq 1 ]] \
    && [[ "$(link_summary blocked)" = "0" ]] \
    && [[ "$(link_summary failures)" = "1" ]] \
    && [[ "$(link_field "$DEAD_URL" result)" = "dead" ]] \
    && [[ "$(link_field "$DEAD_URL" http_status)" = "404" ]]; then
    pass "a 404 page still fails"
else
    fail "a 404 page still fails"
fi
printf '# Bootstrap\n\nThrottled page: %s\n' "$THROTTLED_URL" >"$BLOCKED_REPO/AGENTS.md"
run_builder "$BLOCKED_REPO" >/dev/null
BLOCKED_DIGEST=$(python3 -I -c 'print("b" * 64)')
BLOCKED_ETAG=$(python3 -I -c 'print("c" * 64)')
set_index_fields "$BLOCKED_REPO" "$THROTTLED_URL" \
    "{\"access\":\"ok\",\"http_status\":200,\"checked_on\":\"2026-01-02\",\"digest\":\"$BLOCKED_DIGEST\",\"retrieved_at\":\"2026-01-02\",\"etag\":\"$BLOCKED_ETAG\",\"last_modified\":\"Mon, 01 Jan 2026 00:00:00 GMT\"}"
# WHY: the builder writes one canonical line per row, so a rebuild puts the
# fixture row in that form before the before-and-after byte comparison.
run_builder "$BLOCKED_REPO" >/dev/null
BLOCKED_ROW_BEFORE=$(index_row "$BLOCKED_REPO" "$THROTTLED_URL")
run_builder "$BLOCKED_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/blocked-report.json"
run_builder "$BLOCKED_REPO" --apply-report "$TMP_ROOT/blocked-report.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && grep -q '^0 rows updated' "$TMP_ROOT/out.txt" \
    && grep -q '^1 blocked rows left unchanged' "$TMP_ROOT/out.txt" \
    && [[ -n "$BLOCKED_ROW_BEFORE" ]] \
    && [[ "$(index_row "$BLOCKED_REPO" "$THROTTLED_URL")" = "$BLOCKED_ROW_BEFORE" ]]; then
    pass "apply report leaves a blocked row byte-for-byte unchanged"
else
    fail "apply report leaves a blocked row byte-for-byte unchanged"
fi
printf '# Bootstrap\n\nLive page: %s\nThrottled page: %s\n' "$LIVE_URL" "$THROTTLED_URL" >"$BLOCKED_REPO/AGENTS.md"
run_builder "$BLOCKED_REPO" >/dev/null
set_index_access "$BLOCKED_REPO" "$LIVE_URL" ok 200 2026-01-02
run_builder "$BLOCKED_REPO" >/dev/null
BLOCKED_ROW_BEFORE=$(index_row "$BLOCKED_REPO" "$THROTTLED_URL")
run_builder "$BLOCKED_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/blocked-mixed-report.json"
run_builder "$BLOCKED_REPO" --apply-report "$TMP_ROOT/blocked-mixed-report.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && grep -q '^1 rows updated' "$TMP_ROOT/out.txt" \
    && grep -q '^1 blocked rows left unchanged' "$TMP_ROOT/out.txt" \
    && [[ "$(index_field "$BLOCKED_REPO" "$LIVE_URL" checked_on)" = "$(date +%Y-%m-%d)" ]] \
    && [[ "$(index_field "$BLOCKED_REPO" "$LIVE_URL" digest)" = "$(report_field "$TMP_ROOT/blocked-mixed-report.json" "$LIVE_URL" digest)" ]] \
    && [[ "$(index_row "$BLOCKED_REPO" "$THROTTLED_URL")" = "$BLOCKED_ROW_BEFORE" ]]; then
    pass "a mixed report updates the live row and leaves the blocked row unchanged"
else
    fail "a mixed report updates the live row and leaves the blocked row unchanged"
fi

group "known unfetchable"
ERROR_REPO="$TMP_ROOT/error-repo"
ERROR_URL="http://127.0.0.1:1/unreachable.html"
if make_single_url_repo "$ERROR_REPO" "$ERROR_URL"; then
    pass "error fixture repository builds"
else
    fail "error fixture repository builds"
fi
run_builder "$ERROR_REPO" >/dev/null
set_index_access "$ERROR_REPO" "$ERROR_URL" archive-not-fetchable - -
run_builder "$ERROR_REPO" --check-links
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(link_summary known_unfetchable)" = "1" ]] \
    && [[ "$(link_summary failures)" = "0" ]] \
    && [[ "$(link_field "$ERROR_URL" result)" = "error" ]]; then
    pass "an erroring archive-not-fetchable row is known, not a failure"
else
    fail "an erroring archive-not-fetchable row is known, not a failure"
fi
set_index_access "$ERROR_REPO" "$ERROR_URL" ok 200 2026-01-01
run_builder "$ERROR_REPO" --check-links
status=$?
if [[ "$status" -eq 1 ]] \
    && [[ "$(link_summary failures)" = "1" ]] \
    && [[ "$(link_summary known_unfetchable)" = "0" ]]; then
    pass "an erroring ok row still fails"
else
    fail "an erroring ok row still fails"
fi
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/error-report.json"
run_builder "$ERROR_REPO" >/dev/null
ERROR_ROW_BEFORE=$(index_row "$ERROR_REPO" "$ERROR_URL")
run_builder "$ERROR_REPO" --apply-report "$TMP_ROOT/error-report.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && grep -q '^0 rows updated' "$TMP_ROOT/out.txt" \
    && grep -q '^1 unreachable rows left unchanged' "$TMP_ROOT/out.txt" \
    && [[ -n "$ERROR_ROW_BEFORE" ]] \
    && [[ "$(index_row "$ERROR_REPO" "$ERROR_URL")" = "$ERROR_ROW_BEFORE" ]]; then
    pass "apply report leaves a transport error row byte-for-byte unchanged"
else
    fail "apply report leaves a transport error row byte-for-byte unchanged"
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
TRACE_REPO="$TMP_ROOT/trace-repo"
TRACE_URL="https://www.belastingdienst.nl/a?ref=query-value#section"
if make_single_url_repo "$TRACE_REPO" "$TRACE_URL"; then
    pass "trace guard fixture repository builds"
else
    fail "trace guard fixture repository builds"
fi
run_builder "$TRACE_REPO" >/dev/null
set_index_access "$TRACE_REPO" "$TRACE_URL" ok 200 2026-01-01
printf 'TOKEN=1\nSee https://example.org/private-env\n' >"$TRACE_REPO/.env"
printf 'a\nSee https://example.org/unscanned-text\n' >"$TRACE_REPO/notes.txt"
mkdir -p "$TRACE_REPO/docs"
printf 'a\nSee https://example.org/unscanned-doc\n' >"$TRACE_REPO/docs/other.md"
ln -s ../../.env "$TRACE_REPO/sk-moneybird-accountant/references/linked.md"
run_builder "$TRACE_REPO" --trace .env:2
status=$?
if [[ "$status" -eq 2 ]] \
    && grep -q 'refused, that path is private' "$TMP_ROOT/out.txt" \
    && ! grep -q 'private-env' "$TMP_ROOT/out.txt"; then
    pass "trace refuses a credential file and prints none of it"
else
    fail "trace refuses a credential file and prints none of it"
fi
run_builder "$TRACE_REPO" --trace sk-moneybird-accountant/references/linked.md:2
status=$?
if [[ "$status" -eq 2 ]] \
    && grep -q 'refused, that path is private' "$TMP_ROOT/out.txt" \
    && ! grep -q 'private-env' "$TMP_ROOT/out.txt"; then
    pass "trace refuses a scanned name that links to a credential file"
else
    fail "trace refuses a scanned name that links to a credential file"
fi
run_builder "$TRACE_REPO" --trace notes.txt:2
status=$?
if [[ "$status" -eq 2 ]] \
    && grep -q 'among the scanned markdown files' "$TMP_ROOT/out.txt" \
    && ! grep -q 'unscanned-text' "$TMP_ROOT/out.txt"; then
    pass "trace refuses a file the scan does not read"
else
    fail "trace refuses a file the scan does not read"
fi
run_builder "$TRACE_REPO" --trace docs/other.md:2
status=$?
if [[ "$status" -eq 2 ]] \
    && grep -q 'among the scanned markdown files' "$TMP_ROOT/out.txt" \
    && ! grep -q 'unscanned-doc' "$TMP_ROOT/out.txt"; then
    pass "trace refuses a markdown file outside the scan roots"
else
    fail "trace refuses a markdown file outside the scan roots"
fi
run_builder "$TRACE_REPO" --trace AGENTS.md:3
status=$?
if [[ "$status" -eq 0 ]] \
    && grep -q '^https://www.belastingdienst.nl/a access=ok http_status=200 checked_on=2026-01-01$' "$TMP_ROOT/out.txt" \
    && ! grep -q 'query-value' "$TMP_ROOT/out.txt"; then
    pass "trace prints a URL without its query string and fragment"
else
    fail "trace prints a URL without its query string and fragment"
fi

group "digest"
run_builder "$LINK_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/report-1.json"
if [[ "$(report_field "$TMP_ROOT/report-1.json" "$LIVE_URL" digest)" =~ ^[0-9a-f]{64}$ ]]; then
    pass "a readable URL carries a sha256 digest"
else
    fail "a readable URL carries a sha256 digest"
fi
if [[ "$(report_field "$TMP_ROOT/report-1.json" "$LIVE_URL" retrieved_at)" = "$(date +%Y-%m-%d)" ]]; then
    pass "a readable URL carries its retrieval date"
else
    fail "a readable URL carries its retrieval date"
fi
if [[ "$(report_field "$TMP_ROOT/report-1.json" "$NORM_A_URL" digest)" = "$(report_field "$TMP_ROOT/report-1.json" "$NORM_B_URL" digest)" ]]; then
    pass "normalisation ignores tags, scripts and whitespace runs"
else
    fail "normalisation ignores tags, scripts and whitespace runs"
fi
if [[ -n "$(report_field "$TMP_ROOT/report-1.json" "$TAG_URL" etag)" ]] \
    && [[ -n "$(report_field "$TMP_ROOT/report-1.json" "$LIVE_URL" last_modified)" ]]; then
    pass "the report carries the entity tag and the last modification date"
else
    fail "the report carries the entity tag and the last modification date"
fi
if [[ -z "$(report_field "$TMP_ROOT/report-1.json" "$DEAD_URL" digest)" ]]; then
    pass "a dead page carries no digest"
else
    fail "a dead page carries no digest"
fi
UNCHANGED_DIGEST=$(report_field "$TMP_ROOT/report-1.json" "$NORM_A_URL" digest)
CHANGED_BEFORE=$(report_field "$TMP_ROOT/report-1.json" "$NORM_B_URL" digest)
printf '<div>\n  Fiets\n  <span>Fiets</span>\n  <script>x()</script>\n  en kar\n</div>\n' >"$DOCROOT/norm-b.html"
run_builder "$LINK_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/report-2.json"
if [[ "$(report_field "$TMP_ROOT/report-2.json" "$NORM_B_URL" digest)" != "$CHANGED_BEFORE" ]]; then
    pass "changed page text changes the digest"
else
    fail "changed page text changes the digest"
fi
if [[ "$(report_field "$TMP_ROOT/report-2.json" "$NORM_A_URL" digest)" = "$UNCHANGED_DIGEST" ]]; then
    pass "unchanged page text keeps the digest"
else
    fail "unchanged page text keeps the digest"
fi

# WHY: a PDF digest must cover the raw bytes, so the fixture holds real line
# breaks that page normalisation would collapse. The expected value comes from
# the same bytes the fixture server reads, not from the builder under test.
PDF_EXPECTED=$(file_digest "$DOCROOT/sample.pdf")
PDF_CONTENT_TYPE=$(python3 -I - "$PDF_URL" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=10) as response:
    print(response.headers.get("Content-Type", ""))
PY
)
if [[ "$PDF_CONTENT_TYPE" = "application/pdf" ]]; then
    pass "the fixture server serves the PDF fixture as application/pdf"
else
    fail "the fixture server serves the PDF fixture as application/pdf"
fi
if [[ "$(report_field "$TMP_ROOT/report-1.json" "$PDF_URL" digest)" = "$PDF_EXPECTED" ]]; then
    pass "a PDF response carries the sha256 of its raw bytes"
else
    fail "a PDF response carries the sha256 of its raw bytes"
fi
if [[ -n "$(report_field "$TMP_ROOT/report-1.json" "$PDF_URL" digest)" ]] \
    && [[ "$(report_field "$TMP_ROOT/report-1.json" "$PDF_URL" digest)" = "$(report_field "$TMP_ROOT/report-2.json" "$PDF_URL" digest)" ]]; then
    pass "the same PDF bytes give the same digest twice"
else
    fail "the same PDF bytes give the same digest twice"
fi
PDF_DIGEST_BEFORE=$(report_field "$TMP_ROOT/report-2.json" "$PDF_URL" digest)
# WHY: one flipped bit is the smallest byte change, so the next report must
# carry a different digest for the same address.
python3 -I - "$DOCROOT/sample.pdf" <<'PY'
import sys

path = sys.argv[1]
data = bytearray(open(path, "rb").read())
data[0] = data[0] ^ 0x01
open(path, "wb").write(data)
PY
run_builder "$LINK_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/report-3.json"
PDF_AFTER_EXPECTED=$(file_digest "$DOCROOT/sample.pdf")
PDF_DIGEST_AFTER=$(report_field "$TMP_ROOT/report-3.json" "$PDF_URL" digest)
if [[ "$PDF_DIGEST_AFTER" = "$PDF_AFTER_EXPECTED" ]] \
    && [[ "$PDF_DIGEST_AFTER" != "$PDF_DIGEST_BEFORE" ]]; then
    pass "one changed PDF byte changes the digest"
else
    fail "one changed PDF byte changes the digest"
fi

group "apply report"
cp "$LINK_INDEX" "$TMP_ROOT/index.before-apply"
assert "apply report exits 0" run_builder "$LINK_REPO" --apply-report "$TMP_ROOT/report-2.json"
if [[ "$(index_field "$LINK_REPO" "$LIVE_URL" access)" = "ok" ]] \
    && [[ "$(index_field "$LINK_REPO" "$LIVE_URL" http_status)" = "200" ]] \
    && [[ "$(index_field "$LINK_REPO" "$LIVE_URL" checked_on)" = "$(date +%Y-%m-%d)" ]]; then
    pass "apply report writes the access result, the status and the check date"
else
    fail "apply report writes the access result, the status and the check date"
fi
if [[ "$(index_field "$LINK_REPO" "$LIVE_URL" digest)" = "$(report_field "$TMP_ROOT/report-2.json" "$LIVE_URL" digest)" ]] \
    && [[ "$(index_field "$LINK_REPO" "$LIVE_URL" retrieved_at)" = "$(date +%Y-%m-%d)" ]]; then
    pass "apply report writes the digest and the retrieval date"
else
    fail "apply report writes the digest and the retrieval date"
fi
if [[ "$(index_field "$LINK_REPO" "$TAG_URL" etag)" = "$(report_field "$TMP_ROOT/report-2.json" "$TAG_URL" etag)" ]] \
    && [[ -n "$(index_field "$LINK_REPO" "$TAG_URL" etag)" ]] \
    && [[ -n "$(index_field "$LINK_REPO" "$LIVE_URL" last_modified)" ]]; then
    pass "apply report writes the entity tag and the last modification date"
else
    fail "apply report writes the entity tag and the last modification date"
fi
if [[ "$(index_field "$LINK_REPO" "$DEAD_URL" access)" = "dead" ]]; then
    pass "apply report records a dead answer"
else
    fail "apply report records a dead answer"
fi
if [[ "$(index_field "$LINK_REPO" https://api.jortt.nl/endpoint-1 access)" = "endpoint" ]] \
    && [[ "$(index_field "$LINK_REPO" https://api.jortt.nl/endpoint-1 http_status)" = "None" ]]; then
    pass "apply report leaves an endpoint row alone"
else
    fail "apply report leaves an endpoint row alone"
fi
cp "$LINK_INDEX" "$TMP_ROOT/index.applied"
run_builder "$LINK_REPO" --apply-report "$TMP_ROOT/report-2.json"
if cmp -s "$LINK_INDEX" "$TMP_ROOT/index.applied"; then
    pass "a second apply report changes nothing"
else
    fail "a second apply report changes nothing"
fi
run_builder "$LINK_REPO" --apply-report "$TMP_ROOT/no-such-report.json"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "apply report rejects a missing report"
else
    fail "apply report rejects a missing report"
fi
printf 'not a report\n' >"$TMP_ROOT/broken-report.json"
run_builder "$LINK_REPO" --apply-report "$TMP_ROOT/broken-report.json"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "apply report rejects a broken report"
else
    fail "apply report rejects a broken report"
fi

group "stored fields"
FIELD_REPO="$TMP_ROOT/field-repo"
FIELD_URL="https://www.belastingdienst.nl/b"
if make_fake_repo "$FIELD_REPO"; then
    pass "field fixture repository builds"
else
    fail "field fixture repository builds"
fi
run_builder "$FIELD_REPO" >/dev/null
set_index_fields "$FIELD_REPO" "$FIELD_URL" \
    '{"access":"ok","http_status":200,"checked_on":"2026-01-02","digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","retrieved_at":"2026-01-02","etag":"etag-v1","last_modified":"Mon, 01 Jan 2026 00:00:00 GMT","kst_pending":"kst-37022-3"}'
assert "rewrite with stored fields exits 0" run_builder "$FIELD_REPO"
if keeps_stored_fields "$FIELD_REPO" "$FIELD_URL"; then
    pass "a rebuild keeps every stored field"
else
    fail "a rebuild keeps every stored field"
fi
sed 's/if stored_value is not None:/if False:/' "$BUILDER" \
    >"$FIELD_REPO/sk-moneybird-accountant/scripts/build-source-library.py"
run_builder "$FIELD_REPO" >/dev/null
if keeps_stored_fields "$FIELD_REPO" "$FIELD_URL"; then
    fail "a builder that drops stored digests fails the preservation check"
else
    pass "a builder that drops stored digests fails the preservation check"
fi
if [[ -z "$(index_field "$FIELD_REPO" "$FIELD_URL" digest)" ]]; then
    pass "the mutant drops the stored digest"
else
    fail "the mutant drops the stored digest"
fi

group "dead and perishable"
CHECK_REPO="$TMP_ROOT/check-repo"
PERISHABLE_URL="https://www.tweedekamer.nl/downloads/document?id=2026D99999"
if make_fake_repo "$CHECK_REPO"; then
    pass "check fixture repository builds"
else
    fail "check fixture repository builds"
fi
run_builder "$CHECK_REPO" >/dev/null
printf 'Belastingplan 2027: %s\n' "$PERISHABLE_URL" \
    >>"$CHECK_REPO/sk-moneybird-accountant/references/rules.md"
run_builder "$CHECK_REPO" >/dev/null
PERISHABLE_LINE=$(grep -n 'tweedekamer.nl/downloads/document?id=2026D99999' \
    "$CHECK_REPO/sk-moneybird-accountant/references/rules.md" | cut -d: -f1)
run_builder "$CHECK_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^perishable: sk-moneybird-accountant/references/rules.md:$PERISHABLE_LINE $PERISHABLE_URL" "$TMP_ROOT/out.txt"; then
    pass "check fails on a perishable Tweede Kamer citation"
else
    fail "check fails on a perishable Tweede Kamer citation"
fi
set_index_fields "$CHECK_REPO" "$PERISHABLE_URL" '{"kst_pending":"kst-37022-3"}'
run_builder "$CHECK_REPO" >/dev/null
assert "a pending kst marker lets the citation pass" run_builder "$CHECK_REPO" --check
set_index_access "$CHECK_REPO" "https://www.belastingdienst.nl/a" dead 404 2026-01-01
run_builder "$CHECK_REPO" >/dev/null
run_builder "$CHECK_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^dead cited: https://www.belastingdienst.nl/a cited by: AGENTS.md' "$TMP_ROOT/out.txt" \
    && ! grep -q '^differs:' "$TMP_ROOT/out.txt"; then
    pass "check fails on a cited dead row and names its citing files"
else
    fail "check fails on a cited dead row and names its citing files"
fi

group "watch"
WATCH_REPO="$TMP_ROOT/watch-repo"
ALPHA_URL="http://127.0.0.1:$PORT/tag/alpha.html"
BETA_URL="http://127.0.0.1:$PORT/tag/beta.html"
GAMMA_URL="http://127.0.0.1:$PORT/tag/gamma.html"
DELTA_URL="http://127.0.0.1:1/delta.html"
EPSILON_URL="http://127.0.0.1:$PORT/tag/epsilon.html"
ZETA_URL="http://127.0.0.1:$PORT/error.html"
if make_watch_repo "$WATCH_REPO" "$PORT"; then
    pass "watch fixture repository builds"
else
    fail "watch fixture repository builds"
fi
python3 -I - "$WATCH_REPO/sk-moneybird-accountant/assets/source-watchlist.json" \
    "$ALPHA_URL" "$BETA_URL" "$GAMMA_URL" "$DELTA_URL" "$EPSILON_URL" "$ZETA_URL" "$REFUSED_URL" <<'PY'
import json
import sys

path, alpha, beta, gamma, delta, epsilon, zeta, refused = sys.argv[1:9]
series = [
    {"series": "Alpha series", "urls": [alpha], "cadence": "monthly", "why": "fixture alpha"},
    {"series": "Beta series", "urls": [beta], "cadence": "yearly", "why": "fixture beta"},
    {"series": "Gamma series", "urls": [gamma], "cadence": "on-publication", "why": "fixture gamma"},
    {"series": "Delta series", "urls": [delta], "cadence": "monthly", "why": "fixture delta"},
    {"series": "Epsilon series", "urls": [epsilon], "cadence": "monthly", "why": "fixture epsilon"},
    {"series": "Zeta series", "urls": [zeta], "cadence": "yearly", "why": "fixture zeta"},
    {"series": "Refused series", "urls": [refused], "cadence": "monthly", "why": "fixture refusal"},
]
open(path, "w").write(json.dumps(series, indent=2) + "\n")
PY
run_builder "$WATCH_REPO" >/dev/null
run_builder "$WATCH_REPO" --check-links
status=$?
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/watch-report.json"
assert "watch fixture report is valid JSON" python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$TMP_ROOT/watch-report.json"
if [[ "$status" -eq 0 ]]; then
    pass "watch fixture link check finds no failure"
else
    fail "watch fixture link check finds no failure"
fi
run_builder "$WATCH_REPO" --apply-report "$TMP_ROOT/watch-report.json"
run_builder "$WATCH_REPO" --watch
status=$?
if [[ "$status" -eq 0 ]] \
    && ! grep -q '^changed ' "$TMP_ROOT/out.txt" \
    && grep -q '^failed series=Delta series' "$TMP_ROOT/out.txt"; then
    pass "watch exits 0 with nothing changed and reports a failed fetch"
else
    fail "watch exits 0 with nothing changed and reports a failed fetch"
fi
if ! grep -q 'Gamma series' "$TMP_ROOT/out.txt"; then
    pass "a watched URL with no stored values stays silent"
else
    fail "a watched URL with no stored values stays silent"
fi
if grep -q "^blocked series=Refused series url=$REFUSED_URL status=403" "$TMP_ROOT/out.txt"; then
    pass "a refused watched URL is reported as blocked"
else
    fail "a refused watched URL is reported as blocked"
fi
python3 -I - "$TMP_ROOT/refused-state.json" "$REFUSED_URL" "$BLOCKED_DIGEST" <<'PY'
import json
import sys

json.dump(
    {"urls": {sys.argv[2]: {
        "http_status": 200,
        "etag": None,
        "last_modified": None,
        "digest": sys.argv[3],
        "retrieved_at": "2026-01-02",
    }}},
    open(sys.argv[1], "w"),
)
PY
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/refused-state.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && ! grep -q '^changed ' "$TMP_ROOT/out.txt" \
    && [[ "$(state_field "$TMP_ROOT/refused-state.json" "$REFUSED_URL" http_status)" = "200" ]] \
    && [[ "$(state_field "$TMP_ROOT/refused-state.json" "$REFUSED_URL" digest)" = "$BLOCKED_DIGEST" ]]; then
    pass "a refused watched URL keeps its stored state and reports no change"
else
    fail "a refused watched URL keeps its stored state and reports no change"
fi
printf '<html><body>alpha fixture page, second version</body></html>\n' >"$DOCROOT/alpha.html"
run_builder "$WATCH_REPO" --watch
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^changed series=Alpha series url=$ALPHA_URL reason=.*digest changed cited by: sk-moneybird-accountant/references/alpha.md" "$TMP_ROOT/out.txt"; then
    pass "a changed series is reported with its URL and citing file"
else
    fail "a changed series is reported with its URL and citing file"
fi
if ! grep -q 'Beta series' "$TMP_ROOT/out.txt"; then
    pass "an unchanged series stays silent"
else
    fail "an unchanged series stays silent"
fi
run_builder "$WATCH_REPO" --check-links
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/watch-report-2.json"
run_builder "$WATCH_REPO" --apply-report "$TMP_ROOT/watch-report-2.json"
python3 -I - "$TMP_ROOT/watch-state.json" "$GAMMA_URL" <<'PY'
import json
import sys

json.dump(
    {"urls": {sys.argv[2]: {"http_status": 404, "etag": None, "last_modified": None, "digest": None}}},
    open(sys.argv[1], "w"),
)
PY
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/watch-state.json"
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^changed series=Gamma series url=$GAMMA_URL reason=answers 200 after 404 cited by: -" "$TMP_ROOT/out.txt"; then
    pass "a URL that newly answers 200 after 404 counts as changed"
else
    fail "a URL that newly answers 200 after 404 counts as changed"
fi
STATE_DIGEST=$(python3 -I -c '
import json, sys
print(json.load(open(sys.argv[1]))["urls"][sys.argv[2]]["digest"])
' "$TMP_ROOT/watch-state.json" "$GAMMA_URL" 2>/dev/null)
if [[ "$STATE_DIGEST" =~ ^[0-9a-f]{64}$ ]]; then
    pass "the watch state file stores the fresh digest"
else
    fail "the watch state file stores the fresh digest"
fi
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/watch-state.json"
status=$?
if [[ "$status" -eq 0 ]] && ! grep -q '^changed ' "$TMP_ROOT/out.txt"; then
    pass "a second watch run from the state file reports no change"
else
    fail "a second watch run from the state file reports no change"
fi
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/epsilon-state.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(state_field "$TMP_ROOT/epsilon-state.json" "$EPSILON_URL" http_status)" = "404" ]] \
    && [[ -z "$(state_field "$TMP_ROOT/epsilon-state.json" "$EPSILON_URL" digest)" ]]; then
    pass "a watched URL that answers 404 is recorded with its status"
else
    fail "a watched URL that answers 404 is recorded with its status"
fi
if [[ "$(state_field "$TMP_ROOT/epsilon-state.json" "$ZETA_URL" http_status)" = "500" ]]; then
    pass "a watched URL that answers 500 is recorded with its status"
else
    fail "a watched URL that answers 500 is recorded with its status"
fi
assert "the state file is sorted and ends with a newline" state_is_stable "$TMP_ROOT/epsilon-state.json"
printf '<html><body>epsilon fixture page</body></html>\n' >"$DOCROOT/epsilon.html"
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/epsilon-state.json"
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^changed series=Epsilon series url=$EPSILON_URL reason=answers 200 after 404" "$TMP_ROOT/out.txt"; then
    pass "a recorded 404 that answers 200 is reported as changed"
else
    fail "a recorded 404 that answers 200 is reported as changed"
fi
EPSILON_DIGEST=$(state_field "$TMP_ROOT/epsilon-state.json" "$EPSILON_URL" digest)
if [[ "$EPSILON_DIGEST" =~ ^[0-9a-f]{64}$ ]]; then
    pass "the 200 answer stores a fresh digest"
else
    fail "the 200 answer stores a fresh digest"
fi
rm -f "$DOCROOT/epsilon.html"
run_builder "$WATCH_REPO" --watch --state "$TMP_ROOT/epsilon-state.json"
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(state_field "$TMP_ROOT/epsilon-state.json" "$EPSILON_URL" http_status)" = "404" ]] \
    && [[ "$(state_field "$TMP_ROOT/epsilon-state.json" "$EPSILON_URL" digest)" = "$EPSILON_DIGEST" ]]; then
    pass "a later 404 keeps the stored digest"
else
    fail "a later 404 keeps the stored digest"
fi
DEFAULT_STATE="$WATCH_REPO/sk-moneybird-accountant/assets/source-watch-state.json"
cp "$TMP_ROOT/epsilon-state.json" "$DEFAULT_STATE"
cp "$DEFAULT_STATE" "$TMP_ROOT/default-state.before"
printf '<html><body>epsilon fixture page, second version</body></html>\n' >"$DOCROOT/epsilon.html"
run_builder "$WATCH_REPO" --watch
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^changed series=Epsilon series url=$EPSILON_URL reason=answers 200 after 404" "$TMP_ROOT/out.txt" \
    && cmp -s "$DEFAULT_STATE" "$TMP_ROOT/default-state.before"; then
    pass "watch reads the default state file and never writes it"
else
    fail "watch reads the default state file and never writes it"
fi
rm -f "$DEFAULT_STATE" "$DOCROOT/epsilon.html"
run_builder "$WATCH_REPO" --watch
status=$?
if [[ "$status" -eq 0 ]] && [[ ! -e "$DEFAULT_STATE" ]]; then
    pass "watch without a state file and no default still works"
else
    fail "watch without a state file and no default still works"
fi
run_builder "$WATCH_REPO" --check --watch
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "watch refuses to run with --check"
else
    fail "watch refuses to run with --check"
fi
run_builder "$WATCH_REPO" --state "$TMP_ROOT/watch-state.json"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a state file without watch is a usage error"
else
    fail "a state file without watch is a usage error"
fi
OUTAGE_REPO="$TMP_ROOT/outage-repo"
if make_watch_repo "$OUTAGE_REPO" "$PORT"; then
    pass "outage fixture repository builds"
else
    fail "outage fixture repository builds"
fi
python3 -I - "$OUTAGE_REPO/sk-moneybird-accountant/assets/source-watchlist.json" \
    "$DELTA_URL" "$REFUSED_URL" <<'PY'
import json
import sys

path, delta, refused = sys.argv[1:4]
series = [
    {"series": "Delta series", "urls": [delta], "cadence": "monthly", "why": "fixture delta"},
    {"series": "Refused series", "urls": [refused], "cadence": "monthly", "why": "fixture refusal"},
]
open(path, "w").write(json.dumps(series, indent=2) + "\n")
PY
run_builder "$OUTAGE_REPO" --watch
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^the watch could not check 2 of 2 watched URLs$' "$TMP_ROOT/out.txt" \
    && ! grep -q '^no watched URL changed' "$TMP_ROOT/out.txt"; then
    pass "a watch where every URL failed or was blocked exits 1"
else
    fail "a watch where every URL failed or was blocked exits 1"
fi
python3 -I - "$OUTAGE_REPO/sk-moneybird-accountant/assets/source-watchlist.json" \
    "$DELTA_URL" "$ALPHA_URL" <<'PY'
import json
import sys

path, delta, alpha = sys.argv[1:4]
series = [
    {"series": "Delta series", "urls": [delta], "cadence": "monthly", "why": "fixture delta"},
    {"series": "Alpha series", "urls": [alpha], "cadence": "monthly", "why": "fixture alpha"},
]
open(path, "w").write(json.dumps(series, indent=2) + "\n")
PY
run_builder "$OUTAGE_REPO" --watch
status=$?
if [[ "$status" -eq 0 ]] \
    && ! grep -q 'could not check' "$TMP_ROOT/out.txt" \
    && grep -q '^no watched URL changed' "$TMP_ROOT/out.txt"; then
    pass "a watch with one answering URL beside a failed one still exits 0"
else
    fail "a watch with one answering URL beside a failed one still exits 0"
fi

group "etag fingerprint"
# WHY: a server may send a weak tag holding a long digit run, and the gate
# refuses a committed digit run, so the fixture value is built at run time and
# must never reach a stored file.
DIGIT_TAG=$(printf '%s' 1 2 3 4 5 6 7 8 9 0)
WEAK_ETAG_RAW="W/\"$DIGIT_TAG\""
WEAK_ETAG_HASH=$(python3 -I -c '
import hashlib
import sys

print("sha256:" + hashlib.sha256(sys.argv[1].encode("utf-8")).hexdigest())
' "$WEAK_ETAG_RAW")
ETAG_REPO="$TMP_ROOT/etag-repo"
ETAG_INDEX="$ETAG_REPO/sk-moneybird-accountant/assets/source-library.json"
WEAK_URL="http://127.0.0.1:$PORT/weak/weak.html"
SPARE_URL="http://127.0.0.1:$PORT/weak/spare.html"
printf '<html><body>weak fixture page</body></html>\n' >"$DOCROOT/weak.html"
printf '%s' "$DIGIT_TAG" >"$DOCROOT/weak.html.tag"
printf '<html><body>spare fixture page</body></html>\n' >"$DOCROOT/spare.html"
printf '%s' "$DIGIT_TAG" >"$DOCROOT/spare.html.tag"
if make_single_url_repo "$ETAG_REPO" "$WEAK_URL"; then
    pass "etag fixture repository builds"
else
    fail "etag fixture repository builds"
fi
run_builder "$ETAG_REPO" >/dev/null
run_builder "$ETAG_REPO" --check-links
status=$?
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/etag-report.json"
if [[ "$status" -eq 0 ]] \
    && [[ "$(report_field "$TMP_ROOT/etag-report.json" "$WEAK_URL" result)" = "ok" ]]; then
    pass "the weak-tagged page answers 200"
else
    fail "the weak-tagged page answers 200"
fi
if [[ "$(report_field "$TMP_ROOT/etag-report.json" "$WEAK_URL" etag)" = "$WEAK_ETAG_HASH" ]] \
    && ! grep -Fq "$DIGIT_TAG" "$TMP_ROOT/etag-report.json"; then
    pass "the link report keeps the fingerprint and not the raw digit tag"
else
    fail "the link report keeps the fingerprint and not the raw digit tag"
fi
assert "the etag report applies to the index" run_builder "$ETAG_REPO" --apply-report "$TMP_ROOT/etag-report.json"
if [[ "$(index_field "$ETAG_REPO" "$WEAK_URL" etag)" = "$WEAK_ETAG_HASH" ]] \
    && ! grep -Fq "$DIGIT_TAG" "$ETAG_INDEX"; then
    pass "the index keeps the fingerprint and not the raw digit tag"
else
    fail "the index keeps the fingerprint and not the raw digit tag"
fi
python3 -I - "$ETAG_REPO/sk-moneybird-accountant/assets/source-watchlist.json" "$WEAK_URL" "$SPARE_URL" <<'PY'
import json
import sys

series = [
    {"series": "Weak series", "urls": [sys.argv[2]], "cadence": "monthly", "why": "fixture weak tag"},
    {"series": "Spare series", "urls": [sys.argv[3]], "cadence": "monthly", "why": "fixture old state"},
]
open(sys.argv[1], "w").write(json.dumps(series, indent=2) + "\n")
PY
run_builder "$ETAG_REPO" --watch --state "$TMP_ROOT/etag-state.json"
status=$?
if [[ "$status" -eq 0 ]] && ! grep -q '^changed ' "$TMP_ROOT/out.txt"; then
    pass "an unchanged entity tag stays silent"
else
    fail "an unchanged entity tag stays silent"
fi
if [[ "$(state_field "$TMP_ROOT/etag-state.json" "$WEAK_URL" etag)" = "$WEAK_ETAG_HASH" ]] \
    && ! grep -Fq "$DIGIT_TAG" "$TMP_ROOT/etag-state.json"; then
    pass "the watch state keeps the fingerprint and not the raw digit tag"
else
    fail "the watch state keeps the fingerprint and not the raw digit tag"
fi
OLD_ETAG_FIELDS=$(python3 -I -c '
import json
import sys

print(json.dumps({"etag": sys.argv[1]}))
' "$WEAK_ETAG_RAW")
set_index_fields "$ETAG_REPO" "$WEAK_URL" "$OLD_ETAG_FIELDS"
run_builder "$ETAG_REPO" --watch
status=$?
if [[ "$status" -eq 0 ]] && ! grep -q '^changed ' "$TMP_ROOT/out.txt"; then
    pass "a raw tag stored by an older index still compares"
else
    fail "a raw tag stored by an older index still compares"
fi
python3 -I - "$TMP_ROOT/etag-old-state.json" "$SPARE_URL" "$WEAK_ETAG_RAW" <<'PY'
import json
import sys

json.dump(
    {"urls": {sys.argv[2]: {"http_status": 200, "etag": sys.argv[3]}}},
    open(sys.argv[1], "w"),
)
PY
run_builder "$ETAG_REPO" --watch --state "$TMP_ROOT/etag-old-state.json"
status=$?
if [[ "$status" -eq 0 ]] && ! grep -q '^changed ' "$TMP_ROOT/out.txt"; then
    pass "a raw tag stored by an older state file still compares"
else
    fail "a raw tag stored by an older state file still compares"
fi
if [[ "$(state_field "$TMP_ROOT/etag-old-state.json" "$SPARE_URL" etag)" = "$WEAK_ETAG_HASH" ]] \
    && ! grep -Fq "$DIGIT_TAG" "$TMP_ROOT/etag-old-state.json"; then
    pass "a watch run rewrites an older raw state tag as a fingerprint"
else
    fail "a watch run rewrites an older raw state tag as a fingerprint"
fi
printf '%s' "$DIGIT_TAG$DIGIT_TAG" >"$DOCROOT/weak.html.tag"
run_builder "$ETAG_REPO" --watch
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q "^changed series=Weak series url=$WEAK_URL reason=etag changed cited by: AGENTS.md" "$TMP_ROOT/out.txt" \
    && ! grep -q 'digest changed' "$TMP_ROOT/out.txt"; then
    pass "a changed entity tag is reported"
else
    fail "a changed entity tag is reported"
fi

group "calendar"
CAL_REPO="$TMP_ROOT/cal-repo"
CAL_REF="$CAL_REPO/sk-moneybird-accountant/references/tax-rules"
if make_fake_repo "$CAL_REPO"; then
    pass "calendar fixture repository builds"
else
    fail "calendar fixture repository builds"
fi
write_stamped_readme "$CAL_REF/2026/README.md" 2026-01-01
write_stamped_readme "$CAL_REF/2020/README.md" 2020-01-01
write_stamped_readme "$CAL_REF/dutch-tax-rules.md" 2026-01-01
write_runbook "$CAL_REF/year-rollover.md"
run_builder "$CAL_REPO" --check-calendar --today 2026-10-12
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^stale: sk-moneybird-accountant/references/tax-rules/2026/README.md checked_on=2026-01-01 before checkpoint Prinsjesdag 2026-09-15' "$TMP_ROOT/out.txt" \
    && grep -q '^stale: sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md' "$TMP_ROOT/out.txt" \
    && ! grep -q '2020/README.md' "$TMP_ROOT/out.txt"; then
    pass "calendar fails on a stale current year and skips a past year"
else
    fail "calendar fails on a stale current year and skips a past year"
fi
write_stamped_readme "$CAL_REF/2026/README.md" 2026-10-01
write_stamped_readme "$CAL_REF/dutch-tax-rules.md" 2026-10-01
run_builder "$CAL_REPO" --check-calendar --today 2026-10-12
status=$?
if [[ "$status" -eq 0 ]] && ! grep -q '2020/README.md' "$TMP_ROOT/out.txt"; then
    pass "calendar passes on a fresh current year"
else
    fail "calendar passes on a fresh current year"
fi
run_builder "$CAL_REPO" --check-calendar --today 2026-12-20
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^stale: sk-moneybird-accountant/references/tax-rules/2026/README.md checked_on=2026-10-01 before checkpoint Eerste Kamer vote 2026-12-15' "$TMP_ROOT/out.txt"; then
    pass "calendar uses the latest checkpoint that has passed"
else
    fail "calendar uses the latest checkpoint that has passed"
fi
mv "$CAL_REF/year-rollover.md" "$TMP_ROOT/rollover.aside"
run_builder "$CAL_REPO" --check-calendar --today 2026-10-12
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "calendar exits 2 without the runbook"
else
    fail "calendar exits 2 without the runbook"
fi
printf '# Runbook\n\nNo checkpoint table here.\n' >"$CAL_REF/year-rollover.md"
run_builder "$CAL_REPO" --check-calendar --today 2026-10-12
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "calendar exits 2 without the checkpoint table"
else
    fail "calendar exits 2 without the checkpoint table"
fi
mv "$TMP_ROOT/rollover.aside" "$CAL_REF/year-rollover.md"
write_stamped_readme "$CAL_REF/2026/README.md" -
run_builder "$CAL_REPO" --check-calendar --today 2026-10-12
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -q '^missing: sk-moneybird-accountant/references/tax-rules/2026/README.md has no checked_on' "$TMP_ROOT/out.txt"; then
    pass "calendar fails on a file without a checked_on stamp"
else
    fail "calendar fails on a file without a checked_on stamp"
fi
run_builder "$CAL_REPO" --check-calendar --today 2026-13-45
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "calendar rejects a malformed date"
else
    fail "calendar rejects a malformed date"
fi
run_builder "$CAL_REPO" --today 2026-10-12
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a date without the calendar check is a usage error"
else
    fail "a date without the calendar check is a usage error"
fi

group "frontmatter and term-map field set"
FM_REPO="$TMP_ROOT/frontmatter-repo"
if make_frontmatter_repo "$FM_REPO"; then
    pass "frontmatter fixture repository builds"
else
    fail "frontmatter fixture repository builds"
fi
assert "the frontmatter fixture writes" run_builder "$FM_REPO"
assert "the frontmatter fixture checks clean" run_builder "$FM_REPO" --check

FM_CLI="$FM_REPO/cli-jortt/SKILL.md"
cp "$FM_CLI" "$TMP_ROOT/cli-jortt.aside"
grep -v '^nav_label:' "$FM_CLI" >"$TMP_ROOT/cli-jortt.navlabel-less"
mv "$TMP_ROOT/cli-jortt.navlabel-less" "$FM_CLI"
run_builder "$FM_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^field-set: cli-jortt/SKILL.md misses nav_label$' "$TMP_ROOT/out.txt"; then
    pass "a CLI document missing a field fails and is named"
else
    fail "a CLI document missing a field fails and is named"
fi
cp "$TMP_ROOT/cli-jortt.aside" "$FM_CLI"

FM_FIGURES="$FM_REPO/sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md"
cp "$FM_FIGURES" "$TMP_ROOT/figures.aside"
python3 -I - "$FM_FIGURES" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(
    text.replace('nav_label: "BTW"\n', 'nav_label: "BTW"\nchecked_on: 2026-01-01\n', 1)
)
PY
run_builder "$FM_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^field-set: sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md carries checked_on with no checked source$' "$TMP_ROOT/out.txt"; then
    pass "a checked_on date with no checked source fails and is named"
else
    fail "a checked_on date with no checked source fails and is named"
fi
cp "$TMP_ROOT/figures.aside" "$FM_FIGURES"

FM_MAP="$FM_REPO/sk-moneybird-accountant/assets/term-map.json"
cp "$FM_MAP" "$TMP_ROOT/term-map.aside"
python3 -I - "$FM_MAP" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path))
data["terms"] = [row for row in data["terms"] if row.get("term") != "Aangifte"]
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
run_builder "$FM_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^gloss: sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md has no term-map row for Aangifte (return)$' "$TMP_ROOT/out.txt"; then
    pass "a glossed term missing from the term map fails and is named"
else
    fail "a glossed term missing from the term map fails and is named"
fi
cp "$TMP_ROOT/term-map.aside" "$FM_MAP"

python3 -I - "$FM_MAP" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path))
data["terms"][0]["source_file"] = "references/tax-rules/2025/vat/missing.md"
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
run_builder "$FM_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^term-map: Aangifte source_file does not exist: references/tax-rules/2025/vat/missing.md$' "$TMP_ROOT/out.txt"; then
    pass "a source_file that names no file fails and is named"
else
    fail "a source_file that names no file fails and is named"
fi

python3 -I - "$FM_MAP" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path))
data["terms"][0]["source_file"] = "references/tax-rules/tax-rules/2025/vat/figures.md"
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
if run_builder "$FM_REPO" --write-term-map && python3 -I - "$FM_MAP" <<'PY'
import json
import sys

row = json.load(open(sys.argv[1]))["terms"][0]
sys.exit(0 if row["source_file"] == "references/tax-rules/2025/vat/figures.md" else 1)
PY
then
    pass "the producer repairs a doubled source_file path"
else
    fail "the producer repairs a doubled source_file path"
fi

# WHY: a stored path that resolves only by its last segments must still hold
# the term and its source, the same test --write-term-map applies.
cp "$FM_MAP" "$TMP_ROOT/term-map.aside"
printf '# Router\n\nNo glossed term lives here.\n' >"$FM_REPO/sk-moneybird-accountant/ROUTER.md"
python3 -I - "$FM_MAP" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path))
data["terms"][0]["source_file"] = "no/such/folder/ROUTER.md"
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
PY
run_builder "$FM_REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^term-map: Aangifte source_file does not name the term: ROUTER.md$' "$TMP_ROOT/out.txt"; then
    pass "a source_file that resolves only by suffix must still name the term"
else
    fail "a source_file that resolves only by suffix must still name the term"
fi
rm -f "$FM_REPO/sk-moneybird-accountant/ROUTER.md"
cp "$TMP_ROOT/term-map.aside" "$FM_MAP"

# WHY: an English-first label writes the Dutch term in lowercase, so the
# producer must still find the term its source file names.
FM_FIGURES="$FM_REPO/sk-moneybird-accountant/references/tax-rules/2025/vat/figures.md"
cp "$FM_FIGURES" "$TMP_ROOT/figures.aside"
python3 -I - "$FM_FIGURES" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace("Aangifte", "aangifte"))
PY
if run_builder "$FM_REPO" --write-term-map; then
    pass "the producer accepts a term its source file writes in lowercase"
else
    fail "the producer accepts a term its source file writes in lowercase"
fi
cp "$TMP_ROOT/figures.aside" "$FM_FIGURES"

group "real skill"
# WHY: the index owner regenerates the index after the reference edits land, so
# this case proves the real tree check runs and names only known findings.
python3 -I "$BUILDER" --check >"$TMP_ROOT/real-check.txt" 2>&1
real_status=$?
printf 'real tree --check exit: %s\n' "$real_status"
for kind in missing uncited differs "unknown access" "dead cited" perishable; do
    printf '  %s: %s\n' "$kind" "$(grep -c "^$kind" "$TMP_ROOT/real-check.txt")"
done
if [[ "$real_status" -le 1 ]] && ! grep -q 'Traceback' "$TMP_ROOT/real-check.txt"; then
    pass "the real tree check runs without a crash"
else
    fail "the real tree check runs without a crash"
    sed -n '1,10p' "$TMP_ROOT/real-check.txt"
fi
if grep -Eqv '^(missing: |uncited: |differs: |unknown access |dead cited: |perishable: |field-set: |term-map: |gloss: |gloss measure: |field-set report: |[0-9]+ sources match the index$)' "$TMP_ROOT/real-check.txt"; then
    fail "the real tree check prints only known finding kinds"
    grep -Ev '^(missing: |uncited: |differs: |unknown access |dead cited: |perishable: |field-set: |term-map: |gloss: |gloss measure: |field-set report: |[0-9]+ sources match the index$)' "$TMP_ROOT/real-check.txt" | sed -n '1,10p'
else
    pass "the real tree check prints only known finding kinds"
fi

# ───────────────────────────────────────────────────────────────
# 6. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
