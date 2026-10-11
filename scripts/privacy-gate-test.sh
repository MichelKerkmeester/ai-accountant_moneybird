#!/usr/bin/env bash
# Exercise scripts/privacy-gate.py against a throwaway repository.
# Every sensitive value is generated at runtime so this file stays clean.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/privacy-gate-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
LAST_OUT=""
GATE_STDIN="/dev/null"
GATE_APPROVED=""
ZERO_SHA="$(python3 -c 'print("0" * 40)')"

pass() {
  PASSED=$((PASSED + 1))
  printf 'PASS %s\n' "$1"
}

fail() {
  FAILED=$((FAILED + 1))
  printf 'FAIL %s\n' "$1"
}

reset_gate_env() {
  GATE_STDIN="/dev/null"
  GATE_APPROVED=""
}

# The scanner reads the pushed refs from stdin, so every run gets a stdin file.
run_gate() {
  if [ -n "$GATE_APPROVED" ]; then
    PRIVACY_GATE_CHANGE_APPROVED=1 python3 -I scripts/privacy-gate.py "$@" < "$GATE_STDIN" 2>&1
  else
    PRIVACY_GATE_CHANGE_APPROVED= python3 -I scripts/privacy-gate.py "$@" < "$GATE_STDIN" 2>&1
  fi
}

expect_blocked() {
  local name rule out status
  name="$1"
  rule="$2"
  shift 2
  out="$(run_gate "$@")"
  status=$?
  LAST_OUT="$out"
  if [ "$status" -ne 1 ]; then
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

expect_clean() {
  local name out status
  name="$1"
  shift
  out="$(run_gate "$@")"
  status=$?
  LAST_OUT="$out"
  if [ "$status" -eq 0 ]; then
    pass "$name"
  else
    fail "$name (exit $status, expected 0)"
  fi
}

expect_no_leak() {
  case "$LAST_OUT" in
    *"$2"*)
      fail "$1"
      ;;
    *)
      pass "$1"
      ;;
  esac
}

gen_iban() {
  python3 -c '
def build(country, bban):
    rotated = bban + country + "00"
    digits = "".join(str(int(c, 36)) for c in rotated)
    return country + "%02d" % (98 - int(digits) % 97) + bban
print(build("NL", "ABNA0417164300"))
'
}

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

gen_vat() {
  python3 -c 'print("NL" + "0" * 9 + "B01")'
}

gen_email() {
  python3 -c 'print("zoe" + "@" + "example" + ".nl")'
}

# An allowed domain, so only the identity rule can fire on it.
gen_other_email() {
  python3 -c 'print("leaky" + "@" + "example" + ".org")'
}

gen_digits() {
  python3 -c 'import sys
print(sys.argv[2] * int(sys.argv[1]))' "$1" "$2"
}

gen_secret() {
  python3 -c 'print("k" * 32)'
}

wide_digits() {
  python3 -c 'import sys
print("".join(chr(ord("\uff10") + int(digit)) for digit in sys.argv[1]))' "$1"
}

hyphenate_iban() {
  python3 -c 'import sys
text = sys.argv[1]
print("-".join(text[i:i + 4] for i in range(0, len(text), 4)))' "$1"
}

write_clean_denylist() {
  printf '# no private terms are needed for these tests\n' > .privacy-denylist
}

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
  # Only the one commit that installs the gate files carries the approval
  # variable. Every other commit in these tests runs without it.
  PRIVACY_GATE_CHANGE_APPROVED=1 git commit -qm "install the privacy gate"
  write_clean_denylist
}

reset_tree() {
  git reset -q
  git checkout -q -- .
  git clean -qfd
  write_clean_denylist
}

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

# Content rules.
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
printf 'rate EUR %s\n' '0.00' > sk-moneybird-accountant/references/zzp-tax-and-vat.md
git add sk-moneybird-accountant/references/zzp-tax-and-vat.md
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

# A missing denylist blocks staged, push and message runs.
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

# IBAN variants.
IBAN="$(gen_iban)"
IBAN_LOWER="$(printf '%s' "$IBAN" | tr 'A-Z' 'a-z')"
printf 'iban %s\n' "$IBAN_LOWER" > iban-lower.md
git add iban-lower.md
expect_blocked "lowercase iban" iban --staged
expect_no_leak "lowercase iban never printed" "$IBAN_LOWER"
reset_tree

IBAN="$(gen_iban)"
IBAN_GROUPED="$(hyphenate_iban "$IBAN")"
printf 'iban %s\n' "$IBAN_GROUPED" > iban-grouped.md
git add iban-grouped.md
expect_blocked "hyphenated iban" iban --staged
expect_no_leak "hyphenated iban never printed" "$IBAN_GROUPED"
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
expect_no_leak "push output never prints the iban" "$PUSHED_IBAN"

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
expect_no_leak "merge commit value never printed" "$MERGE_IBAN"
reset_gate_env

# A new branch is checked against the remote, gate files stay informational.
new_repo
BASE_NEW="$(git rev-parse HEAD)"
printf '%s %s %s %s\n' refs/heads/main "$BASE_NEW" refs/heads/main "$ZERO_SHA" > "$WORK/push-new.txt"
GATE_STDIN="$WORK/push-new.txt"
expect_clean "push passes a clean new branch with gate files" --push origin
reset_gate_env

printf 'Result: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
exit 0
