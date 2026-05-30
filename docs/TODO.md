# Dungeon Grinder Cal — TODO & Ideas

A scratchpad for random thoughts so they don't get lost. Newest ideas go under
**Inbox**; once triaged they move to **Backlog** (grouped) or get built and move to
**Done**. Ground-truth design still lives in `GDD.md`; this is the running queue.

---

## Inbox (raw, undated thoughts land here)

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

- **Minimap with fog-of-war** — corner minimap of the floor; rooms reveal as you explore. **FOW
  reveal range scales with INT** (smart contestants see more) — gives INT a third role beyond
  mana/spell dmg. Pairs with the BSP floor layout. *(2026-05-29)*
- **Bosses drop map info** — killing a boss reveals part/all of the floor map (clears fog around
  it / reveals the stairs / marks loot). A reward beyond loot + a reason to hunt Neighborhood
  bosses. Depends on the minimap/FOW system. *(2026-05-29)*

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
