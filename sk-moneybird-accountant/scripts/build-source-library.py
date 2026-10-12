#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE LIBRARY BUILDER
# ───────────────────────────────────────────────────────────────
"""Build or check the external source index for the skill family.

Scans the bootstrap, the root README and the markdown of the three skills for
external links and writes one row per source to the source library index. The
scan never touches the workspace, the spec folders or any private folder, and
only --check-links makes a network call. Access results come from a live check
that the Operator or an agent runs, and a rewrite keeps them per URL. Output is
byte-stable: sorted rows, no timestamps, no randomness.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-links
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --trace <file>:<line>

Options:
    --check       Verify the index without writing it. Reports every cited URL
                  missing from the index and every indexed URL no file cites.
    --check-links Fetch every row a plain fetch can reach and print a JSON
                  report. Endpoint rows and rows recorded as reachable only
                  through WebFetch are reported as skipped, never as failed.
                  A row is ok only when the final answer after followed
                  redirects is 2xx. An unfollowed redirect is a failure of
                  its own kind.
    --trace       Print the index result for every URL on one line of one file,
                  and fail on a dead, unchecked or unindexed URL.

Output:
    sk-moneybird-accountant/assets/source-library.json and a summary on stdout.
    --check-links prints only its JSON report.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, List, NoReturn, Optional, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/build-source-library.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INDEX_PATH = os.path.join(REPO_ROOT, "sk-moneybird-accountant", "assets", "source-library.json")
GUIDE_PATH = os.path.join(REPO_ROOT, "sk-moneybird-accountant", "references", "source-library.md")

# WHY: an allowlist of scan roots keeps the private folders out by construction.
SCAN_ROOTS = ("AGENTS.md", "README.md", "sk-moneybird-accountant", "cli-jortt", "cli-moneybird")

URL_RE = re.compile(r"https?://[^\s)\]>\"'`|]+")
LINK_RE = re.compile(r"\[([^\]]{2,160})\]\((https?://[^)\s]+)\)")
TRAILING_RE = re.compile(r"[.,;:*]+$")

# Badges, the donation link and the repository itself are not sources.
SKIP_HOSTS = {"img.shields.io", "buymeacoffee.com"}
SKIP_FRAGMENTS = ("MichelKerkmeester/ai-accountant_moneybird",)

# API and OAuth addresses are tool endpoints, never pages to read.
ENDPOINT_HOSTS = {"api.jortt.nl", "app.jortt.nl", "mcp.jortt.nl"}
ENDPOINT_PREFIXES = ("https://moneybird.com/api/", "https://moneybird.com/mcp/")

AUTHORITY = {
    "www.belastingdienst.nl": "tax-authority",
    "download.belastingdienst.nl": "tax-authority",
    "kennisgroepen.belastingdienst.nl": "tax-authority",
    "odb.belastingdienst.nl": "tax-authority",
    "over-ons.belastingdienst.nl": "tax-authority",
    "centraalaanspreekpuntpensioenen.belastingdienst.nl": "tax-authority",
    "wetten.overheid.nl": "statute",
    "zoek.officielebekendmakingen.nl": "official-publication",
    "open.overheid.nl": "official-publication",
    "www.tweedekamer.nl": "parliament",
    "www.eerstekamer.nl": "parliament",
    "www.rijksoverheid.nl": "government",
    "ondernemersplein.overheid.nl": "government",
    "business.gov.nl": "government",
    "www.kvk.nl": "government",
    "www.rvo.nl": "government",
    "taxation-customs.ec.europa.eu": "eu",
    "helpcenter.moneybird.nl": "product-docs",
    "moneybird.com": "product-docs",
    "github.com": "product-docs",
    "www.jortt.nl": "product-docs",
    "web.archive.org": "archive",
    "financialfocus.abnamro.nl": "secondary",
    "holdwise.nl": "secondary",
    "mijn.bovag.nl": "secondary",
}

# Access values a live check may record. Their meaning is in the guide.
ACCESS_VALUES = ("ok", "webfetch-only", "pdf-needs-reader", "archive-not-fetchable", "dead", "endpoint", "unchecked")

# A browser-like agent is what public hosts answer without a challenge.
USER_AGENT = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
              "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

FETCH_TIMEOUT = 30
FETCH_ATTEMPTS = 2
READ_LIMIT = 512

# Rows a plain fetch cannot reach, so the link check reports them as skipped.
SKIP_FETCH_ACCESS = ("endpoint", "webfetch-only")

# Access values that fail the trace, beside a URL the index does not hold.
TRACE_FAIL_ACCESS = ("dead", "unchecked")

# ───────────────────────────────────────────────────────────────
# 3. HELPERS
# ───────────────────────────────────────────────────────────────

def fail(message: str) -> NoReturn:
    """Print an error and stop with exit code 2.

    Args:
        message: Error text for stderr.

    Raises:
        SystemExit: Always, with code 2.
    """
    print("error: %s" % message, file=sys.stderr)
    sys.exit(2)


def clean_url(raw: str) -> str:
    """Strip markdown punctuation that trails a URL.

    Args:
        raw: URL as matched in the text.

    Returns:
        The URL without trailing punctuation.
    """
    return TRAILING_RE.sub("", raw)


def is_skipped(url: str) -> bool:
    """Tell whether a URL is a badge, donation link or the repository itself.

    Args:
        url: Cleaned URL.

    Returns:
        True when the URL is not a source.
    """
    host = url.split("/")[2]
    return host in SKIP_HOSTS or any(fragment in url for fragment in SKIP_FRAGMENTS)


def guess_type(url: str) -> str:
    """Guess from the URL alone whether a source is a PDF or a web page.

    Args:
        url: Cleaned URL.

    Returns:
        "pdf" or "html".
    """
    path = url.split("?")[0].lower()
    if path.endswith(".pdf") or "/downloads/document" in path or path.endswith("/file"):
        return "pdf"
    return "html"


def is_endpoint(url: str) -> bool:
    """Tell whether a URL is an API or OAuth endpoint.

    Args:
        url: Cleaned URL.

    Returns:
        True for a tool endpoint.
    """
    return url.split("/")[2] in ENDPOINT_HOSTS or url.startswith(ENDPOINT_PREFIXES)


def markdown_files() -> List[str]:
    """List the markdown files under the scan roots, guide excluded.

    Returns:
        Sorted absolute paths.
    """
    found = []
    for root in SCAN_ROOTS:
        path = os.path.join(REPO_ROOT, root)
        if os.path.isfile(path):
            found.append(path)
            continue
        for directory, _, names in os.walk(path):
            for name in names:
                if name.endswith(".md"):
                    found.append(os.path.join(directory, name))
    # WHY: the guide quotes sources itself, so scanning it would make the index cite itself.
    return sorted(path for path in found if os.path.abspath(path) != GUIDE_PATH)

# ───────────────────────────────────────────────────────────────
# 4. BUILD
# ───────────────────────────────────────────────────────────────

def scan() -> Dict[str, Dict[str, Any]]:
    """Collect every cited source with its citing files and link text.

    Returns:
        Mapping of URL to a dict with the citing files and link-text counts.
    """
    found: Dict[str, Dict[str, Any]] = {}
    for path in markdown_files():
        relative = os.path.relpath(path, REPO_ROOT)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.readlines()
        except OSError as exc:
            fail("cannot read %s: %s" % (relative, exc))
        for line in lines:
            for raw in URL_RE.findall(line):
                url = clean_url(raw)
                if is_skipped(url):
                    continue
                entry = found.setdefault(url, {"cited_by": set(), "titles": {}})
                entry["cited_by"].add(relative)
            for text, raw in LINK_RE.findall(line):
                url = clean_url(raw)
                if url in found:
                    titles = found[url]["titles"]
                    titles[text.strip()] = titles.get(text.strip(), 0) + 1
    return found


def load_index() -> Dict[str, Dict[str, Any]]:
    """Read the current index rows keyed by URL.

    Returns:
        Mapping of URL to its stored row, empty when no index exists.

    Raises:
        SystemExit: If the index exists but is not valid JSON.
    """
    if not os.path.isfile(INDEX_PATH):
        return {}
    try:
        with open(INDEX_PATH, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read the index: %s" % exc)
    return {row["url"]: row for row in data.get("sources", [])}


def build_text(found: Dict[str, Dict[str, Any]], stored: Dict[str, Dict[str, Any]]) -> str:
    """Render the index JSON, keeping recorded access fields per URL.

    Args:
        found: Result of scan().
        stored: Result of load_index().

    Returns:
        The full index text with a trailing newline.
    """
    rows = []
    for url in sorted(found):
        entry = found[url]
        titles = entry["titles"]
        # WHY: the most frequent link text wins, ties go to the alphabetically first.
        title = sorted(titles, key=lambda text: (-titles[text], text))[0] if titles else ""
        old = stored.get(url, {})
        endpoint = is_endpoint(url)
        row = {
            "url": url,
            "host": url.split("/")[2],
            "authority": "endpoint" if endpoint else AUTHORITY.get(url.split("/")[2], "other"),
            "title": title,
            "type": old.get("type") or guess_type(url),
            "access": "endpoint" if endpoint else old.get("access", "unchecked"),
            "http_status": old.get("http_status"),
            "checked_on": old.get("checked_on"),
            "cited_by": sorted(entry["cited_by"]),
        }
        rows.append(row)
    # WHY: one row per line, so a grep for a topic or host returns whole rows.
    lines = [json.dumps(row, ensure_ascii=False, separators=(",", ":")) for row in rows]
    head = '{"generator":%s,"guide":%s,"sources":[' % (
        json.dumps(GENERATOR),
        json.dumps("sk-moneybird-accountant/references/source-library.md"),
    )
    return head + "\n" + ",\n".join(lines) + "\n]}\n"

# ───────────────────────────────────────────────────────────────
# 5. CHECK AND WRITE
# ───────────────────────────────────────────────────────────────

def check_index(found: Dict[str, Dict[str, Any]], stored: Dict[str, Dict[str, Any]], expected: str) -> int:
    """Report drift between the cited sources and the index.

    Args:
        found: Result of scan().
        stored: Result of load_index().
        expected: Index text a write would produce.

    Returns:
        Zero when the index matches, one otherwise.
    """
    cited: Set[str] = set(found)
    indexed: Set[str] = set(stored)
    problems = ["missing: %s" % url for url in sorted(cited - indexed)]
    problems += ["uncited: %s" % url for url in sorted(indexed - cited)]
    problems += [
        "unknown access %r: %s" % (row.get("access"), url)
        for url, row in sorted(stored.items())
        if row.get("access") not in ACCESS_VALUES
    ]
    current = None
    if os.path.isfile(INDEX_PATH):
        with open(INDEX_PATH, "r", encoding="utf-8", newline="") as handle:
            current = handle.read()
    if not problems and current != expected:
        problems.append("differs: rerun without --check to refresh titles and citing files")
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("%d sources match the index" % len(cited))
    return 0


def write_index(expected: str, count: int) -> int:
    """Write the index when it changed.

    Args:
        expected: Index text to write.
        count: Number of sources, for the summary.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the file cannot be written.
    """
    current = None
    if os.path.isfile(INDEX_PATH):
        with open(INDEX_PATH, "r", encoding="utf-8", newline="") as handle:
            current = handle.read()
    if current == expected:
        print("%d sources, index unchanged" % count)
        return 0
    try:
        with open(INDEX_PATH, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(expected)
    except OSError as exc:
        fail("cannot write the index: %s" % exc)
    print("%d sources, wrote %s" % (count, os.path.relpath(INDEX_PATH, REPO_ROOT)))
    return 0

# ───────────────────────────────────────────────────────────────
# 6. LINK CHECK AND TRACE
# ───────────────────────────────────────────────────────────────

def fetch_status(url: str) -> Tuple[Optional[int], Optional[str]]:
    """Fetch one URL and report its final HTTP status after redirects.

    Args:
        url: URL to fetch.

    Returns:
        (status, error): the answer status when the server answered, or
        (None, error text) when every attempt raised. A 3xx status means
        urllib could not follow the redirect.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for _ in range(FETCH_ATTEMPTS):
        try:
            # WHY: the default opener follows redirects, so a moved page reports its final status.
            with urllib.request.urlopen(request, timeout=FETCH_TIMEOUT) as response:
                response.read(READ_LIMIT)
                return response.status, None
        except urllib.error.HTTPError as exc:
            # WHY: a 3xx here is a redirect urllib could not follow and a 4xx is
            # an answer, so only a 5xx is worth one retry.
            if exc.code < 500:
                return exc.code, None
            last_error = "HTTP %d" % exc.code
        except (urllib.error.URLError, OSError, ValueError) as exc:
            last_error = str(exc)
    return None, last_error


def check_links(stored: Dict[str, Dict[str, Any]]) -> int:
    """Fetch every reachable row and print one JSON report.

    Args:
        stored: Result of load_index().

    Returns:
        Zero when no reachable row failed, one otherwise.
    """
    summary = {
        "rows": len(stored),
        "checked": 0,
        "ok": 0,
        "dead": 0,
        "redirects": 0,
        "errors": 0,
        "skipped": 0,
        "endpoints_skipped": 0,
        "recovered": 0,
        "failures": 0,
    }
    rows = []
    for url in sorted(stored):
        access = stored[url].get("access", "unchecked")
        entry = {
            "url": url,
            "host": stored[url].get("host", ""),
            "recorded_access": access,
            "cited_by": stored[url].get("cited_by", []),
        }
        if access in SKIP_FETCH_ACCESS:
            entry.update(result="skipped", reason=access)
            summary["skipped"] += 1
            if access == "endpoint":
                summary["endpoints_skipped"] += 1
            rows.append(entry)
            continue
        summary["checked"] += 1
        status, error = fetch_status(url)
        if error is not None:
            entry.update(result="error", http_status=None, reason=error)
            summary["errors"] += 1
        elif status is not None and 200 <= status < 300:
            entry.update(result="ok", http_status=status)
            summary["ok"] += 1
            if access == "dead":
                summary["recovered"] += 1
        elif status is not None and 300 <= status < 400:
            # WHY: only a final 2xx after followed redirects is a live page, and
            # an unfollowed redirect is neither dead nor a transport error.
            entry.update(result="redirect", http_status=status, reason="redirect not followed")
            summary["redirects"] += 1
        else:
            entry.update(result="dead", http_status=status)
            summary["dead"] += 1
        # WHY: a row already recorded as dead is a known finding, not a new one.
        if entry["result"] in ("dead", "error", "redirect") and access != "dead":
            summary["failures"] += 1
        rows.append(entry)
    report = {
        "generator": GENERATOR,
        "mode": "check-links",
        "checked_on": datetime.date.today().isoformat(),
        "user_agent": USER_AGENT,
        "summary": summary,
        "rows": rows,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if summary["failures"] else 0


def trace_line(target: str, stored: Dict[str, Dict[str, Any]]) -> int:
    """Print the index result for every URL on one line of one file.

    Args:
        target: File path and line number, as <file>:<line>.
        stored: Result of load_index().

    Returns:
        Zero when every cited URL is usable, one when one is dead, unchecked
        or missing from the index.

    Raises:
        SystemExit: With code 2 on a usage error.
    """
    path, separator, number_text = target.rpartition(":")
    if not separator or not number_text.isdigit() or int(number_text) < 1:
        fail("usage: --trace <file>:<line>")
    line_number = int(number_text)
    resolved = os.path.normpath(os.path.join(REPO_ROOT, path))
    if not resolved.startswith(REPO_ROOT + os.sep) or not os.path.isfile(resolved):
        fail("no such file in this repository: %s" % path)
    with open(resolved, "r", encoding="utf-8", errors="replace") as handle:
        lines = handle.readlines()
    if line_number > len(lines):
        fail("%s has no line %d" % (path, line_number))
    # WHY: badges and donation links never enter the index, so the trace ignores them too.
    urls = []
    for raw in URL_RE.findall(lines[line_number - 1]):
        url = clean_url(raw)
        if not is_skipped(url) and url not in urls:
            urls.append(url)
    print("%s:%d" % (os.path.relpath(resolved, REPO_ROOT), line_number))
    if not urls:
        print("no URLs on that line")
        return 0
    problems = []
    for url in urls:
        row = stored.get(url)
        if row is None:
            print("%s access=missing http_status=- checked_on=-" % url)
            problems.append("missing")
            continue
        access = row.get("access", "unchecked")
        status = row.get("http_status")
        print("%s access=%s http_status=%s checked_on=%s" % (
            url,
            access,
            status if status is not None else "-",
            row.get("checked_on") or "-",
        ))
        if access in TRACE_FAIL_ACCESS:
            problems.append(access)
    if problems:
        print("failed: %d of %d URLs (%s)" % (len(problems), len(urls), ", ".join(sorted(set(problems)))))
        return 1
    print("%d URLs, all usable" % len(urls))
    return 0

# ───────────────────────────────────────────────────────────────
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the requested mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the selected mode.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Build or check the external source index for the skill family.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="verify the index without writing it")
    mode.add_argument(
        "--check-links",
        action="store_true",
        help="fetch the indexed pages and print a JSON report",
    )
    mode.add_argument(
        "--trace",
        metavar="<file>:<line>",
        help="print the index result for the URLs on one line of one file",
    )
    args = parser.parse_args(argv)
    stored = load_index()
    if args.check_links:
        if not stored:
            fail("no index to check: %s" % os.path.relpath(INDEX_PATH, REPO_ROOT))
        return check_links(stored)
    if args.trace:
        return trace_line(args.trace, stored)
    found = scan()
    expected = build_text(found, stored)
    if args.check:
        return check_index(found, stored, expected)
    return write_index(expected, len(found))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
