# ClassData.gd (Autoload)
# Class stat bonuses (stacked on race) + starting active/passive skills.
# Source: MVP Master Design — "Class Starting Bonuses & Skills".
extends Node

const CLASSES := {
	"Technomancer": {
		"bonuses": {"INT": 5, "DEX": 2},
		"active": "Fireball", "passive": "Efficient Code (-15% mana costs)",
	},
	"BioPaladin": {
		"bonuses": {"CON": 5, "CHA": 2},
		"active": "Holy Shield", "passive": "Martyr's Hype (gain Ratings when hit)",
	},
	"Brawler": {
		"bonuses": {"STR": 5, "CON": 2},
		"active": "Ground Slam", "passive": "Iron Fist (+20% melee damage)",
	},
	"GlitchWitch": {
		"bonuses": {"DEX": 4, "INT": 3},
		"active": "Blink", "passive": "Data Corruption (skills slow enemies)",
	},
	"GravityGlitcher": {
		"bonuses": {"INT": 4, "DEX": 3},
		"active": "Null-G Singularity", "passive": "Low-G Training (+dash distance)",
	},
	"Scavenger": {
		"bonuses": {"CHA": 5, "DEX": 2},
		"active": "Loot Sense", "passive": "Extreme Coupons (-20% shop prices)",
	},
}

func get_bonuses(c: String) -> Dictionary:
	return CLASSES.get(c, {}).get("bonuses", {})
