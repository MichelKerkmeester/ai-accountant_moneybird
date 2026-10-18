#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: REGRESSION TRAILER TEST
# ───────────────────────────────────────────────────────────────
# Tests check-regression-trailer.py on fixture git repositories built in temp
# dirs. Each repository holds a copy of the checker, which reads the
# repository above it: registration by a fixture workflow run line,
# registration by the hardening matrix, registration read at the parent of the
# commit, a deleted covering test, a suite neither reviewed file names, valid
# and invalid trailers, the non-gate rule and an unknown range. The suite
# also proves that a trailer naming a missing, deleted or unregistered test
# fails. Four more histories cover a gate change inside a merge commit, a
# renamed or copied gate file, a renamed registered test, a commit message
# that holds control characters, a test that exists only in the gate commit
# and a trailer for a test created in the same commit.
# Usage: regression-trailer-test.sh [repo root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, missing checker files or a fixture history that did
#       not build
#
# WHY: the trailer check only guards the gate files when it reads registration
# from the parent of each commit, fails a gate change whose covering test was
# deleted, and passes a gate change with a test the hardening matrix or the
# fixture workflow names, so this suite builds those histories at run time
# with signing and hooks off.
# WHY: the histories also pin the merge, rename, copy, framing and parent
# existence rules, so each rule has a case that fails when its fix is reverted.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS AND ARGUMENT VALIDATION
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: regression-trailer-test.sh [repo root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

CHECKER="$REPO_SRC/sk-moneybird-accountant/scripts/check-regression-trailer.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-regression-trailer.py in the repository\n' >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'error: python3 is not available\n' >&2
    exit 2
fi
if ! command -v git >/dev/null 2>&1; then
    printf 'error: git is not available\n' >&2
    exit 2
fi

# Keep the run away from agent markers and credentials, the way run-tests.sh does
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
unset MONEYBIRD_HMAC_KEY_FILE MONEYBIRD_PILOT_ADMINISTRATION_ID || true
unset MONEYBIRD_GUARD_READ_ONLY || true

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT, GIT ISOLATION AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/regression-trailer-test.XXXXXX") || exit 2
mkdir -p "$TMP_ROOT/gitenv" "$TMP_ROOT/empty-hooks"
# WHY: isolate git config so a developer global config or a hook cannot change the verdicts.
export HOME="$TMP_ROOT/gitenv"
export XDG_CONFIG_HOME="$TMP_ROOT/gitenv/.config"
export GIT_CONFIG_NOSYSTEM=1

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 3. TEST HELPERS AND FIXTURE BUILDERS
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

# Run the fixture repository's own copy of the checker and capture its output
# Args:
#   $1 - Commit range
#   $2 - Repository root
#   $3 - Tag for the captured output file under the temp root
# Returns:
#   The checker exit status
run_check() {
    python3 -I "$2/sk-moneybird-accountant/scripts/check-regression-trailer.py" --range "$1" >"$TMP_ROOT/check-$3.txt" 2>&1
}

# Copy the checker into a fixture repository after its last commit, so the
# untracked copy never enters the history under test
# Args:
#   $1 - Repository root
# Returns:
#   0 when the copy is in place, 1 otherwise
install_checker() {
    mkdir -p "$1/sk-moneybird-accountant/scripts" || return 1
    cp "$CHECKER" "$1/sk-moneybird-accountant/scripts/check-regression-trailer.py" || return 1
}

# Stop the run when a fixture history did not build, because every case that
# reads it would then report a verdict about nothing
# Args:
#   $1 - Name of the fixture history
#   $2... - Every commit hash the history must hold
require_history() {
    local name="$1"
    local sha
    shift
    for sha in "$@"; do
        if [[ -z "$sha" ]]; then
            printf 'error: the %s did not build\n' "$name" >&2
            exit 2
        fi
    done
}

# Create one fixture git repository with signing, hooks and identity pinned
# Args:
#   $1 - Repository folder to create
# Returns:
#   0 when the repository is ready, 1 otherwise
make_repo() {
    local repo="$1"
    mkdir -p "$repo" || return 1
    git -C "$repo" -c init.defaultBranch=main init -q || return 1
    git -C "$repo" config user.name "fixture" || return 1
    git -C "$repo" config user.email "fixture@example.com" || return 1
    git -C "$repo" config commit.gpgsign false || return 1
    git -C "$repo" config core.hooksPath "$TMP_ROOT/empty-hooks" || return 1
    return 0
}

# Stage every change and commit it with an optional body paragraph
# Args:
#   $1 - Repository root
#   $2 - Commit subject
#   $3 - Optional body, used for the trailer
# Returns:
#   0 when the commit is created, 1 otherwise
commit_all() {
    local repo="$1"
    local subject="$2"
    local body="${3:-}"
    git -C "$repo" add -A || return 1
    if [[ -n "$body" ]]; then
        git -C "$repo" commit -q -m "$subject" -m "$body" || return 1
    else
        git -C "$repo" commit -q -m "$subject" || return 1
    fi
    return 0
}

# Print the current commit hash of a repository
# Args:
#   $1 - Repository root
head_of() {
    git -C "$1" rev-parse HEAD
}

# ───────────────────────────────────────────────────────────────
# 4. FIXTURE REPOSITORIES
# ───────────────────────────────────────────────────────────────

# Repo A: registration by a fixture workflow, a non-gate change and a range
# that holds one failing commit.
REPO_A="$TMP_ROOT/repo-a"
if make_repo "$REPO_A"; then
    mkdir -p "$REPO_A/sk-moneybird-accountant" "$REPO_A/cli-moneybird" \
        "$REPO_A/cli-moneybird/cli/moneybird-cli/tests" "$REPO_A/.github/workflows"
    printf '# Fixture contract\n' > "$REPO_A/AGENTS.md"
    printf '# Fixture skill\n' > "$REPO_A/sk-moneybird-accountant/SKILL.md"
    printf '# Fixture tool skill\n' > "$REPO_A/cli-moneybird/SKILL.md"
    printf '# Fixture readme\n' > "$REPO_A/README.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_A/cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
    cat > "$REPO_A/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the guard suite
        run: bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
WORKFLOW
    commit_all "$REPO_A" "fixture baseline"
fi
BASE_A=$(head_of "$REPO_A")

printf '\nA gate change.\n' >> "$REPO_A/AGENTS.md"
commit_all "$REPO_A" "change the gate file"
GATE_A=$(head_of "$REPO_A")

printf '\nA gate change with a registered suite.\n' >> "$REPO_A/sk-moneybird-accountant/SKILL.md"
printf '# extra suite line\n' >> "$REPO_A/cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
commit_all "$REPO_A" "change the gate file with a registered suite change"
SUITE_A=$(head_of "$REPO_A")

printf '\nA note.\n' >> "$REPO_A/README.md"
commit_all "$REPO_A" "change a non-gate file"
DOC_A=$(head_of "$REPO_A")

require_history "suite-registration fixture repository" "$BASE_A" "$GATE_A" "$SUITE_A" "$DOC_A"

# Repo B: the trailer forms.
REPO_B="$TMP_ROOT/repo-b"
if make_repo "$REPO_B"; then
    mkdir -p "$REPO_B/cli-moneybird" "$REPO_B/cli-jortt" \
        "$REPO_B/cli-moneybird/cli/moneybird-cli/tests" "$REPO_B/sk-moneybird-accountant/notes" \
        "$REPO_B/.github/workflows"
    printf '# Fixture tool skill\n' > "$REPO_B/cli-moneybird/SKILL.md"
    printf '# Fixture source skill\n' > "$REPO_B/cli-jortt/SKILL.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_B/cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
    printf '#!/usr/bin/env bash\n' > "$REPO_B/sk-moneybird-accountant/notes/sample-test.sh"
    cat > "$REPO_B/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the guard suite
        run: bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
WORKFLOW
    commit_all "$REPO_B" "fixture baseline"
fi
BASE_B=$(head_of "$REPO_B")

printf '\nA gate change with a trailer.\n' >> "$REPO_B/cli-moneybird/SKILL.md"
commit_all "$REPO_B" "change the gate file with the trailer" \
    "Regression-Test: cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
TRAILER_B=$(head_of "$REPO_B")

printf '\nA gate change with an empty trailer.\n' >> "$REPO_B/cli-jortt/SKILL.md"
commit_all "$REPO_B" "change the gate file with an empty trailer" "Regression-Test:"
EMPTY_B=$(head_of "$REPO_B")

printf '\nA gate change with a trailer for a missing test.\n' >> "$REPO_B/cli-moneybird/SKILL.md"
commit_all "$REPO_B" "change the gate file with a trailer for a missing test" \
    "Regression-Test: sk-moneybird-accountant/scripts/no-such-test.sh"
MISSING_B=$(head_of "$REPO_B")

printf '\nA gate change with a trailer for an unregistered test.\n' >> "$REPO_B/cli-jortt/SKILL.md"
commit_all "$REPO_B" "change the gate file with a trailer for an unregistered test" \
    "Regression-Test: sk-moneybird-accountant/notes/sample-test.sh"
UNREG_B=$(head_of "$REPO_B")

printf '\nA gate change that deletes the registered test its trailer names.\n' >> "$REPO_B/cli-jortt/SKILL.md"
rm -f "$REPO_B/cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
commit_all "$REPO_B" "change the gate file and delete the registered test" \
    "Regression-Test: cli-moneybird/cli/moneybird-cli/tests/run-tests.sh"
DELETED_B=$(head_of "$REPO_B")

require_history "trailer fixture repository" "$BASE_B" "$TRAILER_B" "$EMPTY_B" "$MISSING_B" "$UNREG_B" "$DELETED_B"

# Repo C: registration by the hardening matrix.
REPO_C="$TMP_ROOT/repo-c"
if make_repo "$REPO_C"; then
    mkdir -p "$REPO_C/sk-moneybird-accountant/notes"
    printf '# Fixture contract\n' > "$REPO_C/AGENTS.md"
    cat > "$REPO_C/sk-moneybird-accountant/hardening-matrix.md" <<'MATRIX'
# Fixture matrix

| # | Failure mode | Priority | Control | Test | Owner | Status |
|---|---|---|---|---|---|---|
| F-01 | fixture failure mode | P0 | fixture control | `sk-moneybird-accountant/notes/covering-fixture.sh :: fixture case` | Operator | Covered |
MATRIX
    printf 'fixture case\n' > "$REPO_C/sk-moneybird-accountant/notes/covering-fixture.sh"
    commit_all "$REPO_C" "fixture baseline"
fi
BASE_C=$(head_of "$REPO_C")

printf '\nA gate change with a matrix-registered test.\n' >> "$REPO_C/AGENTS.md"
printf 'fixture case\n' >> "$REPO_C/sk-moneybird-accountant/notes/covering-fixture.sh"
commit_all "$REPO_C" "change the gate file with a matrix-registered test change"
MATRIX_C=$(head_of "$REPO_C")

printf '\nA gate change with a newly added matrix row and test.\n' >> "$REPO_C/AGENTS.md"
cat >> "$REPO_C/sk-moneybird-accountant/hardening-matrix.md" <<'MATRIX'
| F-02 | fixture failure mode | P0 | fixture control | `sk-moneybird-accountant/notes/added-fixture.sh :: added case` | Operator | Covered |
MATRIX
printf 'added case\n' > "$REPO_C/sk-moneybird-accountant/notes/added-fixture.sh"
commit_all "$REPO_C" "change the gate file with a newly added matrix row and test"
MADDED_C=$(head_of "$REPO_C")

printf '\nA gate change that deletes the matrix-named test.\n' >> "$REPO_C/AGENTS.md"
rm -f "$REPO_C/sk-moneybird-accountant/notes/added-fixture.sh"
commit_all "$REPO_C" "change the gate file and delete the matrix-named test"
DELETED_C=$(head_of "$REPO_C")

require_history "matrix-registration fixture repository" "$BASE_C" "$MATRIX_C" "$MADDED_C" "$DELETED_C"

# Repo D: registration by a fixture workflow file, on a plain run line, on a
# block scalar run line and by an evals path, plus one suite it does not run.
REPO_D="$TMP_ROOT/repo-d"
if make_repo "$REPO_D"; then
    mkdir -p "$REPO_D/sk-moneybird-accountant/scripts" \
        "$REPO_D/sk-moneybird-accountant/evals" "$REPO_D/.github/workflows"
    printf '# Fixture contract\n' > "$REPO_D/AGENTS.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_D/sk-moneybird-accountant/scripts/one-test.sh"
    printf '#!/usr/bin/env bash\n' > "$REPO_D/sk-moneybird-accountant/scripts/two-test.sh"
    printf '#!/usr/bin/env bash\n' > "$REPO_D/sk-moneybird-accountant/scripts/spare-test.sh"
    printf '{}\n' > "$REPO_D/sk-moneybird-accountant/evals/evals.json"
    cat > "$REPO_D/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the first suite
        run: bash sk-moneybird-accountant/scripts/one-test.sh
      - name: Run the grader and the second suite
        run: |
          python3 -I sk-moneybird-accountant/scripts/run-evals.py --grade sk-moneybird-accountant/evals/evals.json
          bash sk-moneybird-accountant/scripts/two-test.sh
      - name: Run a check that is not a suite
        run: python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py
WORKFLOW
    commit_all "$REPO_D" "fixture baseline"
fi
BASE_D=$(head_of "$REPO_D")

printf '\nA gate change with the single-line workflow suite.\n' >> "$REPO_D/AGENTS.md"
printf '# one\n' >> "$REPO_D/sk-moneybird-accountant/scripts/one-test.sh"
commit_all "$REPO_D" "change the gate file with the single-line workflow suite"
ONE_D=$(head_of "$REPO_D")

printf '\nA gate change with the block-scalar workflow suite.\n' >> "$REPO_D/AGENTS.md"
printf '# two\n' >> "$REPO_D/sk-moneybird-accountant/scripts/two-test.sh"
commit_all "$REPO_D" "change the gate file with the block-scalar workflow suite"
TWO_D=$(head_of "$REPO_D")

printf '\nA gate change with the workflow evals path.\n' >> "$REPO_D/AGENTS.md"
printf '{"case": "fixture"}\n' > "$REPO_D/sk-moneybird-accountant/evals/evals.json"
commit_all "$REPO_D" "change the gate file with the workflow evals path"
EVALS_D=$(head_of "$REPO_D")

printf '\nA gate change with a suite the workflow does not run.\n' >> "$REPO_D/AGENTS.md"
printf '# spare\n' >> "$REPO_D/sk-moneybird-accountant/scripts/spare-test.sh"
commit_all "$REPO_D" "change the gate file with a suite the workflow does not run"
SPARE_D=$(head_of "$REPO_D")

require_history "workflow-registration fixture repository" "$BASE_D" "$ONE_D" "$TWO_D" "$EVALS_D" "$SPARE_D"

# Repo E: no workflow and no matrix, so nothing can register.
REPO_E="$TMP_ROOT/repo-e"
if make_repo "$REPO_E"; then
    mkdir -p "$REPO_E/sk-moneybird-accountant/scripts"
    printf '# Fixture contract\n' > "$REPO_E/AGENTS.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_E/sk-moneybird-accountant/scripts/only-test.sh"
    commit_all "$REPO_E" "fixture baseline"
fi
BASE_E=$(head_of "$REPO_E")

printf '\nA gate change with a suite and no workflow.\n' >> "$REPO_E/AGENTS.md"
printf '# only\n' >> "$REPO_E/sk-moneybird-accountant/scripts/only-test.sh"
commit_all "$REPO_E" "change the gate file with a suite and no workflow"
NOWORKFLOW_E=$(head_of "$REPO_E")

require_history "no-workflow fixture repository" "$BASE_E" "$NOWORKFLOW_E"

# Repo F: a gate change made inside a merge commit, which a plain git log
# lists without paths.
REPO_F="$TMP_ROOT/repo-f"
if make_repo "$REPO_F"; then
    mkdir -p "$REPO_F/sk-moneybird-accountant/scripts" "$REPO_F/.github/workflows"
    printf '# Fixture contract\n' > "$REPO_F/AGENTS.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_F/sk-moneybird-accountant/scripts/merge-suite-test.sh"
    cat > "$REPO_F/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the merge suite
        run: bash sk-moneybird-accountant/scripts/merge-suite-test.sh
WORKFLOW
    commit_all "$REPO_F" "fixture baseline"
fi
BASE_F=$(head_of "$REPO_F")

printf 'main line\n' > "$REPO_F/main.txt"
commit_all "$REPO_F" "main side of the merge"
MAIN_F=$(head_of "$REPO_F")

git -C "$REPO_F" checkout -q -b side "$BASE_F" || true
printf 'side line\n' > "$REPO_F/side.txt"
commit_all "$REPO_F" "other side of the merge"
SIDE_F=$(head_of "$REPO_F")
git -C "$REPO_F" checkout -q main || true
git -C "$REPO_F" merge -q --no-ff --no-commit side >/dev/null 2>&1 || true
printf '\nA gate change made while merging.\n' >> "$REPO_F/AGENTS.md"
commit_all "$REPO_F" "merge the side branch with a gate change"
MERGE_F=$(head_of "$REPO_F")
MERGE_F_PARENTS=$(git -C "$REPO_F" rev-list --parents -n 1 "$MERGE_F" 2>/dev/null | wc -w | tr -d ' ')

require_history "merge fixture repository" "$BASE_F" "$MAIN_F" "$SIDE_F" "$MERGE_F"
if [[ "${MERGE_F_PARENTS:-0}" -lt 3 ]]; then
    printf 'error: the merge fixture commit has no second parent\n' >&2
    exit 2
fi

# Repo G: a renamed or copied gate file, and a renamed registered test. A
# rename or copy counts on the source side, and a renamed test is a deletion
# of its old path.
REPO_G="$TMP_ROOT/repo-g"
if make_repo "$REPO_G"; then
    mkdir -p "$REPO_G/cli-moneybird" "$REPO_G/sk-moneybird-accountant/scripts" \
        "$REPO_G/.github/workflows"
    printf '# Fixture contract\n' > "$REPO_G/AGENTS.md"
    printf '# Fixture tool skill\n' > "$REPO_G/cli-moneybird/SKILL.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_G/sk-moneybird-accountant/scripts/live-suite-test.sh"
    cat > "$REPO_G/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the live suite
        run: bash sk-moneybird-accountant/scripts/live-suite-test.sh
WORKFLOW
    commit_all "$REPO_G" "fixture baseline"
fi
BASE_G=$(head_of "$REPO_G")

git -C "$REPO_G" mv AGENTS.md CONTRACT.md || true
commit_all "$REPO_G" "rename the gate file"
RENAME_G=$(head_of "$REPO_G")

cp "$REPO_G/cli-moneybird/SKILL.md" "$REPO_G/cli-moneybird/SKILL-extra.md"
commit_all "$REPO_G" "copy the tool skill"
COPY_G=$(head_of "$REPO_G")

printf '\nA tool skill change.\n' >> "$REPO_G/cli-moneybird/SKILL.md"
git -C "$REPO_G" mv sk-moneybird-accountant/scripts/live-suite-test.sh \
    sk-moneybird-accountant/scripts/moved-suite-test.sh || true
commit_all "$REPO_G" "rename the registered test away"
RENAMETEST_G=$(head_of "$REPO_G")

require_history "rename and copy fixture repository" "$BASE_G" "$RENAME_G" "$COPY_G" "$RENAMETEST_G"

# Repo H: a name at the parent that the gate commit fulfils by creating the
# file. The test must exist at the parent too, and a trailer cannot name a
# path that is absent there.
REPO_H="$TMP_ROOT/repo-h"
if make_repo "$REPO_H"; then
    mkdir -p "$REPO_H/sk-moneybird-accountant/notes"
    printf '# Fixture contract\n' > "$REPO_H/AGENTS.md"
    cat > "$REPO_H/sk-moneybird-accountant/hardening-matrix.md" <<'MATRIX'
# Fixture matrix

| # | Failure mode | Priority | Control | Test | Owner | Status |
|---|---|---|---|---|---|---|
| F-01 | fixture failure mode | P0 | fixture control | `sk-moneybird-accountant/notes/late-fixture.sh :: late case` | Operator | Covered |
| F-02 | fixture failure mode | P0 | fixture control | `sk-moneybird-accountant/notes/trailer-fixture.sh :: trailer case` | Operator | Covered |
MATRIX
    commit_all "$REPO_H" "fixture baseline"
fi
BASE_H=$(head_of "$REPO_H")

printf '\nA gate change that creates the named test.\n' >> "$REPO_H/AGENTS.md"
printf 'late case\n' > "$REPO_H/sk-moneybird-accountant/notes/late-fixture.sh"
commit_all "$REPO_H" "change the gate file and create the named test"
CREATED_H=$(head_of "$REPO_H")

printf '\nA gate change with a trailer for a created test.\n' >> "$REPO_H/AGENTS.md"
printf 'trailer case\n' > "$REPO_H/sk-moneybird-accountant/notes/trailer-fixture.sh"
commit_all "$REPO_H" "change the gate file with a trailer for a created test" \
    "Regression-Test: sk-moneybird-accountant/notes/trailer-fixture.sh"
TRAILER_H=$(head_of "$REPO_H")

require_history "parent-existence fixture repository" "$BASE_H" "$CREATED_H" "$TRAILER_H"

# Repo I: a commit message that holds a record or unit separator.
REPO_I="$TMP_ROOT/repo-i"
if make_repo "$REPO_I"; then
    mkdir -p "$REPO_I/sk-moneybird-accountant/scripts" "$REPO_I/.github/workflows"
    printf '# Fixture contract\n' > "$REPO_I/AGENTS.md"
    printf '#!/usr/bin/env bash\n' > "$REPO_I/sk-moneybird-accountant/scripts/framing-suite-test.sh"
    cat > "$REPO_I/.github/workflows/skill-health.yml" <<'WORKFLOW'
name: Fixture skill health
on:
  push:
jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Run the framing suite
        run: bash sk-moneybird-accountant/scripts/framing-suite-test.sh
WORKFLOW
    commit_all "$REPO_I" "fixture baseline"
fi
BASE_I=$(head_of "$REPO_I")

printf '\nA gate change with a control character in its message.\n' >> "$REPO_I/AGENTS.md"
commit_all "$REPO_I" "$(printf 'framing fixture\x1e\x1f subject')"
FRAMING_I=$(head_of "$REPO_I")

require_history "framing fixture repository" "$BASE_I" "$FRAMING_I"

for repo in "$REPO_A" "$REPO_B" "$REPO_C" "$REPO_D" "$REPO_E" "$REPO_F" "$REPO_G" "$REPO_H" "$REPO_I"; do
    if ! install_checker "$repo"; then
        printf 'error: the checker could not be copied into %s\n' "$repo" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 5. RANGE CHECKS
# ───────────────────────────────────────────────────────────────

group "Range checks"

run_check "$BASE_A..$GATE_A" "$REPO_A" gate
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-gate.txt"; then
    pass "a gate change without a test or trailer exits 1 and names the file"
else
    fail "a gate change without a test or trailer exits 1 and names the file (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-gate.txt"
fi

run_check "$GATE_A..$SUITE_A" "$REPO_A" suite
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-suite.txt"; then
    pass "a gate change with a registered suite change exits 0"
else
    fail "a gate change with a registered suite change exits 0 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-suite.txt"
fi

run_check "$SUITE_A..$DOC_A" "$REPO_A" doc
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-doc.txt"; then
    pass "a non-gate change without a trailer exits 0"
else
    fail "a non-gate change without a trailer exits 0 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-doc.txt"
fi

run_check "$BASE_A..$DOC_A" "$REPO_A" mixed
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-mixed.txt"; then
    pass "a range holding one failing commit exits 1"
else
    fail "a range holding one failing commit exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-mixed.txt"
fi

run_check "$BASE_B..$TRAILER_B" "$REPO_B" trailer
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-trailer.txt"; then
    pass "a gate change with the trailer exits 0"
else
    fail "a gate change with the trailer exits 0 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-trailer.txt"
fi

run_check "$TRAILER_B..$EMPTY_B" "$REPO_B" empty
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'cli-jortt/SKILL.md' "$TMP_ROOT/check-empty.txt"; then
    pass "an empty trailer value still exits 1 and names the file"
else
    fail "an empty trailer value still exits 1 and names the file (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-empty.txt"
fi

run_check "$EMPTY_B..$MISSING_B" "$REPO_B" missing
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'names a test missing at this commit' "$TMP_ROOT/check-missing.txt"; then
    pass "a trailer naming a missing test exits 1"
else
    fail "a trailer naming a missing test exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-missing.txt"
fi

run_check "$MISSING_B..$UNREG_B" "$REPO_B" unregistered
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'names an unregistered test' "$TMP_ROOT/check-unregistered.txt"; then
    pass "a trailer naming an unregistered test exits 1"
else
    fail "a trailer naming an unregistered test exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-unregistered.txt"
fi

run_check "$UNREG_B..$DELETED_B" "$REPO_B" deleted-trailer
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'names a test missing at this commit' "$TMP_ROOT/check-deleted-trailer.txt"; then
    pass "a trailer for a registered test the commit deletes exits 1"
else
    fail "a trailer for a registered test the commit deletes exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-deleted-trailer.txt"
fi

run_check "$BASE_C..$MATRIX_C" "$REPO_C" matrix
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-matrix.txt"; then
    pass "a gate change with a matrix-registered test change exits 0"
else
    fail "a gate change with a matrix-registered test change exits 0 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-matrix.txt"
fi

run_check "$MATRIX_C..$MADDED_C" "$REPO_C" matrix-added
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-matrix-added.txt"; then
    pass "a gate change with a newly added matrix row and test exits 1, registration is read at the parent"
else
    fail "a gate change with a newly added matrix row and test exits 1, registration is read at the parent (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-matrix-added.txt"
fi

run_check "$MADDED_C..$DELETED_C" "$REPO_C" matrix-deleted
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-matrix-deleted.txt"; then
    pass "a gate change that deletes the matrix-named test exits 1"
else
    fail "a gate change that deletes the matrix-named test exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-matrix-deleted.txt"
fi

run_check "$BASE_D..$ONE_D" "$REPO_D" workflow-line
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-workflow-line.txt"; then
    pass "a suite on a single-line workflow run line counts"
else
    fail "a suite on a single-line workflow run line counts (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-workflow-line.txt"
fi

run_check "$ONE_D..$TWO_D" "$REPO_D" workflow-block
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-workflow-block.txt"; then
    pass "a suite on a block workflow run line counts"
else
    fail "a suite on a block workflow run line counts (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-workflow-block.txt"
fi

run_check "$TWO_D..$EVALS_D" "$REPO_D" workflow-evals
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'regression-trailer: ok' "$TMP_ROOT/check-workflow-evals.txt"; then
    pass "an evals path on a workflow run line counts"
else
    fail "an evals path on a workflow run line counts (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-workflow-evals.txt"
fi

run_check "$EVALS_D..$SPARE_D" "$REPO_D" workflow-spare
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-workflow-spare.txt"; then
    pass "a suite the fixture workflow does not run exits 1"
else
    fail "a suite the fixture workflow does not run exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-workflow-spare.txt"
fi

run_check "$BASE_E..$NOWORKFLOW_E" "$REPO_E" no-workflow
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-no-workflow.txt"; then
    pass "a suite with no workflow at the parent exits 1"
else
    fail "a suite with no workflow at the parent exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-no-workflow.txt"
fi

run_check "$MAIN_F..$MERGE_F" "$REPO_F" merge
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-merge.txt"; then
    pass "a gate change inside a merge commit exits 1 and names the file"
else
    fail "a gate change inside a merge commit exits 1 and names the file (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-merge.txt"
fi

run_check "$BASE_G..$RENAME_G" "$REPO_G" rename
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-rename.txt"; then
    pass "renaming a gate file exits 1 and names the source path"
else
    fail "renaming a gate file exits 1 and names the source path (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-rename.txt"
fi

run_check "$RENAME_G..$COPY_G" "$REPO_G" copy
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'cli-moneybird/SKILL.md' "$TMP_ROOT/check-copy.txt"; then
    pass "copying a gate file exits 1 and names the source path"
else
    fail "copying a gate file exits 1 and names the source path (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-copy.txt"
fi

run_check "$COPY_G..$RENAMETEST_G" "$REPO_G" rename-test
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'cli-moneybird/SKILL.md' "$TMP_ROOT/check-rename-test.txt"; then
    pass "renaming a registered test away exits 1, the old path is a deletion"
else
    fail "renaming a registered test away exits 1, the old path is a deletion (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-rename-test.txt"
fi

run_check "$BASE_H..$CREATED_H" "$REPO_H" registration-created
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-registration-created.txt"; then
    pass "a test created in the gate commit does not register, exit 1"
else
    fail "a test created in the gate commit does not register, exit 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-registration-created.txt"
fi

run_check "$CREATED_H..$TRAILER_H" "$REPO_H" trailer-created
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'names an unregistered test' "$TMP_ROOT/check-trailer-created.txt"; then
    pass "a trailer naming a test created in the same commit exits 1"
else
    fail "a trailer naming a test created in the same commit exits 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-trailer-created.txt"
fi

run_check "$BASE_I..$FRAMING_I" "$REPO_I" framing
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'AGENTS.md' "$TMP_ROOT/check-framing.txt"; then
    pass "a control character in a commit message does not drop its paths"
else
    fail "a control character in a commit message does not drop its paths (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-framing.txt"
fi

run_check "$DOC_A..$DOC_A" "$REPO_A" empty-range
status=$?
if [[ "$status" -eq 0 ]] && grep -qF '0 commits scanned' "$TMP_ROOT/check-empty-range.txt"; then
    pass "an empty range exits 0 with no commits scanned"
else
    fail "an empty range exits 0 with no commits scanned (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-empty-range.txt"
fi

# ───────────────────────────────────────────────────────────────
# 6. USAGE GUARDS
# ───────────────────────────────────────────────────────────────

group "Usage guards"

run_check "no-such-ref..HEAD" "$REPO_A" bad-range
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "an unknown range is refused with exit 2"
else
    fail "an unknown range is refused with exit 2 (exit $status)"
fi

# ───────────────────────────────────────────────────────────────
# 7. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
