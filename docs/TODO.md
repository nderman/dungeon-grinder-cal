# Dungeon Grinder Cal — TODO & Ideas

A scratchpad for random thoughts so they don't get lost. Newest ideas go under
**Inbox**; once triaged they move to **Backlog** (grouped) or get built and move to
**Done**. Ground-truth design still lives in `GDD.md`; this is the running queue.

---

## Inbox (raw, undated thoughts land here)

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
- **Wire up STR + CHA** — currently dead (only race/class bonuses + loot tags read them).
  STR: melee / knockback / carry? CHA: loot luck / charm lesser bosses / shop prices?
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
