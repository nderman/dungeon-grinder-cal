# LootData.gd (Autoload)
# Loot-box tiers + the item pool + the Director's Algorithm roll. Opened items are rolled into
# INSTANCES: a base item + a RARITY (Common→Legendary) + rolled AFFIXES (extra stat bonuses).
# Rarity = number of affix slots, so higher-tier boxes drop more "custom" gear. Gear equips into
# full-body + accessory slots (Weapon/Head/Chest/Legs/Hands/Amulet/2×Ring/Trinket); consumables
# stock the quick bar.
extends Node

enum Tier { BRONZE, SILVER, GOLD, PLATINUM, LEGENDARY, CELESTIAL }
const TIER_NAMES := ["Bronze", "Silver", "Gold", "Platinum", "Legendary", "Celestial"]

# Item rarity (number of affixes = rarity index). Colour tints the inventory entry.
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(0.85, 0.85, 0.85), Color(0.4, 0.9, 0.45), Color(0.4, 0.65, 1.0),
	Color(0.75, 0.45, 1.0), Color(1.0, 0.65, 0.25),
]

# Equip-slot KEYS (paper-doll positions). Several accessories let you wear more than one item of a
# type, so a key isn't always the item `slot` it accepts — see SLOT_ACCEPTS.
const SLOTS := ["Weapon", "Head", "Chest", "Legs", "Hands", "Amulet", "Ring", "Ring 2", "Trinket"]
# Equip-slot key → the item `slot` type it accepts. Defaults to the key itself (see slot_accepts).
const SLOT_ACCEPTS := {"Ring 2": "Ring"}
const STAT_KEYS := ["STR", "DEX", "INT", "CON", "CHA"]
const BASE_BONUS_PER_TAG := 2   # a gear item's flat bonus to each of its tagged stats

# Weapon damage scaling (single source of truth — Player reads these). Melee scales with STR, ranged
# with INT; knockback scales with STR. Used both in combat AND for the inventory's effective-DPS.
const MELEE_DMG_PER_STR := 0.107    # STR 7 → ×1.75 melee
const RANGED_DMG_PER_INT := 0.125   # INT 4 → ×1.5 ranged
const MELEE_KNOCK_PER_STR := 8.0    # +8px knockback per STR

# --- Effect-affixes: the "interesting" rolls that only appear on Rare+ gear ---------------------
# Beyond flat stat bonuses, Rare+ items roll EFFECT affixes. OFFENSE effects proc on your weapon
# hits (CombatEffects); DEFENSE effects passively buff you (folded into vitals in _derive_vitals).
#   burn  = DoT hearts/sec      leech = fraction of hit healed   crit = chance to double a hit
#   chill = enemy slow fraction chain = fraction arced to a 2nd enemy
#   armor = flat DR%            regen = bonus HP/sec             dodge = +% full-dodge chance
# `adj` prefixes the item name ("Savage War Hammer", "Plated Helm") so loot READS at a glance.
# `adj` = name prefix, `label` = inventory readout. Whether an effect is offense or defense is the
# single source OFFENSE_EFFECTS / DEFENSE_EFFECTS below (routing + aggregation read those arrays).
const EFFECT_AFFIXES := {
	"burn":  {"adj": "Burning",  "label": "Burn"},
	"leech": {"adj": "Leeching", "label": "Leech"},
	"crit":  {"adj": "Savage",   "label": "Crit"},
	"chill": {"adj": "Chilling", "label": "Chill"},
	"chain": {"adj": "Shocking", "label": "Chain"},
	"armor": {"adj": "Plated",   "label": "Armor"},
	"regen": {"adj": "Mending",  "label": "Regen"},
	"dodge": {"adj": "Nimble",   "label": "Dodge"},
}
const OFFENSE_EFFECTS := ["burn", "leech", "crit", "chill", "chain"]  # proc on your weapon hits
const DEFENSE_EFFECTS := ["armor", "regen", "dodge"]                  # passive buffs to you
const EFFECT_MIN_RARITY := 2   # Rare (index 2) and above start rolling effect-affixes
# Which effects a slot may roll: the Weapon does damage (OFFENSE), armour protects (DEFENSE), and
# jewellery has no inherent armour value so it rolls EITHER — a Rare ring can be fiery OR protective.
const ARMOUR_SLOTS := ["Head", "Chest", "Legs", "Hands"]

func _effect_pool_for_slot(slot: String) -> Array:
	if slot == "Weapon":
		return OFFENSE_EFFECTS
	if slot in ARMOUR_SLOTS:
		return DEFENSE_EFFECTS
	return OFFENSE_EFFECTS + DEFENSE_EFFECTS   # Amulet / Ring / Trinket

# Which item `slot` type fits in this equip-slot key (e.g. "Ring 2" accepts a "Ring").
func slot_accepts(slot_key: String) -> String:
	return SLOT_ACCEPTS.get(slot_key, slot_key)

func _ready() -> void:
	# Data guard (debug-only, stripped in release): every gear item's slot must be accepted by some
	# equip-slot key, or the item would silently land in the bag forever, un-equippable.
	for id in ITEMS:
		var s: String = ITEMS[id].get("slot", "")
		if s == "":
			continue   # consumable — no slot
		var ok := false
		for key in SLOTS:
			if slot_accepts(key) == s:
				ok = true
				break
		assert(ok, "LootData: item '%s' has slot '%s' with no matching key in SLOTS" % [id, s])

# id -> { name, tags (stat affinities), min_tier, slot (gear) | kind:"consumable" }
const ITEMS := {
	"health_potion":       {"name": "Health Potion",                "tags": ["CON"],        "min_tier": 0, "kind": "consumable", "potion": true},
	"greater_health_potion": {"name": "Greater Health Potion",      "tags": ["CON"],        "min_tier": 2, "kind": "consumable", "potion": true},
	"mana_battery":        {"name": "Mana Battery",                 "tags": ["INT"],        "min_tier": 0, "kind": "consumable", "potion": true},
	"antidote":            {"name": "Antidote",                     "tags": [],             "min_tier": 1, "kind": "consumable"},
	# Tomes teach an AbilityLibrary ability when used (per-run). The `ability` field flags them.
	"tome_blink":          {"name": "Tome: Blink",                 "tags": ["DEX"],        "min_tier": 1, "kind": "consumable", "ability": "blink"},
	"tome_ground_slam":    {"name": "Tome: Ground Slam",           "tags": ["STR"],        "min_tier": 1, "kind": "consumable", "ability": "ground_slam"},
	"tome_singularity":    {"name": "Tome: Null-G Singularity",    "tags": ["INT"],        "min_tier": 3, "kind": "consumable", "ability": "singularity"},
	"scrap_helm":          {"name": "Scrap Helm",                   "tags": ["CON"],        "min_tier": 0, "slot": "Head"},
	"grip_gloves":         {"name": "Grip Gloves",                  "tags": ["STR"],        "min_tier": 0, "slot": "Hands"},
	"spiked_pauldrons":    {"name": "Spiked Pauldrons",             "tags": ["STR"],        "min_tier": 0, "slot": "Chest"},
	"hype_stim":           {"name": "Hype Stim",                    "tags": ["CHA"],        "min_tier": 0, "slot": "Ring"},
	"lead_lined_vest":     {"name": "Lead-Lined Vest",              "tags": ["CON"],        "min_tier": 1, "slot": "Chest"},
	"sponsors_monocle":    {"name": "Sponsor's Monocle",            "tags": ["CHA"],        "min_tier": 1, "slot": "Head"},
	"overclocked_greaves": {"name": "Overclocked Greaves",          "tags": ["DEX"],        "min_tier": 1, "slot": "Legs"},
	"static_coil":         {"name": "Static Coil",                  "tags": ["INT"],        "min_tier": 2, "slot": "Ring"},
	"hazard_boots":        {"name": "Hazard Boots",                 "tags": ["CON", "DEX"], "min_tier": 2, "slot": "Legs"},
	"gravity_gauntlet":    {"name": "Gravity Gauntlet",             "tags": ["INT"],        "min_tier": 3, "slot": "Hands"},
	# --- Jewellery / trinkets (no armour value — pure stat + affix carriers) ---
	"lucky_charm":         {"name": "Lucky Charm",                 "tags": ["CHA"],        "min_tier": 0, "slot": "Trinket"},
	"power_band":          {"name": "Power Band",                  "tags": ["STR"],        "min_tier": 1, "slot": "Ring"},
	"neural_amulet":       {"name": "Neural Amulet",               "tags": ["INT"],        "min_tier": 1, "slot": "Amulet"},
	"vigor_pendant":       {"name": "Vigor Pendant",               "tags": ["CON"],        "min_tier": 2, "slot": "Amulet"},
	"adrenaline_chip":     {"name": "Adrenaline Chip",             "tags": ["DEX"],        "min_tier": 2, "slot": "Trinket"},
	# --- Weapons (the equipped Weapon-slot item drives the attack via its `weapon` block) ---
	# Starter weapons (STARTER_WEAPONS): all ~equal weak dps, different FEEL — randomised each run.
	"rusty_shiv":     {"name": "Rusty Shiv",     "tags": ["STR"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.55, "cooldown": 0.34, "range": 58.0, "arc": 46.0, "knock": 24.0}},
	"kitchen_knife":  {"name": "Kitchen Knife",  "tags": ["STR"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.42, "cooldown": 0.26, "range": 52.0, "arc": 38.0, "knock": 16.0}},
	"scrap_club":     {"name": "Scrap Club",     "tags": ["STR"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.62, "cooldown": 0.56, "range": 76.0, "arc": 86.0, "knock": 38.0}},
	"pop_pistol":     {"name": "Pop Pistol",     "tags": ["DEX"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 0.45, "cooldown": 0.5, "spread": 14.0}},
	"pipe_wrench":    {"name": "Pipe Wrench",    "tags": ["STR"], "min_tier": 1, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.8, "cooldown": 0.52, "range": 84.0, "arc": 96.0, "knock": 60.0}},
	"cleaver":        {"name": "Bone Cleaver",   "tags": ["STR"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 1.15, "cooldown": 0.70, "range": 92.0, "arc": 100.0, "knock": 55.0}},
	"glitch_pistol":  {"name": "Glitch Pistol",  "tags": ["INT"], "min_tier": 1, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 0.6, "cooldown": 0.28, "spread": 6.0}},
	"scrap_smg":      {"name": "Scrap SMG",      "tags": ["DEX"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 0.35, "cooldown": 0.12, "spread": 16.0}},
	"rail_spike":     {"name": "Rail Spike",     "tags": ["DEX"], "min_tier": 3, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 1.8, "cooldown": 0.85, "spread": 2.0}},
	# Exciting finds (NOT starters — the stuff you actually want to loot):
	"broadsword":     {"name": "Broadsword",     "tags": ["STR"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 1.3, "cooldown": 0.6, "range": 92.0, "arc": 88.0, "knock": 52.0}},
	"nunchucks":      {"name": "Nunchucks",      "tags": ["DEX"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.5, "cooldown": 0.2, "range": 72.0, "arc": 132.0, "knock": 28.0}},
	"crossbow":       {"name": "Crossbow",       "tags": ["DEX"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 1.5, "cooldown": 0.7, "spread": 2.0}},
	"katana":         {"name": "Katana",         "tags": ["STR", "DEX"], "min_tier": 3, "slot": "Weapon", "weapon": {"type": "melee", "damage": 1.0, "cooldown": 0.4, "range": 104.0, "arc": 72.0, "knock": 40.0}},
	"war_hammer":     {"name": "War Hammer",     "tags": ["STR"], "min_tier": 3, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 1.7, "cooldown": 0.82, "range": 88.0, "arc": 112.0, "knock": 96.0}},
	"golden_toaster": {"name": "God-Emperor's Golden Toaster", "tags": ["INT", "STR"], "min_tier": 4, "slot": "Weapon", "weapon": {"type": "melee", "damage": 1.8, "cooldown": 0.6, "range": 108.0, "arc": 120.0, "knock": 80.0}},
}

# The attack you have with no weapon equipped (a weak melee jab). Also the template for `weapon`.
const FISTS := {"type": "melee", "damage": 0.4, "cooldown": 0.45, "range": 80.0, "arc": 110.0, "knock": 25.0}

# Roughly-equal weak weapons a run can open with (random each Season) — variety of FEEL, not power.
const STARTER_WEAPONS := ["rusty_shiv", "kitchen_knife", "scrap_club", "pop_pistol"]

func random_starter_weapon() -> String:
	return STARTER_WEAPONS.pick_random()

func weapon_stats(base: String) -> Dictionary:
	return ITEMS.get(base, {}).get("weapon", FISTS)

func tier_name(t: int) -> String:
	return TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)]

func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)

func is_consumable(id: String) -> bool:
	return ITEMS.get(id, {}).get("kind", "gear") == "consumable"

func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]

func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]

# --- Consumables (effect + amount scale with box tier) -----------------------------------------

# {effect: "heal"|"mana"|"cure_poison"|"learn", amount, ability?}. Higher tiers brew stronger
# potions; a tome (has an `ability` field) teaches that ability.
func consumable_effect(id: String, tier: int) -> Dictionary:
	var it: Dictionary = ITEMS.get(id, {})
	if it.has("ability"):
		return {"effect": "learn", "ability": String(it["ability"]), "amount": 0}
	match id:
		"health_potion":         return {"effect": "heal", "amount": (1 + tier) * 20}
		"greater_health_potion": return {"effect": "heal", "amount": (1 + tier) * 45}
		"mana_battery":          return {"effect": "mana", "amount": (1 + tier) * 10}
		"antidote":              return {"effect": "cure_poison", "amount": 0}
	return {"effect": "", "amount": 0}

# Potions share the DCC "potion sickness" cool-down — drink one before it's up and you get Poisoned.
# The antidote (the cure) is deliberately exempt, so it can never re-poison you while clearing it.
func is_potion(id: String) -> bool:
	return bool(ITEMS.get(id, {}).get("potion", false))

# --- Rolling -----------------------------------------------------------------------------------

# Roll an item for a box tier, weighted toward the crawler's build. Returns an INSTANCE dict:
#   consumable → {kind:"consumable", base, tier}
#   gear       → {kind:"gear", base, slot, rarity, affixes:[{stat,amount}…]}
func roll(tier: int, stats: Dictionary) -> Dictionary:
	var base := _pick_base(tier, stats)
	if base == "":
		return {}
	if is_consumable(base):
		return {"kind": "consumable", "base": base, "tier": tier}
	var rarity := _roll_rarity(tier)
	var slot := String(ITEMS[base].get("slot", "Trinket"))
	var pool := _effect_pool_for_slot(slot)   # which effects THIS slot may roll (offense/defense)
	var affixes := []
	var used_effects: Array[String] = []
	for i in range(rarity):
		# Rare+ turns affix slots into EFFECT rolls — the first slot always, the rest 50/50 with a
		# stat roll. So a Rare item ALWAYS does something interesting, and Epics/Legendaries stack
		# more tricks. Lower rarities stay pure stat-stick (unchanged).
		var want_effect := rarity >= EFFECT_MIN_RARITY and (i == 0 or randf() < 0.5) and used_effects.size() < pool.size()
		if want_effect:
			var eff := _pick_effect(used_effects, pool)
			used_effects.append(eff)
			affixes.append({"effect": eff, "power": _roll_effect_power(eff, tier)})
		else:
			affixes.append({"stat": STAT_KEYS.pick_random(), "amount": randi_range(1, 2 + tier)})
	return {"kind": "gear", "base": base, "slot": slot, "rarity": rarity, "affixes": affixes}

# Pick an effect from this slot's pool, avoiding duplicates already on the item; falls back if all used.
func _pick_effect(used: Array, pool: Array) -> String:
	var avail := pool.filter(func(e): return e not in used)
	return avail.pick_random() if not avail.is_empty() else pool.pick_random()

# Per-effect magnitude, scaled by box tier — the `power` stored on the affix. Offense effects are
# FRACTIONS (crit 0.11 = 11%, burn 1.2 = hearts/sec); defense effects are percentage-POINTS for DR/
# dodge (armor 6.0 = +6% DR) or HP/sec (regen). snappedf keeps the numbers readable.
func _roll_effect_power(effect: String, tier: int) -> float:
	match effect:
		"burn":  return snappedf(0.25 + 0.10 * tier + randf() * 0.30, 0.05)   # DoT hearts/sec
		"leech": return snappedf(0.05 + 0.01 * tier + randf() * 0.04, 0.01)   # fraction of hit healed
		"crit":  return snappedf(0.05 + 0.015 * tier + randf() * 0.05, 0.01)  # crit chance
		"chill": return snappedf(0.20 + 0.03 * tier + randf() * 0.15, 0.05)   # enemy slow fraction
		"chain": return snappedf(0.30 + 0.05 * tier + randf() * 0.20, 0.05)   # splash fraction
		"armor": return snappedf(3.0 + 1.5 * tier + randf() * 4.0, 1.0)       # flat DR % (whole points)
		"regen": return snappedf(0.5 + 0.3 * tier + randf() * 1.0, 0.1)       # bonus HP/sec
		"dodge": return snappedf(2.0 + 0.5 * tier + randf() * 3.0, 1.0)       # +% full-dodge (whole)
	# A listed effect with no power branch would roll 0.0 silently — loud-fail in debug instead.
	# Adding an effect means wiring it here AND in CombatEffects (offense) or _derive_vitals (defense).
	assert(false, "LootData: no _roll_effect_power branch for effect '%s'" % effect)
	return 0.0

# Sum equipped OFFENSE effect-affixes into {effect: total_power}. CombatEffects reads this on each
# weapon hit — effects from ANY slot count, so a Ring of Leeching feeds your sword swings.
func combat_effects(equipped: Dictionary) -> Dictionary:
	return _sum_effects(equipped, OFFENSE_EFFECTS)

# Sum equipped DEFENSE effect-affixes into {armor, regen, dodge}. Player._derive_vitals folds these
# into DR / regen / dodge each time gear changes.
func defensive_effects(equipped: Dictionary) -> Dictionary:
	return _sum_effects(equipped, DEFENSE_EFFECTS)

func _sum_effects(equipped: Dictionary, keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for key in equipped:
		var inst = equipped[key]
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		for af in inst.get("affixes", []):
			if af.has("effect") and String(af["effect"]) in keys:
				var e := String(af["effect"])
				out[e] = float(out.get(e, 0.0)) + float(af["power"])
	return out

func _pick_base(tier: int, stats: Dictionary) -> String:
	var top := _top_stat(stats)
	var pool: Array[String] = []
	for id in ITEMS:
		if id in STARTER_WEAPONS:
			continue   # starters are run-openers only — never the reward for cracking a box
		var it: Dictionary = ITEMS[id]
		if int(it["min_tier"]) > tier:
			continue
		var weight := 1 + int(it["min_tier"])             # higher tiers favour rarer items
		if top != "" and top in it["tags"]:
			weight += 3                                   # Director's Algorithm: build-aware
		for _i in range(weight):
			pool.append(id)
	return "" if pool.is_empty() else pool.pick_random()

# Higher box tiers skew toward higher rarity; capped at the box tier + 1 so a Bronze box can't
# spit a Legendary. Rarity index = affix count.
func _roll_rarity(tier: int) -> int:
	var r := 0
	var cap := mini(tier + 1, RARITY_NAMES.size() - 1)
	while r < cap and randf() < 0.45:
		r += 1
	return r

func _top_stat(stats: Dictionary) -> String:
	var best := ""
	var best_val := -1.0
	for s in stats:
		if float(stats[s]) > best_val:
			best_val = float(stats[s])
			best = s
	return best

# --- Instance helpers --------------------------------------------------------------------------

# Total stat bonus of a gear instance: flat per-tag base + all affixes. {stat: amount}
func instance_bonus(inst: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for s in ITEMS.get(inst.get("base", ""), {}).get("tags", []):
		out[s] = int(out.get(s, 0)) + BASE_BONUS_PER_TAG
	for af in inst.get("affixes", []):
		if af.has("stat"):   # effect-affixes carry no stat — skip them here (see combat_effects)
			out[af["stat"]] = int(out.get(af["stat"], 0)) + int(af["amount"])
	return out

# Effect-affixes prefix the base name with their adjective ("Savage War Hammer", "Burning Ring").
# The FIRST effect wins the prefix (an item with two effects still reads as one flavourful name).
func instance_name(inst: Dictionary) -> String:
	var base_name := item_name(inst.get("base", ""))
	for af in inst.get("affixes", []):
		if af.has("effect"):
			return "%s %s" % [EFFECT_AFFIXES[String(af["effect"])]["adj"], base_name]
	return base_name

# One affix's readout. Rate effects show "/s" (Burn 1.2/s, Regen 1.5/s); DR/dodge are already in
# percent-points (Armor 6%, Dodge 4%); fraction effects scale to % (Crit 11%, Leech 9%, Chill 35%).
func effect_label(af: Dictionary) -> String:
	var e := String(af.get("effect", ""))
	var p := float(af.get("power", 0.0))
	var lbl := String(EFFECT_AFFIXES.get(e, {}).get("label", e))
	match e:
		"burn", "regen": return "%s %.1f/s" % [lbl, p]
		"armor", "dodge": return "%s %d%%" % [lbl, roundi(p)]
		_: return "%s %d%%" % [lbl, roundi(p * 100.0)]

# Effective per-hit damage of a weapon for a wielder's stats (melee scales STR, ranged INT).
func effective_weapon_damage(base: String, stats: Dictionary) -> float:
	var w := weapon_stats(base)
	if String(w.get("type", "melee")) == "ranged":
		return float(w["damage"]) * (1.0 + int(stats.get("INT", 0)) * RANGED_DMG_PER_INT)
	return float(w["damage"]) * (1.0 + int(stats.get("STR", 0)) * MELEE_DMG_PER_STR)

# Sustained DPS = effective per-hit ÷ cooldown — the true "which weapon hits harder" comparison.
func effective_weapon_dps(base: String, stats: Dictionary) -> float:
	var w := weapon_stats(base)
	return effective_weapon_damage(base, stats) / maxf(0.05, float(w.get("cooldown", 0.5)))

# "melee 2.4 dmg · 4.3 DPS · +4 STR · Crit 11%"  (weapon line first, effects last). Passing `stats`
# shows STAT-SCALED effective damage + DPS so weapons are comparable; without it, the base number.
func instance_desc(inst: Dictionary, stats: Dictionary = {}) -> String:
	var parts: PackedStringArray = []
	var base := String(inst.get("base", ""))
	if ITEMS.get(base, {}).has("weapon"):
		var w: Dictionary = ITEMS[base]["weapon"]
		if stats.is_empty():
			parts.append("%s %.1f dmg" % [w["type"], w["damage"]])
		else:
			parts.append("%s %.1f dmg · %.1f DPS" % [w["type"], effective_weapon_damage(base, stats), effective_weapon_dps(base, stats)])
	var b := instance_bonus(inst)
	for s in b:
		parts.append("+%d %s" % [int(b[s]), s])
	for af in inst.get("affixes", []):
		if af.has("effect"):
			parts.append(effect_label(af))
	return " · ".join(parts)
