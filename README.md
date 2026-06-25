# Dungeon Grinder Cal

[![tests](https://github.com/nderman/dungeon-grinder-cal/actions/workflows/tests.yml/badge.svg)](https://github.com/nderman/dungeon-grinder-cal/actions/workflows/tests.yml)
[![deploy-web](https://github.com/nderman/dungeon-grinder-cal/actions/workflows/deploy-web.yml/badge.svg)](https://github.com/nderman/dungeon-grinder-cal/actions/workflows/deploy-web.yml)

### ▶ [Play it in your browser](https://nderman.github.io/dungeon-grinder-cal/)
*Desktop only for now — **keyboard + mouse** (WASD move · arrows/mouse aim · left-mouse fire · Q + right-mouse cast · Space dash · E interact · I inventory · K abilities · 1–4 hotbar · **Esc/P pause + controls**). Progress saves to your browser. Touch controls are on the roadmap.*

📖 **New to it? Read the [Player Guide](docs/guide/)** — stats, races/classes, abilities, combat, enemies, loot, potions, floors, and meta-progression, kept in sync with the code.

A mobile, top-down **twin-stick roguelite shooter** built in **Godot 4 (GDScript)** — Hotline-Miami
lethality meets a snarky reality-TV "meat grinder," with permadeath, deep loot, and persistent
meta-progression. A solo side project and an exercise in clean, scalable game architecture.

> **⚠️ Fan tribute — non-commercial.** This is an unofficial, non-commercial homage inspired by the
> tone of *Dungeon Crawler Carl* (by Matt Dinniman). It is **not affiliated with, endorsed by, or
> licensed by** the rights holders, and uses no official assets. Themed names are placeholder flavour;
> if the project ever goes commercial they can be reskinned to original IP (see
> [`docs/RESKIN.md`](docs/RESKIN.md)). Released under a **non-commercial** licence (below); not for sale.

> 🚧 **Work in progress / prototype.** Mechanics-first: everything renders as gray-box `Polygon2D`
> placeholders while the systems get built out. The interesting part is the architecture, not the art.

---

## What's interesting here (the engineering)

This is built as a **composition-first** Godot project — entities are a `CharacterBody2D` plus modular
component nodes, never deep inheritance trees — with **all cross-system events routed through a single
`SignalBus`** autoload. Combat logic emits; UI / VFX / progression listen. That decoupling is what
lets the systems below stack without tangling.

- **Component combat model** — `Health` / `Movement` / `Protection` (probabilistic damage resist) /
  `Mana` / `AI` / `Hitbox` / `StatusEffect` components. Damage always flows
  `Hitbox → ProtectionComponent → HealthComponent`, never bypassing DR.
- **Affix-driven loot** — gear rolls into instances (base + rarity + affixes). Rare+ items roll
  **effect-affixes** that change how you play: offensive **Burn / Leech / Crit / Chill / Chain** that
  proc on hit, and defensive **Armor / Regen / Dodge**, aggregated across every equipped slot.
- **Loot boxes with tiers _and_ types** — 6 quality tiers (Bronze→Celestial) × 7 types (Weapon,
  Armor, Trinket, Supply, Gear, audience **Fan** boxes, premium **Boss** boxes), with per-tier rarity
  floors so a high-tier box always feels good.
- **Boss roster** — boss rooms roll a distinct archetype (a slam/swing bruiser, a radial bullet-pattern
  artillery turret, a summoner that floods the arena with adds), each a thin entity script riding the
  shared components.
- **Enemy AI** — a small FSM (`idle → chase → telegraph → attack → cooldown`) with a mandatory
  telegraph window, line-of-sight gating, navmesh pathing around cover, and pluggable attack types
  (lunge / ranged / swing).
- **Procedural floors** — a BSP/random-walk generator builds connected rooms (walls + doorways built
  in code), scatters enemies, cover, corpses, and sub-dimensional Safe Rooms.
- **"Achievement → loot" economy** — a manager watches the `SignalBus` and pays out themed loot boxes
  for feats (set an enemy on fire, blow one up, max a stat), in the host AI's snarky voice.
- **Analytics & live experiments** — an in-house **PostHog** SDK (a vendored Godot addon) rides the
  same `SignalBus`: a `Telemetry` listener forwards run / floor / boss / death / progression events
  with zero coupling to gameplay code, **no-ops without an API key** (so CI and fresh clones transmit
  nothing), and honours an in-game opt-out. A server-side **feature flag drives a live A/B experiment**
  (boss-HP tuning) — its variant is pushed *one-way* into gameplay, never read back, so the game never
  depends on the analytics layer. Balance is data-driven: the recent loot-box-spam fix came straight
  off the event counts.

## Engineering hygiene

- **Persistent regression suite** — `game-client/tests/` runs headlessly in one process (`./tests/run_tests.sh`),
  loading autoloads once and exiting non-zero on failure. It runs in **GitHub Actions on every push/PR**
  (the badge above) and makes no network calls.

## Tech

- **Engine:** Godot 4.6, GDScript (typed), code-built `.tscn` scenes.
- **Target:** mobile twin-stick (touch), keyboard/mouse for desktop testing.
- **Architecture docs:** [`AGENTS.md`](AGENTS.md) (operational ground truth) and `docs/` (design + TODO).

## Run it

1. Install **[Godot 4.6](https://godotengine.org/)** (standard build — no C#/.NET needed).
2. Open the **`game-client/`** folder as the project (that folder is `res://`).
3. Run the main scene (`Floor.tscn`). Controls: **WASD** move · **arrow keys** aim · **Space** dash ·
   **mouse** fire · **Q** cast · **E** interact (Phase-Door → Safe Room) · **1–4** hotbar.

Headless smoke test:
```bash
cd game-client
/path/to/Godot --headless --import
/path/to/Godot --headless --fixed-fps 60 --quit-after 240 res://Floor.tscn
```

## Status & roadmap

In: component combat, loot/affixes, tiered loot boxes, the boss roster, enemy elemental statuses
(+ resist gear) and floor hazard themes, the achievement→loot economy, a bounded **endgame**
(Floor 9 Champion → "Season Champion" win screen), a post-win **Nightmare mode**, and **anonymous
telemetry + a live A/B experiment**. Next up: an **art pass** (gray-box → pixel sprites), a proper
**loot-box reveal screen**, **weapon damage affixes** (rarity should lift base DPS, not just add
effects), and **meta token sinks** so prestige keeps mattering once the roster is fully unlocked.
Running notes live in [`docs/TODO.md`](docs/TODO.md).

## Licence

[**PolyForm Noncommercial License 1.0.0**](LICENSE) — free to read, run, learn from, and modify for
**any non-commercial purpose**. Commercial rights are reserved. © 2026 Neal Derman.
