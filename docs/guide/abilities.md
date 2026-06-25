# Abilities

Active abilities come in two flavours: **Spells** (cost mana) and **Skills** (no mana, cooldown only).
You learn them from your class starter and from **Tomes** found mid-run, and they **level up by use**.

## The roster

| Ability | Kind | Scales | Mana | Cooldown | Effect |
|---|---|---|---|---|---|
| Glitch Bolt | Spell | INT | 5 | 0.25 s | Rapid projectile (0.6 base) |
| Fireball | Spell | INT | 20 | 0.6 s | Fat heat bolt (1.4 base) |
| Null-G Singularity | Spell | INT | 30 | 4.0 s | Nova that crushes nearby mobs (1.6, 200 px) |
| Ground Slam | Skill | STR | — | 3.0 s | Nova: damage + **1.5 s stun** (0.65, 170 px) |
| Holy Shield | Skill | CON | — | 8.0 s | Burst heal **+40% DR for 5 s** (golden glow) |
| Blink | Skill | DEX | — | 2.5 s | Phase ~260 px toward your aim |
| Scrap Bomb | Skill | DEX | — | 4.5 s | Drop a delayed AoE charge — **friendly fire!** Drop and run |

Power scales with the ability's stat and its level: `base × (1 + stat × 0.10) × (1 + (level−1) × 0.06)`.

## Leveling (train by use)

- Every **8 casts** = **+1 level**, up to **level 15**. Each level is **+6% power**.
- A **duplicate Tome** of something you already know **ranks it up** (a full level's worth) instead of being wasted.

## Getting abilities

- **Class starter** — granted and bound to `Q` when you pick your class on Floor 3.
- **Tomes** (consumables) — Tome: Blink / Ground Slam (Silver+), Null-G Singularity (Platinum+). Picked-up tomes learn instantly.
- **Item-granted** — Rare+ **weapons & trinkets** have a 20% chance to roll a `Grants <ability>` affix
  (from a skill pool: Scrap Bomb, Ground Slam, Blink, Holy Shield). It auto-slots on the hotbar **while
  equipped**; **unequip and you lose it** — and its cooldown keeps ticking, so you can't hot-swap to dodge cooldowns.

## Casting & binding

Three ways to fire abilities:

- **`Q`** — your **primary** cast (the selected ability).
- **Right Mouse** — a **secondary** cast you bind separately (empty by default).
- **Hotbar `1`–`4`** — each slot holds a consumable *or* an ability; press the number to use it.

Open the **Abilities panel (`K`)** to bind: **left-click** an ability to set it as the `Q` cast,
**right-click** to set it as the **Right-Mouse** secondary. Bound abilities show `[Q]` / `[R]` markers.
Arrange which ability/consumable sits on each hotbar key in the **Inventory (`I`)** — see
[Loot & Items → Hotbar](loot.md#the-hotbar).
