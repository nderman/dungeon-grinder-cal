# Meta-progression

Death is permanent *for the run* — but two currencies carry across Seasons, spent in the **Green Room**
between runs. The whole loop is designed so a harder Season feeds back into making you stronger.

## The two currencies

- **Syndication Points** — the abundant one. You bank **10% of your run's Ratings** on death (**20%** on a
  Champion win). Earned constantly from kills/feats; piles up fast.
- **Milestone Tokens** — the scarce one. One each at **floors 3, 6, 9** (so ~1–3 per run).

## Roster shop (Tokens)

Spend Tokens to permanently unlock new **races** and **classes** (1 token each) — they then become
pickable on Floor 3. This is the core roguelite growth: more builds to try each Season.

## Permanent stat injectors

*(The Syndication sink.)* Once you're sitting on Syndication, buy **permanent +1s to a stat** — applied to *every* future
contestant. Cost escalates per stat: `500 × 1.5^(owned)` → **500, 750, 1125, 1688, …**. No cap (stats
climb to 100+), so there's always something to spend Syndication on.

## Loot sponsorship

*(A Token sink.)* Spend **1 Token** to **sponsor a weapon** — it joins the permanent loot pool and the Director's Algorithm
weights it **+6** in every future roll, so your build's key weapon actually shows up instead of praying to RNG.

## Prestige / New Game+

After your first Champion win, spend Tokens to unlock **NG+ tiers** (cost **3, 5, 7, …** = `3 + 2×tier`).
Select an active tier in the Green Room; each tier scales the **whole Season**:

- Enemies: **+25% HP and +25% damage** per tier
- Rewards: **+25% Ratings/XP** per tier, and **every reward box +1 tier** (capped at Celestial)

So a harder Season pays back more Syndication, Tokens, and loot — the prestige loop compounds. NG+ stacks
on top of floor scaling **and** Nightmare.

## Nightmare mode

Also unlocked after a first win: a Green-Room toggle that makes **enemies hit ×1.6** across the board.
Stacks with NG+ and floor depth. Pure difficulty (its extra-reward side is logged future work).

## Prestige counter

**`seasons_won`** ticks up per Champion victory. Reaching ≥1 unlocks the Nightmare toggle and the NG+
section in the Green Room — the prestige layer only opens once you've actually taken a Champion's head.
