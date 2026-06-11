# AbilityLibrary.gd (Autoload)
# Unified registry for learnable ACTIVE abilities — magical Spells (cost mana) AND nonmagical
# Skills (cooldown only). The player learns abilities (a permanent class starter + per-run tomes),
# selects one as the active cast (the Q key), and levels it by USE (DCC: train with use, cap ~15).
# Replaces the old NanoMagicLibrary.
#
# Fields per ability:
#   kind       "spell" (spends mana) | "skill" (no mana — cooldown gate only)
#   scale      stat that scales effectiveness (INT/STR/CON/DEX/CHA)
#   mana_cost  mana per cast (0 for skills)
#   cooldown   seconds between casts
#   effect     "projectile" | "nova" (AoE around you) | "self_heal" | "blink" (dash to aim)
#   power      base magnitude (damage or heal), scaled by stat + ability level
#   radius     nova AoE radius (px); reach = blink distance (px)
extends Node

const USES_PER_LEVEL := 8        # casts to gain a level
const MAX_LEVEL := 15            # DCC abilities cap ~15
const LEVEL_POWER_STEP := 0.06   # +6% power per level above 1
const SCALE_PER_STAT := 0.1      # +10% effectiveness per point of the scaling stat

const ABILITIES := {
	"glitch_bolt": {"name": "Glitch Bolt", "kind": "spell", "scale": "INT", "mana_cost": 5.0, "cooldown": 0.25, "effect": "projectile", "power": 0.6, "description": "Rapid packet of unstable data."},
	"fireball": {"name": "Fireball", "kind": "spell", "scale": "INT", "mana_cost": 20.0, "cooldown": 0.6, "effect": "projectile", "power": 1.4, "proj_scale": 2.6, "proj_color": Color(1.0, 0.5, 0.12), "description": "A fat bolt of weaponised heat."},
	"singularity": {"name": "Null-G Singularity", "kind": "spell", "scale": "INT", "mana_cost": 30.0, "cooldown": 4.0, "effect": "nova", "power": 1.6, "radius": 200.0, "description": "Collapses local space, crushing nearby mobs."},
	"ground_slam": {"name": "Ground Slam", "kind": "skill", "scale": "STR", "mana_cost": 0.0, "cooldown": 3.0, "effect": "nova", "power": 0.65, "radius": 170.0, "stun": 1.5, "description": "A quake that stuns and rattles everything around you."},
	"holy_shield": {"name": "Holy Shield", "kind": "skill", "scale": "CON", "mana_cost": 0.0, "cooldown": 8.0, "effect": "shield", "power": 14.0, "aura_dr": 40.0, "duration": 5.0, "description": "A shield of faith: a burst of healing AND heavy damage resistance for a few seconds (golden glow while up)."},
	"blink": {"name": "Blink", "kind": "skill", "scale": "DEX", "mana_cost": 0.0, "cooldown": 2.5, "effect": "blink", "reach": 260.0, "power": 0.0, "description": "Phase a short distance toward your aim."},
	"scrap_bomb": {"name": "Scrap Bomb", "kind": "skill", "scale": "DEX", "mana_cost": 0.0, "cooldown": 4.5, "effect": "bomb", "power": 2.8, "radius": 150.0, "fuse": 1.2, "friendly_fire": true, "description": "Drop a junk charge — a big delayed blast that doesn't care whose side you're on. Drop and RUN."},
}

func has_ability(id: String) -> bool:
	return ABILITIES.has(id)

func get_ability(id: String) -> Dictionary:
	return ABILITIES.get(id, {})

func ability_name(id: String) -> String:
	return ABILITIES.get(id, {}).get("name", id)

func is_spell(id: String) -> bool:
	return ABILITIES.get(id, {}).get("kind", "skill") == "spell"

# Use count → ability level (1..MAX_LEVEL).
func level_for_uses(uses: int) -> int:
	return clampi(1 + int(uses / USES_PER_LEVEL), 1, MAX_LEVEL)

func power_mult(level: int) -> float:
	return 1.0 + (level - 1) * LEVEL_POWER_STEP
