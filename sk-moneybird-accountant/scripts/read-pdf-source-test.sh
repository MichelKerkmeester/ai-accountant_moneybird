#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: PDF SOURCE READER TEST
# ───────────────────────────────────────────────────────────────
# Tests read-pdf-source.py with a stub pdftotext, a fixture index, a loopback
# server and, when poppler is installed, the real pdftotext.
# Usage: read-pdf-source-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the reader is only trustworthy when the index row is the single door to
# a download, so this suite proves the refusals beside the read paths.
# WHY: a stub pdftotext on a temp PATH proves the argument order without
# poppler, and a loopback server proves the download reaches the stub. The real-tool cases run only when poppler is installed, and without it
# they print SKIP and are counted apart from the passes, never as passes.
# WHY: the tiny PDF fixture is generated at run time, because a committed xref
# table holds a ten-digit offset run that the privacy gate refuses.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")
PYTHON=$(command -v python3) || exit 2

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND SKILL VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: read-pdf-source-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

READER="$SKILL_SRC/scripts/read-pdf-source.py"
if [[ ! -f "$READER" ]]; then
    printf 'error: missing scripts/read-pdf-source.py in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/read-pdf-source-test.XXXXXX") || exit 2
# WHY: $TMPDIR may end in a slash and may sit under a symlink, and the reader
# normalises the path it is handed, so the fixtures are addressed physically.
TMP_ROOT=$(cd "$TMP_ROOT" && pwd -P)
SERVER_PID=""
STUB_BIN="$TMP_ROOT/stub-bin"
STUB_LOG="$TMP_ROOT/stub.log"
EMPTY_BIN="$TMP_ROOT/empty-bin"
QUIET_BIN="$TMP_ROOT/quiet-bin"

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
skipped=0

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

# Record a skipped check and print its report line
# WHY: a check that never ran is not a pass, so it gets its own line and its
# own count and a suite with skips still exits 0.
# Args:
#   $1 - Check description
skip() {
    skipped=$((skipped + 1))
    printf 'SKIP %s\n' "$1"
}

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Run the reader with the real PATH and capture both streams
# Args:
#   $1 - Reader path
#   $2... - Reader arguments
# Returns:
#   The reader exit status, with stdout in $TMP_ROOT/out.txt
run_reader() {
    local reader="$1"
    shift
    "$PYTHON" -I "$reader" "$@" >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Run the reader with the stub pdftotext first on PATH
# Args:
#   $1 - Reader path
#   $2... - Reader arguments
# Returns:
#   The reader exit status, with stdout in $TMP_ROOT/out.txt
run_stub_reader() {
    local reader="$1"
    shift
    STUB_LOG="$STUB_LOG" PATH="$STUB_BIN:$PATH" "$PYTHON" -I "$reader" "$@" \
        >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Run the reader with an empty PATH, so no pdftotext exists
# Args:
#   $1 - Reader path
#   $2... - Reader arguments
# Returns:
#   The reader exit status, with stderr in $TMP_ROOT/err.txt
run_empty_reader() {
    local reader="$1"
    shift
    env PATH="$EMPTY_BIN" "$PYTHON" -I "$reader" "$@" >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Run the reader with a pdftotext that succeeds with no output
# Args:
#   $1 - Reader path
#   $2... - Reader arguments
# Returns:
#   The reader exit status, with stderr in $TMP_ROOT/err.txt
run_quiet_reader() {
    local reader="$1"
    shift
    PATH="$QUIET_BIN:$PATH" "$PYTHON" -I "$reader" "$@" >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Write the stub pdftotext that logs its arguments and reads the PDF argument
# Args:
#   $1 - Directory to write the stub into
# Returns:
#   0 when the stub is executable, 1 when a write fails
write_stub_pdftotext() {
    local bindir="$1"
    mkdir -p "$bindir" || return 1
    cat >"$bindir/pdftotext" <<'SH'
#!/usr/bin/env bash
# Record the reader's call and prove it passed a readable file.
printf '%s\n' "$*" >>"$STUB_LOG"
input=""
for arg in "$@"; do
    case "$arg" in
        *.pdf) input="$arg" ;;
    esac
done
if [[ -n "$input" ]] && [[ -f "$input" ]]; then
    printf 'stub read %s bytes\n' "$(wc -c <"$input" | tr -d ' ')"
fi
printf 'stub pdftotext page text\n'
SH
    chmod +x "$bindir/pdftotext"
}

# Write a stub pdftotext that succeeds with no output, as a scanned page does
# Args:
#   $1 - Directory to write the stub into
# Returns:
#   0 when the stub is executable, 1 when a write fails
write_empty_pdftotext() {
    local bindir="$1"
    mkdir -p "$bindir" || return 1
    cat >"$bindir/pdftotext" <<'SH'
#!/usr/bin/env bash
# Succeed with no text, as a scanned page does.
exit 0
SH
    chmod +x "$bindir/pdftotext"
}

# Write the one-page PDF fixture with computed cross-reference offsets
# Args:
#   $1 - File path to write
# Returns:
#   0 when the file was written
write_tiny_pdf() {
    "$PYTHON" -I - "$1" <<'PY'
import sys

# WHY: the offsets are computed at run time, so the committed test holds no
# ten-digit run and the privacy gate stays green.
content = b"BT /F1 12 Tf 20 100 Td (fixture page one) Tj ET\n"
objects = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R "
    b"/Resources << /Font << /F1 5 0 R >> >> >>",
    b"<< /Length %d >>\nstream\n" % len(content) + content + b"endstream",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
]
out = bytearray(b"%PDF-1.4\n")
offsets = []
for number, body in enumerate(objects, start=1):
    offsets.append(len(out))
    out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
start = len(out)
out += b"xref\n0 %d\n" % (len(objects) + 1)
# WHY: the free entry is formatted like the others, so no literal long number sits in the file.
out += b"%010d 65535 f \n" % 0
for offset in offsets:
    out += b"%010d 00000 n \n" % offset
out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
    len(objects) + 1,
    start,
)
with open(sys.argv[1], "wb") as handle:
    handle.write(bytes(out))
PY
}

# Build a fixture repository with the reader and a small source index
# Args:
#   $1 - Repository root to create
#   $2 - Port the fixture server listens on
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_reader_repo() {
    local root="$1" port="$2"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" || return 1
    cp "$READER" "$root/sk-moneybird-accountant/scripts/" || return 1
    "$PYTHON" -I - "$root/sk-moneybird-accountant/assets/source-library.json" "$port" <<'PY'
import json
import sys

path, port = sys.argv[1:3]
sources = [
    {
        "url": "http://127.0.0.1:%s/loop.pdf" % port,
        "access": "pdf-needs-reader",
        "title": "Loopback fixture",
    },
    {
        "url": "http://127.0.0.1:%s/away.pdf" % port,
        "access": "pdf-needs-reader",
        "title": "Redirect fixture",
    },
    {
        "url": "http://example.invalid/plain.pdf",
        "access": "pdf-needs-reader",
        "title": "Plain HTTP fixture",
    },
    {
        "url": "https://example.invalid/ok.html",
        "access": "ok",
        "title": "Ordinary page",
    },
]
open(path, "w").write(json.dumps({"generator": "fixture", "guide": "fixture", "sources": sources}))
PY
}

# Wait until a TCP port on 127.0.0.1 accepts a connection
# Args:
#   $1 - Port number
# Returns:
#   0 when the port answers, 1 when it never does
wait_for_port() {
    "$PYTHON" -I - "$1" <<'PY'
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

# Start a quiet fixture server on a free local port and record that port
# Args:
#   $1 - Document root to serve
# Returns:
#   0 when the server answers, 1 when it does not start
start_fixture_server() {
    local docroot="$1" waited=0
    "$PYTHON" -I - "$docroot" >"$TMP_ROOT/server.port" 2>"$TMP_ROOT/server.err" <<'PY' &
import functools
import http.server
import socketserver
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    """Serve the document root and keep the run quiet."""

    def log_message(self, fmt, *args):
        """Keep the fixture server quiet."""

    def do_GET(self):
        """Send /away.pdf to another host name, serve the rest from disk."""
        if self.path == "/away.pdf":
            self.send_response(302)
            self.send_header("Location", "http://localhost:%d/loop.pdf" % self.server.server_address[1])
            self.end_headers()
            return
        super().do_GET()


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

# ───────────────────────────────────────────────────────────────
# 5. CHECKS
# ───────────────────────────────────────────────────────────────

group "list"
run_reader "$READER" --list
status=$?
list_count=$(wc -l <"$TMP_ROOT/out.txt" | tr -d ' ')
if [[ "$status" -eq 0 ]] && [[ "$list_count" -gt 0 ]]; then
    pass "--list prints at least one pdf-needs-reader row"
else
    fail "--list prints at least one pdf-needs-reader row (exit $status, $list_count rows)"
fi
if grep -q '^https://' "$TMP_ROOT/out.txt" && grep -q "$(printf '\t')" "$TMP_ROOT/out.txt"; then
    pass "--list prints a url and a title per row"
else
    fail "--list prints a url and a title per row"
fi

group "usage and refusals"
run_reader "$READER"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a run without a mode exits 2"
else
    fail "a run without a mode exits 2 (exit $status)"
fi
printf '%%PDF-1.4\nlocal fixture\n%%%%EOF\n' >"$TMP_ROOT/local.pdf"
run_reader "$READER" --file "$TMP_ROOT/missing.pdf"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a missing local file exits 2"
else
    fail "a missing local file exits 2 (exit $status)"
fi
run_reader "$READER" --file migration-workspace/saved.pdf
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a migration-workspace path exits 2"
else
    fail "a migration-workspace path exits 2 (exit $status)"
fi
mkdir -p "$TMP_ROOT/migration-workspace" && printf 'private' >"$TMP_ROOT/migration-workspace/saved.pdf"
ln -s "$TMP_ROOT/migration-workspace/saved.pdf" "$TMP_ROOT/harmless.pdf"
run_reader "$READER" --file "$TMP_ROOT/harmless.pdf"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a harmless-named symlink into migration-workspace exits 2"
else
    fail "a harmless-named symlink into migration-workspace exits 2 (exit $status)"
fi
run_reader "$READER" --file .env.example
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "an .env path exits 2"
else
    fail "an .env path exits 2 (exit $status)"
fi
run_reader "$READER" --url https://example.invalid/not-in-the-library.pdf
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a URL outside the library exits 2"
else
    fail "a URL outside the library exits 2 (exit $status)"
fi
run_reader "$READER" --url ""
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'refused, not a source library row' "$TMP_ROOT/err.txt" \
    && ! grep -q 'Traceback' "$TMP_ROOT/err.txt"; then
    pass "an empty --url is refused with exit 2"
else
    fail "an empty --url is refused with exit 2 (exit $status)"
fi
NOT_PDF_URL=$("$PYTHON" -I -c '
import json, sys
rows = json.load(open(sys.argv[1]))["sources"]
print(next(r["url"] for r in rows if r.get("access") == "ok" and r["url"].startswith("https://")))
' "$SKILL_SRC/assets/source-library.json" 2>/dev/null)
run_reader "$READER" --url "$NOT_PDF_URL"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a row that is not pdf-needs-reader exits 2"
else
    fail "a row that is not pdf-needs-reader exits 2 (exit $status)"
fi

group "missing pdftotext"
mkdir -p "$EMPTY_BIN"
run_empty_reader "$READER" --file "$TMP_ROOT/local.pdf"
status=$?
if [[ "$status" -eq 3 ]] && grep -q 'brew install poppler' "$TMP_ROOT/err.txt"; then
    pass "a missing pdftotext exits 3 and names the brew install"
else
    fail "a missing pdftotext exits 3 and names the brew install (exit $status)"
fi

group "stub argument passing"
write_stub_pdftotext "$STUB_BIN" || exit 2
rm -f "$STUB_LOG"
run_stub_reader "$READER" --file "$TMP_ROOT/local.pdf"
status=$?
if [[ "$status" -eq 0 ]] && grep -q 'stub pdftotext page text' "$TMP_ROOT/out.txt"; then
    pass "the stub text reaches stdout"
else
    fail "the stub text reaches stdout (exit $status)"
fi
if grep -Fxq -- "-layout -enc UTF-8 $TMP_ROOT/local.pdf -" "$STUB_LOG"; then
    pass "pdftotext is called with -layout -enc UTF-8 and stdout"
else
    fail "pdftotext is called with -layout -enc UTF-8 and stdout"
fi

group "empty extraction"
write_empty_pdftotext "$QUIET_BIN" || exit 2
run_quiet_reader "$READER" --file "$TMP_ROOT/local.pdf"
status=$?
if [[ "$status" -eq 4 ]] && [[ ! -s "$TMP_ROOT/out.txt" ]] \
    && grep -q 'HTML page' "$TMP_ROOT/err.txt" \
    && grep -q 'Operator' "$TMP_ROOT/err.txt"; then
    pass "an extraction with no text exits 4 and names the fallbacks"
else
    fail "an extraction with no text exits 4 and names the fallbacks (exit $status)"
fi

group "fixture index and loopback"
DOCROOT="$TMP_ROOT/docroot"
mkdir -p "$DOCROOT"
printf '%%PDF-1.4\nloopback fixture\n%%%%EOF\n' >"$DOCROOT/loop.pdf"
start_fixture_server "$DOCROOT" || exit 2
PORT=$(cat "$TMP_ROOT/server.port" 2>/dev/null || true)
FIXTURE_REPO="$TMP_ROOT/reader-repo"
FIXTURE_READER="$FIXTURE_REPO/sk-moneybird-accountant/scripts/read-pdf-source.py"
make_reader_repo "$FIXTURE_REPO" "$PORT" || exit 2
FIXTURE_FILES_BEFORE=$(find "$FIXTURE_REPO" -type f | sort)
run_reader "$FIXTURE_READER" --list
status=$?
fixture_count=$(wc -l <"$TMP_ROOT/out.txt" | tr -d ' ')
if [[ "$status" -eq 0 ]] && [[ "$fixture_count" -eq 3 ]] && ! grep -q 'ok.html' "$TMP_ROOT/out.txt"; then
    pass "the fixture index lists only its pdf-needs-reader rows"
else
    fail "the fixture index lists only its pdf-needs-reader rows (exit $status, $fixture_count rows)"
fi
LOOP_URL="http://127.0.0.1:$PORT/loop.pdf"
PLAIN_URL="http://example.invalid/plain.pdf"
LOOP_BYTES=$(wc -c <"$DOCROOT/loop.pdf" | tr -d ' ')
rm -f "$STUB_LOG"
run_stub_reader "$FIXTURE_READER" --url "$LOOP_URL"
status=$?
if [[ "$status" -eq 0 ]] \
    && grep -q "stub read $LOOP_BYTES bytes" "$TMP_ROOT/out.txt" \
    && grep -q 'stub pdftotext page text' "$TMP_ROOT/out.txt"; then
    pass "the loopback download reaches the stub as a whole file"
else
    fail "the loopback download reaches the stub as a whole file (exit $status)"
fi
rm -f "$STUB_LOG"
run_stub_reader "$FIXTURE_READER" --url "http://127.0.0.1:$PORT/away.pdf"
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'redirects off the indexed host' "$TMP_ROOT/err.txt" \
    && [[ ! -s "$STUB_LOG" ]]; then
    pass "a redirect to another host exits 2 before any extraction"
else
    fail "a redirect to another host exits 2 before any extraction (exit $status)"
fi
if [[ "$(find "$FIXTURE_REPO" -type f | sort)" = "$FIXTURE_FILES_BEFORE" ]]; then
    pass "the loopback read writes nothing inside the fixture repository"
else
    fail "the loopback read writes nothing inside the fixture repository"
fi
run_stub_reader "$FIXTURE_READER" --url "$PLAIN_URL"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a plain HTTP address outside loopback exits 2"
else
    fail "a plain HTTP address outside loopback exits 2 (exit $status)"
fi

group "real pdftotext"
if command -v pdftotext >/dev/null 2>&1; then
    write_tiny_pdf "$TMP_ROOT/tiny.pdf"
    run_reader "$READER" --file "$TMP_ROOT/tiny.pdf"
    status=$?
    if [[ "$status" -eq 0 ]] && grep -q 'fixture page one' "$TMP_ROOT/out.txt"; then
        pass "a real pdftotext extracts the tiny fixed PDF"
    else
        fail "a real pdftotext extracts the tiny fixed PDF (exit $status)"
    fi
else
    skip "a real pdftotext extracts the tiny fixed PDF (pdftotext is not on PATH)"
fi

# ───────────────────────────────────────────────────────────────
# 6. SUMMARY
# ───────────────────────────────────────────────────────────────

if [[ "$skipped" -gt 0 ]]; then
    printf '\nResult: %d passed, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
else
    printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"
fi

[[ "$failed" -eq 0 ]]
