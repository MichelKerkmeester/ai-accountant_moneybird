---
title: Hub and packet routers
description: Makes the repository root a hub that picks the accountant, Moneybird CLI or Jortt CLI packet, with each packet's routing in a ROUTER.md beside its SKILL.md.
trigger_phrases:
  - hub and packet routers
  - parent hub
  - packet router
  - router md
version: 1.0.0.0
---

# Hub and packet routers (SKILL.md, ROUTER.md)

## 1. OVERVIEW

Makes the repository root a hub that picks the accountant, Moneybird CLI or Jortt CLI packet, with each packet's routing in a ROUTER.md beside its SKILL.md.

The root `SKILL.md` is the hub and holds stage one. `mode-registry.json` names the three packets, their folders and their routers, and `hub-router.json` names the default packet and the stage one signals. Each packet keeps its contract in `SKILL.md` and its routing in `ROUTER.md`, so a request reads only the routing of the packets it uses.

---

## 2. HOW IT WORKS

### Stage one

A request starts in the accountant packet, the registry default. A request that names a CLI operation and nothing else starts in that CLI packet. An accountant route whose tool route names a CLI packet hands off to it, and that packet's `ROUTER.md` and `SKILL.md` load before the CLI runs.

### Stage two

`sk-moneybird-accountant/ROUTER.md` holds the Task-Type Table, the route classes, ties and abstain, year and state, the generated router block and migration phase routing. `cli-moneybird/ROUTER.md` and `cli-jortt/ROUTER.md` hold each CLI's operation table, loading levels and router pseudocode. Each packet `SKILL.md` section 2 is a short pointer to its router.

### The checks

`check-route-table.py` reads the route table from `ROUTER.md` and fails when a hub file is missing, a root folder with a `SKILL.md` is not in the registry, a registry packet has no folder or router, a router is not `router_state: active` or lost its routing section, intent model or resource map, the hub `SKILL.md` does not link a router, stage one names a default the registry does not or leaves another mode without phrases or a packet `SKILL.md` embeds a router again. `route-replay.py` reads the table from `ROUTER.md` when it holds one and from `SKILL.md` otherwise, which is where a revision from before the hub keeps it, and names the file when a marker is missing.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `SKILL.md` | Hub | Picks the packet. |
| `mode-registry.json` | Hub | Names the packets, their folders and their routers. |
| `hub-router.json` | Hub | Names the default packet and the stage one signals. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Routes inside the accountant packet. |
| `cli-moneybird/ROUTER.md`, `cli-jortt/ROUTER.md` | Shared | Route inside each CLI packet. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-route-table.py` | Check | Checks the route table in `ROUTER.md` and the hub. |
| `sk-moneybird-accountant/scripts/route-table-test.sh` | Automated test | Proves thirteen of the hub failures on a throwaway copy of the repository. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | Scores every gold row from `ROUTER.md`. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/hub-and-packet-routers.md

Related references:
- [../bookkeeping-and-migration/task-type-routing.md](../bookkeeping-and-migration/task-type-routing.md) - The route table the accountant router holds.
