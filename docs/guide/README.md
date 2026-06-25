# Dungeon Grinder Cal — Player Guide

Welcome to the meat grinder, contestant. This is the field manual for **Dungeon Grinder Cal** — what
the stats do, how the loot works, what's trying to kill you, and how to claw your way to Champion.

> **Maintained alongside the code.** Every number here is pulled from the actual game data, not vibes.
> If a mechanic changes, the matching chapter changes in the same commit (see
> [`AGENTS.md`](../../AGENTS.md) → *Player guide*). If something here looks wrong, the code wins —
> please flag it.

▶ **[Play in the browser](https://nderman.github.io/dungeon-grinder-cal/)** (desktop, keyboard + mouse).

## Contents

1. [Stats](stats.md) — the five attributes and everything they drive (HP, DR, dodge, mana, damage…)
2. [Races & Classes](races-and-classes.md) — your contestant: bonuses, starter abilities, the Floor-3 pick
3. [Abilities](abilities.md) — spells & skills, leveling by use, tomes, item-granted casts, binding Q / Right-Mouse
4. [Combat](combat.md) — weapons & damage, damage resistance, dodge, i-frames, crit, gear affixes, **elemental** (burn/chill + resist)
5. [Enemies](enemies.md) — the roster, elites, and the boss archetypes
6. [Loot & Items](loot.md) — tiers, rarities, affixes, loot boxes, the Director's Algorithm, the hotbar
7. [Potions](potions.md) — healing, **potion sickness**, antidotes
8. [Floors & Stairs](floors-and-stairs.md) — the collapse clock, descending, Safe Rooms, the final floor
9. [Meta-progression](meta-progression.md) — Syndication, Tokens, the roster shop, stat injectors, sponsorship, **New Game+**, Nightmare

## The 30-second version

You descend a bounded dungeon (**9 floors**). Each floor has a **two-stage clock**: stairs open at
2 minutes (or the instant you kill the Floor Boss), and the floor **collapses** — lethal — at 5 minutes.
You start **classless**; on **Floor 3** you lock in a class (and may swap race). Kills grant XP and
Ratings; **achievements pay Loot Boxes** you crack in a **Safe Room** (reached via Phase-Doors). Beat
the **Floor 9 Champion** to win the Season. Death is permanent for the run, but **10% of your Ratings**
banks as **Syndication** and milestone floors pay **Tokens** — spend both in the Green Room to come back
stronger. Then do it again, harder.

## Controls (desktop)

| Action | Input |
|---|---|
| Move | `W A S D` |
| Aim | Mouse / Arrow keys |
| Fire weapon | Left Mouse |
| Cast ability | `Q` (primary) · Right Mouse (secondary) |
| Use hotbar slot | `1` `2` `3` `4` |
| Dash | `Space` |
| Interact / Phase-Door | `E` |
| Inventory | `I` · Abilities (bind casts) `K` |
| Pause / Help | `Esc` / `P` |
