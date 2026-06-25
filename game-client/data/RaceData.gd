# RaceData.gd (Autoload)
# Race stat modifiers (applied on top of MetaManager.BASE_STATS = 4 each, DCC scale) + passives.
# Source: MVP Master Design — "Define the starting stats for the initial player races".
extends Node

# `passive_id` is the machine key the gameplay code checks via GameManager.has_passive(); `passive`
# is the human blurb (UI + the player guide). Keep the two in step.
const RACES := {
	"Human": {
		"bonuses": {},   # Pure baseline. The control group.
		"passive_id": "viewers_choice",
		"passive": "Viewer's Choice: stronger build-aware loot tailoring.",
	},
	"Ogre": {
		"bonuses": {"CON": 3},
		"passive_id": "ponderous_might",
		"passive": "Ponderous Might: double melee knockback; move speed -20%.",
	},
	"Cat": {
		"bonuses": {"DEX": 3, "CHA": 1},
		"passive_id": "audience_darling",
		"passive": "Audience Darling: faster Hype gen; chance to Hiss-stun adjacent mobs.",
	},
	"Trollkin": {
		"bonuses": {"STR": 3},
		"passive_id": "biological_patch",
		"passive": "Biological Patch: regen after 10s without taking damage.",
	},
	"AeroWraith": {
		"bonuses": {"DEX": 3},
		"passive_id": "phasing_flight",
		"passive": "Phasing Flight: dash briefly through walls.",
	},
}

func get_bonuses(race: String) -> Dictionary:
	return RACES.get(race, {}).get("bonuses", {})

func get_passive(race: String) -> String:
	return RACES.get(race, {}).get("passive", "")

func get_passive_id(race: String) -> String:
	return RACES.get(race, {}).get("passive_id", "")
