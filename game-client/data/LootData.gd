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
	"scrap_club":     {"name": "Scrap Club",     "tags": ["STR"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.9, "cooldown": 0.56, "range": 76.0, "arc": 104.0, "knock": 58.0}},
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
	var affixes := []
	for _i in range(rarity):
		affixes.append({"stat": STAT_KEYS.pick_random(), "amount": randi_range(1, 2 + tier)})
	return {"kind": "gear", "base": base, "slot": ITEMS[base].get("slot", "Trinket"), "rarity": rarity, "affixes": affixes}

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
		out[af["stat"]] = int(out.get(af["stat"], 0)) + int(af["amount"])
	return out

func instance_name(inst: Dictionary) -> String:
	return item_name(inst.get("base", ""))

# "melee 1.7 dmg · +4 STR, +2 INT"  (weapon line first if it's a weapon)
func instance_desc(inst: Dictionary) -> String:
	var parts: PackedStringArray = []
	var base := String(inst.get("base", ""))
	if ITEMS.get(base, {}).has("weapon"):
		var w: Dictionary = ITEMS[base]["weapon"]
		parts.append("%s %.1f dmg" % [w["type"], w["damage"]])
	var b := instance_bonus(inst)
	for s in b:
		parts.append("+%d %s" % [int(b[s]), s])
	return " · ".join(parts)
