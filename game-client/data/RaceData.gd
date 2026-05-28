# RaceData.gd (Autoload)
# Race stat modifiers (applied on top of MetaManager.BASE_STATS = 10 each) + passives.
# Source: MVP Master Design — "Define the starting stats for the initial player races".
extends Node

const RACES := {
	"Human": {
		"bonuses": {},   # Pure baseline. The control group.
		"passive": "Viewer's Choice: stronger build-aware loot tailoring (2.0x vs 1.5x).",
	},
	"Ogre": {
		"bonuses": {"CON": 5},
		"passive": "Ponderous Might: 100% melee knockback; move speed -20%.",
	},
	"Cat": {
		"bonuses": {"DEX": 5, "CHA": 2},
		"passive": "Audience Darling: faster Hype gen; chance to Hiss-stun adjacent mobs.",
	},
	"Trollkin": {
		"bonuses": {"STR": 5},
		"passive": "Biological Patch: regen 1 heart after 10s without taking damage.",
	},
	"AeroWraith": {
		"bonuses": {"DEX": 5},
		"passive": "Phasing Flight: ignore floor hazards; dash briefly through walls.",
	},
}

func get_bonuses(race: String) -> Dictionary:
	return RACES.get(race, {}).get("bonuses", {})

func get_passive(race: String) -> String:
	return RACES.get(race, {}).get("passive", "")
