#!/usr/bin/env python3
"""Privacy gate for a public repository.

Personal data and finance records live in git-ignored folders. Anything that
reaches the index, a commit message or a pushed tag is treated as a leak.
Findings are masked and never contain the matched value.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import unicodedata

STAGED = "--staged"
PUSH = "--push"
TREE = "--tree"
HISTORY = "--history"
MESSAGE = "--message"
SELF_TEST = "--self-test-patterns"

CONFIG_FILE = ".privacy-gate.json"
DENYLIST_FILE = ".privacy-denylist"
APPROVAL_ENV = "PRIVACY_GATE_CHANGE_APPROVED"
MIN_TERM_LENGTH = 4

REQUIRED_CONFIG_KEYS = (
    "allowed_extensions",
    "allowed_files",
    "blocked_paths",
    "max_file_bytes",
    "amount_allowed_files",
    "secret_allowed_files",
    "email_allowed_domains",
)

DEFAULT_GATE_FILES = (
    CONFIG_FILE,
    "scripts/privacy-gate.py",
    "scripts/privacy-gate-test.sh",
    "scripts/install-hooks.sh",
    ".github/workflows/privacy-gate.yml",
)
DEFAULT_GATE_DIRECTORIES = (".githooks/",)

IDENTITY_SUFFIX = "@users.noreply.github.com"
# Assembled so this file scans clean under its own email rule.
IDENTITY_EXACT = "noreply@" + "github.com"

GIT_CONFIG = [
    "-c", "core.quotepath=false",
    "-c", "color.ui=false",
    "-c", "diff.noprefix=false",
    "-c", "diff.mnemonicPrefix=false",
]

# Country lengths from the IBAN registry, covering every SEPA country.
IBAN_LENGTHS = {
    "AD": 24, "AE": 23, "AL": 28, "AT": 20, "AZ": 28, "BA": 20, "BE": 16,
    "BG": 22, "BH": 22, "BI": 27, "BR": 29, "BY": 28, "CH": 21, "CR": 22,
    "CY": 28, "CZ": 24, "DE": 22, "DJ": 27, "DK": 18, "DO": 28, "EE": 20,
    "EG": 29, "ES": 24, "FI": 18, "FO": 18, "FR": 27, "GB": 22, "GE": 22,
    "GI": 23, "GL": 18, "GR": 27, "GT": 28, "HR": 21, "HU": 28, "IE": 22,
    "IL": 23, "IQ": 23, "IS": 26, "IT": 27, "JO": 30, "KW": 30, "KZ": 20,
    "LB": 28, "LC": 32, "LI": 21, "LT": 20, "LU": 20, "LV": 21, "LY": 25,
    "MC": 27, "MD": 24, "ME": 22, "MK": 19, "MR": 27, "MT": 31, "MU": 30,
    "NL": 18, "NO": 15, "PK": 24, "PL": 28, "PS": 29, "PT": 25, "QA": 29,
    "RO": 24, "RS": 22, "RU": 33, "SA": 24, "SC": 31, "SD": 18, "SE": 24,
    "SI": 19, "SK": 24, "SM": 27, "SO": 23, "ST": 25, "SV": 28, "TL": 23,
    "TN": 24, "TR": 26, "UA": 29, "VA": 22, "VG": 24, "XK": 20,
}

IBAN_RE = re.compile(
    r"(?<![0-9A-Z])[A-Z]{2}[0-9]{2}(?:[ \t.\-]?[A-Z0-9]{4}){2,7}"
    r"(?:[ \t.\-]?[A-Z0-9]{1,3})?(?![0-9A-Z])",
    re.IGNORECASE,
)
SQUEEZED_IBAN_RE = re.compile(
    r"(?<![0-9A-Z])[A-Z]{2}[0-9]{2}[A-Z0-9]{10,31}", re.IGNORECASE)
IBAN_SEPARATORS_RE = re.compile(r"[ \t.\-]")
SQUEEZE_RE = re.compile(r"[\s.\-]")
BSN_RE = re.compile(
    r"(?<![0-9A-Za-z_])(?:[0-9]{9}|[0-9]{3}[ .\-][0-9]{3}[ .\-][0-9]{3})"
    r"(?![0-9A-Za-z_])"
)
BSN_SEPARATORS_RE = re.compile(r"[ .\-]")
VAT_RE = re.compile(r"(?<![0-9A-Za-z])NL[0-9]{9}B[0-9]{2}(?![0-9A-Za-z])")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
LONG_NUMBER_RE = re.compile(r"(?<![0-9A-Za-z_])[0-9]{10,}(?![0-9A-Za-z_])")
HOME_PATH_RE = re.compile(
    r"/(?:Users|home)/[A-Za-z0-9._-]+|(?i:C:\\Users\\[A-Za-z0-9._-]+)")
AMOUNT_RE = re.compile(
    r"(?:\u20ac\s?[0-9]|[0-9]\s?\u20ac|EUR\s?[0-9]|[0-9]\s?EUR)")
DUTCH_AMOUNT_RE = re.compile(r"\b[0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2}\b")
PEM_HEADER_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")
BEARER_RE = re.compile(r"Bearer\s+[A-Za-z0-9._/+=-]{20,}")
KEY_ASSIGN_RE = re.compile(
    r"(?i)([A-Za-z0-9_.\-]*(?:secret|token|password|passwd|api[_-]?key|apikey"
    r"|access[_-]?key|private[_-]?key|credential|auth)[A-Za-z0-9_.\-]*)"
    r"\s*[:=]\s*[\"']?([A-Za-z0-9._/+=\-]{8,}|\$\{[A-Za-z0-9_]+\})"
)
PLACEHOLDER_MARKERS = ("fake", "example", "placeholder", "dummy", "changeme", "${")
WHITESPACE_RE = re.compile(r"\s+")
STATUS_RE = re.compile(r"^[ACDMRTUXB][0-9]{0,3}$")
ZERO_WIDTH_TABLE = dict.fromkeys([0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF])


def die(message):
    sys.stderr.write("privacy-gate: %s\n" % message)
    sys.exit(2)


def warn(message):
    sys.stderr.write("privacy-gate: warning: %s\n" % message)


def usage():
    sys.stderr.write(
        "usage: python3 -I scripts/privacy-gate.py\n"
        "       (--staged|--push <remote>|--tree|--history|"
        "--message <file>|--self-test-patterns)\n"
    )
    sys.exit(2)


def parse_args(argv):
    if len(argv) < 2 or len(argv) > 3:
        usage()
    mode = argv[1]
    argument = argv[2] if len(argv) > 2 else None
    if mode == PUSH:
        # The remote name is new. An older hook may still call without it, so
        # the fall back is every remote instead of a silent skip.
        return mode, argument
    if mode == MESSAGE:
        if argument is None:
            usage()
        return mode, argument
    if mode in (STAGED, TREE, HISTORY, SELF_TEST) and argument is None:
        return mode, None
    usage()


def git_soft(args, cwd, stdin_data=None):
    command = ["git"] + GIT_CONFIG + args
    try:
        process = subprocess.run(
            command,
            cwd=cwd,
            input=stdin_data,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as exc:
        die("cannot run git: %s" % exc)
    return process.returncode, process.stdout, process.stderr


def git_out(args, cwd, stdin_data=None):
    """Run git and die with one line when it fails.

    A failed git call must never look like empty content that passes.
    """
    status, stdout, stderr = git_soft(args, cwd, stdin_data)
    if status != 0:
        detail = stderr.decode("utf-8", "replace").strip().splitlines()
        first = detail[0] if detail else "exit status %d" % status
        die("git %s failed: %s" % (" ".join(args), first))
    return stdout


def find_root():
    status, stdout, _stderr = git_soft(["rev-parse", "--show-toplevel"], os.getcwd())
    if status != 0:
        die("not inside a git repository")
    return stdout.decode("utf-8", "replace").strip()


def head_config_bytes(root):
    """Return the HEAD copy of the config, or None when HEAD has none."""
    status, _stdout, _stderr = git_soft(
        ["cat-file", "-e", "HEAD:" + CONFIG_FILE], root)
    if status != 0:
        return None
    return git_out(["show", "HEAD:" + CONFIG_FILE], root)


def load_config(root, mode):
    """Return the rules.

    Staged checks read the committed config so a staged rewrite cannot widen
    the rules that are applied to the same index.
    """
    raw = head_config_bytes(root) if mode == STAGED else None
    if raw is None:
        path = os.path.join(root, CONFIG_FILE)
        try:
            with open(path, "rb") as handle:
                raw = handle.read()
        except OSError as exc:
            die("cannot read %s: %s" % (CONFIG_FILE, exc))
    try:
        config = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        die("cannot parse %s: %s" % (CONFIG_FILE, exc))
    for key in REQUIRED_CONFIG_KEYS:
        if key not in config:
            die("%s is missing key %s" % (CONFIG_FILE, key))
    return config


def load_denylist(root):
    """Return (present, terms, ignored)."""
    path = os.path.join(root, DENYLIST_FILE)
    if not os.path.isfile(path):
        return False, [], 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            raw_lines = handle.readlines()
    except OSError as exc:
        die("cannot read %s: %s" % (DENYLIST_FILE, exc))
    terms = []
    ignored = 0
    for raw in raw_lines:
        term = normalize(raw.strip())
        if not term or term.startswith("#"):
            continue
        if len(term) < MIN_TERM_LENGTH:
            ignored += 1
            continue
        lowered = term.lower()
        terms.append(
            (len(terms) + 1, lowered, WHITESPACE_RE.sub("", lowered), len(term))
        )
    return True, terms, ignored


def normalize(text):
    """Fold Unicode tricks and zero-width characters before matching."""
    return unicodedata.normalize("NFKC", text).translate(ZERO_WIDTH_TABLE)


def decode_content(content):
    """Return (text, False), or (None, True) when the blob is binary."""
    if content[:2] in (b"\xff\xfe", b"\xfe\xff"):
        try:
            return normalize(content.decode("utf-16")), False
        except UnicodeDecodeError:
            return None, True
    if b"\0" in content:
        return None, True
    return normalize(content.decode("utf-8", "replace")), False


def iban_body(candidate):
    return IBAN_SEPARATORS_RE.sub("", candidate).upper()


def iban_valid(candidate):
    body = iban_body(candidate)
    length = IBAN_LENGTHS.get(body[:2])
    if length is None or len(body) != length:
        return False
    if not re.match(r"^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$", body):
        return False
    rotated = body[4:] + body[:4]
    digits = []
    for char in rotated:
        if "0" <= char <= "9":
            digits.append(char)
        else:
            digits.append(str(ord(char) - ord("A") + 10))
    return int("".join(digits)) % 97 == 1


def iban_lengths_in(text):
    """Stripped lengths of valid IBANs in one line.

    A trailing word can make the match longer than the IBAN itself, so the
    country length is used as the cut.
    """
    lengths = []
    for match in IBAN_RE.finditer(text):
        body = iban_body(match.group(0))
        length = IBAN_LENGTHS.get(body[:2])
        if length is None or len(body) < length:
            continue
        if iban_valid(body[:length]):
            lengths.append(length)
    return lengths


def squeeze(text):
    return SQUEEZE_RE.sub("", text)


def squeezed_iban_lengths(text):
    """Valid IBANs in a blob with whitespace and separators removed."""
    lengths = []
    for match in SQUEEZED_IBAN_RE.finditer(squeeze(text)):
        body = match.group(0).upper()
        length = IBAN_LENGTHS.get(body[:2])
        if length is None or len(body) < length:
            continue
        if iban_valid(body[:length]):
            lengths.append(length)
    return lengths


def bsn_valid(digits):
    if len(digits) != 9 or digits == "000000000":
        return False
    total = 0
    for index, char in enumerate(digits):
        weight = -1 if index == 8 else 9 - index
        total += weight * int(char)
    return total % 11 == 0


def domain_allowed(domain, allowed):
    domain = domain.lower().rstrip(".")
    for entry in allowed:
        entry = entry.lower()
        if domain == entry or domain.endswith("." + entry):
            return True
    return False


def identity_allowed(email):
    lowered = email.strip().lower()
    if not lowered:
        return False
    return lowered == IDENTITY_EXACT or lowered.endswith(IDENTITY_SUFFIX)


def path_blocked(path, config):
    lowered = path.lower()
    for entry in config["blocked_paths"]:
        entry = entry.lower()
        if entry == ".env":
            if lowered == ".env" or (
                    lowered.startswith(".env.")
                    and lowered != ".env.example"):
                return True
        elif entry.endswith("/"):
            if lowered == entry[:-1] or lowered.startswith(entry):
                return True
        elif lowered == entry or lowered.startswith(entry + "/"):
            return True
    return False


def extension_of(path):
    base = path.rsplit("/", 1)[-1]
    dot = base.rfind(".")
    if dot <= 0:
        return ""
    return base[dot + 1:].lower()


def mask(value, keep=0):
    if keep > 0:
        return "%s...(len %d)" % (value[:keep], len(value))
    return "(len %d)" % len(value)


def placeholder_value(value):
    """True when the captured value itself is marked as not real."""
    lowered = value.lower()
    for marker in PLACEHOLDER_MARKERS:
        if marker in lowered:
            return True
    return False


def secret_hits(line):
    hits = []
    if PEM_HEADER_RE.search(line):
        hits.append(("secret", "private key header"))
    match = BEARER_RE.search(line)
    if match:
        hits.append(("secret", mask(match.group(0), 0)))
    for match in KEY_ASSIGN_RE.finditer(line):
        if placeholder_value(match.group(2)):
            continue
        hits.append(("secret", mask(match.group(0), 0)))
        break
    return hits


def denylist_hit(line, terms):
    lowered = line.lower()
    squeezed = WHITESPACE_RE.sub("", lowered)
    for ordinal, needle, needle_squeezed, length in terms:
        if needle in lowered or needle_squeezed in squeezed:
            return ordinal, length
    return None


class Checker(object):
    def __init__(self, config, denylist):
        self.config = config
        self.allowed_extensions = set(
            entry.lower() for entry in config["allowed_extensions"])
        self.allowed_files = set(
            normalize(entry) for entry in config["allowed_files"])
        self.amount_files = set(
            normalize(entry) for entry in config["amount_allowed_files"])
        self.secret_files = set(
            normalize(entry) for entry in config["secret_allowed_files"])
        self.email_domains = list(config["email_allowed_domains"])
        self.max_bytes = int(config["max_file_bytes"])
        self.gate_files = set(
            normalize(entry)
            for entry in config.get("gate_files", DEFAULT_GATE_FILES))
        self.gate_directories = tuple(
            normalize(entry)
            for entry in config.get("gate_directories", DEFAULT_GATE_DIRECTORIES))
        self.denylist = denylist
        self.findings = []
        self.files_checked = 0
        self._seen = set()

    def add(self, rule, path, number, hint):
        finding = (rule, path, str(number), hint)
        if finding not in self._seen:
            self._seen.add(finding)
            self.findings.append(finding)

    def is_gate_file(self, path):
        if path in self.gate_files:
            return True
        for entry in self.gate_directories:
            if path.startswith(entry):
                return True
        return False

    def check_path(self, path, mode, content):
        self.files_checked += 1
        display = normalize(path)
        if path_blocked(display, self.config):
            self.add("blocked-path", display, "-", "not allowed on a public remote")
        extension = extension_of(display)
        if extension not in self.allowed_extensions and display not in self.allowed_files:
            self.add("file-type", display, "-", extension or "(none)")
        if mode == "120000":
            self.add("symlink", display, "-", "mode 120000")
        if len(content) > self.max_bytes:
            self.add(
                "size", display, "-",
                "%d bytes, limit %d" % (len(content), self.max_bytes))
        text, is_binary = decode_content(content)
        if is_binary:
            # The binary finding already blocks the path. Text rules on
            # undecodable bytes would only add noise.
            self.add("binary", display, "-", "NUL byte in content")
            return
        self.check_text(display, text)

    def check_path_string(self, path):
        display = normalize(path)
        for rule, hint in self.line_hits(display, display):
            self.add(rule, display, "path", hint)

    def check_text(self, path, text):
        iban_lengths = set()
        for number, line in enumerate(text.split("\n"), 1):
            for rule, hint in self.line_hits(path, line):
                if rule == "iban":
                    iban_lengths.add(hint)
                self.add(rule, path, number, hint)
        for length in squeezed_iban_lengths(text):
            hint = "(len %d)" % length
            if hint not in iban_lengths:
                self.add("iban", path, "-", hint)

    def line_hits(self, path, line):
        hits = []
        for length in iban_lengths_in(line):
            hits.append(("iban", "(len %d)" % length))
        for match in BSN_RE.finditer(line):
            digits = BSN_SEPARATORS_RE.sub("", match.group(0))
            if bsn_valid(digits):
                hits.append(("bsn", mask(match.group(0), 0)))
        for match in VAT_RE.finditer(line):
            hits.append(("vat-id", mask(match.group(0), 0)))
        for match in EMAIL_RE.finditer(line):
            value = match.group(0)
            if not domain_allowed(value.rsplit("@", 1)[1], self.email_domains):
                hits.append(("email", mask(value, 2)))
        for match in LONG_NUMBER_RE.finditer(line):
            hits.append(("long-number", mask(match.group(0), 2)))
        for match in HOME_PATH_RE.finditer(line):
            hits.append(("home-path", mask(match.group(0), 2)))
        if path not in self.amount_files:
            match = AMOUNT_RE.search(line)
            if match is None:
                match = DUTCH_AMOUNT_RE.search(line)
            if match is not None:
                hits.append(("amount", mask(match.group(0), 2)))
        if path not in self.secret_files:
            hits.extend(secret_hits(line))
        if self.denylist and path != "LICENSE":
            match = denylist_hit(line, self.denylist)
            if match:
                hits.append(("denylist", "term #%d (len %d)" % match))
        return hits

    def check_identity_email(self, path, role, email):
        if identity_allowed(email):
            return
        self.add(
            "identity", path, "-",
            "%s must end with %s or equal %s"
            % (role, IDENTITY_SUFFIX, IDENTITY_EXACT))


def decode_z(raw):
    return [chunk.decode("utf-8", "replace") for chunk in raw.split(b"\0") if chunk]


def index_entry(root, path):
    # The literal magic keeps a name with wildcards from matching other files.
    raw = git_out(["ls-files", "-s", "-z", "--", ":(literal)" + path], root)
    entry = raw.split(b"\0", 1)[0]
    if not entry:
        die("no index entry for %s" % path)
    fields = entry.decode("utf-8", "replace").split("\t", 1)[0].split()
    if len(fields) < 2:
        die("cannot parse the index entry for %s" % path)
    return fields[0], fields[1]


def blob_content(root, blob, cache):
    if blob not in cache:
        cache[blob] = git_out(["cat-file", "blob", blob], root)
    return cache[blob]


def list_tree(root, rev):
    raw = git_out(["ls-tree", "-r", "-z", rev], root)
    entries = []
    for chunk in raw.split(b"\0"):
        if not chunk:
            continue
        meta, separator, path = chunk.decode("utf-8", "replace").partition("\t")
        if not separator:
            continue
        fields = meta.split()
        if len(fields) < 3:
            continue
        entries.append((fields[0], fields[2], path))
    return entries


def parse_name_status(raw):
    """Return the paths of a `diff-tree --name-status -z` listing.

    With -z the record is `status NUL path NUL`. A tab separated token is
    accepted as well so a format change cannot turn into an empty path list.
    """
    paths = []
    tokens = raw.split(b"\0")
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if not token or token == b"\n":
            index += 1
            continue
        if b"\t" in token:
            fields = token.split(b"\t")
            index += 1
            if len(fields) >= 2:
                paths.append(fields[1].decode("utf-8", "replace"))
            continue
        status = token.decode("utf-8", "replace")
        if STATUS_RE.match(status) and index + 1 < len(tokens):
            paths.append(tokens[index + 1].decode("utf-8", "replace"))
            index += 2
            continue
        index += 1
    return paths


def changed_paths(root, sha):
    """Paths changed against every parent, including typechanges.

    For a merge this covers each parent through -m. For a root commit --root
    makes the whole tree the change set.
    """
    raw = git_out(
        ["diff-tree", "-r", "-m", "--root", "--no-commit-id", "--name-status",
         "-z", "--diff-filter=ACMRT", sha],
        root,
    )
    seen = set()
    paths = []
    for path in parse_name_status(raw):
        if path in seen:
            continue
        seen.add(path)
        paths.append(path)
    return paths


def commit_metadata(root, sha):
    raw = git_out(
        ["log", "-1", "--no-show-signature", "--format=%B%x00%ae%x00%ce", sha],
        root,
    )
    parts = raw.rsplit(b"\0", 2)
    if len(parts) != 3:
        die("cannot read commit metadata for %s" % sha)
    return (
        parts[0].decode("utf-8", "replace"),
        parts[1].decode("utf-8", "replace").strip(),
        parts[2].decode("utf-8", "replace").strip(),
    )


def check_commit(checker, root, sha, cache):
    short = sha[:12]
    message, author_email, committer_email = commit_metadata(root, sha)
    checker.check_text(short, normalize(message))
    checker.check_identity_email(short, "author email", author_email)
    checker.check_identity_email(short, "committer email", committer_email)
    tree = {}
    for mode, blob, path in list_tree(root, sha):
        tree[path] = (mode, blob)
    for path in changed_paths(root, sha):
        display = normalize(path)
        if checker.is_gate_file(display):
            sys.stdout.write(
                "privacy-gate: info: gate file changed in %s: %s\n"
                % (short, display))
        checker.check_path_string(path)
        entry = tree.get(path)
        if entry is None:
            continue
        mode, blob = entry
        if mode == "160000":
            checker.check_path(path, mode, b"")
            continue
        checker.check_path(path, mode, blob_content(root, blob, cache))


def check_tag_message(checker, root, ref, sha):
    kind = git_out(["cat-file", "-t", sha], root).decode("utf-8", "replace").strip()
    if kind != "tag":
        return
    raw = git_out(["cat-file", "tag", sha], root)
    # The tag header carries the tagger identity, so only the message body is
    # content here.
    parts = raw.split(b"\n\n", 1)
    message = parts[1] if len(parts) == 2 else b""
    display = normalize(ref)
    text, is_binary = decode_content(message)
    if is_binary:
        checker.add("binary", display, "-", "NUL byte in tag message")
        return
    checker.check_text(display, text)


def rev_list_not_on_remote(root, local_sha, remote):
    args = ["rev-list", local_sha, "--not"]
    if remote:
        args.append("--remotes=" + remote)
    else:
        args.append("--remotes")
    return git_out(args, root).decode("utf-8", "replace").split()


def commits_for_push(root, local_sha, remote_sha, remote):
    if re.match(r"^0+$", remote_sha):
        return rev_list_not_on_remote(root, local_sha, remote)
    status, stdout, _stderr = git_soft(
        ["rev-list", "%s..%s" % (remote_sha, local_sha)], root)
    if status == 0:
        return stdout.decode("utf-8", "replace").split()
    # The remote tip can be missing locally, so fall back to every commit that
    # is not on the remote. A failure there is fatal, never a silent pass.
    return rev_list_not_on_remote(root, local_sha, remote)


def check_push(checker, root, remote, stdin_bytes, cache):
    seen = set()
    for raw_line in stdin_bytes.decode("utf-8", "replace").splitlines():
        fields = raw_line.split()
        if not fields:
            continue
        if len(fields) != 4:
            die("unexpected pre-push input line")
        local_ref, local_sha, _remote_ref, remote_sha = fields
        if re.match(r"^0+$", local_sha):
            continue
        if local_ref.startswith("refs/tags/"):
            check_tag_message(checker, root, local_ref, local_sha)
        for sha in commits_for_push(root, local_sha, remote_sha, remote):
            if sha in seen:
                continue
            seen.add(sha)
            check_commit(checker, root, sha, cache)


def check_staged(checker, root, cache):
    changed = decode_z(git_out(["diff", "--cached", "--name-only", "-z"], root))
    approved = os.environ.get(APPROVAL_ENV) == "1"
    for path in changed:
        display = normalize(path)
        if not checker.is_gate_file(display):
            continue
        if approved:
            sys.stdout.write(
                "privacy-gate: info: gate file change approved: %s\n" % display)
        else:
            checker.add(
                "gate-change", display, "-",
                "only the Operator may set %s=1" % APPROVAL_ENV)
    scannable = decode_z(git_out(
        ["diff", "--cached", "--name-only", "-z", "--diff-filter=ACMRT"], root))
    for path in scannable:
        checker.check_path_string(path)
        mode, blob = index_entry(root, path)
        if mode == "160000" or re.match(r"^0+$", blob):
            # A gitlink or an intent-to-add entry has no blob to scan here.
            checker.check_path(path, mode, b"")
            continue
        checker.check_path(path, mode, blob_content(root, blob, cache))


def check_staged_identity(checker, root):
    status, stdout, _stderr = git_soft(["config", "--get", "user.email"], root)
    email = stdout.decode("utf-8", "replace").strip() if status == 0 else ""
    checker.check_identity_email("user.email", "git config user.email", email)


def check_tree(checker, root, cache):
    for mode, blob, path in list_tree(root, "HEAD"):
        if mode == "160000":
            checker.check_path(path, mode, b"")
            continue
        checker.check_path(path, mode, blob_content(root, blob, cache))


def check_history(checker, root, cache):
    for sha in git_out(["rev-list", "HEAD"], root).decode("utf-8", "replace").split():
        check_commit(checker, root, sha, cache)


def check_message(checker, message_file):
    try:
        with open(message_file, "r", encoding="utf-8", errors="replace") as handle:
            raw = handle.read()
    except OSError as exc:
        die("cannot read %s: %s" % (message_file, exc))
    # Comment lines are replaced by empty lines so line numbers stay true.
    kept = ["" if line.startswith("#") else line for line in raw.split("\n")]
    checker.files_checked += 1
    checker.check_text(normalize(message_file), normalize("\n".join(kept)))


def build_iban(country, bban):
    rotated = bban + country + "00"
    digits = "".join(str(int(char, 36)) for char in rotated)
    check = 98 - int(digits) % 97
    return "%s%02d%s" % (country, check, bban)


def build_bsn(base):
    weights = (9, 8, 7, 6, 5, 4, 3, 2)
    total = sum(weight * int(char) for weight, char in zip(weights, base))
    check = total % 11
    if check > 9:
        return None
    return "%s%d" % (base, check)


def run_self_test():
    results = []

    def expect(name, condition):
        results.append((name, bool(condition)))

    # Planted strings are assembled at run time so this file scans clean under
    # its own rules.
    iban = build_iban("NL", "ABNA0417164300")
    expect("nl iban builds", iban_valid(iban))
    expect("de iban builds",
           iban_valid(build_iban("DE", "3704" + "0044" + "0532" + "013000")))
    grouped = " ".join(iban[i:i + 4] for i in range(0, len(iban), 4))
    expect("spaced iban accepted", iban_valid(grouped))
    expect("hyphenated iban accepted", iban_valid(grouped.replace(" ", "-")))
    expect("dotted iban accepted", iban_valid(grouped.replace(" ", ".")))
    expect("tabbed iban accepted", iban_valid(grouped.replace(" ", "\t")))
    expect("lowercase iban accepted", iban_valid(grouped.lower()))
    damaged = iban[:-1] + ("0" if iban[-1] != "0" else "1")
    expect("iban damaged digit rejected", not iban_valid(damaged))
    expect("iban wrong length rejected", not iban_valid(iban[:-1]))
    expect("iban unknown country rejected", not iban_valid("XX" + iban[2:]))
    expect("split iban found",
           squeezed_iban_lengths(iban[:8] + "\n" + iban[8:]) == [len(iban)])

    bsn = build_bsn("10000000")
    expect("bsn builds", bsn is not None and bsn_valid(bsn))
    expect("bsn altered digit rejected",
           not bsn_valid(bsn[:8] + str((int(bsn[8]) + 1) % 10)))
    expect("bsn all zeros rejected", not bsn_valid("000000000"))
    grouped_bsn = "%s.%s.%s" % (bsn[:3], bsn[3:6], bsn[6:])
    expect("dotted bsn accepted",
           bool(BSN_RE.search(grouped_bsn))
           and bsn_valid(BSN_SEPARATORS_RE.sub("", grouped_bsn)))
    expect("spaced bsn accepted",
           bool(BSN_RE.search(bsn[:3] + " " + bsn[3:6] + " " + bsn[6:])))
    expect("hyphen bsn accepted",
           bool(BSN_RE.search(bsn[:3] + "-" + bsn[3:6] + "-" + bsn[6:])))
    wide = "".join(chr(ord("\uff10") + int(char)) for char in bsn)
    expect("fullwidth bsn folded",
           normalize(wide) == bsn and bool(BSN_RE.search(normalize(wide))))

    expect("long number flags ten digits", bool(LONG_NUMBER_RE.search("7" * 10)))
    expect("hex hash is not a long number",
           not LONG_NUMBER_RE.search(
               "0123456789abcdef0123456789abcdef01234567"))
    expect("amount flags euro figure", bool(AMOUNT_RE.search("EU" + "R" + " 12")))
    dutch = "1." + "234" + ",56"
    expect("dutch amount flags thousands", bool(DUTCH_AMOUNT_RE.search(dutch)))
    expect("dutch amount flags bare cents",
           bool(DUTCH_AMOUNT_RE.search("bedrag 12" + ",50")))
    expect("dutch amount ignores short cents",
           not DUTCH_AMOUNT_RE.search("1" + ",5"))

    expect("subdomain of an allowed domain accepted",
           domain_allowed("sub.example.com", ["example.com"]))
    expect("other domain rejected",
           not domain_allowed("mail.test", ["example.com"]))
    expect("noreply identity accepted",
           identity_allowed("12345+user" + IDENTITY_SUFFIX))
    expect("github noreply accepted", identity_allowed(IDENTITY_EXACT))
    expect("other identity rejected", not identity_allowed("user@example.com"))

    expect("zero width removed",
           normalize("a\u200bb\u2060c\ufeffd") == "abcd")
    expect("fullwidth digits folded", normalize("\uff11\uff12\uff13") == "123")
    expect("nul byte is binary", decode_content(b"a\0b")[1])
    expect("utf-16 bom decoded",
           decode_content("h\u00e9".encode("utf-16"))[0] == "h\u00e9")
    expect("blocked path is case insensitive",
           path_blocked("Specs/notes.md", {"blocked_paths": ["specs/"]}))
    expect("env example stays allowed",
           not path_blocked(".env.example", {"blocked_paths": [".env"]}))
    expect("env sibling is blocked",
           path_blocked(".env.local", {"blocked_paths": [".env"]}))

    planted = "api" + "_key = \"" + "zq" + ("9" * 12) + "\""
    expect("plain assignment blocks", bool(secret_hits(planted)))
    expect("marker in a trailing comment still blocks",
           bool(secret_hits(planted + "  # example")))
    expect("marker inside the value is ignored",
           not secret_hits("api" + "_key = \"" + "example" + "-value-01\""))
    expect("aws style key name matches",
           bool(KEY_ASSIGN_RE.search(
               "AWS_SECRET_ACCESS" + "_KEY = \"" + "example" + "-value-01\"")))
    expect("shell reference ignored",
           not secret_hits('password: "${DB_PASSWORD}"'))

    failed = [name for name, ok in results if not ok]
    for name in failed:
        sys.stdout.write("privacy-gate: self-test failed: %s\n" % name)
    if failed:
        sys.stdout.write("privacy-gate: self-test %d check(s) failed\n" % len(failed))
        return 1
    sys.stdout.write("privacy-gate: self-test ok (%d checks)\n" % len(results))
    return 0


def report(checker, mode):
    # A path that itself holds a finding would leak the value if printed, so
    # every line naming it shows a short hash instead.
    leaky = {path for _, path, number, _ in checker.findings if number == "path"}

    def shown(path):
        if path in leaky:
            digest = hashlib.sha256(path.encode("utf-8", "replace")).hexdigest()
            return "<redacted path %s>" % digest[:8]
        return path

    for rule, path, number, hint in checker.findings:
        sys.stdout.write("privacy-gate: %s %s:%s %s\n" % (rule, shown(path), number, hint))
    if checker.findings:
        sys.stdout.write("privacy-gate: %d finding(s), blocked\n" % len(checker.findings))
        return 1
    sys.stdout.write(
        "privacy-gate: clean (%s, %d files checked)\n"
        % (mode.strip("-"), checker.files_checked))
    return 0


def main(argv):
    mode, argument = parse_args(argv)
    if mode == SELF_TEST:
        return run_self_test()

    root = find_root()
    config = load_config(root, mode)
    present, denylist, ignored_terms = load_denylist(root)
    checker = Checker(config, denylist)

    if ignored_terms:
        warn("%d denylist term(s) shorter than %d characters ignored"
             % (ignored_terms, MIN_TERM_LENGTH))
    if mode in (STAGED, PUSH, MESSAGE):
        if not present:
            checker.add("denylist-missing", DENYLIST_FILE, "-",
                        "missing, run: bash scripts/install-hooks.sh")
        elif not denylist:
            warn("%s exists but has no terms, run: bash scripts/install-hooks.sh"
                 % DENYLIST_FILE)

    cache = {}
    if mode == STAGED:
        check_staged(checker, root, cache)
        check_staged_identity(checker, root)
    elif mode == PUSH:
        check_push(checker, root, argument, sys.stdin.buffer.read(), cache)
    elif mode == TREE:
        check_tree(checker, root, cache)
    elif mode == HISTORY:
        check_history(checker, root, cache)
    else:
        check_message(checker, argument)
    return report(checker, mode)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
