# Potions

Healing and mana come from consumables on your **hotbar** (`1`–`4`). They scale with the box **tier**
they came from:

| Item | Effect | Per tier |
|---|---|---|
| Health Potion | Heal | `(1 + tier) × 20` HP — 20 at Bronze → 120 at Celestial |
| Greater Health Potion (Gold+) | Heal | `(1 + tier) × 45` HP — much bigger |
| Mana Battery | Restore mana | `(1 + tier) × 10` |
| Antidote (Silver+) | Cure Poison | instant |

## Potion sickness (the DCC catch)

You can't just chain potions. **Any potion starts a cooldown**, scaled by CON:

`cooldown = max(2.5, 12 − CON × 0.4)` seconds.

> e.g. CON 10 → 8 s; CON 23 → 2.8 s. More CON = drink more often.

Drink **another potion before the cooldown clears** and the potion still works — but you get **Poisoned**:

- A DoT of **4% of max HP per second for 5 s** (~20% total if untreated)
- It **bypasses armor and i-frames** — you can't tank it.

So potions are **risk/reward**, not a panic button. Pace them, or pay the poison.

## The antidote

The **Antidote** cures Poison instantly — and it's **exempt from potion sickness**, so using it can never
re-poison you while you're clearing the debuff. Keep one on the bar for themed/elite floors.
