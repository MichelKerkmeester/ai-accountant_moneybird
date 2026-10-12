#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE LIBRARY BUILDER
# ───────────────────────────────────────────────────────────────
"""Build or check the external source index for the skill family.

Scans the bootstrap, the root README and the markdown of the three skills for
external links and writes one row per source to the source library index. The
scan never touches the workspace, the spec folders or any private folder, and
the script makes no network call. Access results come from a live check that
the Operator or an agent runs, and a rewrite keeps them per URL. Output is
byte-stable: sorted rows, no timestamps, no randomness.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check

Options:
    --check     Verify the index without writing it. Reports every cited URL
                missing from the index and every indexed URL no file cites.

Output:
    sk-moneybird-accountant/assets/source-library.json and a summary on stdout.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, NoReturn, Set

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
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the check or write mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the check or write step.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Build or check the external source index for the skill family.",
    )
    parser.add_argument("--check", action="store_true", help="verify the index without writing it")
    args = parser.parse_args(argv)
    found = scan()
    stored = load_index()
    expected = build_text(found, stored)
    if args.check:
        return check_index(found, stored, expected)
    return write_index(expected, len(found))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
