---
title: Commit Message Template
description: The commit message rulebook for this repository, which the sk-git hooks read from this file.
trigger_phrases:
  - "moneybird commit message rules"
  - "privacy gate change trailer"
  - "commit subject format"
importance_tier: normal
contextType: implementation
version: 1.0.0.0
---

# Commit Message Template

## 1. OVERVIEW

This file is the commit rulebook for this repository. The sk-git hooks find it in `.sk-git/` at the repository root and enforce the JSON block in section 6. Without it this repository would have no commit rules at all, because sk-git has no machine-wide default.

It differs from the shared sk-git template in two ways:

- `Privacy-Gate-Change: approved` is a trailer key. A commit that changes a gate file needs that line for the privacy gate, and it may sit in the final trailer paragraph beside `Spec:`.
- There is no `Commit-Id:`. This repository ships no Commit-Id allocator, so nothing would stamp one.

---

## 2. CONTRACT

Subjects use:

```text
type(scope)[!]: imperative summary
```

Type and scope are required. The scope names a stable part of the repository, such as `privacy-gate`, `sk-moneybird-accountant`, `cli-jortt`, `cli-moneybird` or `ci`, and never a number. Aim for 80 characters (`subject.length-target`) and never exceed 100 characters (`subject.max-length`).

Git-generated `Merge`, `Revert`, `fixup!`, `squash!` and `amend!` subjects pass unchanged.

Every authored commit has a prose body that says why. It ends with one trailer paragraph, separated from the prose by a blank line, that carries `Spec: <packet>[/<phase>]` when a packet produced the work. The packet path omits `specs/`. Packets are git-ignored here, so the folder only has to exist on the machine that commits or pushes.

---

## 3. BODY TEMPLATE

```text
<why this change is needed>

<what now behaves differently>

Privacy-Gate-Change: approved
Spec: <packet>[/<phase>]
```

Keep `Privacy-Gate-Change: approved` only when the commit changes a gate file and the Operator approved it. Omit a line rather than writing `N/A`.

---

## 4. EXAMPLE

```text
chore(privacy-gate): allow the new reference files in the amount rule

The new reference files state statutory rates and thresholds, which the
amount rule blocks outside the listed files. The entry lands before the
files because staged mode reads the allowlist from HEAD.

Privacy-Gate-Change: approved
Spec: 007-dutch-tax-research
```

---

## 5. SELF-CHECK

- [ ] The subject matches `type(scope)[!]: imperative summary` (`subject.format`).
- [ ] The scope is a name, not a number (`subject.scope-numeric`), and not a listed alias (`subject.scope-alias`).
- [ ] The summary starts with a lowercase verb (`subject.summary-start`), has no double spaces (`subject.repeated-spaces`) and no closing punctuation (`subject.trailing-punctuation`).
- [ ] The summary is not a vague phrase such as `update` (`subject.vague`) and holds no process language (`subject.process-language`).
- [ ] The subject stays within the 80-character target (`subject.length-target`) and is at most 100 characters (`subject.max-length`).
- [ ] A blank line follows the subject (`body.blank-line`) and a prose body says why (`body.required`).
- [ ] Prose lines stay readable (`body.line-length`).
- [ ] A breaking commit carries `Context:`, `Changes:` and `Verification:` (`body.breaking-sections`) and a `BREAKING CHANGE:` footer (`breaking.footer`).
- [ ] `Spec:` sits in the final paragraph with only trailers beside it (`trailer.final-paragraph`), omits `specs/` (`trailer.spec-prefix`) and names a packet that exists (`trailer.spec-exists`).
- [ ] No `Co-Authored-By`, `Claude-Session` or vendor attribution line (`attribution.forbidden`).
- [ ] The message is not empty (`message.empty`) and not oversized (`message.too-long`).

---

## 6. ENFORCED RULES

The `commit-msg` and `pre-push` hooks and the agent gate read this block through sk-git's `validate-message.mjs`. Editing it changes what they enforce. Each failure names its rule id.

```json
{
  "kind": "commit",
  "version": 1,
  "help": {
    "expected": "type(scope): imperative summary",
    "example": "fix(privacy-gate): block private names at any depth"
  },
  "passthroughSubjects": ["^Merge ", "^Revert \".*\"$", "^fixup! ", "^squash! ", "^amend! "],
  "subject": {
    "types": ["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "release", "revert", "style", "test"],
    "scopeRequired": true,
    "scopePattern": "^[a-z0-9]+(-[a-z0-9]+)*$",
    "scopeAliases": {
      "gate": "privacy-gate",
      "privacy": "privacy-gate",
      "accountant": "sk-moneybird-accountant",
      "skill": "sk-moneybird-accountant"
    },
    "forbidNumericScope": true,
    "allowBreakingMarker": true,
    "summaryStart": { "pattern": "^[a-z]", "hint": "a lowercase imperative verb" },
    "forbidTrailingPattern": "[.!?;:,]$",
    "forbidRepeatedSpaces": true,
    "maxLength": 100,
    "warnLength": 80,
    "vagueSummaries": ["change files", "changes", "checkpoint", "cleanup", "fix", "fix bug", "misc", "misc changes", "miscellaneous changes", "stuff", "update", "update files", "update stuff", "various changes", "work in progress", "wip"],
    "warnPatterns": [
      {
        "id": "subject.process-language",
        "pattern": "(Phase\\s[A-Z0-9]|wave\\s[+A-Za-z0-9]|Lane\\s[A-Z]|[0-9]+\\stasks?|swarm|tranche|WU[0-9]+)",
        "message": "Subject contains internal process language. Move it to the body when it does not describe behavior."
      }
    ]
  },
  "body": {
    "required": true,
    "blankLineAfterSubject": true,
    "warnLineLength": 100,
    "breakingSections": ["Context", "Changes", "Verification"]
  },
  "trailers": {
    "looseKeys": ["Signed-off-by", "Reviewed-by", "Tested-by", "Refs", "Fixes", "Closes", "Related to"],
    "strictKeys": ["Spec", "Privacy-Gate-Change"],
    "machineKeys": ["Spec"],
    "machineKeysInFinalParagraph": true,
    "spec": { "key": "Spec", "root": "specs", "forbiddenPrefix": "specs/", "mustExist": true }
  },
  "attribution": {
    "forbiddenKeys": ["Co-Authored-By", "Claude-Session"],
    "forbiddenTrailerValuePattern": "anthropic"
  },
  "breakingFooterPattern": "^BREAKING CHANGE: .+$"
}
```

---

## 7. RELATED RESOURCES

- [../AGENTS.md](../AGENTS.md) for the gate-file approval rule
- [../scripts/README.md](../scripts/README.md) for the privacy gate that reads the trailer
