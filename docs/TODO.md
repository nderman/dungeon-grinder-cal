# Dungeon Grinder Cal — TODO & Ideas

A scratchpad for random thoughts so they don't get lost. Newest ideas go under
**Inbox**; once triaged they move to **Backlog** (grouped) or get built and move to
**Done**. Ground-truth design still lives in `GDD.md`; this is the running queue.

---

## Inbox (raw, undated thoughts land here)

- **CORPSES + ECONOMY SEED + BOSS-COVER FIX + BALANCE (done 2026-06-02)** —
  - **Lootable corpses** (`Corpse.tscn`, spawned on `enemy_cancelled`): walk over to collect the
    common drip — **gold** (new `GameManager.gold` run currency, scaled off the mob's ratings) + a 6%
    basic-potion chance. HUD gold readout. Auto-fades after 25s. (Gold spends at shops later. Still
    TODO: corpses dropping common GEAR; box CONTENTS scaling by tier — see Loot-Boxes note.)
  - **Boss cover / juking**: cover stays in boss arenas (strategic). Bosses chase **navmesh-only**
    (`AIComponent.chase_navmesh_only`) — path AROUND cover so you can break LoS and outmaneuver them,
    and they can't wedge charging through it. Anti safe-spot: after `STUCK_BEELINE_TIME` (2.5s) of no
    path progress they beeline, so a static safe-spotter can't snipe a boss forever. Trash mobs keep
    the immediate beeline (anti-kite).
  - **Balance**: starter potions 2→1 + corpse potion 6% (was a glut); enemy depth scaling 0.2→**0.35**
    /floor + **+1 mob/floor** in combat rooms (deeper = meatier).
  - **NEXT: Elite-upgrade system** (the real "harder from floor 3/4" answer) — bigger/tankier/stun-
    resistant mobs from floor 3, scaling chance (GDD's +5%/floor). Dial the 0.35 scaling back down
    once elites carry difficulty (variety over number-inflation).

- **ENEMY VARIETY + BaseEnemy (done 2026-06-02)** — `BaseEnemy.tscn` inheritable template (std
  component tree + a 0-DR `ProtectionComponent` so mobs are buffable). New archetypes: **Screamer**
  (fast, 1♥, ~no telegraph swarm) and **Shield-Bot Cleric** (slow support; new `AuraComponent` grants
  50% DR to allies within 200px, expiry-based so it fades when the cleric dies; faint ring VFX).
  Retrofitted Goblin+Sniper with a `ProtectionComponent` so the aura buffs them. **Weighted spawn
  table** (`_pick_enemy_scene`: melee 50 / ranged 20 / screamer 22 / cleric 8 floor-2+) replaced the
  flat coin-flip. Original Goblin/Sniper/Golem stay standalone (only new mobs inherit BaseEnemy);
  weights are first-pass — tune after playtest. Next archetypes: Lava-Lung Toad (hazard), Exploder.

- **LOOTABLE CORPSES + the loot-source split** — kills leave a lootable corpse (walk over /
  interact) that drops **basic common stuff**: coins/gold, low-tier crafting mats, basic potions
  (antidotes), un-enchanted common gear. This is the steady drip from clearing.
  **Loot Boxes stay the POWER source** (achievements/sponsors), and follow the DCC tier ladder —
  Bronze (common/unenchanted) → Silver (basic jewelry, minor armour, copper/silver coin) → Gold
  (moderately enchanted gear, recipes) → Platinum (high-tier enchants, skill books, stat gear) →
  Legendary (artifacts, big stat/perm-point allocations) → Celestial (ultra-rare game-changers). So:
  **corpses = common drip, boxes = better/rarer gear+potions.** Our `LootData.TIER_NAMES` already has
  the ladder; future work is making box CONTENTS match the tier (richer rolls at higher tiers) and the
  optional flavoured boxes (Goblin = explosives, "Talk of the Town" = fame items). Corpses persist a
  few seconds / until looted; rarer mobs → slightly better common drops. Ref:
  https://dungeon-crawler-carl.fandom.com/wiki/Loot_Boxes  *(2026-06-02)*
- **BLOOD / GORE :)** — visual juice for the "meat grinder": blood splatter on hits + a bigger burst
  on a kill (code-built particles/decals via FeedbackManager, like the CLINK!/floating-text pattern),
  maybe lingering stains on the floor. Pairs with the FATALITY/audience-pop moments. *(2026-06-02)*

- **STAT TWEAKS: DEX dodge + CON regen (done 2026-06-02)** — DEX gives a full-dodge chance
  (1.2%/pt, cap 50%, rolled before DR in `ProtectionComponent`, player-only, "DODGE" popup; doesn't
  apply to DoTs). CON gives passive HP regen (0.2 HP/s per pt) — lives in `HealthComponent.regen_rate`
  mirroring `ManaComponent`. Both also help the early-game survivability. INT→detection + CHA→shop
  prices still planned (see Map arc + Stats section).

- **COMBAT POLISH (done 2026-06-02)** — (1) Melee no longer whiffs on close enemies: the swing cone
  is widened by the angle the enemy's body subtends at its distance (stays directional — full
  forward reach, won't clip enemies beside/behind). (2) Boss **stun resist** (`AIComponent.stun_resist`,
  clamped 0-0.95): chance to shrug off + shortens any stun that lands (Floor Boss 0.6, Neighborhood
  0.35; trash 0). (3) HUD ability readout **greys out** when the active ability is on cooldown / out
  of mana (`Player.selected_ability_ready()`).

- **ABILITIES + CLASS/RACE PROGRESSION (done 2026-06-02)** — big arc:
  - **Spells & Skills**: unified `AbilityLibrary` autoload (spells cost mana, skills cooldown-only),
    cast the selected ability on **Q**, **level-on-use** (cap 15), Abilities panel on **K** to pick the
    active. Effects: projectile / nova(AoE) / self_heal / blink. Tomes (consumables) teach abilities
    per-run. Replaced `NanoMagicLibrary`. Ability VFX via `AbilityFx` (nova ring / heal pulse / blink
    streak), mirrors `MeleeSwing`.
  - **Enemy stun**: `AIComponent.stun()` suspends chase/attack + cyan flash. Ground Slam rebalanced
    (damage halved → 0.65, adds 1.5s stun via the `stun` ability field).
  - **Classless start → Floor-3 pick (DCC)**: classless on floors 1-2 (race+base stats only, no class
    ability); on Floor 3 a **mandatory** Race & Class modal (`ClassSelectPanel`) — input is frozen
    until you pick. `GameManager.choose_class/choose_race` apply bonuses as live deltas (preserve
    spent points) + grant/select the class starter.
  - **Roguelite gate**: Floor-3 pick offers only `MetaManager.unlocked_classes/races`; **Green Room
    unlock shop** spends milestone tokens (floors 3/6/9) via `unlock_content()` to grow the roster.

- **EARLY-GAME DIFFICULTY (tuning, deferred)** — floors 1-2 feel hard now (classless weapon-only +
  potion sickness + melee rescale). Levers when ready: innate basic ability while classless, guaranteed
  floor-1 tome, more starting potions, softer early `floor_mult`, or a Rusty Shiv buff. *(2026-06-02)*

- **ABILITIES POLISH (deferred follow-ups)** — (1) class **passives** still unimplemented (Iron Fist,
  Efficient Code, etc. — flavour strings only); (2) skills have no **stamina** resource (cooldown
  only); (3) UI dedup: extract a shared `ModalPanel.make_card(color)` / `add_section` / `top_stat`
  (card StyleBox + section header duplicated across Inventory/Abilities/ClassSelect panels);
  (4) rename internal `skill_points` → **attribute points** now that real Skills exist (UI + GameManager
  + LevelUpPanel + CombatHUD). *(2026-06-02)*

- **POTION SICKNESS (done 2026-06-01)** — DCC cool-down model: any potion starts a CON-scaled
  cool-down (`12 − 0.4·CON`, floored 2.5s); drinking another potion (any kind) before it clears
  inflicts **Poison** (DoT ~4%/s of max HP for 5s, bypasses armour + i-frames). The drink still
  works — risk/reward, not a block. New bases: **Greater Health Potion** (tier 2+, ~2.25× heal) and
  **Antidote** (cures Poison, exempt from the cool-down). Runs start with 2 Health Potions. HUD shows
  a "⚠ Potion sickness Ns" indicator above the quick bar. **Caveat:** quick bar is still FIFO, so you
  can't yet pick the antidote on demand — fixed by the player-assigned hotbar (abilities arc).

- **INVENTORY UI OVERHAUL (done 2026-06-01)** — `InventoryPanel` rebuilt as a two-column paper-doll
  (equip slots, click to remove) + bag grid (click to equip, ✕ to drop), rarity-framed cards,
  effective-stats + quick-bar readout, and **compare-on-hover** (net per-stat delta vs the item it'd
  replace, via `GameManager.resolve_equip_slot` — single source of truth with equip()). Columns sit
  in a viewport-height-capped `ScrollContainer` so a tall inventory scrolls instead of overflowing.
  Still TODO: item icons, drag-to-equip. Pairs with the player-assigned hotbar work.
- **JEWELLERY / TRINKET SLOTS (done 2026-06-01)** — `LootData.SLOTS` now Weapon/Head/Chest/Legs/
  Hands/Amulet/**Ring/Ring 2**/Trinket. `SLOT_ACCEPTS` maps duplicate keys ("Ring 2"→"Ring");
  `GameManager.slots_for_item()` routes equips to the first open matching slot (else swap). 5
  jewellery bases (no armour, pure stat/affix carriers) — the home for future Burn/Leech affixes.
  A debug `assert` in `LootData._ready` guards that every item slot is equippable.

- **ACHIEVEMENT LOOT CADENCE (done 2026-06-01)** — repeatable feats now floor-gated (tutorial drip
  floors 1-3 pay everything, deeper demands higher-tier feats, boss kills always pay); below-
  threshold feats heckle instead of paying. `crowd_pleaser` retargeted from every-Nth-kill grind to
  a **Multi-Kill** flex (2+ cancelled in one ~0.3s blow). Still TODO: capricious "bone" payout +
  crude DCC names (see Flavor-text cluster below).

- **STAT RESCALE to DCC magnitudes (balance pass)** — ref https://dungeon-crawler-carl.fandom.com/wiki/Player_Stats
  DCC: new humans start **3–5** per stat (4=average, 9–10=peak human ever, 100=milestone). We start
  at **base 10 + class (→12–15)** = "peak human at spawn", and each +1 level-up point is trivial
  (15→16). Rescale to small numbers so **leveling matters** (4→5 = +25%).
  - **Plan:** base 10→~4; class/race bonuses scaled down (Brawler +5/+2 → ~+3/+1); then multiply
    every per-stat COEFFICIENT by ~2.5 so starting HP/mana/DR/damage stay ~the same, but each point
    is now a bigger fraction → impactful growth.
  - **Wide range, high ceiling:** stats should climb to **100+ on deep floors** (DCC's 100 = the
    "double future gains" milestone). That's balanced because enemies scale with depth (`floor_mult`),
    so a 100-STR player on floor 15 faces ramped enemies — not trivializing. Implies the run grants
    enough attribute points over many floors to reach triple digits; derived formulas must stay sane
    across the WHOLE 4→100+ range (HP/DR caps, diminishing returns, or linear-but-matched-to-floor).
    DR already caps at 75%; HP/damage need to scale cleanly to 100-stat without breaking.
  - **Touches (re-derive each to hold start outputs):** base stats (MetaManager `BASE_STATS`),
    `RaceData`/`ClassData` bonuses; HP=`CON×4`, mana=`INT×5`, DR=`CON×1.5%` (Player/Protection),
    melee `MELEE_DMG_PER_STR`, ranged `RANGED_DMG_PER_INT`, `SPREAD_PER_DEX`, `DASH_IFRAME_PER_DEX`,
    `CHA_RATINGS_PER`, the `100`-base milestone (future). Attribute-points-per-level (3) may want
    lowering (1–2) since each point now matters more.
  - ⚠️ **Resets the recent melee/HP tuning** — do as ONE deliberate pass + fresh playtest, not
    interleaved with micro-tuning. *(2026-06-01)*

- **LOOT & BUILD SYSTEM (big arc, in progress)** — turn loot into an ARPG-style build system:
  - **Phase 1 (building now):** item INSTANCES (base + **rarity** Common→Legendary, colored +
    rolled **affixes**), **full-body equip slots** (Head/Chest/Legs/Hands/Weapon/2 Rings),
    inventory UI to equip/unequip/compare/drop. Effective stats from equipped items. Replaces the
    old auto-apply-by-id gear.
  - **Phase 2:** weapons as items (equipped weapon drives combat: melee/ranged/fire-rate/spread) +
    weapon-gated start (begin basic, find better).
  - **Hotbar arrangement (player-chosen, NOT auto-ordered):** fixed numbered slots (1–4); the
    player assigns which consumable/spell/skill goes in each slot and can reorder. Use a specific
    slot with its key. Current `quickbar` is an auto-FIFO queue (`1` = oldest) — replace with an
    indexed slot array the player fills from the inventory. *(2026-05-30)*
- **SKILLS = third ability track (nonmagical, learnable)** — per DCC Skills
  (https://dungeon-crawler-carl.fandom.com/wiki/Skills): "talents or nonmagical attacks you learn
  and train." Active (special attacks) or passive (talents). **Level up with use** (cap ~15, like
  spells); acquired via class/race start, gear, potions, guildhalls, dungeon actions. Stats affect
  *effectiveness* but not skill leveling. **Shares the learnable + level-with-use mechanic with
  spells** → build one "Abilities" framework (learn, track level, level-on-use, hotbar-cast/passive)
  and have Spells (magical, mana) + Skills (nonmagical, maybe stamina/cooldown) as two flavors.
  ⚠️ **Terminology clash:** our current "skill points" (XP→levels→3 pts spent on STR/DEX/…) are
  really DCC **attribute points**, NOT Skills — rename to "stat/attribute points" when we build the
  real Skills system to avoid confusion. *(2026-05-30)*
- **SPELLS = LEARNABLE (not loot items)** — per DCC Magic & Spells
  (https://dungeon-crawler-carl.fandom.com/wiki/Magic_%26_Spells): learned via **Tomes** (single-use),
  **Sheet Music** (reusable), or **Guildhalls**; everyone starts with a basic Heal. Spells **level up
  with use** (cap ~15), cost **mana = INT**. Schools (Anguish/Blood/Heirloom). So: a learned-spells
  set on the contestant (persist?), cast from the hotbar; tomes/sheet-music are the acquisition loot.
  Separate system from equipment. *(2026-05-30)*

- **Stairs + safe-room entrances as WALL DOORS** — ✅ DONE (2026-05-30): both now mount flush on a
  corridor-free interior wall (`_wall_anchor` picks the side + rotation), rendered as framed doors.
  Stairs = walk into when open; safe-room = walk up + press E. *Polish later: actual gap in the wall
  / open animation; orient the door art per wall instead of just rotating the node.*
- **Weapon-gated start** — once the weapon/item system is richer, the player starts with only a
  **short-range melee/knife** (no ranged bolt or spells) and must *find* ranged weapons + spells as
  loot. Changes the early game + naturally fixes melee-boss kiting (you can't snipe if you have no
  ranged). Pairs with weapons-as-items. *(2026-05-29)*
- **Melee boss is kiteable by a ranged player** — a melee-only boss can't threaten a player who
  keeps distance + uses cover. Options: a boss gap-closer/ranged attack, or rely on the weapon-gated
  start (melee-only early). Partly mitigated now by beeline-when-unreachable. *(2026-05-29)*

- **Flavor text + Codex screen (DCC voice)** — a cluster of "Cal" personality work:
  - **Boss-battle start screen** — dramatic intro card when a boss arena locks (name, title,
    snarky Cal commentary), à la DCC boss reveals. Ref: https://dungeon-crawler-carl.fandom.com/wiki/Boss
  - **Funny achievement text** — punch up the achievement titles/descriptions in Cal's voice.
    Canon (https://dungeon-crawler-carl.fandom.com/wiki/Category:Achievements, ~159 of them):
    names are crude/dark/funny ("War Criminal", "You're the Reason Why Daddy Drinks!", "Total, Utter
    Failure", "Three Cheers for Slaughter", "Apex Predator"). **Some grant loot boxes, some PURELY
    mock you (no reward)** — which is exactly our floor-gated drip + heckle, so the model's already
    canon; this is a naming/voice pass. New TRIGGERS worth adding (beyond our current 7): killed a
    mob **higher level than you**, **You Found Stairs!**, **Pacifist** (clear a floor w/o killing),
    hoarder (full bag), pet/charm-based, slaughter-count milestones, audience ("They like me!").
    Categories of box by source (canon: Goblin Box = explosives, "Talk of the Town" = fame items).
  - **Funny monster + equipment descriptions** — flavor blurbs on each enemy/boss + item.
  - **Bestiary / Achievement / Dungeon-guide screen** — a codex you open to read the above for
    things you've *encountered* (discovered-gated). Monsters, bosses, weapons, achievements.
    Pairs with HUD work: https://dungeon-crawler-carl.fandom.com/wiki/Heads-Up_Display_(HUD)
  - Data model: add `desc`/`title`/`flavor` fields to AchievementData / LootData / enemy defs;
    track "discovered" set (per save). Reuse the ModalPanel base for the codex screen. *(2026-05-29)*

- **Alternate floor-layout generators per level** — so floors feel distinct. Current BSP =
  dungeon feel. Want e.g. an **open-world** generator: open areas + scattered buildings / forests
  / ponds, less corridor-y. Like DCC Floor 3 (https://dungeon-crawler-carl.fandom.com/wiki/Third_Floor).
  Architecture: make the generator pluggable (a `FloorGenerator` interface; pick by floor number /
  theme). BSP is the first impl. *(2026-05-29)*

- **MAP & HIDDEN INFORMATION (big arc)** — core DCC "what's out there?" tension; right now the
  top-down view reveals every enemy, which kills exploration. Ref: https://dungeon-crawler-carl.fandom.com/wiki/Map
  - **Main top-down view — visibility/FOW:** enemies OUTSIDE line-of-sight aren't drawn. Within a
    **sense radius** (scales with INT / a Pathfinder-style skill) an out-of-sight enemy shows only as
    a **red blip / faint outline** — you detect *something's there* but not *what*. Full sprite only
    with clear LoS. Impl: reuse the wall LoS raycast (we have `AIComponent._has_los`; do the reverse
    for player vision) per-enemy each frame to set sprite visible / blip / hidden — OR Light2D +
    LightOccluder2D on walls for a true vision cone. Unexplored geometry dimmed/fogged.
  - **Minimap (corner):** shows only EXPLORED areas (fog of war); creatures as **dots** — red = mobs/
    bosses, green = you, white = friendly, X = corpses; **safe rooms always visible** even unexplored.
    Reveal expands faster when moving fast. Rooms mark explored as you enter.
  - **Reveal upgrades (loot + abilities, DCC):** *Field Guide* item → reveals mob **type/level** on the
    map (the "what it is"); *Neighborhood Map* → clears FOW in the boss area (this = "killing a boss
    reveals the map" reward); *Ping* spell / *Pathfinder* skill → extend detection range. Ties into the
    Abilities framework + INT.
  - **INT drives detection/minimap (planned stat tie-in):** base enemy-detection / minimap-reveal
    radius scales with INT (recall/awareness, DCC). So INT is the "see what's coming" stat on top of
    mana/spell power — pairs with the reveal items above. *(2026-06-02)*
  - **Dark areas + dynamic lighting** — some rooms/zones are unlit; the player carries a light
    radius (torch/scanner), and there are placed light sources. This *is* the visibility mechanic:
    **Light2D (player + sources) + LightOccluder2D on every wall** → you can't see into the dark or
    past walls, enemies in the dark are unseen until they enter your light (or show as a blip via the
    sense radius). Adds the creepy "what's in the dark?" feel and gives the FOW/LoS hiding for free.
    Light radius could scale with INT / a light item. Pairs with — and may be the cleanest impl of —
    the visibility system above. (Walls are code-built rects, so adding occluders is mechanical.)
  - Sizable system (lighting/occluders + per-enemy visibility + a minimap node + reveal items). *(2026-06-01)*

- **Floor progression — ✅ DONE (2026-05-29):** two-stage clock (stairs open at 120s OR Floor
  Boss death, whichever first; collapse at 300s = lethal DoT), Stairs node in the boss room
  (hidden until open), descend → next floor with run-state carryover + depth scaling, HUD clock.
  *Still TODO:* **enemy spawner** to keep a cleared floor lively while the collapse clock runs;
  tune the timer lengths; stairwell as a richer transition (animation/screen); per-floor difficulty
  curve beyond the flat ×(1+0.2·depth).
- **CON-linked slow regen — NOT built yet** (still just logged below). Confirmed not implemented.
  *(2026-05-29)*

- **More enemy types** — ✅ Syndicate Sniper (ranged) + melee/ranged spawn mix DONE. Remaining
  GDD §7 roster: **Shield-Bot Cleric** (50% DR-aura support — needs an aura/buff mechanic),
  **Lava-Lung Toad** (area-denial — needs a ground hazard), **Screamer** (0.5♥ swarm). Also the
  full per-room spawn-weight table (§6) instead of the flat `ranged_enemy_chance`. Ranged snipers
  pair with the room-variety/cover item. *(2026-05-28)*
  - **Cleanup first:** before adding more enemy scenes, extract a **BaseEnemy.tscn** (CharacterBody2D
    + Health/Movement/AI/HealthBar skeleton) and make Goblin/Sniper/Golem inherited scenes — they're
    3 copies of the same tree now. (Review flag, 2026-05-29.)
  - **Sniper feel:** snipers don't maintain distance — they close to `attack_range` then sit still
    (kiteable, and fire even if you dashed out during the tell since the bolt travels). Consider a
    minimum standoff in `_handle_chase` + maybe a whiff if you leave range. Playtest first.
- **More items / weapons / armour** — expand the `LootData` pool. Armour = CON/DR gear; more
  stat-affinity + flavour variety (cheap: gear auto-applies today). Weapons-as-items needs the
  weapon data model (see Item depth). *(2026-05-28)*
- **Stairwell mechanics + better floor design** — figure out how stairwells work as the
  floor-transition mechanic, and richer floor layout overall. DCC refs:
  https://dungeon-crawler-carl.fandom.com/wiki/Stairwells ·
  https://dungeon-crawler-carl.fandom.com/wiki/First_Floor . Pairs with the "make rooms
  more interesting" item (hazards/cover/shapes). Read the wikis when we build floor v2.
  *(2026-05-28)*
- **Weapon-specific stats** — melee range/damage/arc/knockback (and ranged spread/fire-rate)
  should live on the *weapon*, not as hardcoded `MELEE_*` constants on the Player. Needs a
  weapon/item resource the player equips; pairs with inventory + the loot-items-do-things work.
  *(2026-05-28)*
- **Make rooms more interesting** — ✅ static **cover** layouts DONE (quad/diagonal/scatter/open
  per combat room, blocks movement + LoS both ways). Remaining: **environmental hazards**
  (Glitch-Goop slow, Lava DoT — needs a damage-over-time Area2D), **destructible cover** (health
  on blocks), and **true varied room sizes/shapes** (still one 768px grid square — would need the
  generator/door system to handle non-uniform cells). *(2026-05-28, cover done 2026-05-29)*
  - **More cover variety** — currently 4 layouts (quad/diagonal/scatter/open) of same-color square
    blocks. Want: more layout patterns (corridors-of-cover, central bunker, asymmetric), varied
    block shapes (long walls/barricades, not just squares), maybe themed per room type. *(2026-05-29)*
  - **Door-aware cover (follow-up):** cover is quadrant-only to keep all door channels clear
    without knowing which open. Could defer cover to the generator's 2nd pass (post-open_exit) to
    allow center-cross cover that leaves only OPEN channels clear — richer layouts.
- **Slow health regen, CON-linked** — like the DCC books
  (https://dungeon-crawler-carl.fandom.com/wiki/Health). Out-of-combat HP slowly
  ticks back; rate scales with CON. Makes CON matter more and replaces the
  (now-removed) free full-heal at the stat terminal. *(2026-05-28)*

---

## Backlog

### Stats & combat
- **DEX → ranged accuracy / projectile spread** (second role beyond move speed).
- **CHA drives shop prices (planned stat tie-in)** — CHA already gives the Ratings/audience
  multiplier; when SHOPS land, CHA should also improve **buy/sell prices** (DCC: charm/haggle). The
  Scavenger passive "Extreme Coupons (-20% shop prices)" already assumes a shop price system to hook
  into. (STR = melee/knockback ✓, DEX = speed/accuracy/dodge ✓, CON = HP/DR/regen/potion-cd ✓,
  INT = mana/spell + planned detection, CHA = audience + planned shop prices — every stat now has a
  role or a planned one.) *(2026-06-02)*
- **Item depth (on top of the MVP)** — gear stat bonuses + consumables now work; still TODO:
  **equip slots** + drop/swap, **weapons-as-items** (folds in weapon-specific stats), and
  **affixes** (Burn/Bleed/Lightning/AOE/Leech/Slow). Also consider pausing while the inventory
  screen is open in combat.

### Loot & economy
- **Inventory UI + loot-box visibility** — show pending boxes + what you're holding.
- **Gold currency + shops** (the third rail). Potions + gold *inside* loot boxes.
- **World-drop pickups** — lootable basics outside boxes (enemy drops).
- **Real Boss Boxes** — Floor boss should drop better than Neighborhood; bespoke
  per-tier drops instead of every boss giving the same FATALITY tier-2 box.
- **`lifetime` achievements** — scope is wired but unused; define meta/collection
  milestones (floor depth, total kills, race/class unlocks).

### Testing
- **No persistent test harness** — validation is currently headless scene runs + throwaway
  test scenes (deleted after). New logic (XP curve, CHA mult, vitals-preserve, melee) was
  proven that way but nothing's checked in. Consider a small headless test runner (or GUT)
  so stat math has lasting coverage.

### Architecture / cleanup (from the 2026-05-28 review, deferred)
- **Invulnerability is a single shared bool** — dash i-frames (`set_invulnerable`) and post-hit
  i-frames (`HealthComponent._grant_iframes`) both write `_invuln`; a recent hit's timer can
  end a dash's i-frames early (and vice-versa). Use a refcount or separate dash flag.
- **Melee knockback teleports** (`e.global_position += shove`) — ignores walls; a big shove can
  clip an enemy through thin geometry (physics depenetrates next frame, but it's not clean).
  Route through the enemy's MovementComponent / a velocity impulse, or move_and_collide.
- **Run-lifecycle at one layer** — boot guard currently lives in `LevelGenerator._ready`
  (bandaid); consider a single entry point / `GameManager.ensure_run()`.
- **Prune stale persisted achievements** — old saves keep `first_blood`/`phase_finder`
  in `unlocked_achievements` from the pre-`scope` schema (harmless, but dead data).
- **Stat panel should pause / consume input** — player can move + fire while the
  Level-Up panel is open (low impact: safe room only).
- **Boss `xp_reward` two sources of truth** — `MeatGrinderGolem.tscn` (150) vs
  `LevelGenerator` tier dict (300/120, wins for bosses).
- **LevelUpPanel built in code** — could become a `.tscn` (deliberately code-built for
  headless-import safety; revisit only if it grows).

---

## Done
- **Item system MVP** — gear auto-equips (passive stat bonuses, per-item & removable),
  consumables → quick bar (key `1`), inventory screen (key `I`), HUD quick bar + weapon mode.
  *Deferred:* equip slots, drop/swap, weapons-as-items, affixes, pause-inventory-in-combat. *(2026-05-28)*
- XP → levels → skill points (Safe-Room stat terminal). *(2026-05-28)*
- Achievement scopes (run / repeatable / lifetime) + per-run loot drip. *(2026-05-28)*
- Aggro-on-damage; boss lunge; health bars; weapon-range cut. *(2026-05-28)*
