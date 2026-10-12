---
title: "Payload-bound approval"
description: "Each write runs only for the exact payload the Operator approved: the guard matches a keyed digest of the writer-session dry run with the payload_digest in the run journal and runs a reference and digest pair once."
trigger_phrases:
  - "payload-bound approval"
  - "payload digest"
  - "attachment digest"
  - "approval consumed"
version: 1.0.0.0
---

# Payload-bound approval (moneybird-guard)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Each write runs only for the exact payload the Operator approved: the guard matches a keyed digest of the writer-session dry run with the `payload_digest` in the run journal and runs a reference and digest pair once.

A reference string alone can be replayed and does not say what was approved. The digest binds the approval to the method, the target path and the body, so a changed payload or another record never matches, and the write log row joins the write back to its approval.

---

## 2. HOW IT WORKS

The exit-3 preview prints `payload-digest: <hex>` for the dry run and, for a `--file` write, `attachment-digest: <hex>` over the file bytes. The Operator copies those values into the `WRITE_INTENT` entry beside the `approval_reference`.

Before a confirmed write reaches the real call, the guard recomputes the digest over the writer-session dry run with the Operator-owned key file `migration-workspace/.secrets/alias-hmac.key` and compares it with the entry. A missing digest or a mismatch exits 9 (`PAYLOAD_MISMATCH`) and prints one digest line. A `--file` write also compares the keyed digest of the file bytes with the entry's `attachment_digest` and exits 9 on a mismatch or a missing digest. A missing or unreadable key file exits 1 before the real call and names the location only.

The digest is a keyed HMAC-SHA256 over the method, the URL path without query or fragment and every dry-run line after the first, normalized to LF with one trailing newline. A bare hash is not used.

Single use is enforced through the guard-owned write log. Before the real call the guard refuses a reference and digest pair that already has a row in `migration-workspace/logs/moneybird-writes.jsonl`, whatever the row's exit status, and exits 8 with a consumed message. A retry needs a new `WRITE_INTENT` entry. Each logged row holds the time, method, path, administration ID, exit status, approval reference, batch key and payload digest, and no request or response body.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Computes the digests, matches the intent, refuses a consumed pair and logs the join keys |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Digest match, changed body, reordered keys, another record path, replay, missing key, attachment mismatch and the log row |
| [`cli/moneybird-cli/tests/stub-moneybird-cli`](../../cli/moneybird-cli/tests/stub-moneybird-cli) | Fixture | Prints the multipart field for a `--file` dry run and a deterministic body |
| [MBD-014](../../manual-testing-playbook/write-safety/payload-bound-approval.md) | Manual playbook | Operator check of match, mismatch and replay in a temporary workspace |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/payload-bound-approval.md`

Related references:
- [write-log.md](write-log.md) - The log row that joins a write to its approval
- [dry-run-first-pass.md](dry-run-first-pass.md) - The dry run the digest covers
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
