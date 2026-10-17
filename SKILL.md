---
name: moneybird-accountant
description: Hub for the Moneybird Accountant packets. Picks the accountant, Moneybird CLI or Jortt CLI packet for a request and hands stage two routing to that packet's ROUTER.md.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
version: 1.0.0.0
---

# Moneybird Accountant Hub

The repository root is a parent hub over three packets. This file picks the packet. The packet's own `ROUTER.md` then routes inside it, and its `SKILL.md` holds its contract. Each packet has its own router, so a request reads only the routing of the packets it uses.

---

## 1. WHEN TO USE

| Packet | Use it for | Folder | Router |
|---|---|---|---|
| **accountant** | Every bookkeeping, tax, VAT return (btw-aangifte), yearly overview (jaaroverzicht), income tax return (aangifte inkomstenbelasting) or migration request. The default | `sk-moneybird-accountant/` | [`sk-moneybird-accountant/ROUTER.md`](sk-moneybird-accountant/ROUTER.md) |
| **cli-moneybird** | A Moneybird read or write through `moneybird-guard` | `cli-moneybird/` | [`cli-moneybird/ROUTER.md`](cli-moneybird/ROUTER.md) |
| **cli-jortt** | A read-only Jortt extraction through `jortt-cli` | `cli-jortt/` | [`cli-jortt/ROUTER.md`](cli-jortt/ROUTER.md) |

### When NOT to Use
- Filing a tax return (aangifte, belastingaangifte) or giving legal advice. The accountant packet refuses both.
- Reading `personal database/`, `migration-workspace/` or a `.env` file outside the paths a packet allows.

---

## 2. SMART ROUTING

Routing has two stages. Stage one picks the packet here, from `mode-registry.json` and `hub-router.json`. Stage two is the packet's `ROUTER.md`.

1. A request starts in the accountant packet, the registry default.
2. A request that names a CLI operation and nothing else, such as a `moneybird-guard` read or a `jortt-cli` call, starts in that CLI packet. Nothing else means no accountant task is left once the CLI names and the system names Jortt and Moneybird are set aside. Any task row signal counts, so `moneybird-guard` with bank accounts starts in the accountant packet. A CLI name matches whole words only, so `jortt cli` is not `Jortt clients`.
3. An accountant route whose tool route names `cli-moneybird` or `cli-jortt` hands off to that packet, in the order the tool route names them, and then to the CLI its CLI action names. Read its `ROUTER.md` and its `SKILL.md` before the CLI runs.
4. A refusal stays in the accountant packet and hands off to no CLI packet, even when it names a CLI. So does a request whose accountant rows tie, until its question is answered.
5. When no packet fits, ask one question before loading anything.

The registry holds each packet's folder and router. `sk-moneybird-accountant/scripts/check-route-table.py` checks that the hub files, the registry packets and their routers agree, and that no packet `SKILL.md` embeds a router again. `route-replay.py` scores the packet chain of the HUB gold rows against these rules.

---

## 3. HOW IT WORKS

```text
Moneybird Accountant/
  AGENTS.md            bootstrap: reads this file first
  SKILL.md             this hub, stage one
  mode-registry.json   the packets, their folders and routers
  hub-router.json      stage one signals and the default packet
  sk-moneybird-accountant/   accountant packet: SKILL.md, ROUTER.md
  cli-moneybird/             Moneybird CLI packet: SKILL.md, ROUTER.md
  cli-jortt/                 Jortt CLI packet: SKILL.md, ROUTER.md
```

Each packet keeps its own `graph-metadata.json`, leaf manifest, references, scripts and tests. The CLI packets keep their install guides, because each CLI is set up on its own.

---

## 4. RULES

### ✅ ALWAYS
- **ALWAYS** read this file, then the packet's `ROUTER.md`, then the packet's `SKILL.md`.
- **ALWAYS** keep a packet's routing in its `ROUTER.md` and its contract in its `SKILL.md`.

### ⛔ NEVER
- **NEVER** put a route table, a router block or a router map back into a packet `SKILL.md`.
- **NEVER** edit the generated router block in `sk-moneybird-accountant/ROUTER.md` by hand.

---

## 5. REFERENCES

- [`sk-moneybird-accountant/ROUTER.md`](sk-moneybird-accountant/ROUTER.md), [`cli-moneybird/ROUTER.md`](cli-moneybird/ROUTER.md) and [`cli-jortt/ROUTER.md`](cli-jortt/ROUTER.md): stage two routing, one per packet
- [`mode-registry.json`](mode-registry.json) and [`hub-router.json`](hub-router.json): stage one
- [`sk-moneybird-accountant/SKILL.md`](sk-moneybird-accountant/SKILL.md), [`cli-moneybird/SKILL.md`](cli-moneybird/SKILL.md) and [`cli-jortt/SKILL.md`](cli-jortt/SKILL.md): the packet contracts
