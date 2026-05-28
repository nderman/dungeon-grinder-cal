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
| Stat | Governs |
|---|---|
| **STR** | melee damage, knockback |
| **DEX** | move speed, dash i-frames, accuracy |
| **INT** | spell damage, **max mana = INT×5**, **regen +2%/INT** |
| **CON** | **hearts (CON/5)**, **DR (1.5%/CON)** |
| **CHA** | Ratings gen, shop prices, loot quality |

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
- **Hazards:** Glitch-Goop (−40% speed, 0.25♥/s) · Lava (1♥/s) · Pits (instant Cancel unless flying).
- **Traps:** Disintegrator Beams, Data-Spike Landmines, Automated Turrets. Dashing through with
  i-frames = a **Ratings Spike**.

## 8. Loot & Economy
- Rarity: Trash/Common/Rare/Legendary/Artifact. Rarity = number of **affix slots**
  (stat bonuses + abilities: Burn, Bleed, Lightning, AOE, Life Leech, Slow).
- **Director's Algorithm:** loot weights shift toward the player's highest stat / current
  build (gap-fills CON/healing when near death). Human's passive doubles the tailoring.
- Currencies: **Ratings** (in-run, lost on death) → 10% to **Syndication Points** (persistent).
  **Milestone Tokens** at floors 3/6/9. **Fan Tokens / Bio-Scrap** for crafting/cosmetics.

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
