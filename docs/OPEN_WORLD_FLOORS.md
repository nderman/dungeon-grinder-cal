# Open-World Floors — Design & Phased Plan

Status: **PLAN ONLY (no code yet)** · Author: Cal + NDerman · 2026-06-25

This is the design + build plan for evolving the dungeon from bounded, single-screen-ish floors toward
the **Dungeon-Crawler-Carl "open floor" feel**: sprawling, explorable, per-floor structural identity,
**settlement** towns dotted across them, scattered wild safe rooms, and **boss-gated progression**.

> **The big reframe:** we are NOT building literal book-scale, streamed, Iceland-sized floors. We're
> chasing the *feel* by **evolving the existing generator** within a bounded world. True streaming /
> persistence is a large, separate rewrite (Phase 4) we only take on if bounded floors can't get big
> enough at acceptable performance. Everything before Phase 4 reuses the current architecture.

---

## 1. Where we are today (the real architecture)

(See the floor-gen map in the session notes for file:line detail.)

- **Bounded floor:** BSP split of `WORLD = 5200×3800` → leaf rooms, MST corridors, walls auto-detected by
  edge-sampling, **one floor-wide navmesh** (+ a wider boss navmesh). Max ~32 rooms (BSP depth ≤ 5).
- **Everything spawns at floor load** (`_populate()` in `_ready()`); no streaming/culling.
- **Descend = full scene reload** (`change_scene_to_file(Floor.tscn)`), regenerating a fresh floor. No
  cross-floor world persistence.
- **Room types:** Spawn · Combat · Boss · MiniBoss · PhaseDoor · Safe. Boss arenas **lock + seal** when
  entered (barriers on `SEAL_LAYER`); boss death frees them and **opens the stairs**.
- **Floor clock:** stairs auto-open at 120 s (skip-boss) OR on floor-boss death; floor **collapses**
  (lethal) at 300 s (480 s on Floor 9). Stairs are Area2Ds scattered in Combat rooms.
- **Settlements (current stopgap):** on town floors (2/4/6/8) the Phase-Door leads to an **off-grid sealed
  box** with a vendor — i.e. *a safe-room-shaped shopfront*. **Hierarchy is inverted vs DCC** (see below).

**What scales fine** (floor-agnostic, reuse as-is): enemy pool + weights, floor/elite/NG+/Nightmare
scaling, elemental themes, corpse/loot economy, ratings/XP, inventory/hotbar, the boss roster + seal, the
vendor economy.

**Hardcoded assumptions that gate "open world":** single `WORLD` rect · all entities loaded at once ·
floor-wide navmesh · scene-reload-per-descent · safe room as an off-grid teleport box · one floor "look".

---

## 2. Target model (DCC structure, scoped to us)

Grounded in the floors 1–6 + Settlement wiki read (recorded in `TODO.md`):

- **Floor** = a larger, sprawling **bounded** space with a **per-floor structural theme** (ruins / warren /
  flooded / etc.) — distinct layout + palette, not one generic maze.
- **Settlement** = a safe **district ON the floor** you *walk into* (not a teleport box): a cluster of
  **vendor + NPC + service** buildings, **with an in-town Safe-Room portal** (the "inn"). **NOT inherently
  enemy-proof** — monsters can follow you in; guards *would* fight them (deferred). The only truly safe
  space is the instanced Safe Room itself.
- **Wild Safe Rooms** = the existing personal off-grid box, reached via portals **scattered out in the
  wild** between settlements. Keep this.
- **Progression** = some floors are **boss-gated** (stairs only open by killing the floor boss — the F5
  "conquer the castle to proceed" model, which is canon).

Correct hierarchy: **Floor ⊃ Settlement (contains an in-town Safe Room) + scattered wild Safe-Room portals.**

---

## 3. Phased build (each phase ships + tests independently; ordered risk-low → high)

### Phase 0 — Settlement ON the floor *(fixes the inverted hierarchy; highest value / lowest risk)*
Turn the settlement from an off-grid box into a real district in the level.
- Add a **`Settlement` room type** the generator designates like Boss/Spawn (e.g. a roomy leaf, or
  guaranteed on town floors), built in-world.
- Mark that room **low-/no-spawn** (`_populate` skips combat spawns there) — *not* a hard seal, so a mob
  you drag in can still wander in (matches "not inherently safe"; keep it simple, no guard AI yet).
- Place inside it: the **Vendor NPC** + flavour NPCs (already built) **+ an in-town Safe-Room portal** (the
  existing Teleporter → off-grid personal Safe Room). The bare Safe Room stays for non-settlement floors.
- **Outcome:** you walk into the town on the floor; the safe room is the private box you portal into *from*
  the town. Correct DCC hierarchy, ~no new tech — reuses room types, NPCs, the teleporter, the shop.
- **Risk:** low. **This single phase delivers most of the DCC "town" feel without any open-world gen.**

### Phase 1 — Bigger, more sprawling floors
- Parameterize `WORLD`, BSP `MAX_DEPTH`, and room density as a **per-floor "scale"** that can grow with
  depth (deeper = bigger, more rooms).
- **Performance is the gate** (see Risks): everything loads at once + floor-wide navmesh, so **measure FPS
  on the web build** and cap total rooms/enemies/nodes. Bounded growth only.
- Camera: confirm follow + pick a sensible zoom; a **minimap** becomes worthwhile here (later sub-task).
- **Risk:** medium — purely perf. Find the ceiling before committing.

### Phase 2 — Per-floor structural themes
- A **floor-theme table**: each floor (or range) picks a structural + visual variant that modulates the
  generator (room density/size, corridor width, cover style) + palette, layered on the existing elemental
  theme. Start with 2–3 (e.g. *Ruins*: sparse, wide gaps; *Warren*: dense maze; *Flooded*: chokepoints).
- **Risk:** low–medium — mostly generator params + theming, no architecture change.

### Phase 3 — Boss-gated progression (the F5 model)
- A floor flag where **stairs only open on floor-boss death** (no 120 s timer-skip, no scattered Combat
  stairs — only the boss-room exit).
- **Must co-design with the floor clock:** a gated floor needs enough time to traverse + fight → likely a
  longer (or boss-scaled) collapse window, like Floor 9 already has.
- **Risk:** low — small change to stairs placement + `open_stairs`/clock logic. Mostly a timing-balance call.

### Phase 4 — True open-world tech *(DEFERRED — only if Phases 1–3 hit the perf wall)*
Streaming zones, distance-based spawn/despawn, zone-local navmeshes, no-scene-reload persistence. This is
the large rewrite the map flags (the scene-reload-on-descend seam is the main coupling point). **Do not
start this unless bounded floors provably can't get big enough.**

---

## 4. How existing systems migrate

| System | Migration |
|---|---|
| Vendor / shop economy | Moves into the Phase-0 on-floor Settlement; ports **unchanged** (only placement changes). |
| Safe Room | Two flavours: **in-town** (inside the Settlement, Phase 0) + **wild** scattered portals (keep current off-grid box). |
| Boss lock / seal | Unchanged — works in any room. Phasing-Flight seal-proofing already shipped. |
| Floor clock | **Revisit per floor type** — bigger / boss-gated floors likely need a longer or size-scaled collapse window (see open questions). |
| Descend (scene reload) | **Keep** through Phases 0–3 (no persistence needed). Only Phase 4 touches it. |
| Navmesh | Floor-wide is fine while bounded (Phase 1 perf permitting); zone-local meshes are a Phase-4 concern. |

---

## 5. Risks & open questions

1. **Performance is the #1 constraint.** Everything-loaded + floor-wide navmesh on a **single-threaded web
   build** → bigger floors cost FPS linearly. *Measure before scaling.* This is what gates how "open"
   floors can get without Phase 4.
2. **What does the collapse clock mean on a sprawling floor?** "Leave in 5 minutes" fights "explore a big
   floor." Options: scale `COLLAPSE_TIME` with floor size; make it a generous deep-exploration timer; or
   only collapse-pressure the boss-gated floors. **Needs a design call in Phase 1/3.**
3. **Visibility / camera.** A big floor fully on-screen looks bad; needs a sensible zoom and probably a
   **minimap**. No fog-of-war planned (single-threaded web; keep it cheap).
4. **Settlement safety.** Monsters can follow you in (per NDerman). Phase 0 keeps it a simple low-spawn
   region; **guard-vs-monster combat AI is deferred** (don't over-complicate v1).
5. **Navmesh bake cost** at load grows with floor size (one-time, but a hitch risk on web — relates to the
   threads discussion: a big synchronous bake is exactly the kind of frame-hitch we'd amortize, not thread).

## 6. Explicit non-goals (v1)
Streaming/persistence (Phase 4 only if forced) · guard combat AI · hostile towns · mayor-kill governance ·
settlement size tiers · literal book-scale floors · fog-of-war.

## 7. Recommended starting point
**Phase 0 (Settlement on the floor).** It's small, corrects the hierarchy you flagged, reuses the entire
shop/NPC/safe-room stack, and delivers the town feel immediately — *without* committing to the floor-gen
scale-up. Then **measure perf headroom (Phase 1)** before deciding how big floors can actually get.
