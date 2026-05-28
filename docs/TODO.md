# Dungeon Grinder Cal — TODO & Ideas

A scratchpad for random thoughts so they don't get lost. Newest ideas go under
**Inbox**; once triaged they move to **Backlog** (grouped) or get built and move to
**Done**. Ground-truth design still lives in `GDD.md`; this is the running queue.

---

## Inbox (raw, undated thoughts land here)

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
- **Inventory + quick bar** — for items/weapons/potions. Quick bar = the at-a-glance row
  of equipped weapons + consumables; should also surface the **active weapon mode**
  (RANGED/MELEE — currently only a transient toast on swap) and bind quick-use slots.
  Inventory = full holdings screen. *(2026-05-28)*
- **Make rooms more interesting** — environmental hazards (the Bestiary hazards:
  spikes, gas, etc.), destructible/static **cover** to break line-of-sight, and
  **varied room sizes & shapes** (current rooms are all one 768px square). Procedural
  room templates instead of one parametric box. *(2026-05-28)*
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
- **Make loot items apply real effects** — items are currently just names in
  `run_inventory`; affixes (Burn/Bleed/Lightning/AOE/Leech/Slow) are unimplemented.

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
- XP → levels → skill points (Safe-Room stat terminal). *(2026-05-28)*
- Achievement scopes (run / repeatable / lifetime) + per-run loot drip. *(2026-05-28)*
- Aggro-on-damage; boss lunge; health bars; weapon-range cut. *(2026-05-28)*
