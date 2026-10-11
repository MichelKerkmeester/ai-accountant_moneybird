#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: PRIVACY GATE HOOK INSTALLER
# ───────────────────────────────────────────────────────────────
# Installs the repository git hooks that run the privacy gate.
# Usage: bash scripts/install-hooks.sh
# Exit Codes:
#   0 - Hooks installed
#   1 - A required file is missing
#   other - A git or file command failed (strict mode stops the script)
set -euo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SETUP
# ───────────────────────────────────────────────────────────────

root="$(git rev-parse --show-toplevel)"
cd "$root"

# ───────────────────────────────────────────────────────────────
# 2. REQUIRED FILES
# ───────────────────────────────────────────────────────────────

for file in \
  .githooks/pre-commit \
  .githooks/pre-merge-commit \
  .githooks/pre-push \
  .githooks/commit-msg \
  scripts/privacy-gate.py \
  .privacy-denylist.example
do
  if [[ ! -f "$file" ]]; then
    printf 'privacy-gate: missing %s\n' "$file" >&2
    exit 1
  fi
done

# ───────────────────────────────────────────────────────────────
# 3. HOOKS PATH CONFIGURATION
# ───────────────────────────────────────────────────────────────

git config core.hooksPath .githooks
printf 'privacy-gate: core.hooksPath is now .githooks\n'

# ───────────────────────────────────────────────────────────────
# 4. HOOK FILE PERMISSIONS
# ───────────────────────────────────────────────────────────────

# Git silently skips a hook that is not executable, so every file in
# .githooks is made executable here.
for hook in .githooks/*; do
  if [[ -f "$hook" ]]; then
    chmod +x "$hook"
  fi
done
printf 'privacy-gate: every file in .githooks is executable\n'

# ───────────────────────────────────────────────────────────────
# 5. PRIVACY DENYLIST FILE
# ───────────────────────────────────────────────────────────────

if [[ -f .privacy-denylist ]]; then
  printf 'privacy-gate: .privacy-denylist already exists, left untouched\n'
else
  cp .privacy-denylist.example .privacy-denylist
  chmod 600 .privacy-denylist
  printf 'privacy-gate: created .privacy-denylist with mode 600, add your private terms\n'
fi

# ───────────────────────────────────────────────────────────────
# 6. OPERATOR APPROVAL INSTRUCTIONS
# ───────────────────────────────────────────────────────────────

printf 'privacy-gate: gate file changes are approved with %s=1, which only the Operator sets\n' \
  PRIVACY_GATE_CHANGE_APPROVED
printf 'privacy-gate: a commit that changes a gate file also carries the trailer line %s\n' \
  'Privacy-Gate-Change: approved'
