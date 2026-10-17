---
title: HUB-001 -- Hub packet selection
description: This scenario validates Hub packet selection for HUB-001. It focuses on offline routing and policy.
id: HUB-001
catalog_applicable: true
version: 1.0.0.0
---

# HUB-001 -- Hub packet selection

This document captures the offline prompt, local read sequence, expected signals and evidence for HUB-001.

---

## 1. OVERVIEW

This scenario validates Hub packet selection. It focuses on Route each request through the hub to one packet and read only that packet's router.

### Why This Matters

A local-only check can confirm that the hub picks the right packet and that a request reads the routing of the packets it uses and no other.

---

## 2. SCENARIO CONTRACT

- Objective: Route each request through the hub to one packet and read only that packet's router.
- Real user request: List my Jortt customers with jortt-cli.
- Prompt: List my Jortt customers with jortt-cli.
- Fixture rows: HUB-001 to HUB-010 score the packet chain in `routing-gold.json`. HUB-001 is this prompt, and HUB-003 scores the chain of a tax figure request like the second.
- Expected execution process: Read the project bootstrap and the hub, then inspect only the listed local files. Do not use network access or accounting APIs.
- Expected signals: The hub picks the Jortt packet for the first prompt and the accountant packet for "What is the business mileage rate for the current tax year?". The first reads `cli-jortt/ROUTER.md` and `cli-jortt/SKILL.md` and no accountant router. The second reads `sk-moneybird-accountant/ROUTER.md` and no CLI router, because its tool route is `none`.
- Desired user-visible outcome: A concise route report with the chosen packet, the router read, the reference paths and no API activity.
- Pass/fail: PASS if Each prompt reads the hub, one packet router and that packet's `SKILL.md`. FAIL if A prompt reads a router of a packet it does not use or skips the hub.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the hub.
2. Follow the listed local read sequence for each prompt.
3. Compare the observed reads to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| HUB-001 | Hub packet selection | Route each request through the hub to one packet and read only that packet's router. | List my Jortt customers with jortt-cli. | 1. Read AGENTS.md -> 2. Read SKILL.md -> 3. Read cli-jortt/ROUTER.md -> 4. Read cli-jortt/SKILL.md -> 5. Report the packet, the router and the operation row | The hub picks the Jortt packet, which reads its own router and no accountant router. | Capture the prompt, the chosen packet and the read list. | PASS if The read list holds the hub, `cli-jortt/ROUTER.md` and `cli-jortt/SKILL.md` and no other router. FAIL if It reads `sk-moneybird-accountant/ROUTER.md` or skips the hub. | Check the signals in `hub-router.json` and stage one in `SKILL.md`. Repeat with only local documents. |

### Prompt

- Prompt: List my Jortt customers with jortt-cli.

### Commands

1. Read AGENTS.md
2. Read SKILL.md
3. Read cli-jortt/ROUTER.md
4. Read cli-jortt/SKILL.md
5. Report the packet, the router and the operation row

### Expected

The hub picks the Jortt packet, which reads its own router and no accountant router.

### Evidence

Capture the prompt, the chosen packet and the read list.

### Pass / Fail

- **Pass**: The read list holds the hub, `cli-jortt/ROUTER.md` and `cli-jortt/SKILL.md` and no other router.
- **Fail**: It reads `sk-moneybird-accountant/ROUTER.md` or skips the hub.

### Failure Triage

Check the signals in `hub-router.json` and stage one in `SKILL.md`. Repeat with only local documents.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/reference-and-state/hub-and-packet-routers.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| SKILL.md | Picks the packet |
| hub-router.json | Names the default packet and the stage one signals |
| cli-jortt/ROUTER.md | Routes inside the Jortt packet |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: HUB-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/hub-packet-selection.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read SKILL.md -> 3. Read cli-jortt/ROUTER.md -> 4. Read cli-jortt/SKILL.md -> 5. Report the packet, the router and the operation row

**Expected resources:** SKILL.md, cli-jortt/ROUTER.md and cli-jortt/SKILL.md
