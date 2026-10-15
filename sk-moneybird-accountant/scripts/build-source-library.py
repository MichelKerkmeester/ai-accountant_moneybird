#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE LIBRARY BUILDER
# ───────────────────────────────────────────────────────────────
"""Build or check the external source index for the skill family.

Scans the bootstrap, the root README and the markdown of the three skills for
external links and writes one row per source to the source library index. The
scan never touches the workspace, the spec folders or any private folder, and
only --check-links and --watch make a network call. Access results come from a
live check that the Operator or an agent runs, and a rewrite keeps them per URL
together with the digest, the retrieval date, the entity tag fingerprint, the
last modification date and the pending kst marker. Output is byte-stable:
sorted rows, no timestamps, no randomness.

A digest is the sha256 of the page text after normalisation: script and style
blocks and every tag are removed, entities are unescaped and whitespace is
collapsed. A PDF row hashes the raw bytes, so it needs no reader. An entity tag
is stored as the sha256 of the header value with a `sha256:` prefix, so a raw
tag holding a long digit run never reaches a committed file. A stored tag
without that prefix is hashed when it is read, so an index or a state file
written earlier still compares.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-links
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --apply-report <file>
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --watch [--state <file>]
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar [--today YYYY-MM-DD]
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --trace <file>:<line>
    python3 -I sk-moneybird-accountant/scripts/build-source-library.py --write-term-map

Options:
    --check       Verify the index without writing it. Reports every cited URL
                  missing from the index, every indexed URL no file cites, a
                  cited row recorded dead, a perishable Tweede Kamer download
                  address without a pending kst marker and a count in the
                  guide's section 1 table that disagrees with the index.
    --check-links Fetch every row a plain fetch can reach and print a JSON
                  report with the status, the digest, the retrieval date, the
                  entity tag fingerprint and the last modification date per
                  readable URL.
                  Endpoint rows and rows recorded as reachable only through
                  WebFetch are reported as skipped, never as failed. A row is
                  ok only when the final answer after followed redirects is 2xx.
                  An unfollowed redirect is a failure of its own kind. A 401,
                  403 or 429 is a blocked row: the host refused this client,
                  so the page is not dead and the row is not a failure.
    --apply-report Read a --check-links report and write its access result,
                  status, check date, digest, retrieval date, entity tag
                  fingerprint and last modification date into the matching
                  index rows. A blocked row is left untouched: no field is
                  written, not its access, status, check date, digest,
                  retrieval date, entity tag or last modification date, and
                  it stays out of the update count. The run prints how many
                  blocked rows it skipped. Offline.
    --watch       Fetch every URL of the source watchlist and compare its
                  entity tag fingerprint, last modification date and digest
                  with the stored values. The index row of the URL wins, the
                  state file covers URLs the index does not hold. Every
                  answered status is recorded, including a 404, and a stored
                  404 that answers 200 is reported. A 401, 403 or 429 answer
                  is reported as blocked and leaves the stored values alone.
                  Without --state it reads assets/source-watch-state.json when
                  that file exists and never writes it. Prints one line per
                  changed URL with its series and its citing files. A fetch
                  failure and a refusal are reported per URL and do not stop
                  the run. This mode is network only and never runs with
                  --check.
    --check-calendar Read checked_on from the year READMEs and the rules file,
                  and the checkpoint dates from the rollover runbook. Exits 1
                  when a current or future year is older than the latest passed
                  checkpoint or carries no stamp. Offline.
    --trace       Print the index result for every URL on one line of one file,
                  and fail on a dead, unchecked or unindexed URL.
    --write-term-map Rewrite assets/term-map.json with every source_file
                  resolved to a file under the skill root. A stored path that
                  repeats a folder is collapsed, the resolved file must hold
                  the term and its source, and the map is left untouched on a
                  failure.

Output:
    sk-moneybird-accountant/assets/source-library.json and a summary on stdout.
    --check-links prints only its JSON report. --watch exits 0 when nothing
    changed, 1 when a series changed and 2 on a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import datetime
import hashlib
import html
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
GUIDE_RELATIVE = "sk-moneybird-accountant/references/tax-rules/source-library.md"
GUIDE_PATH = os.path.join(REPO_ROOT, *GUIDE_RELATIVE.split("/"))
WATCHLIST_PATH = os.path.join(REPO_ROOT, "sk-moneybird-accountant", "assets", "source-watchlist.json")
WATCH_STATE_PATH = os.path.join(REPO_ROOT, "sk-moneybird-accountant", "assets", "source-watch-state.json")
SKILL_ROOT = os.path.join(REPO_ROOT, "sk-moneybird-accountant")
REFERENCES_DIR = os.path.join(SKILL_ROOT, "references")
ROLLOVER_PATH = os.path.join(REFERENCES_DIR, "tax-rules", "year-rollover.md")

# WHY: an allowlist of scan roots keeps the private folders out by construction.
SCAN_ROOTS = ("AGENTS.md", "README.md", "sk-moneybird-accountant", "cli-jortt", "cli-moneybird")

# WHY: a year topic is split into four part files, and listing each part in
# cited_by grew the index past the privacy gate's file size limit. The topic
# folder keeps the granularity the index had before the split and stays a
# greppable citing path.
SPLIT_PART_RE = re.compile(
    r"^(sk-moneybird-accountant/references/tax-rules/\d{4}/[a-z0-9-]+/)(?:figures|rules|examples|notes)\.md$"
)

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

# Access values that describe how a page is read, so a live answer keeps them.
KEEP_ACCESS = ("pdf-needs-reader", "archive-not-fetchable")

# WHY: the guide's section 1 measure table is refreshed by hand at a
# checkpoint, so --check compares each stated count with the index. A None
# entry counts every row.
GUIDE_COUNT_MEASURES = (
    ("Sources", None),
    ("Readable as a web page", "ok"),
    ("Readable through WebFetch only", "webfetch-only"),
    ("PDF, downloads but needs a PDF reader", "pdf-needs-reader"),
    ("Archive copy an agent cannot fetch", "archive-not-fetchable"),
    ("Dead link", "dead"),
    ("Tool endpoint, not a source", "endpoint"),
    ("Added after the last access check", "unchecked"),
)

# Cadences a watched series may carry.
CADENCES = ("monthly", "yearly", "on-publication")

# A browser-like agent is what public hosts answer without a challenge.
USER_AGENT = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
              "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

FETCH_TIMEOUT = 30
FETCH_ATTEMPTS = 2

# WHY: the digest needs the whole body and a cap keeps one huge file out of memory.
DIGEST_MAX_BYTES = 24 * 1024 * 1024

# Rows a plain fetch cannot reach, so the link check reports them as skipped.
SKIP_FETCH_ACCESS = ("endpoint", "webfetch-only")

# Access values that fail the trace, beside a URL the index does not hold.
TRACE_FAIL_ACCESS = ("dead", "unchecked")

# WHY: a host that turns this client away still serves the page to others, so
# a refusal is its own result and never a missing page.
BLOCKED_STATUSES = (401, 403, 429)

# WHY: the index keeps one row per line and every stored field per URL. The
# first group is always written, the second only when it holds a value.
BASE_FIELDS = ("url", "host", "authority", "title", "type", "access", "http_status", "checked_on")
CARRIED_FIELDS = ("digest", "retrieved_at", "etag", "last_modified", "kst_pending")

# WHY: a stored entity tag is a fingerprint, so a raw header value with a long
# digit run never reaches the index, the report or the state file.
ETAG_PREFIX = "sha256:"

# The checkpoint table sits under this header in the rollover runbook.
CHECKPOINT_HEADER = ("Checkpoint", "Date", "Refresh")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
YEAR_RE = re.compile(r"^\d{4}$")

# A Tweede Kamer download address is perishable, so a file may cite it only
# while the index row holds the expected kst id.
PERISHABLE_RE = re.compile(r"https?://(?:www\.)?tweedekamer\.nl/downloads/document\?id=[^\s)\]>\"'`|]+")

# Page normalisation: strip the blocks that hold no readable text, then tags.
SCRIPT_BLOCK_RE = re.compile(r"(?is)<script\b.*?</script\s*>")
STYLE_BLOCK_RE = re.compile(r"(?is)<style\b.*?</style\s*>")
TAG_RE = re.compile(r"(?s)<[^>]*>")
WHITESPACE_RE = re.compile(r"\s+")

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


def parse_iso_date(value: Optional[str]) -> Optional[datetime.date]:
    """Parse an ISO date without raising on anything else.

    Args:
        value: Candidate date text.

    Returns:
        The date, or None when the text is missing or not an ISO date.
    """
    if not value:
        return None
    try:
        return datetime.datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return None


def frontmatter_value(path: str, key: str) -> Optional[str]:
    """Read one scalar from the YAML frontmatter of a markdown file.

    Args:
        path: File to read.
        key: Frontmatter key to look up.

    Returns:
        The unquoted value, or None when the file, the block or the key is
        missing.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return None
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            break
        if stripped.startswith(key + ":"):
            value = stripped[len(key) + 1:].strip().strip('"').strip("'")
            return value or None
    return None


def normalize_page(body: bytes) -> str:
    """Reduce a page body to the text a digest can compare.

    Args:
        body: Raw response bytes.

    Returns:
        The text without script and style blocks, without tags, with entities
        unescaped and with every whitespace run collapsed.
    """
    text = body.decode("utf-8", errors="replace")
    text = SCRIPT_BLOCK_RE.sub(" ", text)
    text = STYLE_BLOCK_RE.sub(" ", text)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    return WHITESPACE_RE.sub(" ", text).strip()


def digest_page(body: bytes, kind: str) -> str:
    """Hash one response body the way its access class asks for.

    Args:
        body: Raw response bytes.
        kind: "pdf" to hash the bytes, anything else hashes the text.

    Returns:
        The sha256 hex digest.
    """
    payload = body if kind == "pdf" else normalize_page(body).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def etag_fingerprint(value: Any) -> Optional[str]:
    """Reduce an entity tag to the fingerprint the index stores.

    Args:
        value: Raw entity tag, or a fingerprint read from the index or the
            state file.

    Returns:
        None when the value is missing or not text. The value itself when it
        already carries the prefix. Otherwise the prefix followed by the
        sha256 hex of the value, so a raw tag from an older file still
        compares.
    """
    if not isinstance(value, str) or not value:
        return None
    if value.startswith(ETAG_PREFIX):
        return value
    return ETAG_PREFIX + hashlib.sha256(value.encode("utf-8")).hexdigest()


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


def reference_files() -> List[str]:
    """List every markdown file under references, the guide included.

    Returns:
        Sorted absolute paths.
    """
    found = []
    if not os.path.isdir(REFERENCES_DIR):
        return found
    for directory, _, names in os.walk(REFERENCES_DIR):
        for name in names:
            if name.endswith(".md"):
                found.append(os.path.join(directory, name))
    return sorted(found)

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
                part = SPLIT_PART_RE.match(relative.replace(os.sep, "/"))
                entry["cited_by"].add(part.group(1) if part else relative)
            for text, raw in LINK_RE.findall(line):
                url = clean_url(raw)
                if url in found:
                    titles = found[url]["titles"]
                    titles[text.strip()] = titles.get(text.strip(), 0) + 1
    return found


def read_index() -> Dict[str, Any]:
    """Read the index document.

    Returns:
        The decoded document, an empty one when no index exists.

    Raises:
        SystemExit: If the index exists but is not a valid index document.
    """
    if not os.path.isfile(INDEX_PATH):
        return {"generator": GENERATOR, "guide": GUIDE_RELATIVE, "sources": []}
    try:
        with open(INDEX_PATH, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read the index: %s" % exc)
    if not isinstance(data, dict) or not isinstance(data.get("sources"), list):
        fail("the index does not hold a source list")
    return data


def load_index() -> Dict[str, Dict[str, Any]]:
    """Read the current index rows keyed by URL.

    Returns:
        Mapping of URL to its stored row, empty when no index exists.

    Raises:
        SystemExit: If the index exists but is not valid JSON.
    """
    return {row["url"]: row for row in read_index()["sources"] if isinstance(row, dict) and "url" in row}


def render_row(row: Dict[str, Any]) -> Dict[str, Any]:
    """Order one row for the index and drop the carried fields without a value.

    Args:
        row: Row with any subset of the known fields.

    Returns:
        The row in the fixed index order.
    """
    ordered = {key: row.get(key) for key in BASE_FIELDS}
    for key in CARRIED_FIELDS:
        if row.get(key) is not None:
            ordered[key] = row[key]
    ordered["cited_by"] = row.get("cited_by", [])
    return ordered


def render_index(rows: List[Dict[str, Any]]) -> str:
    """Render index rows as the one-row-per-line JSON document.

    Args:
        rows: Rows to render, in the order to write them.

    Returns:
        The full index text with a trailing newline.
    """
    # WHY: one row per line, so a grep for a topic or host returns whole rows.
    lines = [json.dumps(render_row(row), ensure_ascii=False, separators=(",", ":")) for row in rows]
    head = '{"generator":%s,"guide":%s,"sources":[' % (
        json.dumps(GENERATOR),
        json.dumps(GUIDE_RELATIVE),
    )
    return head + "\n" + ",\n".join(lines) + "\n]}\n"


def build_text(found: Dict[str, Dict[str, Any]], stored: Dict[str, Dict[str, Any]]) -> str:
    """Render the index JSON, keeping the recorded fields per URL.

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
        }
        for key in CARRIED_FIELDS:
            stored_value = old.get(key)
            if stored_value is not None:
                row[key] = stored_value
        row["cited_by"] = sorted(entry["cited_by"])
        rows.append(row)
    return render_index(rows)

# ───────────────────────────────────────────────────────────────
# 5b. FRONTMATTER FIELD SET AND GLOSS MEASURE
# ───────────────────────────────────────────────────────────────

# WHY: the reference frontmatter carries one field set. A file that has a
# frontmatter block must name its own title, description and label, so a
# reader can list the tree and choose a file. checked_on stays optional,
# because it is written only where a source was checked.
FRONTMATTER_REQUIRED = ("title", "description", "nav_label")
FRONTMATTER_ALLOWED = frozenset(
    (
        "title",
        "description",
        "nav_label",
        "trigger_phrases",
        "importance_tier",
        "contextType",
        "version",
        "checked_on",
        "_memory",
    )
)
FRONTMATTER_FIELD_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):")
# WHY: the three CLI documents carry their own skill field set. The two CLI
# skills gain the nav_label of the reference set so one completed field set
# covers the top layer, and the tool fields the skill runtime reads stay.
CLI_DOCUMENTS = ("cli-moneybird/SKILL.md", "cli-jortt/SKILL.md")
BOOTSTRAP_DOCUMENT = "AGENTS.md"
CLI_FRONTMATTER_REQUIRED = ("name", "description", "allowed-tools", "version", "nav_label")
CLI_FRONTMATTER_ALLOWED = frozenset(
    ("name", "description", "allowed-tools", "version", "nav_label", "license")
)
TERM_MAP_PATH = os.path.join(SKILL_ROOT, "assets", "term-map.json")
GENERATED_START_RE = re.compile(r"^<!-- GENERATED:([a-z0-9][a-z0-9._-]*):start -->$")
GENERATED_END_RE = re.compile(r"^<!-- GENERATED:([a-z0-9][a-z0-9._-]*):end -->$")
ITEM_INDEX_BLOCK_ID = "key-figure-index"
PAREN_RE = re.compile(r"\(([^()]*)\)")
HEADING_RE = re.compile(r"^#{1,6}[ \t]+(.*?)[ \t]*$")


def resolve_source_file(source_file: Any) -> Optional[str]:
    """Resolve one stored source_file to a path under the skill root.

    The stored value is relative to the skill root. A value that repeats a
    folder, as a doubled references/tax-rules segment does, is collapsed
    before it is resolved, so the producer can repair a stored path without
    inventing a new attribution.

    Args:
        source_file: Stored value.

    Returns:
        The path relative to the skill root, or None when no normalized
        candidate is a file.
    """
    if not isinstance(source_file, str) or not source_file:
        return None
    parts = [part for part in source_file.replace("\\", "/").split("/") if part not in ("", ".")]
    if not parts or ".." in parts:
        return None
    collapsed: List[str] = []
    for part in parts:
        if not collapsed or collapsed[-1] != part:
            collapsed.append(part)
    candidates = [parts]
    if collapsed != parts:
        candidates.append(collapsed)
    for candidate in candidates:
        for start in range(len(candidate)):
            text = "/".join(candidate[start:])
            if not text:
                continue
            absolute = os.path.abspath(os.path.join(SKILL_ROOT, text))
            if os.path.isfile(absolute) and absolute.startswith(SKILL_ROOT + os.sep):
                return os.path.relpath(absolute, SKILL_ROOT).replace(os.sep, "/")
    return None


def checked_cited_files(stored: Dict[str, Dict[str, Any]]) -> List[str]:
    """List the citing paths of every source that was checked.

    Args:
        stored: Index rows keyed by URL.

    Returns:
        The cited_by paths of the rows whose checked_on is a date.
    """
    cited: List[str] = []
    for row in stored.values():
        if not row.get("checked_on"):
            continue
        for path in row.get("cited_by", []):
            if isinstance(path, str) and path:
                cited.append(path.replace(os.sep, "/"))
    return cited


def file_has_checked_source(
    relative: str,
    text: str,
    stored: Dict[str, Dict[str, Any]],
    checked_cited: List[str],
    kind: str,
) -> bool:
    """Tell whether one file may carry a checked_on date.

    A file that cites a source the index records as checked may carry the
    date. A reference file that cites no indexed source may carry it when a
    checked source is cited under its own directory, which is how a year
    README, a change note or the rules file carries the calendar stamp. Any
    other file may not.

    Args:
        relative: Path of the file relative to the repository root.
        text: File text.
        stored: Index rows keyed by URL.
        checked_cited: Result of checked_cited_files().
        kind: "reference" for the reference tree and the bootstrap, "cli"
            for the two CLI documents.

    Returns:
        True when the checked_on date has a checked source behind it.
    """
    urls: Set[str] = set()
    for raw in URL_RE.findall(text):
        url = clean_url(raw)
        if not is_skipped(url):
            urls.add(url)
    cited = [stored[url] for url in urls if url in stored]
    if any(row.get("checked_on") for row in cited):
        return True
    if kind != "reference" or cited:
        return False
    directory = os.path.dirname(relative).replace(os.sep, "/").rstrip("/") + "/"
    return any(path.startswith(directory) for path in checked_cited)


def one_frontmatter_problems(
    path: str,
    stored: Dict[str, Dict[str, Any]],
    checked_cited: List[str],
    kind: str,
    require_block: bool,
) -> List[str]:
    """List the field-set problems of one markdown file.

    Args:
        path: Absolute path of the file.
        stored: Index rows keyed by URL.
        checked_cited: Result of checked_cited_files().
        kind: "reference" or "cli".
        require_block: True when the file must carry a frontmatter block.

    Returns:
        One problem line per missing, unknown or unsupported field.
    """
    relative = os.path.relpath(path, REPO_ROOT)
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative, exc))
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        # WHY: a reference file without a frontmatter block carries no field
        # set, so it is left out. The three CLI documents must carry one, so
        # a silently absent block is reported by name there.
        if require_block:
            return ["field-set: %s has no frontmatter block" % relative]
        return []
    fields: List[str] = []
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        match = FRONTMATTER_FIELD_RE.match(line)
        if match:
            fields.append(match.group(1))
    if not closed:
        return ["field-set: %s has no closed frontmatter block" % relative]
    required = FRONTMATTER_REQUIRED if kind == "reference" else CLI_FRONTMATTER_REQUIRED
    allowed = FRONTMATTER_ALLOWED if kind == "reference" else CLI_FRONTMATTER_ALLOWED
    problems: List[str] = []
    for name in required:
        if name not in fields:
            problems.append("field-set: %s misses %s" % (relative, name))
    for name in fields:
        if name not in allowed:
            problems.append("field-set: %s carries unknown field %s" % (relative, name))
    if "checked_on" in fields and not file_has_checked_source(
        relative, text, stored, checked_cited, kind
    ):
        problems.append("field-set: %s carries checked_on with no checked source" % relative)
    return problems


def frontmatter_problems(stored: Dict[str, Dict[str, Any]]) -> List[str]:
    """List the files that break the frontmatter field set.

    The reference tree, the bootstrap document and the two CLI documents are
    checked, so one field set covers the top layer and a file without it is
    named. A file that carries checked_on must have a checked source behind
    it, as the field is written only where a source was checked.

    Args:
        stored: Index rows keyed by URL.

    Returns:
        One problem line per file, naming the file and the field.
    """
    problems: List[str] = []
    checked_cited = checked_cited_files(stored)
    for path in reference_files():
        problems += one_frontmatter_problems(path, stored, checked_cited, "reference", False)
    bootstrap = os.path.join(REPO_ROOT, BOOTSTRAP_DOCUMENT)
    if os.path.isfile(bootstrap):
        problems += one_frontmatter_problems(bootstrap, stored, checked_cited, "reference", False)
    for document in CLI_DOCUMENTS:
        path = os.path.join(REPO_ROOT, document)
        if os.path.isfile(path):
            problems += one_frontmatter_problems(path, stored, checked_cited, "cli", True)
    return problems


def top_layer_documents() -> List[str]:
    """List the top-layer documents the field-set check covers.

    Returns:
        The bootstrap document and the two CLI documents that exist.
    """
    found: List[str] = []
    bootstrap = os.path.join(REPO_ROOT, BOOTSTRAP_DOCUMENT)
    if os.path.isfile(bootstrap):
        found.append(bootstrap)
    for document in CLI_DOCUMENTS:
        path = os.path.join(REPO_ROOT, document)
        if os.path.isfile(path):
            found.append(path)
    return found


def term_map_rows() -> List[Dict[str, Any]]:
    """Read the sourced term map.

    Returns:
        The term rows, empty when the tree holds no map.

    Raises:
        SystemExit: If the file cannot be read or holds invalid JSON.
    """
    if not os.path.isfile(TERM_MAP_PATH):
        return []
    try:
        with open(TERM_MAP_PATH, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail("cannot read %s: %s" % (os.path.relpath(TERM_MAP_PATH, REPO_ROOT), exc))
    if not isinstance(data, dict):
        fail("%s holds no JSON object" % os.path.relpath(TERM_MAP_PATH, REPO_ROOT))
    return [row for row in data.get("terms", []) if isinstance(row, dict)]


def term_map_problems() -> List[str]:
    """List the term map entries that carry no source or a broken path.

    Returns:
        One problem line per entry without a term, a gloss, a source or a
        resolvable source_file, so a gloss that no Dutch source uses and a
        path that names no file never land.
    """
    problems: List[str] = []
    for row in term_map_rows():
        term = row.get("term")
        name = term if isinstance(term, str) and term else "unnamed term"
        if not isinstance(term, str) or not term:
            problems.append("term-map: an entry has no term")
            continue
        if not isinstance(row.get("gloss"), str) or not row.get("gloss"):
            problems.append("term-map: %s has no gloss" % name)
        if not isinstance(row.get("source"), str) or not row.get("source"):
            problems.append("term-map: %s has no source" % name)
        source_file = row.get("source_file")
        if not isinstance(source_file, str) or not source_file:
            problems.append("term-map: %s has no source_file" % name)
        elif resolve_source_file(source_file) is None:
            problems.append("term-map: %s source_file does not exist: %s" % (name, source_file))
    return problems


def write_term_map() -> int:
    """Rewrite the term map with every source_file resolved.

    The producer keeps the authored term, gloss and source of a row and
    rewrites only its source_file, so the path a previous run wrote is the
    only value that changes. A path that does not resolve, or a resolved file
    that does not hold the term and its source, fails the run and writes
    nothing.

    Returns:
        Zero on success.

    Raises:
        SystemExit: When the map is missing or a row does not resolve.
    """
    relative = os.path.relpath(TERM_MAP_PATH, REPO_ROOT)
    if not os.path.isfile(TERM_MAP_PATH):
        fail("no term map: %s" % relative)
    try:
        with open(TERM_MAP_PATH, "r", encoding="utf-8") as handle:
            document = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail("cannot read %s: %s" % (relative, exc))
    if not isinstance(document, dict) or not isinstance(document.get("terms"), list):
        fail("%s holds no term list" % relative)
    repaired = 0
    for row in document["terms"]:
        if not isinstance(row, dict):
            fail("the term map holds a row that is not an object")
        term = row.get("term")
        name = term if isinstance(term, str) and term else "unnamed term"
        resolved = resolve_source_file(row.get("source_file"))
        if resolved is None:
            fail("term-map: %s source_file does not resolve: %s" % (name, row.get("source_file")))
        resolved_path = os.path.join(SKILL_ROOT, resolved)
        try:
            with open(resolved_path, "r", encoding="utf-8", errors="replace") as handle:
                body = handle.read()
        except OSError as exc:
            fail("cannot read %s: %s" % (resolved, exc))
        if isinstance(term, str) and term and term not in body:
            fail("term-map: %s source_file does not name the term: %s" % (name, resolved))
        source = row.get("source")
        if isinstance(source, str) and source and source not in body:
            fail("term-map: %s source_file does not cite its source: %s" % (name, resolved))
        if row.get("source_file") != resolved:
            row["source_file"] = resolved
            repaired += 1
    document["generated_by"] = GENERATOR
    text = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    current = None
    try:
        with open(TERM_MAP_PATH, "r", encoding="utf-8", newline="") as handle:
            current = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative, exc))
    if current == text:
        print(
            "term-map: unchanged, %d rows, %d paths repaired"
            % (len(document["terms"]), repaired)
        )
        return 0
    try:
        with open(TERM_MAP_PATH, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    except OSError as exc:
        fail("cannot write %s: %s" % (relative, exc))
    print(
        "term-map: wrote %s, %d rows, %d paths repaired"
        % (relative, len(document["terms"]), repaired)
    )
    return 0


def generated_block(text: str, block_id: str) -> Optional[str]:
    """Return the body of one generated block of a markdown file.

    Args:
        text: File text.
        block_id: Fence id to read.

    Returns:
        The body text, or None when the file holds no such block.
    """
    opened: Optional[int] = None
    lines = text.split("\n")
    for index, line in enumerate(lines):
        if opened is None:
            match = GENERATED_START_RE.match(line)
            if match and match.group(1) == block_id:
                opened = index + 1
            continue
        if GENERATED_END_RE.match(line):
            return "\n".join(lines[opened:index])
    return None


def table_cells(line: str) -> List[str]:
    """Split one markdown table line into its cells.

    Args:
        line: Table line.

    Returns:
        The stripped cell texts, empty when the line is not a table line.
    """
    text = line.strip()
    if not text.startswith("|"):
        return []
    if not text.endswith("|"):
        text += "|"
    return [cell.strip() for cell in text.strip("|").split("|")]


def item_index_items(text: str) -> List[str]:
    """Read the Item cell of every row of the generated item index.

    Args:
        text: File text.

    Returns:
        The item cells, in row order.
    """
    body = generated_block(text, ITEM_INDEX_BLOCK_ID)
    if body is None:
        return []
    items: List[str] = []
    for line in body.split("\n"):
        cells = table_cells(line)
        if len(cells) >= 2 and re.fullmatch(r"\d+", cells[1]):
            items.append(cells[0])
    return items


def key_figure_source_items(text: str) -> List[str]:
    """Read the Item cell of every row of the authored KEY FIGURES table.

    The scan skips the generated item index between the heading and the
    table, so the source rows come from the table a writer authored.

    Args:
        text: File text.

    Returns:
        The item cells, in row order.
    """
    lines = text.split("\n")
    start: Optional[int] = None
    for index, line in enumerate(lines):
        heading = HEADING_RE.match(line)
        if heading and "KEY FIGURES" in heading.group(1).upper():
            start = index
            break
    if start is None:
        return []
    index = start + 1
    opened = False
    while index < len(lines):
        line = lines[index]
        if GENERATED_START_RE.match(line):
            opened = True
            index += 1
            continue
        if GENERATED_END_RE.match(line):
            opened = False
            index += 1
            continue
        if not opened and line.strip().startswith("|"):
            break
        index += 1
    if index >= len(lines):
        return []
    header = table_cells(lines[index])
    index += 1
    if index < len(lines) and set(lines[index].strip()) <= set("|-: "):
        index += 1
    column = header.index("Item") if "Item" in header else 0
    items: List[str] = []
    while index < len(lines) and lines[index].strip().startswith("|"):
        cells = table_cells(lines[index])
        if len(cells) > column:
            items.append(cells[column])
        index += 1
    return items


def unowned_gloss_problems(pairs: List[Tuple[str, str]]) -> List[str]:
    """List the glossed terms of an item index with no term-map row.

    The item index is generated from the authored KEY FIGURES table, so a
    parenthetical the source row does not carry was inserted from the term
    map. When the map holds no row that explains it, the insertion has no
    source and the check names the term.

    Args:
        pairs: The (term, gloss) pairs the map holds, longest term first.

    Returns:
        One problem line per inserted gloss that no map row explains.
    """
    problems: List[str] = []
    for path in reference_files():
        if os.path.basename(path) != "figures.md":
            continue
        relative = os.path.relpath(path, REPO_ROOT)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                text = handle.read()
        except OSError as exc:
            fail("cannot read %s: %s" % (relative, exc))
        indexed = item_index_items(text)
        source = key_figure_source_items(text)
        if not indexed or not source:
            continue
        for index_item, source_item in zip(indexed, source):
            inserted = set(PAREN_RE.findall(index_item)) - set(PAREN_RE.findall(source_item))
            for gloss in sorted(inserted):
                stop = index_item.find("(%s)" % gloss)
                if stop < 0:
                    continue
                prefix = index_item[:stop].rstrip()
                if any(
                    gloss == pair_gloss and prefix.endswith(pair_term)
                    for pair_term, pair_gloss in pairs
                ):
                    continue
                word = re.search(r"([^\s|()\[\]]+)$", prefix)
                term = word.group(1) if word else prefix[-24:]
                problems.append(
                    "gloss: %s has no term-map row for %s (%s)" % (relative, term, gloss)
                )
    return problems


def generated_bodies(path: str) -> List[str]:
    """Return the body of every generated block of one markdown file.

    Args:
        path: Absolute path of the file.

    Returns:
        The body texts, in file order.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (path, exc))
    bodies: List[str] = []
    opened: Optional[int] = None
    lines = text.split("\n")
    for index, line in enumerate(lines):
        if opened is None:
            if GENERATED_START_RE.match(line):
                opened = index + 1
            continue
        if GENERATED_END_RE.match(line):
            bodies.append("\n".join(lines[opened:index]))
            opened = None
    return bodies


def gloss_problems() -> Tuple[int, int, List[str]]:
    """Measure the first-use glosses of every generated table.

    A first use counts once per mapped term and per generated table. It is
    glossed when the term text is followed by its map gloss in parentheses.

    Returns:
        The glossed count, the first-use count and one problem line per
        first use without its gloss.
    """
    terms = term_map_rows()
    pairs = sorted(
        (
            (row["term"], row["gloss"])
            for row in terms
            if isinstance(row.get("term"), str)
            and isinstance(row.get("gloss"), str)
            and row.get("source")
        ),
        key=lambda pair: (-len(pair[0]), pair[0]),
    )
    glossed = 0
    total = 0
    problems: List[str] = []
    for path in reference_files():
        relative = os.path.relpath(path, REPO_ROOT)
        for body in generated_bodies(path):
            if "|" not in body:
                continue
            for term, gloss in pairs:
                match = re.search(r"(?<!\w)" + re.escape(term) + r"(?!\w)", body)
                if match is None:
                    continue
                total += 1
                if body[match.end():match.end() + len(gloss) + 3] == " (%s)" % gloss:
                    glossed += 1
                else:
                    problems.append("gloss: %s first use of %s carries no gloss" % (relative, term))
    problems += unowned_gloss_problems(pairs)
    return glossed, total, problems


# ───────────────────────────────────────────────────────────────
# 6. CHECK AND WRITE
# ───────────────────────────────────────────────────────────────

def dead_cited_problems(found: Dict[str, Dict[str, Any]], stored: Dict[str, Dict[str, Any]]) -> List[str]:
    """List every row recorded dead that a file still cites.

    Args:
        found: Result of scan().
        stored: Result of load_index().

    Returns:
        One problem line per dead row the scan still finds, with its citing
        files. A dead row no file cites any more is an uncited problem instead.
    """
    problems = []
    for url in sorted(stored):
        if stored[url].get("access") != "dead" or url not in found:
            continue
        citing = sorted(found[url]["cited_by"])
        if not citing:
            continue
        problems.append("dead cited: %s cited by: %s" % (url, ", ".join(citing)))
    return problems


def perishable_problems(stored: Dict[str, Dict[str, Any]]) -> List[str]:
    """List every perishable Tweede Kamer address without a pending kst marker.

    Args:
        stored: Result of load_index().

    Returns:
        One problem line per occurrence, with its file and line.
    """
    problems = []
    for path in reference_files():
        relative = os.path.relpath(path, REPO_ROOT)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.readlines()
        except OSError as exc:
            fail("cannot read %s: %s" % (relative, exc))
        for number, line in enumerate(lines, start=1):
            for raw in PERISHABLE_RE.findall(line):
                url = clean_url(raw)
                if stored.get(url, {}).get("kst_pending"):
                    continue
                problems.append("perishable: %s:%d %s" % (relative, number, url))
    return problems


def guide_count_problems(stored: Dict[str, Dict[str, Any]]) -> List[str]:
    """Compare the guide's section 1 count table with the index.

    Args:
        stored: Result of load_index().

    Returns:
        One problem line per measure that disagrees. A guide without the table
        is left alone, and a guide that states one measure must state them all,
        because a half-refreshed table is drift as well.
    """
    if not os.path.isfile(GUIDE_PATH):
        return []
    try:
        with open(GUIDE_PATH, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read the source guide: %s" % exc)
    known = dict(GUIDE_COUNT_MEASURES)
    stated: Dict[str, Optional[int]] = {}
    collecting = False
    for line in text.splitlines():
        cells = table_cells(line)
        if not collecting:
            # WHY: the section 1 table is the one with the Measure and Count
            # header, so a later table that reuses a measure word is ignored.
            if len(cells) == 2 and cells == ["Measure", "Count"]:
                collecting = True
            continue
        if cells and all(cell and set(cell) <= set("-:") for cell in cells):
            continue
        if len(cells) != 2 or cells[0] not in known:
            break
        value = cells[1].replace(",", "").strip()
        stated[cells[0]] = int(value) if value.isdigit() else None
    # WHY: a fixture guide without the table is not this check's business, but
    # one stated measure means the table is in play and must agree in full.
    if not stated:
        return []
    problems = []
    for label, access in GUIDE_COUNT_MEASURES:
        if label not in stated:
            problems.append("guide count: %s row is missing" % label)
            continue
        if stated[label] is None:
            problems.append("guide count: %s is not a number" % label)
            continue
        if access is None:
            expected = len(stored)
        else:
            expected = sum(1 for row in stored.values() if row.get("access") == access)
        if stated[label] != expected:
            problems.append(
                "guide count: %s states %d but the index holds %d" % (label, stated[label], expected)
            )
    return problems


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
    problems += dead_cited_problems(found, stored)
    problems += perishable_problems(stored)
    problems += guide_count_problems(stored)
    problems += frontmatter_problems(stored)
    problems += term_map_problems()
    glossed, first_uses, gloss_lines = gloss_problems()
    problems += gloss_lines
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
    print("gloss measure: glossed %d of %d strict first uses" % (glossed, first_uses))
    print(
        "field-set report: %d reference files and %d top-layer documents carry the required fields"
        % (len(reference_files()), len(top_layer_documents()))
    )
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


def apply_report(path: str) -> int:
    """Write the fields of a link report into the matching index rows.

    A blocked row is left untouched. A host that refuses this client says
    nothing about the page, so no field is written and the row stays out of
    the update count. The skipped blocked rows are counted on stdout.

    Args:
        path: Path to the JSON report a --check-links run printed.

    Returns:
        Zero on success.

    Raises:
        SystemExit: With code 2 when the report is missing or unreadable, or
        when the index cannot be written.
    """
    if not os.path.isfile(path):
        fail("no such report: %s" % path)
    try:
        with open(path, "r", encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read the report: %s" % exc)
    rows = report.get("rows") if isinstance(report, dict) else None
    if not isinstance(rows, list):
        fail("the report holds no rows")
    checked_on = report.get("checked_on")
    if not isinstance(checked_on, str):
        checked_on = datetime.date.today().isoformat()
    document = read_index()
    by_url = {row.get("url"): row for row in document["sources"] if isinstance(row, dict)}
    updated = 0
    blocked = 0
    for entry in rows:
        if not isinstance(entry, dict):
            continue
        url = entry.get("url")
        row = by_url.get(url)
        if row is None:
            continue
        result = entry.get("result")
        if result not in ("ok", "dead", "blocked", "redirect", "error"):
            continue
        if result == "blocked":
            # WHY: a host that turns this client away says nothing about the
            # page, so every stored field stays and the row is not an update.
            blocked += 1
            continue
        recorded = entry.get("recorded_access") or row.get("access", "unchecked")
        if result == "ok":
            # WHY: a reading class says how the page is read, not whether it answered.
            row["access"] = recorded if recorded in KEEP_ACCESS else "ok"
        elif result == "dead":
            row["access"] = "dead"
        else:
            # WHY: a transport failure says nothing about the page, so the row
            # keeps its recorded access and its digest.
            row["access"] = row.get("access", recorded)
        row["http_status"] = entry.get("http_status")
        row["checked_on"] = checked_on
        if result == "ok":
            for key in ("digest", "retrieved_at", "last_modified"):
                value = entry.get(key)
                if value is not None:
                    row[key] = value
            # WHY: a report from an earlier run may hold a raw header value, so
            # the index always stores the fingerprint of it.
            etag = etag_fingerprint(entry.get("etag"))
            if etag is not None:
                row["etag"] = etag
        updated += 1
    expected = render_index(document["sources"])
    current = None
    if os.path.isfile(INDEX_PATH):
        with open(INDEX_PATH, "r", encoding="utf-8", newline="") as handle:
            current = handle.read()
    if current == expected:
        print("%d rows updated, index unchanged" % updated)
        if blocked:
            print("%d blocked rows left unchanged" % blocked)
        return 0
    try:
        with open(INDEX_PATH, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(expected)
    except OSError as exc:
        fail("cannot write the index: %s" % exc)
    print("%d rows updated, wrote %s" % (updated, os.path.relpath(INDEX_PATH, REPO_ROOT)))
    if blocked:
        print("%d blocked rows left unchanged" % blocked)
    return 0

# ───────────────────────────────────────────────────────────────
# 6. LINK CHECK AND TRACE
# ───────────────────────────────────────────────────────────────

class PermanentRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Follow a 308 Permanent Redirect on every supported Python.

    Python before 3.11 has no http_error_308 and refuses code 308 in
    redirect_request, so a 308 stops the fetch and a live page reports as a
    redirect. The base class follows 307, the other method-preserving
    redirect, so this subclass sends 308 down that path and keeps the base
    class redirect cap.
    """

    def http_error_308(self, req: Any, fp: Any, code: int, msg: str, headers: Any) -> Any:
        """Send a 308 through the 307 path.

        Args:
            req: Request that got the redirect.
            fp: Response file object.
            code: HTTP status code, 308.
            msg: HTTP reason phrase.
            headers: Response headers.

        Returns:
            The response of the followed request.
        """
        return self.http_error_307(req, fp, code, msg, headers)

    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> Any:
        """Accept 308 beside the codes the base class accepts.

        Args:
            req: Request that got the redirect.
            fp: Response file object.
            code: HTTP status code.
            msg: HTTP reason phrase.
            headers: Response headers.
            newurl: Location to fetch next.

        Returns:
            The follow-up request, or None when the base class declines.
        """
        if code == 308:
            code = 307
        return super().redirect_request(req, fp, code, msg, headers, newurl)


# WHY: one opener per process follows 308 beside the codes the default follows.
FETCH_OPENER = urllib.request.build_opener(PermanentRedirectHandler())


def fetch_page(url: str, kind: str) -> Dict[str, Any]:
    """Fetch one URL and report its final status, headers and digest.

    Args:
        url: URL to fetch.
        kind: "pdf" to hash the raw bytes, anything else hashes the page text.

    Returns:
        A dict with status, error, etag, last_modified, digest and retrieved_at.
        The etag is already the stored fingerprint of the header value. Status
        is None when every attempt raised a transport error. An HTTP
        error keeps its status, and a 5xx is retried before its status is
        returned. Digest and retrieved_at stay None when the answer was not a
        2xx or the body passed the digest cap.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    last_status = None
    last_headers: Dict[str, Any] = {}
    for _ in range(FETCH_ATTEMPTS):
        try:
            # WHY: the opener follows redirects, including a 308 that Python
            # before 3.11 leaves unfollowed, so a moved page reports its final
            # status.
            with FETCH_OPENER.open(request, timeout=FETCH_TIMEOUT) as response:
                body = response.read(DIGEST_MAX_BYTES + 1)
                result = {
                    "status": response.status,
                    "error": None,
                    "etag": etag_fingerprint(response.headers.get("ETag")),
                    "last_modified": response.headers.get("Last-Modified"),
                    "digest": None,
                    "retrieved_at": None,
                }
                if 200 <= response.status < 300 and len(body) <= DIGEST_MAX_BYTES:
                    result["digest"] = digest_page(body, kind)
                    result["retrieved_at"] = datetime.date.today().isoformat()
                return result
        except urllib.error.HTTPError as exc:
            # WHY: a 3xx here is a redirect urllib could not follow and a 4xx is
            # an answer, so only a 5xx is worth one retry. A 5xx keeps its
            # status after the retries, so an answered failure is recorded.
            headers = exc.headers if exc.headers is not None else {}
            if exc.code < 500:
                return {
                    "status": exc.code,
                    "error": None,
                    "etag": etag_fingerprint(headers.get("ETag")),
                    "last_modified": headers.get("Last-Modified"),
                    "digest": None,
                    "retrieved_at": None,
                }
            last_error = "HTTP %d" % exc.code
            last_status = exc.code
            last_headers = headers
        except (urllib.error.URLError, OSError, ValueError) as exc:
            last_error = str(exc)
            last_status = None
            last_headers = {}
    return {
        "status": last_status,
        "error": last_error,
        "etag": etag_fingerprint(last_headers.get("ETag")),
        "last_modified": last_headers.get("Last-Modified"),
        "digest": None,
        "retrieved_at": None,
    }


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
        "blocked": 0,
        "redirects": 0,
        "errors": 0,
        "skipped": 0,
        "endpoints_skipped": 0,
        "recovered": 0,
        "known_unfetchable": 0,
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
        fetched = fetch_page(url, stored[url].get("type") or guess_type(url))
        status = fetched["status"]
        if fetched["error"] is not None:
            entry.update(result="error", http_status=None, reason=fetched["error"])
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
        elif status is not None and status in BLOCKED_STATUSES:
            # WHY: a refused client is not a missing page, so a 401, 403 or
            # 429 gets its own result and stays out of failures.
            entry.update(result="blocked", http_status=status)
            summary["blocked"] += 1
        else:
            entry.update(result="dead", http_status=status)
            summary["dead"] += 1
        entry.update(
            etag=fetched["etag"],
            last_modified=fetched["last_modified"],
            digest=fetched["digest"],
            retrieved_at=fetched["retrieved_at"],
        )
        # WHY: a row recorded dead, or recorded as unfetchable by nature, is a
        # known finding. Both are reported in the row and kept out of the
        # failure count. A blocked row stays out of the count as well. A row
        # recorded ok that errors must still fail.
        if entry["result"] in ("dead", "error", "redirect"):
            if access in ("dead", "archive-not-fetchable"):
                summary["known_unfetchable"] += 1
            else:
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
# 7. WATCH
# ───────────────────────────────────────────────────────────────

def load_watchlist() -> List[Dict[str, Any]]:
    """Read the watched series from the source watchlist.

    Returns:
        The list of series, each with a name, URLs, a cadence and a reason.

    Raises:
        SystemExit: With code 2 when the file is missing or invalid.
    """
    if not os.path.isfile(WATCHLIST_PATH):
        fail("no watchlist: %s" % os.path.relpath(WATCHLIST_PATH, REPO_ROOT))
    try:
        with open(WATCHLIST_PATH, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read the watchlist: %s" % exc)
    if isinstance(data, list):
        series = data
    elif isinstance(data, dict):
        series = data.get("series")
    else:
        series = None
    if not isinstance(series, list) or not series:
        fail("the watchlist holds no series")
    for entry in series:
        if not isinstance(entry, dict):
            fail("a watched series is not an object")
        name = entry.get("series")
        if not isinstance(name, str) or not name.strip():
            fail("a watched series has no name")
        urls = entry.get("urls")
        if not isinstance(urls, list) or not urls or not all(isinstance(url, str) for url in urls):
            fail("watched series %r has no URL list" % name)
        if entry.get("cadence") not in CADENCES:
            fail("watched series %r has cadence %r" % (name, entry.get("cadence")))
    return series


def load_state(path: Optional[str]) -> Dict[str, Dict[str, Any]]:
    """Read the stored watch values for URLs the index does not hold.

    Args:
        path: State file, or None when the run keeps no state.

    Returns:
        Mapping of URL to its stored watch values.

    Raises:
        SystemExit: With code 2 when the file exists but is invalid.
    """
    if not path or not os.path.isfile(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read the state file: %s" % exc)
    if not isinstance(data, dict):
        fail("the state file is not an object")
    urls = data.get("urls", data)
    if not isinstance(urls, dict):
        fail("the state file holds no URL map")
    for url, values in urls.items():
        if not isinstance(values, dict):
            fail("the state file entry for %s is not an object" % url)
    return urls


def write_state(path: str, state: Dict[str, Dict[str, Any]], today: str) -> None:
    """Write the stored watch values back to the state file.

    Args:
        path: State file to write.
        state: Mapping of URL to its stored watch values.
        today: Date of this run.

    Raises:
        OSError: If the file cannot be written.
    """
    payload = {"generator": GENERATOR, "updated_at": today, "urls": state}
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


def watch(state_path: Optional[str], stored: Dict[str, Dict[str, Any]]) -> int:
    """Fetch every watched URL and report each changed series.

    Args:
        state_path: State file to read and write, or None to read only the
            default state file when it exists.
        stored: Result of load_index().

    Returns:
        Zero when no series changed, one when at least one did.

    Raises:
        SystemExit: With code 2 on a usage error.
    """
    series_list = load_watchlist()
    read_path = state_path
    if read_path is None and os.path.isfile(WATCH_STATE_PATH):
        read_path = WATCH_STATE_PATH
    state = load_state(read_path)
    today = datetime.date.today().isoformat()
    changed = 0
    failures = 0
    blocked = 0
    for series in series_list:
        name = series["series"]
        for url in series["urls"]:
            if url in stored:
                recorded = stored[url]
            else:
                recorded = state.get(url) or {}
            if is_endpoint(url) or recorded.get("access") in SKIP_FETCH_ACCESS:
                print("skipped series=%s url=%s reason=%s" % (name, url, recorded.get("access") or "endpoint"))
                continue
            fetched = fetch_page(url, guess_type(url))
            status = fetched["status"]
            if fetched["error"] is not None or status is None:
                failures += 1
                print("failed series=%s url=%s reason=%s" % (name, url, fetched["error"]))
            if status is None:
                continue
            if status in BLOCKED_STATUSES:
                # WHY: a refused client says nothing about the page, so the
                # stored values stay and no change is reported.
                blocked += 1
                print("blocked series=%s url=%s status=%d" % (name, url, status))
                continue
            reasons = []
            if 200 <= status < 300:
                if recorded.get("access") == "dead" or recorded.get("http_status") == 404:
                    reasons.append("answers 200 after 404")
                # WHY: the stored value may be a raw tag from an older index,
                # so both sides are compared as fingerprints.
                if recorded.get("etag") and fetched["etag"] \
                        and etag_fingerprint(recorded["etag"]) != etag_fingerprint(fetched["etag"]):
                    reasons.append("etag changed")
                if recorded.get("last_modified") and fetched["last_modified"] \
                        and recorded["last_modified"] != fetched["last_modified"]:
                    reasons.append("last-modified changed")
                if recorded.get("digest") and fetched["digest"] and recorded["digest"] != fetched["digest"]:
                    reasons.append("digest changed")
            if reasons:
                changed += 1
                citing = stored.get(url, {}).get("cited_by", [])
                print("changed series=%s url=%s reason=%s cited by: %s" % (
                    name,
                    url,
                    ", ".join(reasons),
                    ", ".join(citing) if citing else "-",
                ))
            if state_path:
                # WHY: a non-2xx answer gets no digest, so the earlier digest
                # stays and a later 200 can still be compared.
                state[url] = {
                    "http_status": status,
                    "etag": fetched["etag"] if fetched["etag"] is not None else etag_fingerprint(recorded.get("etag")),
                    "last_modified": fetched["last_modified"] if fetched["last_modified"] is not None else recorded.get("last_modified"),
                    "digest": fetched["digest"] if fetched["digest"] is not None else recorded.get("digest"),
                    "retrieved_at": fetched["retrieved_at"] if fetched["retrieved_at"] is not None else recorded.get("retrieved_at"),
                }
    if state_path:
        try:
            write_state(state_path, state, today)
        except OSError as exc:
            fail("cannot write the state file: %s" % exc)
    if failures:
        print("%d watched URLs did not answer" % failures)
    if blocked:
        print("%d watched URLs were blocked" % blocked)
    if changed:
        print("%d watched URLs changed" % changed)
        return 1
    print("no watched URL changed")
    return 0

# ───────────────────────────────────────────────────────────────
# 8. CALENDAR
# ───────────────────────────────────────────────────────────────

def load_checkpoints() -> Optional[List[Tuple[str, datetime.date]]]:
    """Read the checkpoint table from the rollover runbook.

    Returns:
        One (name, date) pair per checkpoint, or None when the runbook, its
        header row or every dated row is missing.
    """
    if not os.path.isfile(ROLLOVER_PATH):
        return None
    try:
        with open(ROLLOVER_PATH, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
    except OSError:
        return None
    checkpoints: List[Tuple[str, datetime.date]] = []
    in_table = False
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|"):
            if in_table:
                break
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if not in_table:
            if cells[:3] == list(CHECKPOINT_HEADER):
                in_table = True
            continue
        if len(cells) < 3 or not cells[0] or set(cells[0]) <= set("-: "):
            continue
        day = parse_iso_date(cells[1].strip('"').strip("'"))
        if day is None:
            continue
        checkpoints.append((cells[0].strip('"').strip("'"), day))
    if not in_table or not checkpoints:
        return None
    return checkpoints


def check_calendar(today_text: Optional[str]) -> int:
    """Check every current or future year file against the calendar.

    Args:
        today_text: ISO date the check runs as, or None for the real date.

    Returns:
        Zero when every current or future year is fresh, one when a file is
        stale or carries no checked_on.

    Raises:
        SystemExit: With code 2 on a usage error or a missing checkpoint table.
    """
    if today_text is None:
        today = datetime.date.today()
    else:
        parsed = parse_iso_date(today_text)
        if parsed is None:
            fail("usage: --today wants YYYY-MM-DD")
        today = parsed
    checkpoints = load_checkpoints()
    if checkpoints is None:
        fail("no checkpoint table in %s" % os.path.relpath(ROLLOVER_PATH, REPO_ROOT))
    passed = [checkpoint for checkpoint in checkpoints if checkpoint[1] <= today]
    if not passed:
        print("no checkpoint has passed by %s, nothing to compare" % today.isoformat())
        return 0
    name, day = max(passed, key=lambda checkpoint: checkpoint[1])
    base = os.path.join(REFERENCES_DIR, "tax-rules")
    targets = []
    if os.path.isdir(base):
        for folder in sorted(os.listdir(base)):
            if not YEAR_RE.match(folder) or int(folder) < today.year:
                continue
            readme = os.path.join(base, folder, "README.md")
            if os.path.isfile(readme):
                targets.append(readme)
    # WHY: the rules file states which year applies, so it always counts as current.
    targets.append(os.path.join(base, "dutch-tax-rules.md"))
    problems = 0
    for path in targets:
        relative = os.path.relpath(path, REPO_ROOT)
        checked_on = frontmatter_value(path, "checked_on")
        day_checked = parse_iso_date(checked_on)
        if day_checked is None:
            print("missing: %s has no checked_on" % relative)
            problems += 1
        elif day_checked < day:
            print("stale: %s checked_on=%s before checkpoint %s %s" % (
                relative,
                day_checked.isoformat(),
                name,
                day.isoformat(),
            ))
            problems += 1
    if problems:
        return 1
    print("%d files current at the %s checkpoint (%s)" % (len(targets), name, day.isoformat()))
    return 0

# ───────────────────────────────────────────────────────────────
# 9. ENTRY POINT
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
        "--apply-report",
        metavar="<file>",
        help="write a link report into the matching index rows",
    )
    mode.add_argument(
        "--watch",
        action="store_true",
        help="fetch the watched series and report every change",
    )
    mode.add_argument(
        "--check-calendar",
        action="store_true",
        help="check the year files against the rollover calendar",
    )
    mode.add_argument(
        "--trace",
        metavar="<file>:<line>",
        help="print the index result for the URLs on one line of one file",
    )
    mode.add_argument(
        "--write-term-map",
        action="store_true",
        help="rewrite assets/term-map.json with every source_file resolved",
    )
    parser.add_argument(
        "--state",
        metavar="<file>",
        help="state file to read and write for watched URLs the index does not hold",
    )
    parser.add_argument(
        "--today",
        metavar="YYYY-MM-DD",
        help="date the calendar check runs as",
    )
    args = parser.parse_args(argv)
    if args.state and not args.watch:
        fail("usage: --state needs --watch")
    if args.today and not args.check_calendar:
        fail("usage: --today needs --check-calendar")
    if args.write_term_map:
        return write_term_map()
    if args.check_calendar:
        return check_calendar(args.today)
    stored = load_index()
    if args.watch:
        return watch(args.state, stored)
    if args.check_links:
        if not stored:
            fail("no index to check: %s" % os.path.relpath(INDEX_PATH, REPO_ROOT))
        return check_links(stored)
    if args.apply_report:
        return apply_report(args.apply_report)
    if args.trace:
        return trace_line(args.trace, stored)
    found = scan()
    expected = build_text(found, stored)
    if args.check:
        return check_index(found, stored, expected)
    return write_index(expected, len(found))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
