# NanoMagicLibrary.gd (Autoload)
# Universal spell definitions. Any contestant can cast; INT scales impact.
# Scaling (applied in Player.execute_nano_magic, DCC stat scale):
#   damage = base_damage * (1 + INT * 0.125)
#   cost   = mana_cost   * max(0.1, 1 - INT * 0.025)   # floored so high INT can't zero/negate cost
extends Node

const SPELLS := {
	"glitch_bolt": {
		"name": "Glitch Bolt", "mana_cost": 5, "damage": 0.5, "cooldown": 0.2,
		"effect_type": "projectile",
		"description": "Rapid-fire packet of unstable data.",
	},
	"static_chain": {
		"name": "Static Chain", "mana_cost": 25, "damage": 1.0, "cooldown": 3.0,
		"effect_type": "chain_lightning",
		"description": "Arcs electrical feedback between up to 4 mobs.",
	},
	"molecular_beam": {
		"name": "Molecular Beam", "mana_cost": 50, "damage": 2.0, "cooldown": 8.0,
		"effect_type": "beam",
		"description": "Concentrated disintegrator stream; ignores shields.",
	},
	"gravity_well": {
		"name": "Gravity Well", "mana_cost": 40, "damage": 0.2, "cooldown": 12.0,
		"effect_type": "aoe_pull",
		"description": "Collapses local space to herd mobs into a kill-zone.",
	},
}
