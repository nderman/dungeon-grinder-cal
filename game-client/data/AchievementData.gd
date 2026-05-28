# AchievementData.gd (Autoload)
# Achievement definitions. Each grants a Loot Box of `tier` (LootData.Tier).
# `repeatable` true = re-grants every trigger (performance feats); false = one-time (persisted).
extends Node

const ACHIEVEMENTS := {
	"first_blood":  {"title": "You've Killed a Mob!",        "desc": "Your first kill.",                   "tier": 0, "repeatable": false},
	"phase_finder": {"title": "Sub-Dimensional Tourist",     "desc": "Found a Phase-Door.",                "tier": 0, "repeatable": false},
	"speed_demon":  {"title": "Speed Demon!",                "desc": "3 kills in 2 seconds.",              "tier": 1, "repeatable": true},
	"near_death":   {"title": "Near Death!",                 "desc": "Survived at a sliver of health.",    "tier": 1, "repeatable": true},
	"untouchable":  {"title": "Untouchable!",                "desc": "Dashed clean through a killer.",     "tier": 0, "repeatable": true},
	"boss_slayer":  {"title": "Boss Slayer",                 "desc": "Put a boss in the ground.",          "tier": 2, "repeatable": true},
}
