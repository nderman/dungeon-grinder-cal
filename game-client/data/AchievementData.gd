# AchievementData.gd (Autoload)
# Achievement definitions. Each grants a Loot Box of `tier` (LootData.Tier).
# `scope` decides loot cadence — achievements are the PRIMARY per-run loot source:
#   "run"        = once per run, resets each Episode  (per-run milestones)
#   "repeatable" = fires every trigger, no dedup       (performance feats / grind drip)
#   "lifetime"   = once EVER, persisted to disk         (meta milestones / collection)
extends Node

const ACHIEVEMENTS := {
	"first_blood":  {"title": "You've Killed a Mob!",        "desc": "First kill of the run.",             "tier": 0, "scope": "run"},
	"phase_finder": {"title": "Sub-Dimensional Tourist",     "desc": "Found a Phase-Door this run.",       "tier": 0, "scope": "run"},
	"speed_demon":  {"title": "Speed Demon!",                "desc": "3 kills in 2 seconds.",              "tier": 1, "scope": "repeatable"},
	"crowd_pleaser":{"title": "Multi-Kill!",                 "desc": "Cancelled 2+ mobs in a single blow.", "tier": 0, "scope": "repeatable"},
	"near_death":   {"title": "Near Death!",                 "desc": "Survived at a sliver of health.",    "tier": 1, "scope": "repeatable"},
	"untouchable":  {"title": "Untouchable!",                "desc": "Dashed clean through a killer.",     "tier": 0, "scope": "repeatable"},
	"boss_slayer":  {"title": "Boss Slayer",                 "desc": "Put a boss in the ground.",          "tier": 2, "scope": "repeatable"},
	# --- Combat spectacle (show off the new affixes/primitives) ---
	"pyromaniac":   {"title": "Pyromaniac",                  "desc": "Set a contestant on fire. The crematorium union sends its regards.", "tier": 0, "scope": "run"},
	"michael_bay":  {"title": "Michael Bay Approved",        "desc": "Blew an enemy to chunks. Do it again.",          "tier": 1, "scope": "repeatable"},
	"chain_react":  {"title": "Chain Reaction",              "desc": "One hit, two corpses. Efficient.",               "tier": 1, "scope": "repeatable"},
	# --- Survival & misery ---
	"grave_robber": {"title": "Grave Robber",                "desc": "Looted a corpse. They won't be needing it.",     "tier": 0, "scope": "run"},
	"tapped_out":   {"title": "Tapped Out",                  "desc": "Cast on an empty tank. Pack a battery.",         "tier": 0, "scope": "run"},
	"cancelled":    {"title": "Cancelled",                   "desc": "Died on live TV. The audience will remember you for roughly four seconds.", "tier": 0, "scope": "lifetime"},
	# --- Stat milestones (re-earnable per run; STR title adapts to your Race) ---
	"stat_max_str": {"title": "Strongest That Ever Lived",   "desc": "Cranked STR to 20. Pure beefcake.",              "tier": 2, "scope": "run"},
	"stat_max_dex": {"title": "Greased Lightning",           "desc": "Cranked DEX to 20. Blink and you'll miss it.",   "tier": 2, "scope": "run"},
	"stat_max_int": {"title": "Big Brain Energy",            "desc": "Cranked INT to 20. Insufferable.",               "tier": 2, "scope": "run"},
	"stat_max_con": {"title": "Absolute Unit",               "desc": "Cranked CON to 20. An immovable object.",        "tier": 2, "scope": "run"},
	"stat_max_cha": {"title": "Crowd Favorite",              "desc": "Cranked CHA to 20. The sponsors adore you.",     "tier": 2, "scope": "run"},
}
