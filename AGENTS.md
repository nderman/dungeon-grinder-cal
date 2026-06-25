# AGENTS.md — Dungeon Grinder Cal

Instructions for any coding agent (or human) working in this repo. This is the
**operational ground truth**; `docs/GDD.md` is the **design ground truth**. Read both
before writing code.

## What this is
A mobile, top-down **twin-stick roguelite shooter** in **Godot 4 + GDScript**.
Reality-TV "meat grinder" + weird science-fantasy. Hotline-Miami lethality, permadeath,
persistent meta-progression. Hosted by snarky AI **Dungeon Director "Cal."**

## Non-negotiable directives
1. **Composition over Inheritance.** Entities = `CharacterBody2D` + modular component
   nodes (`HealthComponent`, `MovementComponent`, `ProtectionComponent`, `ManaComponent`,
   `HitboxComponent`, `AIComponent`). Add a component for new behavior; never build deep
   base-class trees. A component decides *what* it does, not *who* owns it.
2. **All cross-system events go through `SignalBus`** (autoload). Combat logic emits;
   UI/VFX/SFX listen. Components must not reach into the HUD directly.
3. **Typed GDScript only.** No C#, no visual scripting.
4. **Cal's voice in comments.** Comments reflect the Director's snark — never write a
   flat comment like "increments health"; write "patch up the contestant's leaky bits."
5. **Mobile-first.** Twin-stick touch input; keep draw calls and per-frame work lean.

## Canonical constants (current — verified against code 2026-06-25)
These drifted from the original design via balance passes; the values below are what the code actually
does. Player-facing detail (with examples) lives in [`docs/guide/`](docs/guide/) — keep both in sync.
- Stats (baseline **4** each, DCC scale): **STR, DEX, INT, CON, CHA**. CHA is currently audience-flavour only (no live formula).
- Health: **`HP = CON × 10`**; a DR proc shrugs 1♥ ("Clink!"). HP regen **`CON × 0.2 /s + gear`, total cap 3.0/s**.
- DR (probabilistic): **`DR% = CON × 3.6 + gear`, cap 75%**. Dodge (full negate, rolled first): **`DEX × 1.2 + gear`, cap 35%**.
- Mana: **`max = INT × 12`**; **`regen = 1.8 × (1 + INT × 0.05)`**. (Spell mana-cost is flat — no INT discount in code yet.)
- Weapon damage: melee **`×(1 + STR×0.107)`**, gun **`×(1 + DEX×0.08)`**, magic **`×(1 + INT×0.04)`**; Rare+ weapons add a rarity power mult (~×1.2 Rare → ×1.6 Legendary).
- Ability power: **`base × (1 + stat×0.1) × (1 + (level−1)×0.06)`**; **8 casts/level, cap 15**.
- Enemy scaling: HP & damage **`×(1 + 0.35 × (floor−1))`**, plus elites/Nightmare/NG+ on top.
- Death: **10% of Ratings → Syndication** (20% on a Champion win); Milestone Token at floors **3/6/9**.

## Repo layout (monorepo)
```
/docs                      # Design ground truth (GDD.md + future room/UI specs)
/game-client               # The Godot 4 project — open THIS folder in Godot (res:// = here)
  /scripts/autoloads       # SignalBus, MetaManager, GameManager
  /data                    # RaceData, ClassData, NanoMagicLibrary (autoloads/resources)
  /components              # The modular "brains" (one responsibility each)
  /entities/{player,enemies}  # Assembled PackedScenes (.tscn) + their controller scripts
  /levels{,/prefabs}       # LevelGenerator.gd + the 10 room scenes
  /ui                      # CombatHUD.tscn, SafeRoomUI.tscn, GreenRoom.tscn
  /assets                  # Optimized, committed art/audio (PNG/OGG)
/assets-raw                # Source PSDs/wavs — gitignored; LFS only
```
Autoloads (registered in `game-client/project.godot`, load order matters):
`SignalBus → RaceData → ClassData → NanoMagicLibrary → MetaManager → GameManager`.

## SignalBus map (see `scripts/autoloads/SignalBus.gd`)
`dr_triggered` · `player_damaged` · `enemy_cancelled` · `ratings_spike(type)` ·
`player_dashed` · `hazard_active` · `achievement_unlocked` · `sponsor_pod_incoming` ·
`hype_threshold_reached` · `spell_cast` · `mana_updated` · `mana_depleted` ·
`box_opened` · `item_acquired` · `stat_injected` · `phasedoor_discovered`.
`ratings_spike` types that pay out (GameManager.SPIKE_TABLE): `SPEED_DEMON`, `NEAR_DEATH`,
`UNTOUCHABLE`, `DRAMA_SPIKE`, `FATALITY`. Non-payout: `TELEGRAPH_START`, `CANCELLED`.

## Current state (what exists)
**Implemented (GDScript):** all 6 autoloads/data scripts; components Health, Hitbox,
Movement, Protection, Mana, AI, Aura, MeleeSwing, AbilityFx, StatusEffect, CombatEffects, ElementMark;
`LevelGenerator.gd`; `entities/player/Player.gd`; `project.godot` with autoloads +
twin-stick input map. Loot is rolled into instances (base + rarity + affixes); Rare+ gear
rolls EFFECT-affixes (Burn/Leech/Crit/Chill/Chain offensive, Armor/Regen/Dodge defensive) that
proc on weapon hits via `CombatEffects`. Loot boxes have a **tier** (Bronze→Celestial, per-tier
rarity floor) AND a **type** (gear/weapon/armor/trinket/supply/fan/boss — constrains the roll pool);
achievements grant a fitting box via `AchievementData` `box_type`, opened in a Safe Room. Enemies: Goblin/Brute/Screamer/Sniper + Cleric/Healer
elites. Boss rooms roll a **roster** (`_pick_boss_scene`): Golem (slam+swing), Hexgun (radial
volleys), Showrunner (summons adds + ranged) — each a thin entity script on the shared components.
Enemies inflict **elemental statuses** on the player via `AIComponent.on_hit_effect` (burn/chill);
`StatusEffect` works on player + mobs, mitigated by `Player.elemental_resist()` (Fire/Frost Resist
affixes). Floors 3+ roll an **Inferno/Cryo theme** (`LevelGenerator.floor_element`) that makes a share
of mobs + all elites elemental — a telegraphed hazard you gear resist for.
**Runnable game (`Floor.tscn` = main scene):** `LevelGenerator` builds an **Open Floor** —
a Random Walk grid of parametric `Room`s (walls + door-gaps built in code via `Room.gd`),
doors opened between neighbours, enemies + Phase-Doors scattered, and a sub-dimensional
`SafeRoom` parked off-grid. You spawn in the Spawn room. Controls: move WASD, aim arrows,
dash Space, fire mouse, cast Q, **interact E** (Phase-Door pad → Safe Room; the portal there
warps you back via `GameManager.last_safe_room_entrance_pos`). `CombatHUD` shows HP/mana/
hype/ratings; death → placeholder Green Room. `Main.tscn` is kept as a single-room combat
test bench.
**Endgame:** the run is bounded — `GameManager.FINAL_FLOOR` (9) is the Season's last floor. It has no
stairs down; killing its `FINAL_BOSS` (Champion) calls `GameManager.win_run()` → the Green Room shows
a "Season Champion" screen (`MetaManager.seasons_won` prestige). Death still routes to `end_run()`.
**Nightmare mode** (`MetaManager.nightmare_enabled`, unlocked after a win, toggled in the Green Room)
sets `GameManager.nightmare` at run start → enemies deal `×NIGHTMARE_DMG_MULT` damage (`nightmare_dmg_mult()`).
**Not yet built (next work):**
- **Balance pass** (defensive affixes stack too hard); **art** (gray-box `Polygon2D`); weapon damage
  affixes (rarity adds effects but not base dmg); a unique multi-phase final boss. See `docs/TODO.md`.
- Scripts still to draft: `InputComponent` (optional — Player handles input inline now),
  `SafeRoomTerminal.gd`, `LootBoxTerminal.gd`, `SponsorDropPod.gd`, `GreenRoomUI.gd`,
  `CastingCouchUI.gd`, `FeedbackManager.gd` (the SignalBus listener that plays VFX/SFX),
  weapon/affix system, loot tables. Full specs for all of these are in `docs/GDD.md`.

## Build order (recommended)
1. `Player.tscn` + a test room → confirm twin-stick movement, dash, mana.
2. One enemy scene using `AIComponent` → confirm telegraph + damage + DR "Clink!".
3. `CombatHUD.tscn` wired to `SignalBus` (hearts dim on `player_damaged`, mana bar, Hype).
4. 3–5 room prefabs + `LevelGenerator` → a connected open floor with a Phase-Door.
5. Safe Room terminals (stat injection + loot box) → mid-run progression.
6. `GameManager.end_run` → Green Room → `GreenRoomUI` token spend → loop closes.

## Telemetry
Anonymous PostHog analytics via the in-house `addons/posthog/` SDK. `Telemetry.gd` (autoload) listens
to `SignalBus`/`GameManager` and forwards to `PostHog.capture()` — gameplay code stays unaware. Key +
host come from `POSTHOG_API_KEY`/`POSTHOG_HOST` env, or a gitignored repo-root `.env` that the
`EnvConfig` autoload loads for you (Godot has no native `.env` — env vars override the file). NEVER
committed; no-op without a key, so CI/clones send nothing. Opt-out: `MetaManager.analytics_enabled`. Remote balance experiment: `boss-hp-tuning`
flag → `Telemetry.boss_hp_mult()`. See `PostHog.md`. The test suite forces `PostHog.test_mode` (no net).

## Tests
Headless regression suite in `game-client/tests/` — **`./tests/run_tests.sh`** (exits non-zero on
failure; run it as the `/shipit` test step). One process loads autoloads once and runs every
`test_*.gd` (each `extends TestCase`). Add a test: write `tests/test_foo.gd`, preload it into
`TestRunner.gd`'s `TESTS`. Must be scene-driven — `godot -s` doesn't load autoloads. See `tests/README.md`.

## Player guide (keep it in sync)
A player-facing field manual lives in [`docs/guide/`](docs/guide/) — chapters for stats, races/classes,
abilities, combat, enemies, loot, potions, floors/stairs, and meta-progression, written from the real
code values. **It's maintained like the test suite: when you change a player-visible mechanic (a stat
formula, ability, enemy/loot/floor number, a new system), update the matching `docs/guide/` chapter in
the SAME change.** It's plain Markdown (renders on GitHub; drops into mdBook/GitBook if we ever publish it).

## Conventions
- File/class names PascalCase; component scripts end in `Component`.
- Components fetch siblings via `get_node_or_null` and degrade gracefully if absent.
- Damage flows: `HitboxComponent` → victim's `ProtectionComponent.handle_incoming_damage`
  → `HealthComponent.take_damage`. Don't bypass DR.
- Run the project from the `game-client/` folder (it is the Godot project root).

## Starter prompt for an agent
> Act as a lead Godot 4 developer. Read `AGENTS.md` and `docs/GDD.md`. Following strict
> Composition-over-Inheritance and routing all combat events through `SignalBus`, assemble
> `Player.tscn` from the existing components and build one test combat room so the
> contestant can move, dash, cast Glitch Bolt, and take DR-mitigated damage. Use gray-box
> placeholders for art. Keep comments in Cal's snarky voice.
