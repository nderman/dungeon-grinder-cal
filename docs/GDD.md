# Dungeon Grinder Cal — MVP Master Design Document

> Consolidated from the full design session. This is the single design "Ground Truth."
> Tone: snarky intergalactic reality-TV "meat grinder" hosted by the AI **Dungeon Director, Cal**.

## 1. Vision
A mobile, top-down twin-stick roguelite shooter in **Godot 4 / GDScript**. It fuses
**Hotline Miami** twitch lethality with **Dungeon Crawler Carl**-style weird
science-fantasy and a brutal reality-TV framing. Contestants are dropped into a
procedurally generated dungeon ("the show"); death is permadeath ("Cancellation"),
but meta-progression persists for the next "Season."

**Architecture mandate:** Composition over Inheritance. Entities = a `CharacterBody2D`
+ modular component nodes. Swap behavior by swapping components, never deep class trees.

## 2. Core Loops
- **Micro-loop (the Episode):** clear an **open floor** of prefab rooms via "sorties."
  Earn **Ratings** (in-run currency) and **Hype** through stylish/violent play. Spend
  Ratings at **Sponsor Drop-Pods** (mid-run, hype-triggered) and **Safe Room terminals**.
- **Macro-loop (the Network):** on death, 10% of Ratings convert to permanent
  **Syndication Points**. Reaching floors 3/6/9 grants **Milestone Tokens** spent in the
  **Green Room** to unlock one race OR class per token.

## 3. Combat Model ("Small Pool")
- Health is measured in **hearts**; **1 heart per 5 CON**. Half-heart granularity allowed.
- Standard mobs deal **1 heart**, bosses **2+**. Brief **i-frames** on the Dash.
- **Damage Resistance (probabilistic):** `DR% = CON × 1.5 + flat gear DR`, capped **75%**.
  A successful roll ignores **one** heart (the "Clink!"). Mob 1→0, boss 2→1.
- Healing is rare (potions / "Near Death" pity boxes), not floor litter.

## 4. Stats (baseline 10 each)
| Stat | Governs | Status |
|---|---|---|
| **STR** | melee damage, knockback | ✅ melee swing + shove (both STR-scaled); see weapon mode below |
| **DEX** | move speed, dash i-frames, accuracy | ✅ all three (speed `300+DEX×5`; spread `14°−DEX×0.9`; i-frames `+DEX×0.01s`) |
| **INT** | spell damage, **max mana = INT×5**, **regen +2%/INT** | ✅ done |
| **CON** | **hearts (CON/5)**, **DR (1.5%/CON)** | ✅ done |
| **CHA** | Ratings gen, shop prices, loot quality | ⚠️ Ratings gen done (`×(1+CHA×0.02)` on every payout); shop prices = no shops yet; loot quality = TODO |

**Weapon modes:** the **primary attack button** (`fire`, left-click) performs the **active
mode** — RANGED (Glitch Bolt, INT-scaled) or MELEE (STR-scaled arc swing + knockback, 96px /
120° / `0.5×(1+STR×0.1)`♥). **Right-click (`swap_weapon`) toggles** the mode, so a melee build
never changes which button it presses. *(Active-mode HUD indicator lands with the quick bar — TODO.)*

**Nano-Magic is universal, INT-scaled:** `damage = base × (1 + INT×0.05)`,
`cost = base × (1 − INT×0.01)`. Spells: Glitch Bolt, Static Chain, Molecular Beam, Gravity Well.

## 5. Roster (floor-gated, one unlock per Milestone Token)
**Races** (bonuses over baseline): Human (—, Viewer's Choice loot tailoring) ·
Ogre (+5 CON, knockback/−speed) · Cat (+5 DEX +2 CHA, hype/hiss) · Trollkin (+5 STR, regen) ·
Aero-Wraith (+5 DEX, flight/phase).
**Classes:** Technomancer (+5 INT +2 DEX) · Bio-Paladin (+5 CON +2 CHA) · Brawler (+5 STR +2 CON) ·
Glitch-Witch (+4 DEX +3 INT) · Gravity-Glitcher (+4 INT +3 DEX) · Scavenger (+5 CHA +2 DEX).
Unlock tiers: **Floor 3** → Ogre/Trollkin/Brawler/Bio-Paladin · **Floor 6** → Cat/Aero-Wraith/Technomancer/Gravity-Glitcher · **Floor 9** → legendary tier.

## 6. World — Open Floor Sorties
- **Random Walk** over a 2D grid stitches prefab `PackedScene` rooms (~1000px apart).
- Boss room = furthest-walked tile. **2–3 Phase-Doors** lead to one persistent,
  sub-dimensional **Safe Room**; exiting returns you to the door you entered.
- **10 Season-One rooms:** Casting Couch (spawn), Ratings Trap, Crossfire Corridor,
  Sludge Pit, Shield-Bot Sanctuary, Ambush Alley, Hype-Building Hall, Green Room Oasis
  (safe), Meat-Grinder's Stage (boss), The Wrap-Up (exit).

### Spawn weighting (Melee / Ranged / Static-Trap / Support-Elite)
Ratings Trap 50/30/10/10 · Crossfire Corridor 20/50/30/0 · Sludge Pit 30/40/10/20 ·
Shield-Bot Sanctuary 10/20/20/50 · Ambush Alley 70/10/20/0 · Hype-Building Hall 30/30/10/30 ·
Meat-Grinder's Stage 0/0/0/100 (boss). Spawn/Safe/Exit = 0.
**Director scaling:** +5% Elite-upgrade chance per floor; low Hype → more Melee; 0.5 hearts → more Static (kiteable) for clutch.

## 7. Bestiary & Hazards
- **Glitch-Goblin** (melee rush, 1♥, 0.3s tell) · **Syndicate Sniper** (ranged, 1.2s laser) ·
  **Shield-Bot Cleric** (support, grants 50% DR aura) · **Lava-Lung Toad** (area-denial, 0.8s tell) ·
  **Screamer** (0.5♥ swarm, no tell). **Boss: Meat-Grinder Golem** (10 segments, 2 phases;
  Phase 2 at 50% adds lava in corner pits, faster slams, chain-slam combo).
- **Implemented:** Glitch-Goblin (melee lunge) + **Syndicate Sniper** (ranged — `AIComponent.ranged`
  fires a `GlitchBolt` grouped onto `"player"` after the 1.2s tell; 2♥, approaches to 340px).
  `LevelGenerator` mixes melee/ranged via `ranged_enemy_chance` (0.3). Shield-Bot Cleric, Lava-Lung
  Toad, Screamer + the per-room spawn-weight table (§6) are TODO.
- **Hazards:** Glitch-Goop (−40% speed, 0.25♥/s) · Lava (1♥/s) · Pits (instant Cancel unless flying).
- **Traps:** Disintegrator Beams, Data-Spike Landmines, Automated Turrets. Dashing through with
  i-frames = a **Ratings Spike**.
- **Boss tiers (DCC):** floors hold **multiple bosses**, ranked Neighborhood → Borough →
  City → Province (F4+) → Country (F6+) → **Floor Boss**. On **Floor 1 bosses are arena-locked**
  (the room seals on entry until the boss falls); deeper floors they roam. High-CHA can charm
  lesser bosses (not Country/Floor). Each drops a tier-rarity **Boss Box** + **persistent loot**
  (a copy for every participant) + a star + an achievement.
  *MVP:* the generator places ~2 Neighborhood bosses (5♥, scaled-down Golems) + 1 Floor Boss
  (Meat-Grinder Golem, 10♥, 2 phases); distinct per-tier prefabs + Boss-Box loot are TODO.

## 8. Loot & Economy
- **Loot Box tiers (DCC):** Bronze → Silver → Gold → Platinum → Legendary → Celestial.
  Achievements grant boxes; they open **only in a Safe Room, all at once, low→high tier** (DCC).
- Item affix rarity: Trash/Common/Rare/Legendary/Artifact = number of **affix slots**
  (Burn, Bleed, Lightning, AOE, Life Leech, Slow). *(affix system still TODO)*
- **Implemented (MVP framework):** `LootData` (box tiers + build-aware roll), `AchievementData`
  + `AchievementManager` (SignalBus events → achievements → boxes), Safe-Room `LootBoxTerminal`
  opens all pending boxes. Boss Boxes / per-tier prefabs / affixes are TODO.
- **Item system (live):** opened items split by `kind`. **Gear** auto-equips — grants +(1+tier)
  to each tagged stat, tracked per-item in `GameManager.equipped_gear` (removable, so equip-slots
  drop in later) and summed into `_item_bonuses`; `get_effective_stats()` = base + gear, which the
  Player re-derives vitals/combat from. **Consumables** (CON→heal, INT→mana, scaled by tier) stock
  a **quick bar**, used with key **`1`** (`GameManager.use_consumable`). **Inventory** screen toggles
  with **`I`** (`InventoryPanel`, read-only list of gear + consumables). HUD shows the quick bar +
  active weapon mode. *TODO: equip slots, drop/swap, weapons-as-items, affixes, pause-in-combat.*
- **Achievements are the PRIMARY per-run loot source**, with three `scope`s (`AchievementData`):
  - `run` — once per run, reset on `SignalBus.run_started` (first kill, first phase-door). Per-run drip.
  - `repeatable` — fires every trigger, no dedup (Speed Demon, Crowd Pleaser, dodges, boss kills).
  - `lifetime` — once *ever*, persisted to `MetaManager.unlocked_achievements` (meta milestones).
  - **Kill→loot drip** lives in `GameManager._track_kill`: a `CROWD_PLEASER` box every `KILLS_PER_BOX`
    (6) kills + a `SPEED_DEMON` spike on `SPEED_DEMON_KILLS` (3) within `SPEED_DEMON_WINDOW` (2s).
    *Was the bug:* `first_blood` used to be one-time-persisted, so loot dried up after the first-ever
    kill; the repeatable feats had reward-table entries but **no detector emitting them**.
- **Director's Algorithm:** loot weights shift toward the player's highest stat / current
  build (gap-fills CON/healing when near death). Human's passive doubles the tailoring.
- **Currencies (three distinct rails — do not conflate):**
  - **XP** — earned from kills → **level-ups** → **skill points** the player spends on stats.
    This is the *character-growth* rail (the "level up, get loot, then risk the boss" grind-gate).
    **Implemented:** `HealthComponent.xp_reward` per mob (goblin 20, Neighborhood boss 120, Floor
    boss 300) → `SignalBus.xp_awarded` → `GameManager.add_xp`. Curve `xp_to_next(lvl)=80×lvl`
    (L1→80, L2→160…); each level banks **3 skill points** (DCC). Levels reset per run (roguelite).
    Spend in a Safe Room at the **`LevelTerminal`** (cyan pad, press E) → `LevelUpPanel` `+` per
    stat → `GameManager.spend_skill_point` mutates the shared run-stats dict + emits `stat_injected`,
    so the Player re-derives hearts/mana/speed (a level-up doubles as a full patch-up). HUD shows
    `LVL n` + an XP bar + a `★n` pip when points are unspent. *(Skills/spells leveling-by-use: TODO.)*
  - **Ratings (Hype)** — the *audience* rail. Drives **loot drops + fan/sponsor boxes** and Ratings
    Spikes (§9). NOT a shop wallet. In-run, partly converts to persistent **Syndication Points**.
  - **Gold** — the *shop* rail. Spent at shops/vendors for gear. *(Shops are TODO.)*
  - **Milestone Tokens** at floors 3/6/9; **Syndication Points** = persistent Green-Room meta.
  - *Superseded:* the earlier "Ratings → stat-injection terminal" idea is replaced by XP→skill-points.

## 9. Ratings Spikes (audience economy)
| Trigger | Achievement | Reward |
|---|---|---|
| 3 kills / 2s | Speed Demon | +10% Hype / +50 |
| clear room @ 0.5♥ | Near Death | +25% / +150 |
| dash through a trap | Untouchable | +5% / +25 |
| boss phase shift | Drama Spike | +15% / +100 |
| spell-kill elite/boss | Fatality | +20% / +200 |
Hype past 100% → **Sponsor Drop-Pod** delivered to a room `Marker2D`.

## 10. Mobile UX
Twin-stick: floating left joystick (move), right joystick (aim+fire past 0.8 deadzone).
Dash + active-spell buttons arc around the right stick. HUD: heart segments + mana bar
(top-left), Hype Meter + Ratings + minimap (top), Audience-Comment ticker, achievement pop-ups.
See `docs/` UI notes; build `CombatHUD.tscn` + `SafeRoomUI.tscn`.

## 11. Feedback Library (the "Juice") — drive via SignalBus
Clink (DR) · player hit (red vignette + shake + crunch) · enemy Cancel (static + cha-ching) ·
crit/ratings-spike pop-ups + crowd roar · dash ghost-trail/whoosh · hazard sizzle/squelch ·
achievement fanfare · Sponsor Pod incoming shadow + boom · Hype thresholds (HUD sparks) ·
spell VFX + mana-empty error · loot unboxing (rarity-colored beam) · stat injection hiss.
