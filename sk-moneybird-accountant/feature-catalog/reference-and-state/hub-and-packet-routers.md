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

A request starts in the accountant packet, the registry default. A request that names a CLI operation and nothing else starts in that CLI packet, or in each CLI it names in registry order: once the CLI signals and the system names Jortt and Moneybird are set aside, no accountant task is left. A request that names a phase number holds a migration task, and so does one that names both systems with a bare system name or a move verb such as `copy` or `import`, where a CLI name counts for its system. A T1 or T2 route that holds a move verb holds a migration task too, as in `use jortt-cli to copy the Jortt export`. A CLI name, the packet names `cli-jortt` and `cli-moneybird` included, matches whole words only. A negated name such as `do not use jortt-cli` starts no CLI packet, though a tool route that names it still hands off, and `not only jortt-cli` negates nothing. An accountant route whose tool route names a CLI packet hands off to it in the order the tool route names them, and then to the CLI its CLI action names. That packet's `ROUTER.md` and `SKILL.md` load before the CLI runs. A refusal and an abstain stay in the accountant packet and hand off to no CLI packet. A request that names a CLI is read as a refusal when the text left after the CLI and system names is one.

### Stage two

`sk-moneybird-accountant/ROUTER.md` holds the Task-Type Table, the route classes, ties and abstain, year and state, the generated router block and migration phase routing. `cli-moneybird/ROUTER.md` and `cli-jortt/ROUTER.md` hold each CLI's operation table, loading levels and router pseudocode. Each packet `SKILL.md` section 2 is a short pointer to its router.

### The checks

`check-route-table.py` reads the route table from `ROUTER.md` and fails when a hub file is missing, a root folder with a `SKILL.md` is not in the registry, a registry packet has no folder or router, a router is not `router_state: active` or lost its routing section, intent model or resource map, the hub `SKILL.md` does not link a router, stage one names a default the registry does not or leaves another mode without phrases, a registry `packetSkillName` differs from its `SKILL.md` name, a `packetKind` is not the kind of its role or a packet `SKILL.md` embeds a router again. `route-replay.py` reads the table from `ROUTER.md` when it holds one and from `SKILL.md` otherwise, which is where a revision from before the hub keeps it, and names the file when a marker is missing. It also resolves stage one from `mode-registry.json`, `hub-router.json` and the winning tool route, writes the packet chain to the `packets` column and fails a row that names a `gold_packets` chain it does not match. The HUB gold rows cover a CLI start for each CLI, a tax figure with no handoff, a purchase invoice (inkoopfactuur) and a migration phase that hand off, a refusal that names a CLI, a request that names Jortt clients, a CLI action next to a tax figure, an abstain that names a CLI and a purchase invoice with a negated filing word that keeps its handoff. HUB-011 to HUB-019 add a migration that names a CLI, a phase number with a CLI, a receipt read with `jortt-cli`, a packet name, a negated CLI name with and without a task, two CLIs at once, a negated filing word next to a CLI start and the word Jortt next to the Jortt CLI. HUB-020 to HUB-030 add a Jortt CLI export into Moneybird, two CLIs with a move verb, the word Jortt kept next to Moneybird, a Jortt write that blocks the handoff, `not only` with two CLIs, the packet name `cli-jortt` as a T7 signal, a push on a migration route, a write the request rules out, a phase number next to the Jortt CLI, an `add` write that blocks the handoff and a write to a local summary file that keeps it. `route-replay-test.sh` also proves that a filing request naming `jortt-cli` hands off to none and that a twin pair differing only in its chain is a parity mismatch.

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
| `sk-moneybird-accountant/scripts/check-route-table.py` | Test harness | Checks the route table in `ROUTER.md` and the hub. |
| `sk-moneybird-accountant/scripts/route-table-test.sh` | Automated test | Proves fourteen of the hub failures on a throwaway copy of the repository. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | Scores every gold row from `ROUTER.md`, and fails the HUB rows on a dropped hub signal or a missing mode registry. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | Holds the HUB rows and their gold packet chains. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/hub-and-packet-routers.md

Related references:
- [../bookkeeping-and-migration/task-type-routing.md](../bookkeeping-and-migration/task-type-routing.md) - The route table the accountant router holds.
