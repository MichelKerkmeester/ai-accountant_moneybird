#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: REGRESSION TRAILER CHECK
# ───────────────────────────────────────────────────────────────
"""Check a commit range for gate file changes without a covering test.

The range is listed with git rev-list. Each commit is then read on its own,
its message with git log and its changed paths with git diff-tree against its
first parent. Reading one commit at a time keeps a message that holds a
control character from changing where the next commit starts, and the
first-parent diff gives a merge commit its paths. A rename or copy counts as
a change to both the source and the destination. A commit that changes a
skill gate file must change a registered test in the same commit, or carry a
Regression-Test: trailer line that names a registered test which exists at
that commit. The registered set is read from the parent of the commit being
checked and holds exactly two sources: the test paths the hardening matrix
names, and the test files the skill health workflow runs, parsed from its run
lines. A named test counts only when it also exists at the parent, so a test
created in the commit under check cannot cover it. A suite path that a name
or a glob happens to match does not register. A registered path the commit
deletes is not registered, and a deleted path is never a test change. The
script uses the Python standard library only, reads the local repository only
and makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range <base>..<head>
    python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range <base>..<head> --root DIR

Options:
    --range R   Commit range for git log, written as <base>..<head>.
    --root DIR  Read another repository. Defaults to the root above this
                script.

Output:
    "regression-trailer: ok" with the commit count on stdout when the range
    passes, one line per finding otherwise. Exit 0 when the range passes, 1 on
    a finding and 2 on a usage error or a git failure.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import subprocess
import sys
from typing import List, NoReturn, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/check-regression-trailer.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# WHY: these files hold the routing table, the read-only rules, the guard and
# the write contract, so a change to one needs a covering test or a trailer.
GATE_FILES = (
    "AGENTS.md",
    "cli-jortt/SKILL.md",
    "cli-moneybird/SKILL.md",
    "cli-moneybird/cli/moneybird-cli/moneybird-guard",
    "sk-moneybird-accountant/SKILL.md",
    "sk-moneybird-accountant/references/migration/shared-mechanisms.md",
)

# One line that names the covering test. An empty value names nothing.
TRAILER_RE = re.compile(r"^Regression-Test:[ \t]*(\S.*)$", re.MULTILINE)

# Registration is read from the parent of the commit under check. Only two
# reviewed surfaces register a test: the hardening matrix names test paths by
# hand, and the skill health workflow names the files its run lines execute.
# The workflow is a privacy gate file, so neither surface can be widened by
# the commit that a new suite would cover.
MATRIX_REL = "sk-moneybird-accountant/hardening-matrix.md"
WORKFLOW_REL = ".github/workflows/skill-health.yml"

# A run line registers a token that ends with one of these test path forms.
TEST_PATH_SUFFIXES = ("-test.sh", "run-tests.sh", "-test.py", "evals.json")

# One run key with an optional list dash, its indentation, and the rest of
# its line. The dash form is what a compact workflow step uses.
RUN_KEY_RE = re.compile(r"^([ \t]*)(?:-[ \t]+)?run:(.*)$")

# The characters that separate one shell word from the next.
COMMAND_SPLIT_RE = re.compile(r"[\s'\"]+")

# The matrix test cell holds a repo-relative path, this separator, then a case.
TEST_SEPARATOR = " :: "

# A status that changes the content of a registered test. A rename source is
# a deletion. A copy source keeps its content, so neither counts.
TEST_CHANGE_STATUSES = ("A", "M", "T")

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


def run_git(root: str, args: List[str], label: str) -> str:
    """Run one required git command and return its stdout.

    Args:
        root: Repository root.
        args: Arguments after the -C root pair.
        label: Name used in the error message.

    Returns:
        The command stdout.

    Raises:
        SystemExit: If git is missing or the command fails.
    """
    command = ["git", "-C", root] + args
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as exc:
        fail("cannot run git: %s" % exc)
    if result.returncode != 0:
        fail("%s failed: %s" % (label, result.stderr.strip() or "unknown error"))
    return result.stdout


def try_git(root: str, args: List[str]) -> str:
    """Run one optional git command and return its stdout, or an empty string.

    Args:
        root: Repository root.
        args: Arguments after the -C root pair.

    Returns:
        The command stdout, or an empty string when the command fails.

    Raises:
        SystemExit: If git is missing.
    """
    command = ["git", "-C", root] + args
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as exc:
        fail("cannot run git: %s" % exc)
    return result.stdout if result.returncode == 0 else ""


def run_commands(text: str) -> List[str]:
    """Read every shell command the workflow runs.

    Args:
        text: Workflow file text.

    Returns:
        One string per run line. A block scalar contributes one string per
        indented line, a plain run line contributes its command text.
    """
    lines = text.splitlines()
    commands: List[str] = []
    index = 0
    while index < len(lines):
        match = RUN_KEY_RE.match(lines[index].rstrip())
        if match is None:
            index += 1
            continue
        indent = len(match.group(1))
        rest = match.group(2).strip()
        index += 1
        if rest and rest[0] not in "|>":
            commands.append(rest)
            continue
        while index < len(lines):
            line = lines[index]
            if not line.strip():
                index += 1
                continue
            if len(line) - len(line.lstrip(" \t")) <= indent:
                break
            commands.append(line.strip())
            index += 1
    return commands


def command_test_paths(command: str) -> Set[str]:
    """Read the test paths one shell command names.

    Args:
        command: One run line with its arguments.

    Returns:
        The tokens that end with a test path suffix, with a leading ./ and
        surrounding quotes, commas or backticks removed.
    """
    paths: Set[str] = set()
    for raw in COMMAND_SPLIT_RE.split(command):
        word = raw.strip("`'\",")
        if word.startswith("./"):
            word = word[2:]
        if word.endswith(TEST_PATH_SUFFIXES):
            paths.add(word)
    return paths


def workflow_test_paths(root: str, sha: str) -> Set[str]:
    """Read the test paths the skill health workflow runs at one commit.

    Args:
        root: Repository root.
        sha: Commit to read.

    Returns:
        The repo-relative test paths on its run lines. An absent workflow
        file returns no paths.
    """
    text = try_git(root, ["show", "%s:%s" % (sha, WORKFLOW_REL)])
    paths: Set[str] = set()
    for command in run_commands(text):
        paths.update(command_test_paths(command))
    return paths


def tree_paths(root: str, sha: str) -> Set[str]:
    """List every path present at one commit.

    Args:
        root: Repository root.
        sha: Commit to read.

    Returns:
        The repo-relative paths of the commit tree.
    """
    return {
        line.strip()
        for line in try_git(root, ["ls-tree", "-r", "--name-only", sha]).splitlines()
        if line.strip()
    }


def parent_of(root: str, sha: str) -> str:
    """Read the first parent of one commit.

    Args:
        root: Repository root.
        sha: Commit to read.

    Returns:
        The parent hash, or an empty string for a root commit.
    """
    fields = try_git(root, ["rev-list", "--parents", "-n", "1", sha]).split()
    return fields[1] if len(fields) > 1 else ""

# ───────────────────────────────────────────────────────────────
# 4. GIT LOG AND REGISTRATION
# ───────────────────────────────────────────────────────────────

def parse_name_status(output: str) -> List[Tuple[str, str]]:
    """Turn NUL separated git diff-tree output into status and path pairs.

    A rename keeps the source as a deletion and the destination as an
    addition, so the source side can never cover a gate change. A copy
    keeps the source as a copy and the destination as an addition. Both
    sides reach the gate match.

    Args:
        output: The NUL separated diff-tree output.

    Returns:
        One status and path pair per change, in diff order.
    """
    fields = output.split("\0")
    changed: List[Tuple[str, str]] = []
    index = 0
    while index < len(fields):
        status = fields[index].strip()
        index += 1
        if not status:
            continue
        if status[0] in ("R", "C"):
            if index + 1 >= len(fields):
                break
            source = fields[index]
            destination = fields[index + 1]
            index += 2
            changed.append(("D" if status[0] == "R" else "C", source))
            changed.append(("A", destination))
        else:
            if index >= len(fields):
                break
            changed.append((status, fields[index]))
            index += 1
    return changed


def changed_paths(root: str, sha: str) -> List[Tuple[str, str]]:
    """Read the paths one commit changes against its first parent.

    A compare against the first parent gives a merge commit its paths,
    which a plain git log leaves empty for a merge.

    Args:
        root: Repository root.
        sha: Commit to read.

    Returns:
        One status and path pair per change. An added or modified path
        holds its git status, a rename source is a deletion and a copy
        source holds the copy status.

    Raises:
        SystemExit: If git is missing or git diff-tree fails.
    """
    base = [
        "diff-tree",
        "-r",
        "--name-status",
        "-z",
        "-M",
        "-C",
        "--find-copies-harder",
        "--no-commit-id",
    ]
    parent = parent_of(root, sha)
    if parent:
        args = base + [parent, sha]
    else:
        args = base + ["--root", sha]
    return parse_name_status(run_git(root, args, "git diff-tree"))


def read_commits(root: str, commit_range: str) -> List[Tuple[str, str, List[Tuple[str, str]]]]:
    """Read the commits of a range with their messages and changed files.

    The range is listed first. Each commit is then read on its own, one
    call for the message and one for the paths, so a message that holds a
    record or unit separator cannot change how the next commit is read.

    Args:
        root: Repository root.
        commit_range: Range for git log, written as <base>..<head>.

    Returns:
        One tuple per commit: the full hash, the message and the changed
        paths with their change status, such as A for an added file and M
        for a modified one.

    Raises:
        SystemExit: If git is missing or a git command fails.
    """
    shas = [
        line.strip()
        for line in run_git(root, ["rev-list", commit_range], "git rev-list").splitlines()
        if line.strip()
    ]
    commits: List[Tuple[str, str, List[Tuple[str, str]]]] = []
    for sha in shas:
        message = run_git(root, ["log", "-1", "--format=%B", sha], "git log")
        commits.append((sha, message, changed_paths(root, sha)))
    return commits


def matrix_test_paths(root: str, sha: str) -> List[str]:
    """Read the test paths the hardening matrix names at one commit.

    Args:
        root: Repository root.
        sha: Commit to read.

    Returns:
        The repo-relative test paths from the matrix test cells. An absent
        matrix file returns no paths.
    """
    text = try_git(root, ["show", "%s:%s" % (sha, MATRIX_REL)])
    paths = []
    for line in text.splitlines():
        line = line.strip()
        if not (line.startswith("|") and line.endswith("|")):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 7 or cells[2] not in ("P0", "P1", "P2"):
            continue
        cell = cells[4]
        if len(cell) >= 2 and cell.startswith("`") and cell.endswith("`"):
            cell = cell[1:-1].strip()
        if TEST_SEPARATOR not in cell:
            continue
        path = cell.split(TEST_SEPARATOR, 1)[0].strip()
        if path:
            paths.append(path)
    return paths


def read_registration(root: str, sha: str, present: Set[str]) -> Set[str]:
    """Read the registered tests for one commit.

    Args:
        root: Repository root.
        sha: Commit to check.
        present: Every path present at the commit.

    Returns:
        The test paths the parent names in the hardening matrix or the skill
        health workflow and that exist at the parent and at the commit. A
        name read from either reviewed surface is registration, and no name
        or glob match is. A test that exists only in the commit under check
        is not registered, and a path the commit deletes is not registered,
        so removing a covering test cannot cover the commit that removes it.
    """
    parent = parent_of(root, sha)
    if not parent:
        return set()
    parent_paths = tree_paths(root, parent)
    named = set(matrix_test_paths(root, parent)) | workflow_test_paths(root, parent)
    return {path for path in named if path in parent_paths and path in present}

# ───────────────────────────────────────────────────────────────
# 5. CHECK
# ───────────────────────────────────────────────────────────────

def check_commit(
    sha: str,
    message: str,
    changed: List[Tuple[str, str]],
    registered: Set[str],
    present: Set[str],
) -> List[str]:
    """Check one commit with a gate file change for its covering test.

    Args:
        sha: Full commit hash.
        message: Full commit message, including any trailer.
        changed: Change status and path for every file the commit touched.
        registered: Registered test paths for the commit.
        present: Every path present at the commit.

    Returns:
        One problem line per finding, empty when the commit is covered.
    """
    gate_hits = sorted({path for _, path in changed} & set(GATE_FILES))
    if not gate_hits:
        return []
    # WHY: a deleted path is never a test change, a rename source is read as
    # a deletion and a copy source keeps its content, so none of them can
    # cover the gate change. The registered set already drops every path
    # missing at the parent or at this commit.
    if any(path in registered and status[0] in TEST_CHANGE_STATUSES for status, path in changed):
        return []
    trailers = [value.strip() for value in TRAILER_RE.findall(message)]
    if any(value in registered for value in trailers):
        return []
    if trailers:
        problems = []
        for value in trailers:
            if value not in present:
                problems.append(
                    "commit %s: Regression-Test: %s names a test missing at this commit"
                    % (sha[:12], value)
                )
            else:
                problems.append(
                    "commit %s: Regression-Test: %s names an unregistered test"
                    % (sha[:12], value)
                )
        return problems
    return [
        "commit %s: %s changed without a registered test change or a Regression-Test: trailer"
        % (sha[:12], ", ".join(gate_hits))
    ]


def check_range(root: str, commit_range: str) -> int:
    """Check every commit of a range for a gate change without cover.

    Args:
        root: Repository root.
        commit_range: Range for git log, written as <base>..<head>.

    Returns:
        Zero when the range passes, one on a finding.
    """
    commits = read_commits(root, commit_range)
    problems: List[str] = []
    for sha, message, changed in commits:
        present = tree_paths(root, sha)
        registered = read_registration(root, sha, present)
        problems.extend(check_commit(sha, message, changed, registered, present))
    if problems:
        for problem in problems:
            print("regression-trailer: %s" % problem)
        return 1
    print("regression-trailer: ok (%d commits scanned)" % len(commits))
    return 0

# ───────────────────────────────────────────────────────────────
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the range check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the range passes, one on a finding.

    Raises:
        SystemExit: If the root is not a directory.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check a commit range for gate file changes without a covering test.",
    )
    parser.add_argument("--range", required=True, metavar="BASE..HEAD", help="commit range for git log")
    parser.add_argument(
        "--root",
        default=REPO_ROOT,
        metavar="DIR",
        help="read another repository instead of the one above this script",
    )
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        fail("not a directory: %s" % args.root)
    return check_range(root, args.range)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
