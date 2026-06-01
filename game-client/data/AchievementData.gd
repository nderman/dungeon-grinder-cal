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
}
