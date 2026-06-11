extends TestCase
# Loot box TYPES constrain the roll pool; per-tier rarity FLOOR; safe low-tier fallback.
func _init() -> void: test_name = "loot_boxes"

func run() -> void:
	var stats := {"STR": 10, "INT": 10, "CHA": 10}
	var ok_weapon := true
	var ok_armor := true
	var ok_supply := true
	var ok_gear := true
	for _i in range(250):
		if LootData.roll(5, stats, "weapon").get("slot", "") != "Weapon": ok_weapon = false
		if String(LootData.roll(5, stats, "armor").get("slot", "")) not in LootData.ARMOUR_SLOTS: ok_armor = false
		if LootData.roll(5, stats, "supply").get("kind", "") != "consumable": ok_supply = false
		if LootData.roll(5, stats, "gear").get("kind", "") == "consumable": ok_gear = false
	check(ok_weapon, "weapon box rolls only weapons")
	check(ok_armor, "armor box rolls only armour slots")
	check(ok_supply, "supply box rolls only consumables")
	check(ok_gear, "gear box never rolls a consumable")

	# Tier rarity floor: a Legendary-tier (4) gear box never rolls below its floor.
	var under_floor := false
	for _i in range(250):
		var g := LootData.roll(4, stats, "gear")
		if g.get("kind") == "gear" and int(g["rarity"]) < LootData.TIER_RARITY_FLOOR[4]: under_floor = true
	check(not under_floor, "tier-4 box never rolls below the rarity floor")

	# Boss box floors one rarity higher; never empty even for a Bronze weapon box (falls back to gear).
	var boss_low := false
	for _i in range(250):
		var b := LootData.roll(3, stats, "boss")
		if b.get("kind") == "gear" and int(b["rarity"]) < LootData.TIER_RARITY_FLOOR[3] + 1: boss_low = true
	check(not boss_low, "boss box floors one rarity above its tier")
	var empties := 0
	for _i in range(100):
		if LootData.roll(0, stats, "weapon").is_empty(): empties += 1
	eq(empties, 0, "a Bronze weapon box never returns empty (falls back to gear)")
	eq(LootData.box_type_name("boss"), "Boss", "box_type_name maps known types")
	eq(LootData.box_type_name("zzz"), "Gear", "box_type_name defaults unknown to Gear")
