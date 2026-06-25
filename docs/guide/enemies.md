# Enemies

HP is in **hearts**; damage is the pre-DR hit you take. Deeper floors scale enemy HP **and** damage by
`×(1 + 0.35 × (floor−1))` — so a floor-9 mob hits ~2.8× as hard as its floor-1 cousin, before Nightmare/NG+.

## The roster

Spawns are weighted (the number in parentheses is its relative spawn weight):

| Enemy | HP | Threat | Notes |
|---|---|---|---|
| **Glitch Goblin** (50) | 2 | Melee lunge | The bread-and-butter trash. |
| **Syndicate Sniper** (20) | 2 | **Ranged** | Long 1.2 s tell — dodge the shot, then close. Slowest mob. |
| **Screamer** (22) | 2 | Fast melee | **Almost no telegraph** (0.05 s) and the fastest thing on the floor. Swarms. |
| **Brute** (14) | 5 | Telegraphed **swing** | Sidestep the arc (don't back straight up). **Chills** on hit. |
| **Shield-Bot Cleric** (8, floor 2+) | 3 | Support | Projects a **50% DR aura** to nearby allies. **Kill it first.** |
| **Healer** (7, floor 2+) | 4 | Support | **Heals** nearby allies ~0.8 HP/s. **Kill it first.** |

## Elites (Floor 3+)

Any mob can be upgraded to an **Elite** — gold-tinted, and a real threat:

- Chance scales with depth: `10% + 4%/floor`, **capped 40%**.
- **×2.5 HP**, **×1.35 damage**, ×1.4 size, **×2 XP & Ratings**, and gains stun-resistance (you can't Ground-Slam-lock them).
- **Always elemental** — they carry the floor theme (or a signature, or a random burn/chill) at elite strength.

Elites are the real difficulty knob deep — quality over quantity.

## Bosses

Each Floor Boss room rolls one of three **archetypes** (below). All bosses **enrage at ≤50% HP**
(faster, nastier, pops a DRAMA_SPIKE), resist stuns, and pay big XP/Ratings + a Boss loot box.

| Boss tier | HP | Damage | Stun resist | Where |
|---|---|---|---|---|
| Floor Boss | 28 | 64 | 60% | the floor's boss room |
| Neighborhood (mini) | 11 | 34 | 35% | scattered mini-arenas |
| **Champion** (final) | **55** | **80** | **75%** | Floor 9 only — **beating it wins the Season** |

*(All scaled further by floor depth, Nightmare, and NG+.)*

### Archetypes

- **Meat-Grinder Golem** — melee bruiser: lunges and swings (50/50), **burns** on hit. Enraged: faster, rushes harder.
- **The Hexgun** — artillery turret: telegraphed **radial bullet volleys** (rings & spinning spirals — no static safe gap, circle-strafe). Enraged: denser, faster volleys.
- **The Showrunner** — summoner: hangs back, potshots you, and **calls in waves of adds** (capped at its own 8). Enraged: bigger, faster waves. Fight through the swarm to reach it.
