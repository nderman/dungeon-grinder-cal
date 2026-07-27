# AchievementData.gd (Autoload)
# Achievement definitions. Each grants a Loot Box of `tier` (LootData.Tier).
# `scope` decides loot cadence — achievements are the PRIMARY per-run loot source:
#   "run"        = once per run, resets each Episode  (per-run milestones)
#   "repeatable" = fires every trigger, no dedup       (performance feats / grind drip)
#   "lifetime"   = once EVER, persisted to disk         (meta milestones / collection)
extends Node

const ACHIEVEMENTS := {
	# `box_type` (optional, default "gear") picks WHICH loot box the feat pays out — combat feats pay
	# Weapon boxes, audience/style feats pay Fan boxes, a boss pays a premium Boss box, etc.
	# First kill of the run pays a Silver WEAPON box — the guaranteed early-game weapon every class gets
	# on Floor 1 (no other weapon-box feat is reachable while classless + gearless; telemetry showed
	# Floor 1 was 0 weapon boxes out of 39). Weapon boxes must be tier ≥1 — no tier-0 weapon is droppable.
	"first_blood":  {"title": "You've Killed a Mob!",        "desc": "First kill of the run — armed and dangerous.", "tier": 1, "scope": "run", "box_type": "weapon"},
	"phase_finder": {"title": "Sub-Dimensional Tourist",     "desc": "Found a Phase-Door this run.",       "tier": 0, "scope": "run"},
	# Speed Demon is the michael_bay problem all over again, one rung down the ladder: telemetry (27 Jul,
	# a 4-floor run) caught it firing 11× for 11 Silver boxes. It's the engine of a feedback LOOP — a good
	# weapon makes 3-kills-in-2s trivial, which pays a box, which buys a better weapon. Same personal-
	# cooldown lever, same reason: pace the drip without demoting the tier. 90s, not the 12s default —
	# its natural rate was ~1 per 44s, so the default never bound; only a cooldown longer than that does.
	"speed_demon":  {"title": "Speed Demon!",                "desc": "3 kills in 2 seconds.",              "tier": 1, "scope": "repeatable", "box_type": "fan", "cooldown": 90.0},
	"crowd_pleaser":{"title": "Multi-Kill!",                 "desc": "Cancelled 2+ mobs in a single blow.", "tier": 0, "scope": "repeatable", "box_type": "fan", "cooldown": 30.0},
	# Latent version of the same flood (caught by the guard test, not telemetry — the run that exposed the
	# others was too easy to ever go low). Hovering at a sliver of HP while regen ticks would re-trip this
	# every few seconds, paying a box each time exactly when you're least supposed to be rewarded.
	"near_death":   {"title": "Near Death!",                 "desc": "Survived at a sliver of health.",    "tier": 1, "scope": "repeatable", "box_type": "fan", "cooldown": 60.0},
	"untouchable":  {"title": "Untouchable!",                "desc": "Dashed clean through a killer.",     "tier": 0, "scope": "repeatable", "box_type": "fan"},
	"boss_slayer":  {"title": "Boss Slayer",                 "desc": "Put a boss in the ground.",          "tier": 2, "scope": "repeatable", "box_type": "boss"},
	# --- Combat spectacle (show off the new affixes/primitives) -> Weapon boxes ---
	"pyromaniac":   {"title": "Pyromaniac",                  "desc": "Set a contestant on fire. The crematorium union sends its regards.", "tier": 1, "scope": "run", "box_type": "weapon"},
	# AoE/bomb kills trip "BOOM" on basically every frag, so this is the spammiest repeatable by far
	# (telemetry: 9 Silver boxes off floor 3 once). The 45s personal cooldown is the anti-flood lever —
	# NOT a tier demotion: tier must stay ≥1 or the "Weapon Box" rolls non-weapon gear (no tier-0 weapon
	# is droppable), which silently gutted early weapon supply. tier 1 + 45s = an honest, paced drip.
	"michael_bay":  {"title": "Michael Bay Approved",        "desc": "Blew an enemy to chunks. Do it again.",          "tier": 1, "scope": "repeatable", "box_type": "weapon", "cooldown": 45.0},
	# Same story: 8 Silver Weapon boxes in one 4-floor run, because a Chain affix trips it on most kills.
	"chain_react":  {"title": "Chain Reaction",              "desc": "One hit, two corpses. Efficient.",               "tier": 1, "scope": "repeatable", "box_type": "weapon", "cooldown": 90.0},
	# --- Survival & misery -> Supply boxes ---
	"grave_robber": {"title": "Grave Robber",                "desc": "Looted a corpse. They won't be needing it.",     "tier": 0, "scope": "run", "box_type": "supply"},
	"tapped_out":   {"title": "Tapped Out",                  "desc": "Cast on an empty tank. Pack a battery.",         "tier": 0, "scope": "run", "box_type": "supply"},
	"stop_drop_roll":{"title": "Stop, Drop & Roll",          "desc": "Survived being set on fire. Hot enough for ya?", "tier": 1, "scope": "run", "box_type": "fan"},
	"cancelled":    {"title": "Cancelled",                   "desc": "Died on live TV. The audience will remember you for roughly four seconds.", "tier": 0, "scope": "lifetime"},
	# --- Stat milestones (re-earnable per run; STR title adapts to your Race; box fits the stat) ---
	"stat_max_str": {"title": "Strongest That Ever Lived",   "desc": "Cranked STR to 20. Pure beefcake.",              "tier": 2, "scope": "run", "box_type": "weapon"},
	"stat_max_dex": {"title": "Greased Lightning",           "desc": "Cranked DEX to 20. Blink and you'll miss it.",   "tier": 2, "scope": "run", "box_type": "trinket"},
	"stat_max_int": {"title": "Big Brain Energy",            "desc": "Cranked INT to 20. Insufferable.",               "tier": 2, "scope": "run", "box_type": "trinket"},
	"stat_max_con": {"title": "Absolute Unit",               "desc": "Cranked CON to 20. An immovable object.",        "tier": 2, "scope": "run", "box_type": "armor"},
	"stat_max_cha": {"title": "Crowd Favorite",              "desc": "Cranked CHA to 20. The sponsors adore you.",     "tier": 2, "scope": "run", "box_type": "fan"},
}
