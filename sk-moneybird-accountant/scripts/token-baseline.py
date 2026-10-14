#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: TOKEN BASELINE
# ───────────────────────────────────────────────────────────────
"""Count the reference corpus in two pinned encodings and write or check the baseline.

Walks every markdown file under sk-moneybird-accountant/references/ and counts
its UTF-8 bytes and its tokens in cl100k_base and o200k_base, whole file and
per H2 section. It adds the named units, the corpus total, the 2026 car topic
file, the 2026 year README, SKILL.md and the two car routes, and the overhead
rows for the generated nav and toc block bodies and for references/index.json.
The run writes one JSON file or checks it and is offline and byte-stable.

The Operator chose o200k_base as the stand-in for the executing models on
2026-10-12, with cl100k_base kept as a second column. Both encodings are
proxies, so every count stands in for a model family and none is exact.
Re-measure on every reference change, because a content edit moves the counts.

Offline rule: the two encoding data files must sit in TIKTOKEN_CACHE_DIR under
the name tiktoken derives for them, the sha1 hex of their data URL. The run
checks that each file exists and that its sha256 matches the pin below before
it loads an encoding, so a missing file or a changed file stops the run with
exit code 2 instead of starting a download.

Pinned encoding data, sha256 of each cached file:
    cl100k_base  223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7
    o200k_base   446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d

The encoding library sits outside the standard library. The run works under
the plain interpreter and under an isolated one, where it adds the user
site directory that the isolated mode leaves out.

Usage:
    TIKTOKEN_CACHE_DIR=<cache> python3 sk-moneybird-accountant/scripts/token-baseline.py
    TIKTOKEN_CACHE_DIR=<cache> python3 sk-moneybird-accountant/scripts/token-baseline.py --check

Options:
    --check     Recompute every count in memory, compare with the baseline
                file and report each drifted row. Writes nothing and exits 1
                on drift.

Output:
    sk-moneybird-accountant/benchmark/token-baseline.json in write mode, the
    named unit rows and the car route ratio in both modes, and one drift line
    per stale row in check mode. Exit 0 when the file is written or matches,
    1 on drift, and 2 on a missing encoding cache, a pin mismatch, an
    unreadable file or a write error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import hashlib
import json
import os
import re
import site
import sys
import tempfile
import warnings
from typing import Any, Dict, List, NoReturn, Optional, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

PROGRAM = "token-baseline"
GENERATOR = "sk-moneybird-accountant/scripts/token-baseline.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKILL_ROOT = os.path.join(REPO_ROOT, "sk-moneybird-accountant")
REFERENCES_ROOT = os.path.join(SKILL_ROOT, "references")
INDEX_PATH = os.path.join(REFERENCES_ROOT, "index.json")
BASELINE_PATH = os.path.join(SKILL_ROOT, "benchmark", "token-baseline.json")

MARKDOWN_SUFFIX = ".md"
CODE_FENCE_PREFIXES = ("```", "~~~")
HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.*?)[ \t]*$")
SLUG_RE = re.compile(r"[^\w\s-]", re.UNICODE)
SPACE_RE = re.compile(r"\s+")

# A generated block sits between two marker lines that each stand alone. The
# body is what a reader loads, so the overhead rows count the bytes between
# the markers and never the markers themselves.
FENCE_START_RE = re.compile(r"^<!-- GENERATED:([a-z0-9][a-z0-9._-]*):start -->$")
FENCE_END_RE = re.compile(r"^<!-- GENERATED:([a-z0-9][a-z0-9._-]*):end -->$")
NAV_BLOCK_ID = "nav"
TOC_BLOCK_ID = "toc"
BLOCK_IDS = (NAV_BLOCK_ID, TOC_BLOCK_ID)

# The pin. The url is the data URL tiktoken asks for, the sha1 of that url is
# the cache file name, and the sha256 is the hash of the file itself.
ENCODINGS: Tuple[Dict[str, str], ...] = (
    {
        "name": "cl100k_base",
        "sha256": "223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7",
        "url": "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken",
    },
    {
        "name": "o200k_base",
        "sha256": "446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d",
        "url": "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken",
    },
)
ENCODING_NAMES = tuple(entry["name"] for entry in ENCODINGS)
LEAD_ENCODING = "o200k_base"
SECOND_ENCODING = "cl100k_base"
LIBRARY_NAME = "tiktoken"
LIBRARY_VERSION = "0.11.0"
CACHE_ENV = "TIKTOKEN_CACHE_DIR"

NAV_NAME = "nav block bodies"
TOC_NAME = "toc block bodies"
INDEX_NAME = "references/index.json"
CORPUS_NAME = "corpus total"
CAR_CURRENT_NAME = "car route current"
CAR_PROPOSED_NAME = "car route proposed"
CAR_SECTION_ANCHOR = "2-key-figures"

REMEASURE_RULE = "re-measure on every reference change"
PROXY_NOTE = (
    "Both encodings are proxies for the tokenizers of the executing models. "
    "No public encoding matches them exactly, so every count stands in for a "
    "model family."
)

# WHY: the transport module that the encoding library imports warns about a
# library version that matters for a network call, and this run makes none.
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL")

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
    print("%s: %s" % (PROGRAM, message), file=sys.stderr)
    sys.exit(2)


def relative_path(path: str) -> str:
    """Return a file path relative to the repository root.

    Args:
        path: Absolute or relative path.

    Returns:
        The path relative to the repository root.
    """
    return os.path.relpath(path, REPO_ROOT)


def default_mode() -> int:
    """Return the mode a new file gets under the current umask.

    Returns:
        The read and write bits that the umask leaves open.
    """
    current = os.umask(0)
    os.umask(current)
    return 0o666 & ~current


def read_text(path: str) -> str:
    """Read one file as UTF-8 text.

    Args:
        path: File to read.

    Returns:
        The file text.

    Raises:
        SystemExit: If the file cannot be read or is not UTF-8.
    """
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative_path(path), exc))
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail("not utf-8 %s: %s" % (relative_path(path), exc))


def line_spans(text: str) -> List[Tuple[int, str, int, int]]:
    """Split text into lines with their numbers and character offsets.

    A line keeps its ending out of the content, and the offsets cover the
    whole text, so slicing on the offsets reproduces the input.

    Args:
        text: File text.

    Returns:
        List of (line number, content, start offset, end offset).
    """
    spans: List[Tuple[int, str, int, int]] = []
    start = 0
    number = 0
    length = len(text)
    while start < length:
        newline = text.find("\n", start)
        number += 1
        if newline == -1:
            spans.append((number, text[start:].rstrip("\r"), start, length))
            break
        spans.append((number, text[start:newline].rstrip("\r"), start, newline + 1))
        start = newline + 1
    return spans


def frontmatter_end(spans: List[Tuple[int, str, int, int]]) -> int:
    """Return the index of the first line after a leading frontmatter block.

    Args:
        spans: Result of line_spans().

    Returns:
        The index of the first content line, zero when no frontmatter block is
        closed.
    """
    if not spans or spans[0][1].strip() != "---":
        return 0
    for index in range(1, len(spans)):
        if spans[index][1].strip() == "---":
            return index + 1
    return 0


def slugify(heading: str) -> str:
    """Return the anchor slug of a heading.

    Args:
        heading: Heading text.

    Returns:
        The lower case slug with punctuation dropped and spaces as hyphens.
    """
    text = SLUG_RE.sub("", heading.strip().lower())
    return SPACE_RE.sub("-", text.strip())


def h2_sections(text: str) -> List[Dict[str, Any]]:
    """Split one markdown file into its H2 sections.

    A section runs from its heading line to the line before the next H2, so
    the blank and separator lines between two sections belong to the earlier
    one. A heading inside frontmatter or inside a code fence is no heading.
    The title keeps the number that the heading carries.

    Args:
        text: File text.

    Returns:
        Rows in file order with the anchor, the heading line number, the line
        count, the heading line offset, the title and the slice text.
    """
    spans = line_spans(text)
    total = len(spans)
    headings: List[Tuple[int, str, int]] = []
    in_code = False
    for number, content, start, _ in spans[frontmatter_end(spans):]:
        if content.strip().startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = HEADING_RE.match(content)
        if not match or len(match.group(1)) != 2:
            continue
        headings.append((number, match.group(2).strip(), start))
    rows: List[Dict[str, Any]] = []
    used: Dict[str, int] = {}
    for index, (number, title, start) in enumerate(headings):
        last_heading = index + 1 < len(headings)
        stop = headings[index + 1][2] if last_heading else len(text)
        base = slugify(title)
        count = used.get(base, 0)
        used[base] = count + 1
        rows.append(
            {
                # WHY: a repeated heading takes a numbered suffix, as an anchor does.
                "anchor": base if count == 0 else "%s-%d" % (base, count),
                "line": number,
                "lines": (headings[index + 1][0] - number) if last_heading else (total - number + 1),
                "text": text[start:stop],
                "title": title,
            }
        )
    return rows


def count_tokens(text: str, encoders: Dict[str, Any]) -> Dict[str, int]:
    """Count the tokens of one text in every encoding.

    A special token spelling in the text counts as ordinary text, so a
    document never raises on that ground and the count stays a body count.

    Args:
        text: Text to count.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        Token count by encoding name.
    """
    return {name: len(encoder.encode_ordinary(text)) for name, encoder in encoders.items()}


def count_bytes(text: str) -> int:
    """Count the UTF-8 bytes of one text.

    Args:
        text: Text to measure.

    Returns:
        The byte count.
    """
    return len(text.encode("utf-8"))


def token_text(counts: Dict[str, int]) -> str:
    """Render one token count per encoding, the lead encoding first.

    Args:
        counts: Token count by encoding name.

    Returns:
        One comma separated list of name and count.
    """
    order = [LEAD_ENCODING] + [name for name in ENCODING_NAMES if name != LEAD_ENCODING]
    return ", ".join("%s %d" % (name, counts[name]) for name in order)


def ratio_text(ratios: Dict[str, float]) -> str:
    """Render the route ratio per encoding, the lead encoding first.

    Args:
        ratios: Ratio by encoding name.

    Returns:
        One comma separated list of name and ratio.
    """
    order = [LEAD_ENCODING] + [name for name in ENCODING_NAMES if name != LEAD_ENCODING]
    return ", ".join("%s %.4f" % (name, ratios[name]) for name in order)

# ───────────────────────────────────────────────────────────────
# 4. CACHE PIN
# ───────────────────────────────────────────────────────────────

def cache_file_name(url: str) -> str:
    """Return the cache file name tiktoken derives from a data URL.

    Args:
        url: Data URL of one encoding.

    Returns:
        The sha1 hex of the URL, the name tiktoken looks up in the cache.
    """
    return hashlib.sha1(url.encode()).hexdigest()


def cache_dir() -> str:
    """Return the encoding cache directory.

    Returns:
        The value of TIKTOKEN_CACHE_DIR.

    Raises:
        SystemExit: When the variable is unset or empty, because a download
        would follow.
    """
    directory = os.environ.get(CACHE_ENV, "")
    if not directory:
        fail(
            "missing encoding cache %s (%s is not set)"
            % (ENCODING_NAMES[0], CACHE_ENV)
        )
    return directory


def check_cache(directory: str) -> None:
    """Check both encoding data files against the pin before any count runs.

    Args:
        directory: Value of TIKTOKEN_CACHE_DIR.

    Raises:
        SystemExit: When a cache file is missing or its sha256 differs from
        the pin.
    """
    for entry in ENCODINGS:
        name = entry["name"]
        path = os.path.join(directory, cache_file_name(entry["url"]))
        if not os.path.isfile(path):
            fail("missing encoding cache %s (%s)" % (name, cache_file_name(entry["url"])))
        try:
            with open(path, "rb") as handle:
                data = handle.read()
        except OSError as exc:
            fail("missing encoding cache %s (%s: %s)" % (name, cache_file_name(entry["url"]), exc))
        digest = hashlib.sha256(data).hexdigest()
        if digest != entry["sha256"]:
            fail(
                "pin mismatch %s (%s, sha256 %s)"
                % (name, cache_file_name(entry["url"]), digest)
            )


def add_user_site() -> None:
    """Add the user site directory to the import path when it is missing.

    An isolated interpreter leaves the user site directory out of the path,
    and the encoding library sits there on this machine. The directory goes
    last, which is where a plain interpreter keeps it.
    """
    user_site = site.getusersitepackages()
    if user_site and os.path.isdir(user_site) and user_site not in sys.path:
        sys.path.append(user_site)


def load_encoders() -> Dict[str, Any]:
    """Load the two pinned encoders from the local cache.

    Returns:
        Mapping of encoding name to an encoder.

    Raises:
        SystemExit: When the library is missing or its version is not the
        pinned one.
    """
    add_user_site()
    try:
        import tiktoken
    except ImportError as exc:
        fail("cannot import %s: %s" % (LIBRARY_NAME, exc))
    version = getattr(tiktoken, "__version__", "unknown")
    if version != LIBRARY_VERSION:
        fail(
            "pin mismatch %s (pinned %s, found %s)"
            % (LIBRARY_NAME, LIBRARY_VERSION, version)
        )
    return {name: tiktoken.get_encoding(name) for name in ENCODING_NAMES}

# ───────────────────────────────────────────────────────────────
# 5. BASELINE
# ───────────────────────────────────────────────────────────────

def markdown_files() -> List[str]:
    """List every markdown file under the references root.

    Returns:
        Sorted absolute paths.
    """
    found: List[str] = []
    for directory, _, names in os.walk(REFERENCES_ROOT):
        for name in names:
            if name.endswith(MARKDOWN_SUFFIX):
                found.append(os.path.join(directory, name))
    return sorted(found)


def file_row(path: str, encoders: Dict[str, Any]) -> Dict[str, Any]:
    """Count one markdown file, whole file and per H2 section.

    Args:
        path: Absolute path of the file.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        A row with the path, the byte count, the token counts and the section
        rows.
    """
    text = read_text(path)
    sections = [
        {
            "anchor": item["anchor"],
            "bytes": count_bytes(item["text"]),
            "line": item["line"],
            "lines": item["lines"],
            "title": item["title"],
            "tokens": count_tokens(item["text"], encoders),
        }
        for item in h2_sections(text)
    ]
    return {
        "bytes": count_bytes(text),
        "path": relative_path(path),
        "sections": sections,
        "tokens": count_tokens(text, encoders),
    }


def block_bodies(text: str, path: str) -> Dict[str, List[str]]:
    """Collect the body of every nav and toc block in one file.

    Args:
        text: File text.
        path: Absolute path of the file, for the error message.

    Returns:
        Mapping of block id to its bodies, in file order.

    Raises:
        SystemExit: When a start marker has no end marker.
    """
    bodies: Dict[str, List[str]] = {}
    lines = line_spans(text)
    index = 0
    while index < len(lines):
        match = FENCE_START_RE.match(lines[index][1])
        if not match or match.group(1) not in BLOCK_IDS:
            index += 1
            continue
        block_id = match.group(1)
        stop = index + 1
        while stop < len(lines):
            end = FENCE_END_RE.match(lines[stop][1])
            if end and end.group(1) == block_id:
                break
            stop += 1
        if stop == len(lines):
            fail("unmatched block marker %s in %s" % (block_id, relative_path(path)))
        bodies.setdefault(block_id, []).append(text[lines[index][3]:lines[stop][2]])
        index = stop + 1
    return bodies


def overhead_rows(paths: List[str], encoders: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Count the generated block bodies and the reference index.

    Args:
        paths: Markdown files under the references root.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        One row for the nav bodies, one for the toc bodies and one for
        references/index.json.
    """
    totals = {name: 0 for name in BLOCK_IDS}
    blocks = {name: 0 for name in BLOCK_IDS}
    holders = {name: 0 for name in BLOCK_IDS}
    tokens = {name: {encoding: 0 for encoding in ENCODING_NAMES} for name in BLOCK_IDS}
    for path in paths:
        found = block_bodies(read_text(path), path)
        for block_id in BLOCK_IDS:
            bodies = found.get(block_id, [])
            if bodies:
                holders[block_id] += 1
            for body in bodies:
                blocks[block_id] += 1
                totals[block_id] += count_bytes(body)
                counts = count_tokens(body, encoders)
                for encoding in ENCODING_NAMES:
                    tokens[block_id][encoding] += counts[encoding]
    index_text = read_text(INDEX_PATH)
    label = {NAV_BLOCK_ID: NAV_NAME, TOC_BLOCK_ID: TOC_NAME}
    rows = [
        {
            "blocks": blocks[block_id],
            "bytes": totals[block_id],
            "files": holders[block_id],
            "name": label[block_id],
            "tokens": tokens[block_id],
        }
        for block_id in BLOCK_IDS
    ]
    rows.append(
        {
            "blocks": 1,
            "bytes": count_bytes(index_text),
            "files": 1,
            "name": INDEX_NAME,
            "tokens": count_tokens(index_text, encoders),
        }
    )
    return rows


def unit_row(name: str, reads: List[str], parts: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Build one named unit row out of its read set.

    Args:
        name: Unit name.
        reads: Read set, one address per part.
        parts: Rows with a byte count and a token count each.

    Returns:
        A row with the name, the read set, the summed bytes and the summed
        token counts.
    """
    return {
        "bytes": sum(part["bytes"] for part in parts),
        "name": name,
        "reads": reads,
        "tokens": {
            encoding: sum(part["tokens"][encoding] for part in parts)
            for encoding in ENCODING_NAMES
        },
    }


def file_unit(path: str, rows: Dict[str, Dict[str, Any]], encoders: Dict[str, Any]) -> Dict[str, Any]:
    """Build the unit row of one named file.

    Args:
        path: Path relative to the repository root.
        rows: File rows of the corpus keyed by their path, which hold the
            reference files only.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        The unit row. A named file outside the references root is counted on
        the spot.
    """
    row = rows.get(path)
    if row is None:
        row = file_row(os.path.join(REPO_ROOT, path), encoders)
    return unit_row(path, [path], [row])


def section_part(path: str, anchor: str, rows: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
    """Build one part from the H2 section of a named file.

    The part runs from the heading line of the section to the line before the
    next H2, the same slice the section rows use.

    Args:
        path: Path relative to the repository root.
        anchor: Anchor of the section.
        rows: File rows keyed by their path.

    Returns:
        A part with the byte count and the token counts.

    Raises:
        SystemExit: When the file or the section is missing.
    """
    row = rows.get(path)
    if row is None:
        fail("named unit file is not in the corpus: %s" % path)
    for section in row["sections"]:
        if section["anchor"] == anchor:
            return {"bytes": section["bytes"], "tokens": section["tokens"]}
    fail("named unit section is not in %s: %s" % (path, anchor))


def car_ratio(units: List[Dict[str, Any]]) -> Dict[str, float]:
    """Return the proposed route over the current route, per encoding.

    Args:
        units: Unit rows, holding the two car route rows.

    Returns:
        The ratio by encoding name, rounded to four decimals.

    Raises:
        SystemExit: When a route row is missing or the current route is empty.
    """
    found = {row["name"]: row["tokens"] for row in units}
    current = found.get(CAR_CURRENT_NAME)
    proposed = found.get(CAR_PROPOSED_NAME)
    if current is None or proposed is None:
        fail("car route rows are missing")
    ratios: Dict[str, float] = {}
    for encoding in ENCODING_NAMES:
        if current[encoding] == 0:
            fail("car route current is empty in %s" % encoding)
        ratios[encoding] = round(proposed[encoding] / current[encoding], 4)
    return ratios


def pin_block() -> Dict[str, Any]:
    """Return the pin block of the baseline.

    Returns:
        The pinned encoding names, the library version, the sha256 and the
        cache file of each data file, the proxy note and the re-measure rule.
    """
    return {
        "cache_dir_env": CACHE_ENV,
        "encodings": {
            entry["name"]: {
                "cache_file": cache_file_name(entry["url"]),
                "sha256": entry["sha256"],
                "url": entry["url"],
            }
            for entry in ENCODINGS
        },
        "lead_encoding": LEAD_ENCODING,
        "library": LIBRARY_NAME,
        "proxy_note": PROXY_NOTE,
        "remeasure_rule": REMEASURE_RULE,
        "second_encoding": SECOND_ENCODING,
        "version": LIBRARY_VERSION,
    }


def build_baseline(encoders: Dict[str, Any]) -> Dict[str, Any]:
    """Count the whole corpus and build the baseline structure.

    Args:
        encoders: Mapping of encoding name to an encoder.

    Returns:
        The baseline with the pin block, the file rows, the named units, the
        overhead rows and the car route ratio.
    """
    paths = markdown_files()
    files = [file_row(path, encoders) for path in paths]
    rows = {row["path"]: row for row in files}
    corpus = {
        "bytes": sum(row["bytes"] for row in files),
        "files": len(files),
        "name": CORPUS_NAME,
        "reads": [relative_path(REFERENCES_ROOT)],
        "sections": sum(len(row["sections"]) for row in files),
        "tokens": {
            encoding: sum(row["tokens"][encoding] for row in files)
            for encoding in ENCODING_NAMES
        },
    }
    readme_path = "sk-moneybird-accountant/references/tax-rules/2026/README.md"
    topic_path = "sk-moneybird-accountant/references/tax-rules/2026/kosten-en-auto.md"
    skill_path = "sk-moneybird-accountant/SKILL.md"
    readme = file_unit(readme_path, rows, encoders)
    topic = file_unit(topic_path, rows, encoders)
    units = [
        corpus,
        file_unit(topic_path, rows, encoders),
        readme,
        file_unit(skill_path, rows, encoders),
        unit_row(CAR_CURRENT_NAME, [readme_path, topic_path], [readme, topic]),
        unit_row(
            CAR_PROPOSED_NAME,
            [readme_path, "%s#%s" % (topic_path, CAR_SECTION_ANCHOR)],
            [readme, section_part(topic_path, CAR_SECTION_ANCHOR, rows)],
        ),
    ]
    return {
        "car_route": {
            "current": CAR_CURRENT_NAME,
            "proposed": CAR_PROPOSED_NAME,
            "ratio": car_ratio(units),
        },
        "files": files,
        "generator": GENERATOR,
        "overhead": overhead_rows(paths, encoders),
        "pin": pin_block(),
        "units": units,
    }


def section_count(data: Dict[str, Any]) -> int:
    """Count the H2 section rows of a baseline.

    Args:
        data: Result of build_baseline().

    Returns:
        The number of sections across the file rows.
    """
    return sum(len(row["sections"]) for row in data["files"])


def render(data: Dict[str, Any]) -> str:
    """Render the baseline JSON.

    Args:
        data: Result of build_baseline().

    Returns:
        The file text with sorted keys, an indent of two spaces and a
        trailing newline.
    """
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"

# ───────────────────────────────────────────────────────────────
# 6. REPORT
# ───────────────────────────────────────────────────────────────

def report(data: Dict[str, Any]) -> None:
    """Print the named unit rows and the car route ratio.

    Args:
        data: Result of build_baseline().
    """
    for row in data["units"]:
        print(
            "%s: unit %s: %d bytes, %s"
            % (PROGRAM, row["name"], row["bytes"], token_text(row["tokens"]))
        )
    print("%s: %s: %s" % (PROGRAM, "car route ratio", ratio_text(data["car_route"]["ratio"])))


def drift_lines(stored_text: str, expected: Dict[str, Any]) -> List[str]:
    """Compare the stored baseline with the recomputed one, row by row.

    Args:
        stored_text: Text of the baseline file.
        expected: Result of build_baseline().

    Returns:
        One line per drifted row, or one line when only the shape differs.
    """
    try:
        stored = json.loads(stored_text)
    except ValueError as exc:
        return ["the baseline file is not valid JSON: %s" % exc]
    if not isinstance(stored, dict):
        return ["the baseline file holds no JSON object"]
    lines = ["%s: row differs" % key for key in ("generator", "pin") if stored.get(key) != expected[key]]
    stored_files = stored.get("files")
    if isinstance(stored_files, list) and all(isinstance(row, dict) for row in stored_files):
        old = {row.get("path"): row for row in stored_files}
        new = {row["path"]: row for row in expected["files"]}
        lines += ["files: added %s" % path for path in sorted(set(new) - set(old))]
        lines += ["files: removed %s" % path for path in sorted(set(old) - set(new))]
        lines += [
            "files: changed %s" % path
            for path in sorted(set(old) & set(new))
            if old[path] != new[path]
        ]
    else:
        lines.append("files: row differs")
    lines += [
        "%s: row differs" % key
        for key in ("units", "overhead", "car_route")
        if stored.get(key) != expected[key]
    ]
    if not lines:
        lines.append("output differs but no row changed, rerun without --check")
    return lines

# ───────────────────────────────────────────────────────────────
# 7. CHECK AND WRITE
# ───────────────────────────────────────────────────────────────

def read_stored() -> Optional[str]:
    """Read the baseline file as text.

    Returns:
        The file text, or None when the file does not exist.

    Raises:
        SystemExit: When the file cannot be read.
    """
    if not os.path.isfile(BASELINE_PATH):
        return None
    try:
        with open(BASELINE_PATH, "r", encoding="utf-8", newline="") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative_path(BASELINE_PATH), exc))


def write_baseline(text: str, data: Dict[str, Any]) -> int:
    """Write the baseline when it changed.

    Args:
        text: Baseline text to write.
        data: Result of build_baseline().

    Returns:
        Zero on success.

    Raises:
        SystemExit: When the file cannot be written.
    """
    if read_stored() == text:
        print(
            "%s: baseline unchanged, %d files, %d sections"
            % (PROGRAM, len(data["files"]), section_count(data))
        )
        return 0
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(
            prefix=".token-baseline-", dir=os.path.dirname(BASELINE_PATH)
        )
        os.close(descriptor)
        with open(temporary, "wb") as handle:
            handle.write(text.encode("utf-8"))
        # WHY: the temporary file starts out private, and the baseline is a
        # shared artifact like the other generated JSON files.
        os.chmod(temporary, default_mode())
        os.replace(temporary, BASELINE_PATH)
        temporary = None
    except OSError as exc:
        fail("cannot write %s: %s" % (relative_path(BASELINE_PATH), exc))
    finally:
        # WHY: a half-written temporary file must not survive a failed rename.
        if temporary is not None and os.path.exists(temporary):
            os.unlink(temporary)
    print(
        "%s: wrote %s, %d files, %d sections"
        % (PROGRAM, relative_path(BASELINE_PATH), len(data["files"]), section_count(data))
    )
    return 0


def check_baseline(text: str, data: Dict[str, Any]) -> int:
    """Compare the baseline file with the recomputed one.

    Args:
        text: Baseline text a write would produce.
        data: Result of build_baseline().

    Returns:
        Zero when the file matches, one on drift.
    """
    stored = read_stored()
    if stored is None:
        print("%s: drift: the baseline file is missing" % PROGRAM)
        return 1
    if stored != text:
        for line in drift_lines(stored, data):
            print("%s: drift: %s" % (PROGRAM, line))
        return 1
    print(
        "%s: check ok, %d files, %d sections"
        % (PROGRAM, len(data["files"]), section_count(data))
    )
    return 0

# ───────────────────────────────────────────────────────────────
# 8. ENTRY POINT
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
        description="Count the reference corpus in two pinned encodings and write or check the baseline.",
    )
    parser.add_argument("--check", action="store_true", help="verify the baseline without writing it")
    args = parser.parse_args(argv)
    check_cache(cache_dir())
    data = build_baseline(load_encoders())
    text = render(data)
    code = check_baseline(text, data) if args.check else write_baseline(text, data)
    if code == 0:
        report(data)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
