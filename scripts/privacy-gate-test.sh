#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: PRIVACY GATE TEST SUITE
# ───────────────────────────────────────────────────────────────
# Exercises scripts/privacy-gate.py against throwaway repositories.
# Every sensitive value is generated at runtime so this file stays clean.
# Usage: scripts/privacy-gate-test.sh
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
# Failing gate runs are asserted through $?, so -e must stay off
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. CONFIGURATION
# ───────────────────────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/privacy-gate-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
LAST_OUT=""
GATE_STDIN="/dev/null"
GATE_APPROVED=""
ZERO_SHA="$(python3 -c 'print("0" * 40)')"

# ───────────────────────────────────────────────────────────────
# 2. TEST HARNESS HELPERS
# ───────────────────────────────────────────────────────────────

# Record a passing check and print its name
# Args:
#   $1 - Check name to report
pass() {
  PASSED=$((PASSED + 1))
  printf 'PASS %s\n' "$1"
}

# Record a failing check and print its name
# Args:
#   $1 - Check name to report
fail() {
  FAILED=$((FAILED + 1))
  printf 'FAIL %s\n' "$1"
}

# Restore the gate environment variables to their default values
reset_gate_env() {
  GATE_STDIN="/dev/null"
  GATE_APPROVED=""
}

# Run the gate with the current environment and stdin source
# Args:
#   $@ - Arguments passed through to the gate
# Returns:
#   The gate exit status
# The scanner reads the pushed refs from stdin, so every run gets a stdin file.
run_gate() {
  if [[ -n "$GATE_APPROVED" ]]; then
    PRIVACY_GATE_CHANGE_APPROVED=1 python3 -I scripts/privacy-gate.py "$@" < "$GATE_STDIN" 2>&1
  else
    PRIVACY_GATE_CHANGE_APPROVED='' python3 -I scripts/privacy-gate.py "$@" < "$GATE_STDIN" 2>&1
  fi
}

# Assert that a gate run exits 1 with the expected rule finding
# Args:
#   $1 - Check name to report
#   $2 - Rule id the finding must name
#   $@ - Arguments passed to the gate
expect_blocked() {
  local name rule out status
  name="$1"
  rule="$2"
  shift 2
  out="$(run_gate "$@")"
  status=$?
  LAST_OUT="$out"
  if [[ "$status" -ne 1 ]]; then
    fail "$name (exit $status, expected 1)"
    return 0
  fi
  case "$out" in
    *"privacy-gate: $rule "*)
      pass "$name"
      ;;
    *)
      fail "$name (rule $rule not reported)"
      ;;
  esac
}

# Assert that a gate run exits 0 for the given check
# Args:
#   $1 - Check name to report
#   $@ - Arguments passed to the gate
expect_clean() {
  local name out status
  name="$1"
  shift
  out="$(run_gate "$@")"
  status=$?
  LAST_OUT="$out"
  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name (exit $status, expected 0)"
  fi
}

# Assert that the last gate output never contains the sensitive value
# Args:
#   $1 - Check name to report
#   $2 - Sensitive value that must not appear
expect_no_leak() {
  local name="$1"
  local value="$2"
  case "$LAST_OUT" in
    *"$value"*)
      fail "$name"
      ;;
    *)
      pass "$name"
      ;;
  esac
}

# ───────────────────────────────────────────────────────────────
# 3. VALUE GENERATORS AND FIXTURES
# ───────────────────────────────────────────────────────────────

# Print an IBAN with a valid checksum
gen_iban() {
  python3 -c '
def build(country, bban):
    rotated = bban + country + "00"
    digits = "".join(str(int(c, 36)) for c in rotated)
    return country + "%02d" % (98 - int(digits) % 97) + bban
print(build("NL", "ABNA0417164300"))
'
}

# Print a generated BSN that passes the mod 11 check
gen_bsn() {
  python3 -c '
weights = [9, 8, 7, 6, 5, 4, 3, 2]
for base in range(10000000, 10000100):
    digits = [int(c) for c in str(base)]
    rest = sum(w * d for w, d in zip(weights, digits)) % 11
    if rest <= 9:
        print("%08d%d" % (base, rest))
        break
'
}

# Print a generated VAT identifier that matches the gate pattern
gen_vat() {
  python3 -c 'print("NL" + "0" * 9 + "B01")'
}

# Print a generated personal email address that trips the email rule
gen_email() {
  python3 -c 'print("zoe" + "@" + "example" + ".nl")'
}

# Print a generated email address for the identity checks
# An allowed domain, so only the identity rule can fire on it.
gen_other_email() {
  python3 -c 'print("leaky" + "@" + "example" + ".org")'
}

# Print a run of one repeated digit
# Args:
#   $1 - Number of digits to print
#   $2 - Digit to repeat
gen_digits() {
  python3 -c 'import sys
print(sys.argv[2] * int(sys.argv[1]))' "$1" "$2"
}

# Print a repeated character run that trips the secret rule
gen_secret() {
  python3 -c 'print("k" * 32)'
}

# Print fullwidth digit variants of a digit string
# Args:
#   $1 - Digit string to convert
wide_digits() {
  python3 -c 'import sys
print("".join(chr(ord("\uff10") + int(digit)) for digit in sys.argv[1]))' "$1"
}

# Print an IBAN grouped into blocks of four joined by hyphens
# Args:
#   $1 - IBAN text to group
hyphenate_iban() {
  python3 -c 'import sys
text = sys.argv[1]
print("-".join(text[i:i + 4] for i in range(0, len(text), 4)))' "$1"
}

# Write a denylist that holds no private terms
write_clean_denylist() {
  printf '# no private terms are needed for these tests\n' > .privacy-denylist
}

# Build a throwaway repository with the gate installed and a seed commit
# Leaves the working directory inside the new repository
new_repo() {
  rm -rf "$WORK/repo"
  mkdir -p "$WORK/repo/scripts" "$WORK/repo/.githooks"
  cp "$ROOT/scripts/privacy-gate.py" "$WORK/repo/scripts/privacy-gate.py"
  cp "$ROOT/.privacy-gate.json" "$WORK/repo/.privacy-gate.json"
  cd "$WORK/repo" || exit 1
  git -c init.defaultBranch=main init -q .
  git config user.name "Privacy Gate Test"
  git config user.email "gate-test@users.noreply.github.com"
  git config commit.gpgsign false
  git config core.hooksPath .githooks
  printf 'seed\n' > notes.md
  git add -A
  # The install commit starts the history, so it carries the approval variable
  # and the trailer that every later gate change needs. Commits after it run
  # without either unless a test says otherwise.
  PRIVACY_GATE_CHANGE_APPROVED=1 git commit -qm "install the privacy gate" \
    -m "Privacy-Gate-Change: approved"
  write_clean_denylist
}

# Discard local changes, remove untracked files and restore a clean denylist
reset_tree() {
  git reset -q
  git checkout -q -- .
  git clean -qfd
  write_clean_denylist
}

# ───────────────────────────────────────────────────────────────
# 4. BASIC MODE CHECKS
# ───────────────────────────────────────────────────────────────

printf 'privacy gate test suite\n'
new_repo

# Staged mode on a clean file.
printf 'hello\n' > readme.md
git add readme.md
expect_clean "clean staged markdown" --staged
git commit -qm docs

expect_clean "tree on a clean repo" --tree
expect_clean "history on a clean repo" --history

# Blocked path, file type, symlink, binary and size.
mkdir -p migration-workspace
printf 'draft\n' > migration-workspace/x.md
git add migration-workspace/x.md
expect_blocked "staged blocked path" blocked-path --staged
reset_tree

printf 'plain text under a pdf name\n' > invoice.pdf
git add invoice.pdf
expect_blocked "staged file type" file-type --staged
reset_tree

ln -s notes.md link.md
git add link.md
expect_blocked "staged symlink" symlink --staged
reset_tree

printf 'text\000more\n' > blob.md
git add blob.md
expect_blocked "staged binary" binary --staged
reset_tree

yes 'filler line' | head -n 60000 > big.md
git add big.md
expect_blocked "staged size" size --staged
reset_tree

# ───────────────────────────────────────────────────────────────
# 5. CONTENT RULE CHECKS
# ───────────────────────────────────────────────────────────────

IBAN="$(gen_iban)"
printf 'payment to %s\n' "$IBAN" > payments.md
git add payments.md
expect_blocked "staged iban" iban --staged
expect_no_leak "iban value never printed" "$IBAN"
reset_tree

BSN="$(gen_bsn)"
printf 'bsn %s\n' "$BSN" > person.md
git add person.md
expect_blocked "staged bsn" bsn --staged
expect_no_leak "bsn value never printed" "$BSN"
reset_tree

VAT="$(gen_vat)"
printf 'vat %s\n' "$VAT" > company.md
git add company.md
expect_blocked "staged vat id" vat-id --staged
reset_tree

EMAIL="$(gen_email)"
printf 'mail %s\n' "$EMAIL" > contact.md
git add contact.md
expect_blocked "staged email" email --staged
expect_no_leak "email value never printed" "$EMAIL"
reset_tree

LONG="$(gen_digits 12 7)"
printf 'ledger %s\n' "$LONG" > ledger.md
git add ledger.md
expect_blocked "staged long number" long-number --staged
reset_tree

printf 'workdir /Users/%s\n' 'probe' > local.md
git add local.md
expect_blocked "staged home path" home-path --staged
reset_tree

printf 'total EUR %s\n' '1234.56' > invoice-note.md
git add invoice-note.md
expect_blocked "staged amount" amount --staged
reset_tree

mkdir -p sk-moneybird-accountant/references
printf 'rate EUR %s\n' '0.00' > sk-moneybird-accountant/references/dutch-tax-rules.md
git add sk-moneybird-accountant/references/dutch-tax-rules.md
expect_clean "amount in an allowed reference file" --staged
reset_tree

SECRET_VALUE="$(gen_secret)"
printf 'api_key=%s\n' "$SECRET_VALUE" > config-notes.md
git add config-notes.md
expect_blocked "staged secret" secret --staged
expect_no_leak "secret value never printed" "$SECRET_VALUE"
reset_tree

printf 'api_key=%s\n' 'EXAMPLE_FAKE_TOKEN_9k2n' > example-notes.md
git add example-notes.md
expect_clean "fake secret is ignored" --staged
reset_tree

# ───────────────────────────────────────────────────────────────
# 6. DENYLIST AND PATH CHECKS
# ───────────────────────────────────────────────────────────────

# Denylist terms, with and without the space.
TERM="Client$(printf ' ')Alpha"
printf '%s\n' "$TERM" > .privacy-denylist
printf 'about %s today\n' "$TERM" > note.md
git add note.md
expect_blocked "denylist term with a space" denylist --staged
expect_no_leak "denylist term never printed" "$TERM"
case "$LAST_OUT" in
  *"term #1"*)
    pass "denylist reports the term number"
    ;;
  *)
    fail "denylist reports the term number"
    ;;
esac

printf 'about %s today\n' "$(printf '%s' "$TERM" | tr -d ' ')" > note2.md
git add note2.md
expect_blocked "denylist term without a space" denylist --staged
rm -f .privacy-denylist
reset_tree

# A missing denylist blocks staged, push, message and answer runs.
rm -f .privacy-denylist
printf 'clean text\n' > readme.md
git add readme.md
expect_blocked "missing denylist blocks staged" denylist-missing --staged
case "$LAST_OUT" in
  *scripts/install-hooks.sh*)
    pass "missing denylist points at install-hooks.sh"
    ;;
  *)
    fail "missing denylist points at install-hooks.sh"
    ;;
esac
reset_tree

rm -f .privacy-denylist
printf 'plain message\n' > "$WORK/message-plain.txt"
expect_blocked "missing denylist blocks message mode" denylist-missing --message "$WORK/message-plain.txt"
reset_tree

rm -f .privacy-denylist
printf 'plain answer\n' > "$WORK/answer-plain.txt"
expect_blocked "missing denylist blocks answer mode" denylist-missing --answer "$WORK/answer-plain.txt"
reset_tree

# A blocked path written with capitals.
mkdir -p Specs
printf 'draft\n' > Specs/notes.md
git add -f Specs/notes.md
expect_blocked "uppercase blocked path" blocked-path --staged
reset_tree

# A tracked file replaced by a symlink is a typechange.
printf 'plain\n' > switch.md
git add switch.md
git commit -qm switch
rm switch.md
ln -s notes.md switch.md
git add switch.md
expect_blocked "typechange to symlink" symlink --staged
reset_tree

# Unicode digits are folded before the BSN check.
BSN="$(gen_bsn)"
BSN_WIDE="$(wide_digits "$BSN")"
printf 'bsn %s\n' "$BSN_WIDE" > bsn-wide.md
git add bsn-wide.md
expect_blocked "fullwidth digit bsn" bsn --staged
expect_no_leak "fullwidth bsn never printed" "$BSN_WIDE"
reset_tree

# A BSN written as three groups.
BSN="$(gen_bsn)"
BSN_GROUPED="${BSN:0:3}.${BSN:3:3}.${BSN:6:3}"
printf 'bsn %s\n' "$BSN_GROUPED" > bsn-grouped.md
git add bsn-grouped.md
expect_blocked "3-3-3 bsn with dots" bsn --staged
reset_tree

# A Dutch amount without a currency.
printf 'bedrag 12%s50\n' ',' > bedrag.md
git add bedrag.md
expect_blocked "dutch bare amount" amount --staged
reset_tree

# ───────────────────────────────────────────────────────────────
# 7. VARIANT AND GATE FILE CHECKS
# ───────────────────────────────────────────────────────────────

# IBAN variants.
IBAN="$(gen_iban)"
IBAN_LOWER="$(printf '%s' "$IBAN" | tr '[:upper:]' '[:lower:]')"
printf 'iban %s\n' "$IBAN_LOWER" > iban-lower.md
git add iban-lower.md
expect_blocked "lowercase iban" iban --staged
reset_tree

IBAN="$(gen_iban)"
IBAN_GROUPED="$(hyphenate_iban "$IBAN")"
printf 'iban %s\n' "$IBAN_GROUPED" > iban-grouped.md
git add iban-grouped.md
expect_blocked "hyphenated iban" iban --staged
reset_tree

IBAN="$(gen_iban)"
printf '%s\n%s\n' "${IBAN:0:8}" "${IBAN:8}" > iban-split.md
git add iban-split.md
expect_blocked "iban split across two lines" iban --staged
case "$LAST_OUT" in
  *"iban-split.md:- "*)
    pass "split iban is reported on line -"
    ;;
  *)
    fail "split iban is reported on line -"
    ;;
esac
expect_no_leak "split iban never printed" "$IBAN"
reset_tree

# The marker has to be inside the captured value.
SECRET_VALUE="$(gen_secret)"
printf 'api_key = "%s"  # example\n' "$SECRET_VALUE" > example-comment.md
git add example-comment.md
expect_blocked "secret with a trailing example comment" secret --staged
expect_no_leak "commented secret value never printed" "$SECRET_VALUE"
reset_tree

SECRET_VALUE="$(gen_secret)"
printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$SECRET_VALUE" > aws-notes.md
git add aws-notes.md
expect_blocked "aws secret access key name" secret --staged
expect_no_leak "aws key value never printed" "$SECRET_VALUE"
reset_tree

# A sensitive value in the file name itself.
IBAN_NAME="$(gen_iban)"
printf 'shipped\n' > "payments-${IBAN_NAME}.md"
git add "payments-${IBAN_NAME}.md"
expect_blocked "sensitive file name" iban --staged
case "$LAST_OUT" in
  *":path "*)
    pass "file name finding is reported on line path"
    ;;
  *)
    fail "file name finding is reported on line path"
    ;;
esac
expect_no_leak "file name value never printed" "$IBAN_NAME"
reset_tree

# Gate files need the Operator's approval variable.
printf '{}\n' > .privacy-gate.json
git add .privacy-gate.json
expect_blocked "staged gate change needs approval" gate-change --staged
case "$LAST_OUT" in
  *PRIVACY_GATE_CHANGE_APPROVED*)
    pass "gate change names the approval variable"
    ;;
  *)
    fail "gate change names the approval variable"
    ;;
esac
reset_tree

printf '{}\n' > .privacy-gate.json
git add .privacy-gate.json
GATE_APPROVED=1
expect_clean "approved gate change is allowed" --staged
reset_gate_env
reset_tree

# A staged config cannot widen the rules that the same index is checked with.
python3 - <<'PY'
import json

with open(".privacy-gate.json", "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["allowed_extensions"] = sorted(set(config["allowed_extensions"]) | {"txt"})
with open(".privacy-gate.json", "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
PY
printf 'plain notes\n' > widen-notes.txt
git add .privacy-gate.json widen-notes.txt
GATE_APPROVED=1
expect_blocked "staged config widening is not applied" file-type --staged
reset_gate_env
reset_tree
reset_gate_env

# ───────────────────────────────────────────────────────────────
# 8. MESSAGE AND PUSH MODE CHECKS
# ───────────────────────────────────────────────────────────────

# Commit message mode reads the message before the commit exists.
IBAN_MSG="$(gen_iban)"
printf 'reserve %s\n' "$IBAN_MSG" > "$WORK/commit-message.txt"
expect_blocked "commit message with an iban" iban --message "$WORK/commit-message.txt"
expect_no_leak "commit message value never printed" "$IBAN_MSG"

printf '# %s\nplain message\n' "$IBAN_MSG" > "$WORK/commit-message-comment.txt"
expect_clean "message mode ignores comment lines" --message "$WORK/commit-message-comment.txt"

# Push mode over a range.
new_repo
BASE="$(git rev-parse HEAD)"
PUSHED_IBAN="$(gen_iban)"
printf 'pay %s\n' "$PUSHED_IBAN" > payments.md
git add payments.md
git commit -qm payments
TIP="$(git rev-parse HEAD)"

printf '%s %s %s %s\n' refs/heads/main "$TIP" refs/heads/main "$BASE" > "$WORK/push-range.txt"
GATE_STDIN="$WORK/push-range.txt"
expect_blocked "push blocks a range with an iban" iban --push origin

# A commit message is part of the pushed content.
MSG_IBAN="$(gen_iban)"
git commit -q --allow-empty -m "reserve $MSG_IBAN"
TIP_MSG="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$TIP_MSG" refs/heads/main "$TIP" > "$WORK/push-message.txt"
GATE_STDIN="$WORK/push-message.txt"
expect_blocked "push scans the commit message" iban --push origin
expect_no_leak "push commit message value never printed" "$MSG_IBAN"

# The author email has to be a noreply identity.
LEAK_EMAIL="$(gen_other_email)"
git -c user.email="$LEAK_EMAIL" commit -q --allow-empty -m "identity note"
TIP_ID="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$TIP_ID" refs/heads/main "$TIP_MSG" > "$WORK/push-identity.txt"
GATE_STDIN="$WORK/push-identity.txt"
expect_blocked "push blocks a non noreply author" identity --push origin
expect_no_leak "author email value never printed" "$LEAK_EMAIL"

rm -f .privacy-denylist
printf '%s %s %s %s\n' refs/heads/main "$TIP_ID" refs/heads/main "$TIP_ID" > "$WORK/push-nodeny.txt"
GATE_STDIN="$WORK/push-nodeny.txt"
expect_blocked "missing denylist blocks push mode" denylist-missing --push origin
write_clean_denylist

printf '%s %s %s %s\n' refs/heads/main "$TIP_ID" refs/heads/main "$TIP_ID" > "$WORK/push-clean.txt"
GATE_STDIN="$WORK/push-clean.txt"
expect_clean "push passes an empty range" --push origin
reset_gate_env

# ───────────────────────────────────────────────────────────────
# 9. PUSH MODE EDGE CASES
# ───────────────────────────────────────────────────────────────

# A pushed annotated tag carries its own message.
new_repo
TAG_IBAN="$(gen_iban)"
TAG_NAME="release-tag"
git tag -a -m "release $TAG_IBAN" "$TAG_NAME"
TAG_SHA="$(git rev-parse "$TAG_NAME")"
printf '%s %s %s %s\n' "refs/tags/$TAG_NAME" "$TAG_SHA" "refs/tags/$TAG_NAME" "$ZERO_SHA" > "$WORK/push-tag.txt"
GATE_STDIN="$WORK/push-tag.txt"
expect_blocked "pushed annotated tag with an iban" iban --push origin
expect_no_leak "tag message value never printed" "$TAG_IBAN"
reset_gate_env

# A merge commit that only exists in the merge itself.
new_repo
printf 'placeholder\n' > shared.md
git add shared.md
git commit -qm base-change
MERGE_BASE="$(git rev-parse HEAD)"
git checkout -q -b side
printf 'beta\n' > shared.md
git commit -qam beta
git checkout -q main
printf 'gamma\n' > shared.md
git commit -qam gamma
git merge --no-commit side >/dev/null 2>&1 || true
MERGE_IBAN="$(gen_iban)"
printf 'pay %s\n' "$MERGE_IBAN" > shared.md
git add shared.md
git commit -qm "resolve side"
MERGE_SHA="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$MERGE_SHA" refs/heads/main "$MERGE_BASE" > "$WORK/push-merge.txt"
GATE_STDIN="$WORK/push-merge.txt"
expect_blocked "merge commit that introduces an iban" iban --push origin
reset_gate_env

# A new branch is checked against the remote, the install commit already
# carries the gate trailer.
new_repo
BASE_NEW="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$BASE_NEW" refs/heads/main "$ZERO_SHA" > "$WORK/push-new.txt"
GATE_STDIN="$WORK/push-new.txt"
expect_clean "push passes a clean new branch with gate files" --push origin
reset_gate_env

# A push with no remote name checks a new branch against every remote, so a
# commit a remote already holds is not scanned again.
new_repo
git checkout -q -b published
PUBLISHED_IBAN="$(gen_iban)"
printf 'pay %s\n' "$PUBLISHED_IBAN" > published.md
git add published.md
git commit -qm published
git update-ref refs/remotes/mirror/published HEAD
printf 'clean note\n' > note.md
git add note.md
git commit -qm note
TIP_ANY="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/published "$TIP_ANY" refs/heads/published "$ZERO_SHA" > "$WORK/push-any.txt"
GATE_STDIN="$WORK/push-any.txt"
expect_clean "push with no remote name skips commits a remote holds" --push ""
reset_gate_env

# A pushed commit that touches a gate file needs the trailer line.
new_repo
GATE_ANCHOR="$(git rev-parse HEAD)"
printf 'scratch/\n' > .gitignore
git add .gitignore
git commit -qm "ignore scratch files"
GATE_TIP="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$GATE_TIP" refs/heads/main "$GATE_ANCHOR" > "$WORK/push-gate-file.txt"
GATE_STDIN="$WORK/push-gate-file.txt"
expect_blocked "push blocks a gate change without the trailer" gate-change --push origin
case "$LAST_OUT" in
  *"Privacy-Gate-Change: approved"*)
    pass "gate change finding names the trailer"
    ;;
  *)
    fail "gate change finding names the trailer"
    ;;
esac

printf 'build/\n' > .gitignore
git add .gitignore
git commit -qm "ignore build output" -m "Privacy-Gate-Change: approved"
GATE_OK="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$GATE_OK" refs/heads/main "$GATE_TIP" > "$WORK/push-gate-approved.txt"
GATE_STDIN="$WORK/push-gate-approved.txt"
expect_clean "push accepts a gate change with the trailer" --push origin
reset_tree

# Removing a gate file is a gate change too.
new_repo
DELETE_ANCHOR="$(git rev-parse HEAD)"
git rm -q .privacy-gate.json
git commit -qm "drop the config file"
DELETE_TIP="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$DELETE_TIP" refs/heads/main "$DELETE_ANCHOR" > "$WORK/push-gate-delete.txt"
GATE_STDIN="$WORK/push-gate-delete.txt"
expect_blocked "push blocks a deleted gate file" gate-change --push origin

printf '%s %s %s %s\n' refs/heads/main "$DELETE_TIP" refs/heads/main "$DELETE_TIP" > "$WORK/push-no-config.txt"
GATE_STDIN="$WORK/push-no-config.txt"
out="$(run_gate --push origin)"
status=$?
LAST_OUT="$out"
reported=no
case "$out" in
  *".privacy-gate.json"*) reported=yes ;;
esac
if [[ "$status" -eq 2 ]] && [[ "$reported" = yes ]]; then
  pass "a remote tip without the config fails closed"
else
  fail "a remote tip without the config fails closed (exit $status)"
fi
reset_tree
# The commit above removed the config, so step back to a HEAD that still has
# it before testing a staged deletion.
git reset -q --hard "$DELETE_ANCHOR"
write_clean_denylist

git rm -q .privacy-gate.json
expect_blocked "staged deletion of a gate file" gate-change --staged
reset_tree

# A rename lists only its destination, so the gate file it leaves has to count
# as changed too.
git mv .privacy-gate.json gate-config.json
expect_blocked "staged rename of a gate file" gate-change --staged
reset_tree

# ───────────────────────────────────────────────────────────────
# 10. BASELINE AND COMMIT-MSG CHECKS
# ───────────────────────────────────────────────────────────────

# Commits at or before the recorded baseline are exempt.
new_repo
printf 'scratch/\n' > .gitignore
git add .gitignore
git commit -qm "ignore scratch files"
printf 'build/\n' > .gitignore
git add .gitignore
git commit -qm "ignore build output"
BASELINE_SHA="$(git rev-parse HEAD)"
python3 - "$BASELINE_SHA" <<'PY'
import json
import sys

with open(".privacy-gate.json", "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["gate_change_baseline"] = sys.argv[1]
with open(".privacy-gate.json", "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
PY
git add .privacy-gate.json
git commit -qm "record the gate baseline" -m "Privacy-Gate-Change: approved"
BASELINE_TIP="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$BASELINE_TIP" refs/heads/main "$ZERO_SHA" > "$WORK/push-baseline.txt"
GATE_STDIN="$WORK/push-baseline.txt"
expect_clean "commits at or before the baseline are exempt" --push origin
reset_tree

# The commit-msg check needs the trailer and the approval variable.
new_repo
printf '{}\n' > .privacy-gate.json
git add .privacy-gate.json
printf 'plain message\n' > "$WORK/message-gate.txt"
expect_blocked "message on a staged gate change needs the trailer" gate-change --message "$WORK/message-gate.txt"
case "$LAST_OUT" in
  *"Privacy-Gate-Change: approved"*)
    pass "message finding names the trailer"
    ;;
  *)
    fail "message finding names the trailer"
    ;;
esac

printf 'gate change\n\nPrivacy-Gate-Change: approved\n' > "$WORK/message-gate-ok.txt"
expect_blocked "message trailer without the approval is blocked" gate-change --message "$WORK/message-gate-ok.txt"
GATE_APPROVED=1
expect_blocked "message approval without the trailer is blocked" gate-change --message "$WORK/message-gate.txt"
expect_clean "message trailer plus approval passes" --message "$WORK/message-gate-ok.txt"
reset_gate_env
reset_tree

printf 'plain message\n' > "$WORK/message-plain.txt"
expect_clean "message without a staged gate change is fine" --message "$WORK/message-plain.txt"
reset_gate_env

# ───────────────────────────────────────────────────────────────
# 11. ANCHOR AND HOOK CHECKS
# ───────────────────────────────────────────────────────────────

# Push mode reads the rules from the remote tip, so a local rewrite of the
# config cannot widen them.
new_repo
ANCHOR_SHA="$(git rev-parse HEAD)"
python3 - <<'PY'
import json

with open(".privacy-gate.json", "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["allowed_extensions"] = sorted(set(config["allowed_extensions"]) | {"txt"})
with open(".privacy-gate.json", "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
PY
printf 'plain notes\n' > widen.txt
git add widen.txt
git commit -qm "add notes"
ANCHOR_TIP="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$ANCHOR_TIP" refs/heads/main "$ANCHOR_SHA" > "$WORK/push-anchor.txt"
GATE_STDIN="$WORK/push-anchor.txt"
expect_blocked "push reads the rules from the remote tip" file-type --push origin
reset_tree

# Push mode runs the anchor copy of the gate when the local copy differs.
new_repo
CODE_ANCHOR="$(git rev-parse HEAD)"
RERUN_IBAN="$(gen_iban)"
printf 'pay %s\n' "$RERUN_IBAN" > payments.md
git add payments.md
git commit -qm "payments note"
CODE_TIP="$(git rev-parse HEAD)"
python3 - <<'PY'
with open("scripts/privacy-gate.py", "r", encoding="utf-8") as handle:
    text = handle.read()
patched = text.replace("    return report(checker, mode)",
                       "    report(checker, mode)\n    return 0")
if patched == text:
    raise SystemExit("the gate script was not weakened")
with open("scripts/privacy-gate.py", "w", encoding="utf-8") as handle:
    handle.write(patched)
PY
printf '%s %s %s %s\n' refs/heads/main "$CODE_TIP" refs/heads/main "$CODE_ANCHOR" > "$WORK/push-anchor-code.txt"
GATE_STDIN="$WORK/push-anchor-code.txt"
expect_blocked "push runs the anchor gate code" iban --push origin
reset_tree

# An anchor gate older than the re-run rule gets no flag it cannot parse.
new_repo
cat > scripts/privacy-gate.py <<'PY'
import sys
if sys.argv[1:] != ["--push", "origin"]:
    sys.stderr.write("old gate: unexpected arguments\n")
    sys.exit(2)
sys.stdout.write("old gate ran\n")
PY
git add scripts/privacy-gate.py
git commit -qm "older gate

Privacy-Gate-Change: approved"
OLD_ANCHOR="$(git rev-parse HEAD)"
cp "$ROOT/scripts/privacy-gate.py" scripts/privacy-gate.py
printf '%s %s %s %s\n' refs/heads/main "$OLD_ANCHOR" refs/heads/main "$OLD_ANCHOR" > "$WORK/push-old-anchor.txt"
GATE_STDIN="$WORK/push-old-anchor.txt"
expect_clean "an older anchor gate runs without the re-run flag" --push origin
case "$LAST_OUT" in
  *"old gate ran"*) pass "the older anchor gate is the one that judged the push" ;;
  *) fail "the older anchor gate is the one that judged the push" ;;
esac
reset_tree

# Tree mode reads the rules from HEAD.
new_repo
python3 - <<'PY'
import json

with open(".privacy-gate.json", "r", encoding="utf-8") as handle:
    config = json.load(handle)
config["allowed_extensions"] = sorted(set(config["allowed_extensions"]) | {"txt"})
with open(".privacy-gate.json", "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
PY
printf 'plain notes\n' > widen.txt
git add .privacy-gate.json widen.txt
git commit -qm "allow notes files" -m "Privacy-Gate-Change: approved"
expect_clean "tree reads the rules from HEAD" --tree
reset_tree

# The pre-merge-commit hook stops a merge that stages a blocked path.
new_repo
printf 'base\n' > shared.md
git add shared.md
git commit -qm base
git checkout -q -b side
mkdir -p migration-workspace
printf 'draft\n' > migration-workspace/x.md
git add migration-workspace/x.md
git commit -qm "side adds a blocked path"
git checkout -q main
printf 'main side\n' > other.md
git add other.md
git commit -qm "main side"
mkdir -p .githooks
cp "$ROOT/.githooks/pre-merge-commit" .githooks/pre-merge-commit
chmod +x .githooks/pre-merge-commit
if git merge -q --no-edit side > "$WORK/merge-hook.txt" 2>&1; then
  fail "pre-merge-commit hook blocks a merge with a blocked path"
else
  pass "pre-merge-commit hook blocks a merge with a blocked path"
fi
git merge --abort >/dev/null 2>&1 || true
reset_tree

# ───────────────────────────────────────────────────────────────
# 12. ANSWER MODE CHECKS
# ───────────────────────────────────────────────────────────────

# A drafted answer is scanned before it is sent. Masking afterwards is not a
# control, so every case is a run of the gate itself on generated values.
new_repo
REF_PATH="sk-moneybird-accountant/references/dutch-tax-rules.md"
mkdir -p "$(dirname "$REF_PATH")"
PUBLIC_FIGURE="$(python3 -c 'import random
print("%d.%03d" % (random.randint(1, 9), random.randint(0, 999)))')"
printf 'Gemengde kosten drempel: \342\202\254 %s,50\n' "$PUBLIC_FIGURE" > "$REF_PATH"
git add "$REF_PATH"
git commit -qm "add a public reference" -m "Reference figure for the answer mode cases."
ANSWER_IBAN="$(gen_iban)"
TRANSCRIPT_IBAN="$(gen_iban)"
LEAKS_CAUGHT=0
CLEAN_BLOCKED=0

printf 'Pay the supplier at %s today.\n' "$ANSWER_IBAN" > "$WORK/answer-leak.txt"
expect_blocked "answer with an iban" iban --answer "$WORK/answer-leak.txt"
[[ "$LAST_OUT" == *"privacy-gate: iban "* ]] && LEAKS_CAUGHT=$((LEAKS_CAUGHT + 1))
expect_no_leak "answer value never printed" "$ANSWER_IBAN"

printf 'The invoice is booked on the costs ledger.\n' > "$WORK/answer-clean.txt"
expect_clean "clean answer passes" --answer "$WORK/answer-clean.txt"
[[ "$LAST_OUT" == *"privacy-gate: clean"* ]] || CLEAN_BLOCKED=$((CLEAN_BLOCKED + 1))

printf 'Bank line for %s loaded.\n' "$TRANSCRIPT_IBAN" > "$WORK/transcript-leak.txt"
expect_blocked "clean answer with a leaking transcript" iban \
  --answer "$WORK/answer-clean.txt" --transcript "$WORK/transcript-leak.txt"
[[ "$LAST_OUT" == *"privacy-gate: iban "* ]] && LEAKS_CAUGHT=$((LEAKS_CAUGHT + 1))

printf 'The threshold is \342\202\254 %s,50, see %s.\n' "$PUBLIC_FIGURE" "$REF_PATH" \
  > "$WORK/answer-public.txt"
expect_clean "public figure with its reference citation passes" --answer "$WORK/answer-public.txt"
[[ "$LAST_OUT" == *"privacy-gate: clean"* ]] || CLEAN_BLOCKED=$((CLEAN_BLOCKED + 1))

printf 'The threshold is \342\202\254 %s.\n' "$PUBLIC_FIGURE" > "$WORK/answer-uncited.txt"
expect_blocked "amount without a citation" amount --answer "$WORK/answer-uncited.txt"

printf 'You paid \342\202\254 %s9, see %s.\n' "$PUBLIC_FIGURE" "$REF_PATH" > "$WORK/answer-miscited.txt"
expect_blocked "amount the cited reference does not hold" amount --answer "$WORK/answer-miscited.txt"

printf 'You paid \342\202\254 %s, see %s.\n' "${PUBLIC_FIGURE%?}" "$REF_PATH" > "$WORK/answer-prefix.txt"
expect_blocked "amount that is only a prefix of a cited figure" amount --answer "$WORK/answer-prefix.txt"

printf 'You paid \342\202\254 %s9.\n' "$PUBLIC_FIGURE" > "$REF_PATH.draft"
cp "$REF_PATH.draft" "$REF_PATH"
expect_blocked "answer saved at an amount-allowed path still scans amounts" amount --answer "$REF_PATH"
printf 'You paid \342\202\254 %s9, see %s.\n' "$PUBLIC_FIGURE" "$REF_PATH" > "$REF_PATH"
expect_blocked "draft saved over a reference cannot cite itself" amount --answer "$REF_PATH"
git checkout -q -- "$REF_PATH"
rm -f "$REF_PATH.draft"

printf 'The threshold is \342\202\254 %s, see %s.\n' "${PUBLIC_FIGURE%%.*}" "$REF_PATH" > "$WORK/answer-comma.txt"
expect_blocked "amount that stops before a decimal part of the cited figure" amount --answer "$WORK/answer-comma.txt"

WIDE_IBAN="$(gen_iban)"
{ printf 'Account %s' "${WIDE_IBAN:0:8}"; printf '%200s\n\n\n' ''; printf '%s\n' "${WIDE_IBAN:8}"; } > "$WORK/answer-wide.txt"
expect_blocked "iban split by wide whitespace" iban --answer "$WORK/answer-wide.txt"

SPLIT_IBAN="$(gen_iban)"
printf 'Pay to %s\n%s today.\n' "${SPLIT_IBAN:0:12}" "${SPLIT_IBAN:12}" > "$WORK/answer-split.txt"
expect_blocked "iban split across lines after a word" iban --answer "$WORK/answer-split.txt"
expect_no_leak "split iban value never printed" "$SPLIT_IBAN"

if run_gate --transcript "$WORK/transcript-leak.txt" --staged > /dev/null 2>&1; then
  fail "transcript flag outside answer mode is refused"
else
  pass "transcript flag outside answer mode is refused"
fi

printf 'answer leak catch rate: %d/2\n' "$LEAKS_CAUGHT"
printf 'answer false positives: %d/2\n' "$CLEAN_BLOCKED"
if [[ "$LEAKS_CAUGHT" -eq 2 && "$CLEAN_BLOCKED" -eq 0 ]]; then
  pass "answer rates meet the target"
else
  fail "answer rates meet the target"
fi
reset_tree

# ───────────────────────────────────────────────────────────────
# 13. FINAL REPORT
# ───────────────────────────────────────────────────────────────

printf 'Result: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
exit 0
