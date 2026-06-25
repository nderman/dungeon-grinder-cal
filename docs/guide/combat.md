# Combat

## Weapons & damage

Your equipped weapon drives your attack — **melee** weapons swing an arc, **ranged** fire projectiles.
Per-hit damage = `weapon base × (1 + stat-scaling) × rarity power`:

- **Melee** scales **STR** (`×(1 + STR×0.107)`), **guns** scale **DEX** (`×0.08`), **magic weapons** scale **INT** (`×0.04`).
- **Rarity power** (Rare+ weapons only): `1.0 + (rarity−1)×0.2` → roughly **Rare ×1.2 · Epic ×1.4 · Legendary ×1.6**.
  So an Epic weapon genuinely hits harder than a Common one — not just fancier affixes.

The inventory shows **effective dmg + DPS** for your stats, and folds the weapon's own **crit** into the DPS so the number's honest.

## Defense (the order a hit resolves)

1. **Dodge** (DEX, cap 35%) — a clean miss; the whole hit is negated.
2. **Damage Resistance** (CON × 3.6%, + gear armor, cap 75%) — on a proc, **one heart is shrugged** ("Clink!").
3. Whatever's left hits your HP.

Plus **i-frames**: dashing grants 0.2 s + `DEX×0.025` of invulnerability, and taking a hit grants a brief
0.4 s window. (Two independent timers — neither cancels the other.)

> Two things **ignore DR and i-frames**: **Poison** (potion-sickness DoT) and the **floor collapse** DoT.
> You can't tank those — cure/leave.

## Gear affixes

Rare+ gear rolls **effect affixes** (Rare = 1, Epic = 2, Legendary = 3+). These are fully live (unlike race/class passives).

**Offensive** (proc on your weapon hits — from *any* equipped slot):

| Affix | Adjective | Does |
|---|---|---|
| Crit | Savage | Chance to **×2** a hit |
| Burn | Burning | Fire **DoT** for 3 s |
| Leech | Leeching | Heal a fraction of damage dealt |
| Chill | Chilling | **Slows** the victim for 2.5 s |
| Chain | Shocking | Arcs a fraction to the nearest *other* enemy (240 px) |

**Defensive** (passive, folded into your vitals):

| Affix | Adjective | Does |
|---|---|---|
| Armor | Plated | Flat **+DR%** (counts toward the 75% cap) |
| Regen | Mending | Bonus HP/s (counts toward the 3.0/s cap) |
| Dodge | Nimble | **+dodge%** (toward the 35% cap) |
| Fire Resist | Flameproof | Shrugs incoming **Burn** (power + duration) |
| Frost Resist | Frostward | Shrugs incoming **Chill** (power + duration) |

Higher tier = bigger rolls. Effects from every slot stack — a Ring of Leeching feeds your sword swings.

## Elemental damage

Two statuses, applied by elemental enemies (and your own Burn/Chill affixes onto enemies):

- **Burn** — a DoT, **3 s**, ticking every 0.5 s. Power is hearts/sec.
- **Chill** — a **slow**, **2.5 s**, up to ~80% (you never freeze solid).

**Resisting it:** the **Fire Resist / Frost Resist** affixes cut both the *power and duration* of incoming
Burn/Chill, up to **60%** mitigation. That's your planned counter to a themed floor.

### Floor elemental themes

From **Floor 3+**, a floor has a **50%** chance to roll an **INFERNO** (burn) or **CRYO** (chill) theme,
announced on entry with the resist to prioritise. On a themed floor:

- ~**60%** of regular mobs gain the floor element (lighter power), and **all elites** carry it (stronger).
- Some enemies have a **signature** element regardless of theme (the Brute chills, the Golem boss burns).

Gear a matching resist before diving a themed floor and it goes from punishing to manageable.
