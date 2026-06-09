# Reskin to original IP

This game's **flavour** (names, host, framing) riffs on *Dungeon Crawler Carl*. The **mechanics,
code, and systems are original and ours** — only the themed strings need swapping to make the project
fully ownable and safe to one day commercialize. This doc is the map: do a find/replace pass, rename a
couple of files, and the project is 100% original IP.

**Risk legend:** 🔴 direct reference (must change before any commercial use) · 🟠 evocative / DCC-adjacent
(change to be safe) · 🟢 generic reality-TV / roguelite trope (fine to keep).

## Name map

| Current term | Where it appears | Risk | Suggested original replacements (pick one) |
|---|---|---|---|
| **Dungeon Grinder Cal** (title) | README, AGENTS.md, docs, window title | 🔴 | `GRINDHOUSE`, `SUBLEVEL`, `KILLSCREEN`, `MEATFLOOR`, `THE CRAWL` |
| **Cal** / **Dungeon Director Cal** (host AI) | AGENTS.md "Cal's voice", comments | 🔴 | host name: `VOX`, `MAXX`, `THE DIRECTOR`, `M.C.`, `OVERSEER` |
| **Princess Donut** | comment in AchievementManager (race-title gag) | 🔴 | drop the in-joke, or a new mascot companion of your own |
| **the System** | comments, snark, `SHOW'S OVER` etc. | 🟠 | `the Production`, `the Grid`, `the Network`, `the Feed` |
| **Green Room** | death/return screen, `GameManager`, UI | 🟠 | `the Lounge`, `Backstage`, `Respawn Lounge`, `the Vault` |
| **Showrunner** (summoner boss) | `Showrunner.gd/.tscn`, boss roster | 🟠 | `The Producer`, `The Wrangler`, `The Casting Director` |
| **Meat-Grinder Golem** | `MeatGrinderGolem.gd/.tscn` | 🟠 | `Scrap Golem`, `Grinder`, `The Compactor` (also rename files) |
| **Syndicate** / **Syndication Points** | `MetaManager`, meta currency | 🟠 | `the Network` / `Network Points`, `the Studio` / `Studio Credits` |
| **Cancelled** (death / `CANCELLED` spike) | death flow, achievement, ticker | 🟠 | `Eliminated`, `Off the Air`, `Wrapped`, `Flatlined` |
| **meat grinder** (tagline framing) | README, AGENTS.md | 🟠 | `the gauntlet`, `the grinder`, `the meatgrind` (your own coinage) |
| **crematorium** | one achievement desc | 🟢 | keep — generic |
| **Ratings / Hype / Sponsor / Audience** | scoring + meta systems | 🟢 | keep — generic reality-TV tropes, no specific-IP tie |
| **Loot boxes / tiers / achievements** | loot + economy | 🟢 | keep — genre-standard |

## How to execute (later, its own commit)

1. **Strings first** — grep-and-replace the 🔴/🟠 terms across `game-client/`, `docs/`, `README.md`,
   `AGENTS.md`. Start with the highest-risk: `grep -rniE "dungeon grinder cal|\bcal\b|princess donut"`.
2. **Rename files/classes** — `MeatGrinderGolem.{gd,tscn,gd.uid}` and `Showrunner.{gd,tscn,gd.uid}`
   if you change those boss names; update the `ext_resource` paths in `Floor.tscn` + `class_name`s.
3. **Host voice** — the AGENTS.md "comments in Cal's voice" directive: keep the *snarky-host* style,
   just rename the host. The voice is a vibe, not the IP.
4. **Window title / project name** — `game-client/project.godot` `config/name`.
5. Re-run the headless smoke test (`--import` + boot `Floor.tscn`) — string/file renames are the kind
   of change that silently breaks a scene `ext_resource` path.

## What you do NOT need to change

The actual product: the composition/`SignalBus` architecture, the affix/effect system, DR/dodge/regen
math, the loot-box tier×type system, the boss-AI FSM, procedural generation — all original. Reskinning
is cosmetic; the engineering that makes this a portfolio piece is already yours.
