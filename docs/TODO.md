# Dungeon Grinder Cal — TODO & Ideas

A scratchpad for random thoughts so they don't get lost. Newest ideas go under
**Inbox**; once triaged they move to **Backlog** (grouped) or get built and move to
**Done**. Ground-truth design still lives in `GDD.md`; this is the running queue.

---

## Inbox (raw, undated thoughts land here)

- **TELEMETRY + LIVE A/B EXPERIMENT — DONE (2026-06-12).** Vendored **PostHog** Godot addon
  (`addons/posthog/`, copied not submoduled so the public repo is self-contained). `Telemetry.gd`
  autoload rides `SignalBus`/`GameManager` and forwards run/floor/boss/death/level/loot/achievement
  events — pure listener, gameplay code stays unaware; **no-ops without an API key** so CI/clones send
  nothing. Key+host come from `POSTHOG_API_KEY`/`POSTHOG_HOST` env OR a gitignored repo-root `.env`
  loaded by the new `EnvConfig` autoload (Godot has no native `.env`). Opt-out via
  `MetaManager.analytics_enabled`; tests force `PostHog.test_mode` (no network). **Live experiment**
  "Boss HP tuning (+15%)" (PostHog id 83534, EU): flag `boss-hp-tuning` (`control`/`test`), `test`
  cohort fights +15%-HP bosses via `Telemetry.boss_hp_mult()` PUSHED one-way into `GameManager.boss_hp_mult`
  (LevelGenerator reads the plain field, never the analytics layer). Primary metric = boss kill rate;
  secondaries = bosses killed / floors descended per player. **Currently a DRAFT** — launch once
  there's play volume per variant (solo playtesting won't power the funnel). Follow-ups: launch +
  watch deaths-by-floor / class popularity; PostHog MCP is wired so balance audits can query events
  directly. See `PostHog.md` for the full spec.
- **MICHAEL BAY BOX FLOOD — FIXED (2026-06-12).** Telemetry caught it on day one: `michael_bay`
  ("Blew an enemy to chunks") minted **9 Silver Weapon Boxes on floor 3 in one session** — its trigger
  (`BOOM`, any bomb/AoE kill) trips on nearly every kill and the only brake was the shared 12s
  repeatable cooldown. Fix: demote **tier 1→0** (floor gate now only pays a box on floors 1-3, heckles
  past that) + new optional per-achievement **`cooldown`** field (default 12s) set to **45s** for
  michael_bay. The cooldown-override mechanism is reusable for any future AoE-spam feat. Regression
  test added. *(General lesson: the achievement→loot economy needs a per-feat trigger-frequency sanity
  check — a feat that fires on every kill can't carry the same cooldown as a skill feat.)*

- **WEAPON DPS vs PER-HIT — basic mobs bumped 1→2 HP (2026-06-17).** Player report: the Pipe Wrench
  one-shot everything while the higher-DPS Rusty Shiv took 2-3 hits. Not a bug — at STR 7 (Human) the
  shiv is 0.96/hit, the pipe 1.40/hit, and almost every basic mob had exactly 1.0 HP, so per-hit was
  the ONLY thing that mattered on trash and the shiv's speed/DPS edge was wasted (it sat a hair under
  the one-shot line). Fix: GlitchGoblin/Screamer/BaseEnemy 1→2 HP so kills take 2-3 hits and DPS reads.
  **WATCH:** Screamer is a fast, no-telegraph, ~22%-spawn swarm mob — at 2 HP a swarm may be brutal.
  If early game feels unfair, revert Screamer to 1 HP (or trim swarm size), keep Goblin at 2. Deeper
  idea: DPS is meaningless vs 1-HP enemies generally — fast weapons only shine on 2+ HP / bosses, so
  the weapon "feel" trade-off (fast vs heavy) only exists where enemies survive multiple hits.

- **NIGHTMARE MODE — v1 DONE (2026-06-12).** Unlocked after a win; Green Room toggle
  (`MetaManager.nightmare_enabled`, persisted) → `GameManager.nightmare` at run start → enemies deal
  `×1.6` damage (`nightmare_dmg_mult()`, applied in `_spawn_enemy`/`_spawn_boss`). Follow-ups: it
  should **reward more** (a harder mode with no extra loot/ratings is just pain — boost box tier /
  ratings / a Nightmare-only cosmetic), and could **scale with `seasons_won`** (Nightmare+1, +2…); a
  HUD badge while active would beat the floor-1 toast. Also a natural **token sink** if rewards gate
  behind it.
- **META DEAD-ENDS once the roster is unlocked — FIXED (2026-06-17), all 3 sinks shipped.** Player hit
  it at Season Champion (11 Tokens + 17955 Syndication, "nothing left to contract"). Built the full sink
  suite: (1) **Permanent stat injectors** — Syndication → permanent +1 stats (escalating per-stat cost,
  feeds `permanent_stat_buffs`); (2) **Loot sponsorship** — Tokens → favour a weapon in the Director's
  drop pool (wired the dead `permanent_loot_pool` into `_pick_base`, +6 weight); (3) **Prestige / NG+** —
  Tokens → unlock NG+ tiers that scale enemies harder (HP+dmg, stacks on Nightmare) AND rewards richer
  (ratings/XP ×, box tier +tier), gated behind a first win, selectable 0..unlocked. All in the Green Room
  shop, persisted, covered by `test_meta.gd`. Follow-ups: a stat-injector cap or diminishing returns if
  100+ stacking trivialises; NG+ could gate a Celestial-only weapon; sponsor armor/trinkets too (weapons-only now).
- **ENDGAME — DONE (2026-06-11).** Bounded run: `GameManager.FINAL_FLOOR=9`, no stairs down, kill the
  `FINAL_BOSS` (Champion, ~2× a Floor Boss) → `win_run()` → Green Room "Season Champion" screen +
  `MetaManager.seasons_won`. Follow-ups: a UNIQUE multi-phase final boss (currently a roster boss at
  Champion tier + its 50% enrage); guarantee a Boss room on the final floor (else only collapse-death).

- **BALANCE: defensive stacking → invulnerable — first pass applied 2026-06-12.** Gear **regen capped
  2.5/s** (`Player.GEAR_REGEN_CAP`), **resist cap 90%→60%** (`StatusEffect.RESIST_CAP`), **dodge cap
  50%→35%** (`ProtectionComponent.DODGE_CAP`), **enemy dmg/depth 0.25→0.35** (`GameManager.FLOOR_DMG_PER_DEPTH`).
  Also weapon scaling fixed (STR/DEX/INT) so ranged/INT no longer dominates. PLAYTEST, then tune
  further if still off; possible follow-up: diminishing returns on stacked defense across slots.

- **WEAPON DAMAGE AFFIXES (DPS feels low on high-rarity weapons)** — rarity only adds effect/stat
  affixes, NOT base damage, so an Epic Broadsword hits exactly as hard as a Common one (player saw
  "Epic 2.4 dmg / 4.0 DPS" and expected more). Let Rare+ weapons roll a **damage/range multiplier**
  affix (the deferred LootData idea). Also: the inventory DPS number excludes crit/chain/burn — fold
  at least **crit** (a clean ×(1+crit) multiplier) into the displayed effective DPS. *(2026-06-11)*
- **BOSS ALWAYS-LOCK (ideal) — partial: safety-net shipped 2026-06-11.** Shipped: a boss arena only
  SEALS if its room is a true dead-end (degree-1 leaf, no stray corridor) — otherwise it wakes on
  approach but doesn't trap you (`_arm_boss_lock` sealable flag). This removes the "forced fight to
  explore" bug. The boss already PREFERS a clean off-path leaf, so it locks in the common case; the
  open fallback only fires when EVERY dead-end is crossed by a corridor (rare). **User's preferred
  ideal: it should ALWAYS lock + never spawn on the main path.** To guarantee that, RESERVE the boss
  leaf BEFORE carving corridors (reorder so `_carve` treats the boss room as a no-cross zone), so a
  clean dead-end always exists. Bigger level-gen reorder — deferred. *(2026-06-11)*

- **REGRESSION-TEST SUITE — DONE (2026-06-11).** `game-client/tests/` + `./tests/run_tests.sh` (one
  headless process, autoloads load once, exits non-zero on failure). `TestCase` base + `TestStubs`
  (PlayerStub etc.) + `TestRunner`. Seeded 8 ported tests: loot_boxes, loot_affixes, combat_effects,
  elemental, floor_themes, boss_seal, crash_teardown (the get_tree()-null regression), holy_shield.
  Run it as the `/shipit` test step. Follow-ups: add tests as features land; consider wiring into CI.
- **LOOT BOX OPENING PRESENTATION — reveal screen DONE (2026-06-18).** `ui/LootRevealPanel.gd`
  (ModalPanel): the Safe-Room terminal now plays a reveal — boxes pop in one at a time low→high,
  rarity-coloured with ✨/🌟 markers, E/SPACE fast-forwards then closes. `open_all_boxes` returns the
  sorted haul ([{box,item,rarity,tier}]) for it. Covered by `test_loot_reveal.gd`. **Still TODO (art
  pass):** distinct box VISUALS per tier/type (Bronze vs Celestial, a glowy Boss box, a Fan gift box)
  + an actual open animation/particles — deferred with the rest of the gray-box → sprites work.
- **ELEMENTAL ATTACKS + RESIST GEAR + FLOOR THEMES — DONE (2026-06-10).** Enemies inflict statuses
  back via `AIComponent.on_hit_effect` ("burn"/"chill") at `_hit_target`; `StatusEffect` now works on
  the player (chill drives `Player.speed_mult`, burn ticks apply_dot) and is mitigated by
  `Player.elemental_resist()`. Resist affixes **Fire Resist (Flameproof)** / **Frost Resist (Frostward)**
  shorten+weaken the matching status. Floors 3+ roll an **Inferno/Cryo** theme (`LevelGenerator.floor_element`)
  → a share of mobs + ALL elites go elemental, banner announces the hazard. Golem=burn, Brute=chill
  signatures. Bonus: **"Stop, Drop & Roll"** achievement (survive a burn, via a "DOUSED" spike).
  - Follow-ups: nicer floor-intro **banner** (currently a toast); **ranged** elemental enemies (arm the
    projectile with the effect — only melee `_hit_target` carries it today); an at-a-glance **tint** on
    themed mobs so the hazard reads before they hit you.
- **Boss enrage/defeat boilerplate is 3x now — DONE (2026-06-17).** `components/BossPhaseComponent.gd`:
  watches the sibling HealthComponent, emits `enraged` once at `enrage_threshold` (+ DRAMA_SPIKE) and
  fires FATALITY + a per-boss `defeat_toast` on death. A COMPONENT, not a base class. Golem/Hexgun/
  Showrunner each create it in `_ready`, set the toast, and connect `enraged` to their own escalation;
  a 4th boss just drops it in. Covered by `test_boss_phase.gd`. *(flagged 2026-06-07)*
- **ACHIEVEMENT VARIETY — batch 1 DONE (2026-06-08).** Pattern: emit a `ratings_spike` type at the
  mechanic site, map it in `AchievementManager`. Shipped 11: Pyromaniac (IGNITE), Michael Bay Approved
  (BOOM), Chain Reaction (CHAIN_KILL), Grave Robber, Tapped Out (`mana_depleted`), Cancelled
  (`end_run`'s CANCELLED), + 5 stat milestones at 20 (STR title is race-adaptive via `title_override`).
  - **Batch 2 (the 🔧 ones that need new plumbing):**
    - **"Knife to a Gun Fight"** — melee-kill a RANGED enemy. Needs kill context: thread killer-weapon
      type + victim archetype through the kill (`enemy_cancelled` carries neither today).
    - **Boss trophies** — per-boss defeat (Golem/Hexgun/Showrunner): give each `_on_defeated` its own
      spike type, or a `boss_defeated(id)` signal.
    - **"Flawless Victory"** — kill a boss taking zero damage (track player hits during the locked arena).
    - **"Stop, Drop & Roll"** — get set on fire (needs a fire source vs the PLAYER — a fire-enemy/hazard).
    - **"Leech Lord"** — heal a cumulative threshold via Leech (needs a per-run counter, reset on `run_started`).
  - Optional polish: give the spectacle spikes (IGNITE/BOOM/…) a small `SPIKE_TABLE` audience ratings
    pop — currently trigger-only (the achievement toast is the only feedback). On-theme for the show.

- **MULTIPLE FINAL BOSSES for replayability** (lower priority — endgame isn't built yet) — once the
  bounded-run/final-boss arc exists (see endgame TODO), have >1 climactic final boss rolled per run
  (the Showrunner? the System? a celebrity guest?), each with its own arena + phases, so the ending
  isn't identical every Season. Reuses the new boss-roster pattern (`_pick_boss_scene`), just gated
  to the final floor with a dedicated final-boss pool. *(2026-06-04)*
- **REFACTOR: extract `Combat.deal(victim, raw_dmg)` helper — DONE (2026-06-17).** `components/Combat.gd`:
  one static chokepoint routing raw damage through the victim's DR into its HealthComponent, returning
  the HP actually removed. Wired into all 6 sites (CombatEffects._chain, Player nova + melee, Bomb._hit,
  HitboxComponent, AIComponent._hit_target). Bonus: leech/chain/hit_landed now read the REAL HP removed
  (capped on overkill) instead of uncapped post-DR. Covered by `test_combat.gd`. *(flagged 2026-06-03)*
- **ITEMS NEED EFFECTS — v1 BUILT (2026-06-03).** Rare+ gear now rolls EFFECT affixes (not just
  flat stats): **Burn** (fire DoT), **Leech** (heal on hit), **Crit** (chance to double), **Chill**
  (slow), **Chain** (arc damage to a 2nd enemy). Summed across ALL equipped slots
  (`LootData.combat_effects`) and applied on every weapon hit (melee + ranged) via `CombatEffects`;
  timed statuses live in `StatusEffect` (burn ticks DoT, chill drops `AIComponent.speed_mult`). Item
  names get an adjective ("Savage War Hammer", "Burning Ring") and the inventory desc lists the
  effects. Rare always gets ≥1 effect; Epic/Legendary stack more.
  - **DEFENSIVE affixes — DONE (2026-06-04).** Armour rolls **Armor** (flat DR%, finally wires the
    dead `gear_dr`), **Regen** (bonus HP/s), **Dodge** (+% full-dodge); folded into vitals in
    `_derive_vitals`. Slot routing: Weapon→offense, armour→defense, jewellery→either (`_effect_pool_for_slot`).
  - **Inventory EFFECTIVE damage/DPS — DONE (2026-06-04).** Weapon cards show stat-scaled dmg + DPS
    (`effective_weapon_damage`/`_dps`); dmg-scaling consts moved to LootData as single source.
  - Still deferred: effects only proc on WEAPON hits, not spells (decide if leech/crit should feed
    casts); **thorns** (needs attacker ref at the hit site); weapons rolling **damage/range modifiers**;
    **proc-on-kill** mini-explosion (reuse Bomb); balance pass once playtested.

- **Stun doesn't interrupt a committed enemy attack** — both the lunge loop and the new swing
  coroutine keep running through a `stun()` (short windows ~0.18s so low impact). If we want stun to
  feel weightier, add `if is_stunned(): return` inside the swing/lunge loops to cancel mid-attack. *(2026-06-03)*

- **EXPLOSION PRIMITIVE → mines / grenades / exploding enemies / traps** — the new `Bomb` (fuse →
  AoE blast, hits enemies + optionally the player, art-free draw) is a reusable primitive. Spin-offs:
  (a) **Exploding enemy** — a mob that detonates a Bomb-blast on death (or on reaching you), forcing
  spacing; (b) **Grenade** consumable/ability variants (different fuse/radius/damage); (c) **Mines** —
  proximity-armed (no fuse; trigger on enemy/player enter via an Area2D) — player-placed OR enemy
  hazard; (d) **Traps** (GDD §7: Data-Spike Landmines, Disintegrator Beams, Automated Turrets) — level
  hazards reusing the blast. Generalize Bomb into a shared "detonate(pos,damage,radius,mask)" helper so
  all of these share one explosion. *(2026-06-03)*

- **ENEMY MELEE SWINGS (weapon attacks) — variety** — some (not all) melee enemies should SWING a
  weapon in a telegraphed arc instead of the current lunge-and-touch. Different counterplay (sidestep
  the arc vs back away), more readable + menacing, and a great boss-move. Implementation: add an attack
  TYPE to `AIComponent` ("lunge" | "swing" | "ranged"); the "swing" path telegraphs then does an arc
  hit-check in front (mirror the player's `_melee_tick`: range + arc dot, through DR) + a `MeleeSwing`-
  style slash VFX for enemies. Reuses existing melee-arc tech. Pairs with anti-kite (a swinging brute
  with reach + sprint punishes kiters) and gives bosses a real weapon attack. *(2026-06-03)*

- **WEAPONS + HEALER ENEMY (done 2026-06-03)** —
  - Loot no longer drops the 4 STARTER_WEAPONS (`_pick_base` skips them). Added exciting finds:
    Broadsword, Nunchucks (fast/wide), Crossbow (accurate), Katana (reach), War Hammer (knockback),
    rolling from tier 2-3 boxes.
  - **Healer** enemy (floor 2+): generalized `AuraComponent` to a `heal_per_tick` mode (reuses the
    Cleric's tick/range/ring) — heals nearby allies (~2.7 HP/s), not itself, green ring. Kill-the-medic
    dynamic. (Cleric scene now sets `aura_dr=50` explicitly since the default went to 0.) Also guarded
    `HealthComponent.heal()` against reviving a 0-HP corpse, matching the other HP mutators.

- **HOTBAR (done 2026-06-03)** — replaced the FIFO quick bar with a 4-slot assignable hotbar (keys
  1-4). Each slot holds a consumable (stacked by base+tier with ×count) or an ability. Consumables
  auto-slot on pickup, abilities auto-slot on learn → class ability + tome both bound & usable, and
  you can press the key for the SPECIFIC potion you want. Q still casts the K-panel-selected ability.
  `GameManager.hotbar` + `use_slot()` + `hotbar_slot_label()` (shared by HUD + inventory).
  **Still TODO**: manual rearrange (drag/assign), maybe >4 slots, overflow handling beyond drop.

- **RANGED ENEMIES: HOLD FIRE WITH NO LoS (quick AI fix)** — they currently telegraph then fire even
  if you've ducked behind cover, wasting the shot into a wall. Re-check `_has_los(target)` at the
  moment of firing (`_execute_attack`/`_fire_projectile`); if blocked, cancel the shot (back to CHASE)
  instead of shooting the wall. Small `AIComponent` change. *(2026-06-03)*
- **ANTI-KITE / RANGED-PLAYER CHALLENGE** — high-DEX move speed (300 + DEX×12.5) lets you outrun ALL
  enemies and bosses and kite freely. Counters to add: (a) more **fast swarmy** mobs (small, quick, low
  HP — extend Screamers / a new flanker), (b) a **boss SPRINT/charge** ability (periodic dash to close
  distance on a kiter), (c) **bosses with ranged/projectile attacks** so they can punish kiting (boss
  "weapons"), (d) maybe curve DEX→speed (diminishing) so speed isn't unbounded. Pairs with enemy-variety
  arc. *(2026-06-03)*

- **HOLY SHIELD → real timed buff + active indicator** — currently `holy_shield` is just an instant
  self-heal (no "active" state to show). Redesign it into an actual shield: a temporary buff (brief
  +DR / damage absorb / partial invuln) for a few seconds, with a **golden outline on the player**
  while it's active so you can see it's up. (First held-buff ability — sets the pattern for buff VFX +
  a player buff-state.) *(2026-06-03)*

- **HOTBAR = unified assignable slots (TOP PRIORITY)** — replace the FIFO quick bar with numbered
  slots (1-4) the player ASSIGNS: a slot can hold a **consumable, a spell, OR a skill**. Solves
  multiple live complaints: (a) can't choose which potion to use (FIFO), (b) tome + class ability —
  want BOTH usable / switchable without the K-panel dance, (c) spells/skills slotted alongside items.
  Press the slot key to use/cast it. Keep the Abilities panel (K) for *learning/inspecting*; the
  hotbar is for *using*. *(2026-06-03)*
- **INVENTORY: show EFFECTIVE weapon damage (DONE 2026-06-04)** — weapon cards now show stat-scaled
  per-hit dmg + DPS (`effective_weapon_damage`/`effective_weapon_dps`), so Pipe Wrench vs Bone Cleaver
  is a clear comparison. Scaling consts (MELEE_DMG_PER_STR etc.) moved Player→LootData (single source).

- **EARLY-GAME VARIETY + BOSS-NAV + UNBLOCKS (done 2026-06-03)** —
  - **Boss stuck — real cause fixed**: boss navmesh clearance was 40px but the Floor Boss body is
    ~67px (golem ×1.45), so it routed through gaps too tight for itself. Bumped to **74px**.
  - **Tome unblock**: tomes now **auto-learn on pickup** (`add_consumable` learns + toasts, doesn't
    queue) — no more drinking your potions to reach the tome.
  - **Random starter weapon** (shiv/kitchen_knife/scrap_club/pop_pistol — `STARTER_WEAPONS`) +
    **random starting race** from unlocked (changeable Floor 3).
  - **Fireball** big + orange (`proj_scale`/`proj_color` on GlitchBolt.setup); **mana regen** 5→1.8/s.
  - **HUD**: fixed bottom-left overlap (potion/ability rows collided with Weapon label); added a
    **race·class indicator** (top-left); potion warning relabeled "Potion cooldown … (drink = Poison)".

- **RUN-START INTRO SCREEN ("Welcome to the dungeon")** — a System-announcer card on run start that
  surfaces the random setup we now roll: *"Welcome to the dungeon. Floor 1. **Cat**. You found a
  **Kitchen Knife** on the way in… now KILL! KILL! KILL!"* Shows race + starter weapon + **starting
  stats** (STR/DEX/INT/CON/CHA) + race ability (below), (+ later class reveal on Floor 3) in Cal/System
  voice. Makes the random race/weapon feel INTENTIONAL and mostly replaces the need for the race HUD
  label. Pairs with the boss-intro card + flavour pass; reuse the ModalPanel base. Tap/space to drop
  in. *(2026-06-03)*

- **RACE ABILITIES / PASSIVES** — races currently grant only stat bonuses; their `passive` field is
  flavour text only (unimplemented). Give each race a real perk — either implement the existing
  passives (Ogre "Ponderous Might" 100% knockback/-20% speed, Cat "Hiss-stun" + faster Hype, Trollkin
  regen after 10s safe, AeroWraith dash-through-walls/ignore-hazards) AND/OR a granted **racial
  ability** (an AbilityLibrary id, like the class starter — `RaceData.get_starter_ability`). Makes the
  random starting race matter beyond numbers + feeds the intro screen. *(2026-06-03)*

- **ENDGAME / FINAL BOSS + WIN STATE (design, not now)** — the run currently descends forever
  (collapse clock + permadeath, a floor-boss each level); there's no climax or "you won." Need a
  defined ending. Seeds:
  - A **bounded run** to a final floor (e.g. floor 9 or 12 — ties to our milestone-token floors 3/6/9),
    instead of infinite descent. Or keep endless but a fightable **true-ending mega-boss** at a
    milestone you choose to challenge.
  - A unique **climactic arena + multi-phase final boss** (the Showrunner? the System itself?), with the
    dramatic boss-intro card (already logged), an audience-climax ratings spike, distinct music/visced.
  - **Win screen / "Season Champion"**: run summary, a big one-time reward, prestige unlock; maybe
    **NG+** (harder loop, new modifiers) so winning opens a new layer rather than just ending.
  - Make it FEEL earned (DCC tone): the System's grudging respect, the audience going wild, a
    Celestial-tier box, etc. Pairs with the achievement/flavour voice pass.  *(2026-06-03)*

- **ART PASS — pixel-art sprites/tileset** — replace the code-built `Polygon2D` placeholders with
  real 16×16 pixel art. Candidate pack: https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites
  Scope: (1) entities — swap each `Polygon2D` for `Sprite2D`/`AnimatedSprite2D` (visual is isolated
  per-scene, so no logic changes; player/goblin/screamer/sniper/cleric/golem/corpse/doors). (2) floors
  + walls — tiled texture (`TileMapLayer` or textured polys) over the code-built room rects instead of
  flat colours. (3) the recent color-coding (red/magenta/green/etc.) becomes distinct *sprites*.
  ⚠️ **Check the pack's LICENSE** (attribution / CC0) before shipping art. Big visual jump; do after
  the gameplay systems settle. *(2026-06-02)*

- **ELITES + PROGRESSION + POLISH (done 2026-06-02)** —
  - **Elite-upgrade system**: floor 3+, scaling chance (10% +4%/floor, cap 40%) upgrades ANY mob to an
    Elite — ×1.4 size, ×2.5 HP, ×1.35 dmg, stun-resist ≥0.3 (can't Ground-Slam-lock), gold glow, 2×
    XP/gold. Difficulty via quality not inflation → dialed depth scaling back 0.35→**0.25** and reverted
    the mob-count bump.
  - **Exponential XP**: `xp_to_next = 80 × 1.4^(lvl-1)` (was linear) — grindier deep. And mob/boss
    `xp_reward × floor_mult` so tougher/deeper kills (+ elites ×2) pay more — the steeper curve is
    funded by hunting big threats.
  - **Boss gold fix**: bosses now set `ratings` (Floor 240 / Neighborhood 90) → corpse gold ~60/~22
    (was ~3) + the audience jackpot.
  - **Stairs/phase doors no longer spawn in passages**: `_wall_anchor` anchors to the middle of a
    solid wall span (≥140px), never the wall centre where corridors attach. (30/30 doors clean over 6
    floors.)
  - **Enemy recolor** for readability: player's cyan is now unique (Sniper→magenta, Cleric→silver-gold).
  - **Quickbar stacking**: HUD shows "Health Potion ×7" not a wall of repeats. (Real fix = the
    player-assigned hotbar, NEXT arc — indexed slots 1-4, pick what goes where, replace FIFO.)

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
- **Invulnerability is a single shared bool — DONE (2026-06-17).** Split into `_held_invuln` (dash +
  boss dormancy, via `set_invulnerable`) and a timed `_hit_invuln_until` window (player post-hit);
  `is_invulnerable()` ORs them, so neither can cancel the other. Also dropped the `_grant_iframes`
  await coroutine for an expiry timestamp. Covered by `test_combat.gd`.
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
