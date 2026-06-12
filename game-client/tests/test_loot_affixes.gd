extends TestCase
# Effect-affixes: slot routing (offense weapon / defense armour / either jewellery), instance_bonus
# skips effects, adjective names, effect labels, effective weapon damage/DPS, resist affixes.
func _init() -> void: test_name = "loot_affixes"

func run() -> void:
	# Rare+ gear always carries an effect; slot routing keeps offense/defense in their lanes.
	var weap_effects := {}
	var armor_effects := {}
	var rare_plus := 0
	var rare_with_effect := 0
	for _i in range(800):
		var inst := LootData.roll(5, {"STR": 10})
		if inst.get("kind") != "gear": continue
		var slot := String(inst.get("slot", ""))
		var has_eff := false
		for af in inst["affixes"]:
			if af.has("effect"):
				has_eff = true
				if slot == "Weapon": weap_effects[af["effect"]] = true
				elif slot in LootData.ARMOUR_SLOTS: armor_effects[af["effect"]] = true
		if int(inst["rarity"]) >= LootData.EFFECT_MIN_RARITY:
			rare_plus += 1
			if has_eff: rare_with_effect += 1
	eq(rare_plus, rare_with_effect, "every Rare+ item carries an effect")
	for e in weap_effects: check(e in LootData.OFFENSE_EFFECTS, "weapon only rolls offense effects (%s)" % e)
	for e in armor_effects: check(e in LootData.DEFENSE_EFFECTS, "armour only rolls defense effects (%s)" % e)

	# Aggregation + display.
	var eq_set := {
		"Weapon": {"affixes": [{"effect": "crit", "power": 0.2}, {"stat": "STR", "amount": 3}]},
		"Head": {"affixes": [{"effect": "armor", "power": 6.0}, {"effect": "fire_resist", "power": 0.4}]},
	}
	approx(float(LootData.combat_effects(eq_set).get("crit", 0)), 0.2, "combat_effects sums offense")
	approx(float(LootData.defensive_effects(eq_set).get("fire_resist", 0)), 0.4, "defensive_effects sums resist")
	var w := {"base": "broadsword", "affixes": [{"effect": "burn", "power": 1.0}, {"stat": "STR", "amount": 3}]}
	eq(int(LootData.instance_bonus(w).get("STR", 0)), 5, "instance_bonus = base 2 + affix 3, skips the burn effect")
	eq(LootData.instance_name(w), "Burning Broadsword", "effect adjective prefixes the name")
	eq(LootData.effect_label({"effect": "fire_resist", "power": 0.4}), "Fire Resist 40%", "resist labels as a percentage")

	# Effective weapon damage scales off the weapon's PRIMARY tag: STR melee, DEX guns, INT magic.
	approx(LootData.effective_weapon_damage("broadsword", {"STR": 10}), 1.3 * (1.0 + 10 * LootData.MELEE_DMG_PER_STR), "heavy melee scales STR")
	approx(LootData.effective_weapon_damage("crossbow", {"DEX": 8, "INT": 99}), 1.5 * (1.0 + 8 * LootData.RANGED_DMG_PER_DEX), "a mundane gun scales DEX, not INT")
	approx(LootData.effective_weapon_damage("glitch_pistol", {"INT": 10, "DEX": 99}), 0.6 * (1.0 + 10 * LootData.MAGIC_DMG_PER_INT), "a MAGIC gun scales INT (modestly)")
	eq(LootData.weapon_scale_stat("nunchucks"), "DEX", "a DEX-tagged melee weapon scales DEX")
	truthy("DPS" in LootData.instance_desc({"base": "broadsword", "affixes": []}, {"STR": 10}), "desc shows DPS when stats are passed")
