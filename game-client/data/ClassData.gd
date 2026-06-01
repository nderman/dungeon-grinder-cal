# ClassData.gd (Autoload)
# Class stat bonuses (stacked on race) + starting active/passive skills.
# Source: MVP Master Design — "Class Starting Bonuses & Skills".
extends Node

const CLASSES := {
	"Technomancer": {
		"bonuses": {"INT": 3, "DEX": 1},
		"active": "Fireball", "passive": "Efficient Code (-15% mana costs)",
	},
	"BioPaladin": {
		"bonuses": {"CON": 3, "CHA": 1},
		"active": "Holy Shield", "passive": "Martyr's Hype (gain Ratings when hit)",
	},
	"Brawler": {
		"bonuses": {"STR": 3, "CON": 1},
		"active": "Ground Slam", "passive": "Iron Fist (+20% melee damage)",
	},
	"GlitchWitch": {
		"bonuses": {"DEX": 2, "INT": 2},
		"active": "Blink", "passive": "Data Corruption (skills slow enemies)",
	},
	"GravityGlitcher": {
		"bonuses": {"INT": 2, "DEX": 2},
		"active": "Null-G Singularity", "passive": "Low-G Training (+dash distance)",
	},
	"Scavenger": {
		"bonuses": {"CHA": 3, "DEX": 1},
		"active": "Loot Sense", "passive": "Extreme Coupons (-20% shop prices)",
	},
}

func get_bonuses(c: String) -> Dictionary:
	return CLASSES.get(c, {}).get("bonuses", {})
