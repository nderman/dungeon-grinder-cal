# Loot & Items

Loot Boxes are the **power source** (achievements pay them out; you crack them in a Safe Room). Corpses
drip the common stuff (gold, the odd potion). Every box has a **tier** (quality) and a **type** (what it draws from).

## Tiers & rarities

**Tiers** set how good a box's rolls can be:

`Bronze (0) · Silver (1) · Gold (2) · Platinum (3) · Legendary (4) · Celestial (5)`

**Rarity** sets how many **affix slots** an item rolls (and its colour):

| Rarity | Affix slots | Colour |
|---|---|---|
| Common | 0 | grey |
| Uncommon | 1 | green |
| Rare | 2 | blue |
| Epic | 3 | purple |
| Legendary | 4 | gold |

Higher-tier boxes have a **rarity floor** (a Platinum box can't roll Common) and climb toward `tier+1`.
**Boss boxes** floor *and* cap one rarity higher; **Fan boxes** gamble harder toward the top.

## Affixes

Rare+ items roll **effect affixes** — see [Combat → Gear affixes](combat.md#gear-affixes) for the full
list (Crit/Burn/Leech/Chill/Chain offensive; Armor/Regen/Dodge/Fire-/Frost-Resist defensive). Two extras
worth knowing:

- **Weapon power** — Rare+ *weapons* also roll a base-damage multiplier (~Rare ×1.2 → Legendary ×1.6), shown as a `Power ×N` tag.
- **Granted abilities** — Rare+ weapons/trinkets have a 20% shot at a `Grants <ability>` affix (see [Abilities](abilities.md#getting-abilities)).

## Box types & the Director's Algorithm

Box types: **weapon · armor · trinket · supply** (consumables) **· gear** (any equipment) **· fan** (anything, gambles up) **· boss** (premium).

When a box rolls, the **Director's Algorithm** is build-aware: items get more weight for higher min-tier,
**+3 weight** if their stat tag matches your **top stat**, and **+6** if you've
[sponsored](meta-progression.md#loot-sponsorship) them. So a STR build sees more STR gear, and sponsored
weapons show up reliably.

## Opening boxes (the reveal)

Boxes only open in a **Safe Room** (via a Phase-Door). The terminal cracks your whole haul at once,
low tier → high, in a **reveal screen** — each item pops in rarity-coloured (★ for Epic, ★★ for
Legendary). Gear auto-equips into an empty matching slot (else it goes to your bag); consumables stack on the hotbar.

## The hotbar

Four slots (`1`–`4`), each holding a **consumable stack** or an **ability**. Manage it in the **Inventory (`I`)**:

- **Tap a slot, then another** to **swap** them (reorder so the right thing's on the right key).
- Tap an entry in the **"Add:"** row to drop an unslotted ability into the selected/first-free slot.
- **✕** clears a slot (an ability returns to the pool; a consumable is discarded).

If the bar's full when something new arrives, a consumable is dropped (with a warning) and an ability
stays unslotted until you free a slot.
