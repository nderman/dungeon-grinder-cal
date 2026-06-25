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

## Milestone Tokens

Reaching the milestone floors banks a **[Milestone Token](meta-progression.md)** —
**floors 3, 6, and 9**. These are your between-Seasons currency for the roster shop.

## The final floor (9)

Floor 9 has **no stairs down** — the only exit is **killing the Champion**, a ~2× Floor Boss (55 HP,
hits for 80, 75% stun-resist, enrages at half). Put it in the ground and you're **Season Champion**:
the run is won, you bank a Token + a big Syndication cut, and `seasons_won` ticks up (unlocking
[Nightmare](meta-progression.md#nightmare-mode) and [New Game+](meta-progression.md#prestige--new-game)).
