# Floors & Stairs

A Season is **9 floors**. Each floor runs on a **two-stage clock** (seconds since you arrived):

| Stage | When | What happens |
|---|---|---|
| **Stairs open** | 120 s elapsed **OR** the Floor Boss dies (whichever first) | You can now descend. |
| **Collapse** | 300 s elapsed | The floor starts killing you: **20 HP every 0.5 s** (= 40 HP/s), ignoring armor & i-frames. Leave. |

So there are two ways down: **rush the Floor Boss** for its XP/loot and the stairs it opens, or **wait
out the 2-minute timer** and skip the boss (forfeiting its rewards). Either way, don't still be on the
floor at 5 minutes.

## Descending & the boss room

Stairs sit in the **boss room**, hidden until they open. Boss arenas **seal** when entered (a real
dead-end fight) so you commit to it — though a boss won't trap you if its room is just a through-corridor.

Enemy HP and damage scale with depth: `×(1 + 0.35 × (floor−1))`.

## Safe Rooms (Phase-Doors)

Scattered on each floor are **Phase-Doors** — step on one and press **`E`** to drop into an off-grid
**Safe Room**, then take the portal back. The Safe Room is where you:

- **Open your Loot Boxes** (the reveal — see [Loot](loot.md#opening-boxes-the-reveal)).
- **Spend banked level-up points** on stats at the terminal.

## Towns & vendors

On **town floors (2, 4, 6, 8)**, your Phase-Door drops you into a **Settlement** instead of a bare Safe
Room — a safe, populated hub. Same loot-box + stat terminals, plus **non-combatant NPCs**: a **Vendor**
you walk up to (`E`) to spend **Gold** on gear and potions, and townsfolk with the odd warning. Stock is
rolled fresh per town (build-aware — it leans toward your top stat) and scales with depth, so deeper
towns sell better kit. Gold comes from corpses; this is what it's *for*. A **Scavenger** pays 20% less
(Extreme Coupons). Floors 1 and 9 have no town — the tutorial and the Champion are all business.

## Milestone Tokens

Reaching the milestone floors banks a **[Milestone Token](meta-progression.md)** —
**floors 3, 6, and 9**. These are your between-Seasons currency for the roster shop.

## The final floor (9)

Floor 9 has **no stairs down** — the only exit is **killing the Champion**, a ~2× Floor Boss (55 HP,
hits for 80, 75% stun-resist, enrages at half).

> ⏳ **The clock still runs — but longer.** Floor 9 collapses at **8 minutes** (vs 5 on the floors below):
> there's nowhere to flee, so it's the boss fight, not a dawdle-check. The HUD shows a **FINISH IN m:ss**
> countdown, a banner warns you ~30 s out, then the arena crushes you (un-dodgeable). 8 minutes is enough
> to grind the Champion down even under-geared — but you still can't kite it forever. Race the building.

Put it in the ground and you're **Season Champion**:
the run is won, you bank a Token + a big Syndication cut, and `seasons_won` ticks up (unlocking
[Nightmare](meta-progression.md#nightmare-mode) and [New Game+](meta-progression.md#prestige--new-game)).
