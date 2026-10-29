---
title: "Moneybird Accountant Hub Router"
description: "Stage one of the moneybird-accountant hub: the rules that pick the accountant, Moneybird CLI or Jortt CLI packet, and the modes mode-registry.json and hub-router.json declare."
trigger_phrases:
  - "moneybird accountant hub router"
  - "moneybird accountant stage one routing"
importance_tier: important
contextType: general
version: 1.0.0.0
router_state: active
skill_pointer: SKILL.md
---

# Moneybird Accountant Hub Router

The stage one router for the hub [`SKILL.md`](./SKILL.md). `SKILL.md` keeps the packet table and the
link that points here; this file holds the rules that pick a packet and the modes they pick from.

---

## 1. OVERVIEW

Every Moneybird Accountant request starts here and leaves for exactly one packet, or for each CLI packet it names in registry order: the accountant packet `sk-moneybird-accountant` by default, the Moneybird CLI packet `cli-moneybird` or the Jortt CLI packet `cli-jortt`. This file decides only the packet. The packet's own `ROUTER.md` then routes inside it, and its `SKILL.md` holds its contract, so a request reads only the routing of the packets it uses.

The authority for the modes is `mode-registry.json`, and for the stage one signals, the default and the hand-off it is `hub-router.json`. Section 3 names the modes the way those two files do.

---

## 2. INTENT MODEL

Routing has two stages. Stage one picks the packet here, from `mode-registry.json` and `hub-router.json`. Stage two is the packet's `ROUTER.md`.

1. A request starts in the accountant packet, the registry default.
2. A request that names a CLI operation and nothing else, such as a `moneybird-guard` read or a `jortt-cli` call, starts in that CLI packet, or in each CLI it names in registry order. Nothing else means no accountant task is left once the CLI names in `hub-router.json` and the system names Jortt and Moneybird are set aside. Any task row signal but the weak word `btw` counts, so `moneybird-guard` with bank accounts starts in the accountant packet. So does a phase number, or both systems with a bare system name or a move verb, where a CLI name counts for its system, and so does a migration route that holds a move verb, as in `use jortt-cli to copy the Jortt export`. A CLI name matches whole words only, so `jortt cli` is not `Jortt clients`. A negated name such as `do not use jortt-cli` starts no CLI packet, but a tool route that names it still hands off.
3. An accountant route whose tool route names `cli-moneybird` or `cli-jortt` hands off to that packet, in the order the tool route names them, and then to the CLI its CLI action names. Read its `ROUTER.md` and its `SKILL.md` before the CLI runs.
4. A refusal stays in the accountant packet and hands off to no CLI packet, even when it names a CLI. So does a request whose accountant rows tie, until its question is answered.
5. When no packet fits, ask one question before loading anything.

The registry holds each packet's folder and router. `sk-moneybird-accountant/scripts/check-route-table.py` checks that the hub files, the registry packets and their routers agree, and that no packet `SKILL.md` embeds a router again. `route-replay.py` scores the packet chain of the HUB gold rows against these rules.

---

## 3. MACHINE ROUTER

The modes and stage one signals as `mode-registry.json` and `hub-router.json` declare them. The two JSON files stay the authority, and `sk-moneybird-accountant/scripts/check-route-table.py` fails when a registry mode or its router is missing from this block. This section is the last in the file.

```json
{
  "registry": "mode-registry.json",
  "stageOne": "hub-router.json",
  "defaultMode": "accountant",
  "modes": [
    {"workflowMode": "accountant", "packet": "sk-moneybird-accountant", "packetKind": "workflow", "router": "sk-moneybird-accountant/ROUTER.md", "default": true},
    {"workflowMode": "cli-moneybird", "packet": "cli-moneybird", "packetKind": "tool", "router": "cli-moneybird/ROUTER.md", "default": false},
    {"workflowMode": "cli-jortt", "packet": "cli-jortt", "packetKind": "tool", "router": "cli-jortt/ROUTER.md", "default": false}
  ],
  "signals": {
    "accountant": [],
    "cli-moneybird": ["cli-moneybird", "moneybird-guard", "moneybird-cli", "moneybird cli"],
    "cli-jortt": ["cli-jortt", "jortt-cli", "jortt cli"]
  },
  "handoff": "An accountant route whose tool route names a CLI packet hands off to that packet",
  "fallback": "Ask one question before loading anything"
}
```
