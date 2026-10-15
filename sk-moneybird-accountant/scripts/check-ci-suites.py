#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: CI SUITE REGISTRATION CHECK
# ───────────────────────────────────────────────────────────────
"""Check that every offline suite has a run line in the skill health workflow.

Every *-test.sh under the skill scripts folder, every *-test.sh under
route-replay and each CLI test runner is a suite the repository ships. A
suite that no run line in .github/workflows/skill-health.yml names runs on no
push and no pull request, so a regression in it stays invisible until someone
runs it by hand. This check reads the workflow run lines through the same
parser the regression trailer check uses, so one suite list serves both. A
block scalar contributes one command per indented line and a plain run line
contributes its command text, so a suite named in a pipe block, after && or
on its own line all count. The workflow is a privacy gate file, so the check
reports the run line a missing suite needs and never edits the workflow. The
script uses the Python standard library only, reads local files only and
makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-ci-suites.py
    python3 -I sk-moneybird-accountant/scripts/check-ci-suites.py --root DIR

Options:
    --root DIR  Read another repository. Defaults to the root above this
                script.

Output:
    "check-ci-suites: ok, N suites registered" on stdout when every suite has
    a run line, one "missing-run PATH" line per suite without one otherwise.
    Exit 0 when every suite has a run line, 1 on a missing run line and 2 on a
    usage error or a missing workflow.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import glob
import importlib.util
import os
import sys
from typing import Any, List, NoReturn, Set

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/check-ci-suites.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

WORKFLOW_REL = ".github/workflows/skill-health.yml"

# WHY: the parser lives with the regression trailer check, which already reads
# the run lines to learn which tests are registered, so this check imports it
# instead of holding a second copy that can drift.
PARSER_HELPER = "check-regression-trailer.py"

# The suite globs the workflow has to cover, relative to the repository root.
SUITE_GLOBS = (
    "sk-moneybird-accountant/scripts/*-test.sh",
    "sk-moneybird-accountant/scripts/route-replay/*-test.sh",
)

# The CLI test runners sit outside the skill scripts folder.
CLI_SUITES = (
    "cli-moneybird/cli/moneybird-cli/tests/run-tests.sh",
    "cli-jortt/cli/jortt-cli/tests/run-tests.sh",
    "cli-moneybird/scripts/exit-code-parity-test.sh",
)

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


def load_parser() -> Any:
    """Load the run line parser from the regression trailer check.

    Returns:
        The parser module.

    Raises:
        SystemExit: If the helper is missing or cannot be loaded.
    """
    helper = os.path.join(SCRIPT_DIR, PARSER_HELPER)
    if not os.path.isfile(helper):
        fail("missing parser helper: %s" % PARSER_HELPER)
    spec = importlib.util.spec_from_file_location("ci_suites_regression_trailer", helper)
    if spec is None or spec.loader is None:
        fail("cannot load parser helper: %s" % PARSER_HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_text(path: str) -> str:
    """Read one text file.

    Args:
        path: Absolute file path.

    Returns:
        The file text.

    Raises:
        SystemExit: If the file cannot be read.
    """
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (path, exc))


def discover_suites(root: str) -> List[str]:
    """List every suite file the repository ships.

    Args:
        root: Repository root.

    Returns:
        The sorted repo-relative suite paths from the globs and the CLI list.
    """
    suites: Set[str] = set()
    for pattern in SUITE_GLOBS:
        for path in glob.glob(os.path.join(root, pattern)):
            suites.add(os.path.relpath(path, root).replace(os.sep, "/"))
    for relative in CLI_SUITES:
        if os.path.isfile(os.path.join(root, relative)):
            suites.add(relative)
    return sorted(suites)


def workflow_suite_paths(root: str, parser: Any) -> Set[str]:
    """Read the suite paths the skill health workflow runs.

    Args:
        root: Repository root.
        parser: The loaded run line parser module.

    Returns:
        The repo-relative suite paths on the workflow run lines.

    Raises:
        SystemExit: If the workflow file is missing.
    """
    workflow = os.path.join(root, WORKFLOW_REL)
    if not os.path.isfile(workflow):
        fail("missing %s, the check reads its run lines" % WORKFLOW_REL)
    paths: Set[str] = set()
    for command in parser.run_commands(read_text(workflow)):
        paths.update(parser.command_test_paths(command))
    return paths


def check(root: str, parser: Any) -> int:
    """Report every suite that no workflow run line names.

    Args:
        root: Repository root.
        parser: The loaded run line parser module.

    Returns:
        Zero when every suite has a run line, one otherwise.
    """
    suites = discover_suites(root)
    registered = workflow_suite_paths(root, parser)
    missing = [suite for suite in suites if suite not in registered]
    if missing:
        print("check-ci-suites: %d suites, %d without a run line" % (len(suites), len(missing)))
        for suite in missing:
            print("missing-run %s" % suite)
        return 1
    print("check-ci-suites: ok, %d suites registered" % len(suites))
    return 0


def main(argv: List[str]) -> int:
    """Parse arguments and run the check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the check.

    Raises:
        SystemExit: If the root is not a directory.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check that every offline suite has a run line in the skill health workflow.",
    )
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
    return check(root, load_parser())


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
