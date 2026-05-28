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

## Canonical constants (do not drift)
- Stats (baseline **10** each): **STR, DEX, INT, CON, CHA**.
- Health: hearts; **`hearts = floor(CON / 5)`**; mobs deal 1♥, bosses 2+♥; half-hearts allowed.
- DR (probabilistic): **`DR% = CON*1.5 + gear`, cap 75%**; success ignores 1♥ ("Clink!").
- Mana: **`max = INT*5`**; **`regen = base*(1 + INT*0.02)`**.
- Spells (universal): **`dmg = base*(1 + INT*0.05)`**, **`cost = base*(1 - INT*0.01)`**.
- Death: **10% of Ratings → Syndication Points**; Milestone Token at floors **3/6/9**.

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
Movement, Protection, Mana, AI; `LevelGenerator.gd`; `entities/player/Player.gd`;
`project.godot` with autoloads + twin-stick input map.
**Runnable vertical slice:** `Main.tscn` (set as the main scene) drops `Player.tscn` and a
`GlitchGoblin.tscn` into `TestRoom.tscn`. Open the **`game-client/`** folder in Godot 4 and
press Play — move = WASD, aim = arrows, dash = Space, cast Glitch Bolt = Q, fire = mouse.
The goblin telegraphs, hits for 1♥, CON gives a DR "Clink!" chance; at 0♥ you're Cancelled to
the placeholder `ui/GreenRoom.tscn`. (`HealthComponent.configured_hearts` lets an enemy scene
set its own pool; the Player still derives hearts from CON.)
**Not yet built (next work):**
- Real scenes — author in-editor (gray-box art is fine): the **10 room prefabs** (each needs
  `open_exit(dir)`, `Marker2D` spawn/door points, `NavigationRegion2D`, camera bounds), more
  enemy types, `CombatHUD.tscn`, `SafeRoomUI.tscn`, and a real Green Room.
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
