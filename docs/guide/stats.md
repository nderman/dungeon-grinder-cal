# Stats

Five attributes — **STR, DEX, INT, CON, CHA** — start at **4 each** (DCC scale: 4 = average human).
Race and class bump them at run start, level-ups hand you **3 points** to spend at a Safe-Room terminal,
and permanent [stat injectors](meta-progression.md#permanent-stat-injectors) carry across Seasons. They
climb high — deep floors expect triple digits.

Each point is a *meaningful* fraction at these magnitudes, so where you spend matters.

## What each stat does

### STR — melee & knockback
- **Melee damage** ×`(1 + STR × 0.107)`. A War Hammer (1.7 base) goes 1.89 → 2.48 → 4.00 at STR 4 / 10 / 20.
- **Knockback** = weapon base + `STR × 5` px.
- Scales STR-based abilities (e.g. Ground Slam).

### DEX — speed, evasion, accuracy
- **Move speed** = `300 + DEX × 12.5` px/s (350 at base → 550 at DEX 20). High DEX outruns most things.
- **Dodge** = `DEX × 1.2 %` (+ gear), **capped 35%** — a full dodge negates the *entire* hit, rolled before DR.
- **Accuracy**: ranged spread tightens by `DEX × 1.1°` — near-perfect by ~DEX 14.
- **Dash i-frames**: +`DEX × 0.025 s` on top of the 0.2 s dash (so DEX 20 = ~0.7 s of invulnerable dash).
- **Ranged (gun) damage** ×`(1 + DEX × 0.08)`.

### INT — mana & spells
- **Max mana** = `INT × 12` (48 at base).
- **Mana regen** = `1.8 × (1 + INT × 0.05)` /s.
- Scales INT-based **spell** power (Glitch Bolt, Fireball, Singularity).
- **Magic-weapon** damage (the Glitch Pistol) ×`(1 + INT × 0.04)` — deliberately modest; INT's real payoff is spells.

### CON — survival
- **Max HP** = `CON × 10` (40 at base, 230 at CON 23).
- **Damage Resistance** = `CON × 3.6 %` (+ gear armor), **capped 75%**. On a DR proc, one heart is shrugged ("Clink!").
- **HP regen** = `CON × 0.2` /s (+ gear), **total capped at 3.0 /s** — you can't out-regen the dungeon by stacking CON alone.

### CHA — the audience
- Flavour/audience-facing. Drives Ratings/Hype feel in the show framing.
- ⚠️ *Not currently wired into a damage/economy formula in code* — treat it as the weakest stat to invest in for now.

## Quick reference

| Effect | Stat | Formula | Cap |
|---|---|---|---|
| Max HP | CON | CON × 10 | — |
| Damage Resistance % | CON | CON × 3.6 (+gear) | 75% |
| HP regen /s | CON | CON × 0.2 (+gear) | 3.0/s |
| Dodge % | DEX | DEX × 1.2 (+gear) | 35% |
| Move speed px/s | DEX | 300 + DEX × 12.5 | — |
| Dash i-frames | DEX | 0.2 + DEX × 0.025 s | — |
| Ranged spread | DEX | base − DEX × 1.1° | 0° |
| Max mana | INT | INT × 12 | — |
| Mana regen /s | INT | 1.8 × (1 + INT × 0.05) | — |
| Melee damage | STR | ×(1 + STR × 0.107) | — |
| Knockback px | STR | weapon + STR × 5 | — |
| Gun / magic damage | DEX / INT | ×(1 + DEX×0.08 / INT×0.04) | — |

*(Defensive caps exist because, untuned, stacked CON/DEX made you literally unkillable by ~floor 6.)*
