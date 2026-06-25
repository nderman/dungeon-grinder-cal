# ClassData.gd (Autoload)
# Class stat bonuses (stacked on race) + starting active/passive skills.
# Source: MVP Master Design — "Class Starting Bonuses & Skills".
extends Node

# `ability` = the AbilityLibrary id of the class's permanent STARTER active (granted every run —
# part of the class identity, the "Hybrid" half). `active` is its display name.
const CLASSES := {
	"Technomancer": {
		"bonuses": {"INT": 3, "DEX": 1},
		"active": "Fireball", "ability": "fireball", "passive_id": "efficient_code", "passive": "Efficient Code (-15% mana costs)",
	},
	"BioPaladin": {
		"bonuses": {"CON": 3, "CHA": 1},
		"active": "Holy Shield", "ability": "holy_shield", "passive_id": "martyrs_hype", "passive": "Martyr's Hype (gain Ratings when hit)",
	},
	"Brawler": {
		"bonuses": {"STR": 3, "CON": 1},
		"active": "Ground Slam", "ability": "ground_slam", "passive_id": "iron_fist", "passive": "Iron Fist (+20% melee damage)",
	},
	"GlitchWitch": {
		"bonuses": {"DEX": 2, "INT": 2},
		"active": "Blink", "ability": "blink", "passive_id": "data_corruption", "passive": "Data Corruption (skills slow enemies)",
	},
	"GravityGlitcher": {
		"bonuses": {"INT": 2, "DEX": 2},
		"active": "Null-G Singularity", "ability": "singularity", "passive_id": "low_g_training", "passive": "Low-G Training (+dash distance)",
	},
	"Scavenger": {
		"bonuses": {"CHA": 3, "DEX": 1},
		"active": "Scrap Bomb", "ability": "scrap_bomb", "passive_id": "extreme_coupons", "passive": "Extreme Coupons (-20% shop prices)",
	},
}

func get_bonuses(c: String) -> Dictionary:
	return CLASSES.get(c, {}).get("bonuses", {})

# Machine key for the class passive (checked via GameManager.has_passive). "" if none.
func get_passive_id(c: String) -> String:
	return CLASSES.get(c, {}).get("passive_id", "")

# The AbilityLibrary id this class starts with (its permanent active). "" if none.
func get_starter_ability(c: String) -> String:
	return CLASSES.get(c, {}).get("ability", "")
