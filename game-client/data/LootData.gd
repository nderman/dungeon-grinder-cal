# LootData.gd (Autoload)
# Loot-box tiers + the item pool + the Director's Algorithm roll. Opened items are rolled into
# INSTANCES: a base item + a RARITY (Common→Legendary) + rolled AFFIXES (extra stat bonuses).
# Rarity = number of affix slots, so higher-tier boxes drop more "custom" gear. Gear equips into
# full-body slots (Head/Chest/Legs/Hands/Weapon/Ring); consumables stock the quick bar.
extends Node

enum Tier { BRONZE, SILVER, GOLD, PLATINUM, LEGENDARY, CELESTIAL }
const TIER_NAMES := ["Bronze", "Silver", "Gold", "Platinum", "Legendary", "Celestial"]

# Item rarity (number of affixes = rarity index). Colour tints the inventory entry.
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(0.85, 0.85, 0.85), Color(0.4, 0.9, 0.45), Color(0.4, 0.65, 1.0),
	Color(0.75, 0.45, 1.0), Color(1.0, 0.65, 0.25),
]

const SLOTS := ["Head", "Chest", "Legs", "Hands", "Weapon", "Ring"]
const STAT_KEYS := ["STR", "DEX", "INT", "CON", "CHA"]
const BASE_BONUS_PER_TAG := 2   # a gear item's flat bonus to each of its tagged stats

# id -> { name, tags (stat affinities), min_tier, slot (gear) | kind:"consumable" }
const ITEMS := {
	"health_potion":       {"name": "Health Potion",                "tags": ["CON"],        "min_tier": 0, "kind": "consumable"},
	"mana_battery":        {"name": "Mana Battery",                 "tags": ["INT"],        "min_tier": 0, "kind": "consumable"},
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
	# --- Weapons (the equipped Weapon-slot item drives the attack via its `weapon` block) ---
	"rusty_shiv":     {"name": "Rusty Shiv",     "tags": ["STR"], "min_tier": 0, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 0.7, "cooldown": 0.40, "range": 90.0, "arc": 120.0, "knock": 40.0}},
	"pipe_wrench":    {"name": "Pipe Wrench",    "tags": ["STR"], "min_tier": 1, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 1.1, "cooldown": 0.52, "range": 104.0, "arc": 120.0, "knock": 64.0}},
	"cleaver":        {"name": "Bone Cleaver",   "tags": ["STR"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "melee",  "damage": 1.7, "cooldown": 0.70, "range": 98.0, "arc": 110.0, "knock": 55.0}},
	"glitch_pistol":  {"name": "Glitch Pistol",  "tags": ["INT"], "min_tier": 1, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 0.6, "cooldown": 0.28, "spread": 6.0}},
	"scrap_smg":      {"name": "Scrap SMG",      "tags": ["DEX"], "min_tier": 2, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 0.35, "cooldown": 0.12, "spread": 16.0}},
	"rail_spike":     {"name": "Rail Spike",     "tags": ["DEX"], "min_tier": 3, "slot": "Weapon", "weapon": {"type": "ranged", "damage": 1.8, "cooldown": 0.85, "spread": 2.0}},
	"golden_toaster": {"name": "God-Emperor's Golden Toaster", "tags": ["INT", "STR"], "min_tier": 4, "slot": "Weapon", "weapon": {"type": "melee", "damage": 2.6, "cooldown": 0.6, "range": 112.0, "arc": 130.0, "knock": 80.0}},
}

# The attack you have with no weapon equipped (a weak melee jab). Also the template for `weapon`.
const FISTS := {"type": "melee", "damage": 0.4, "cooldown": 0.45, "range": 80.0, "arc": 110.0, "knock": 25.0}

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

# --- Consumables (unchanged: CON→heal, INT→mana, scaled by box tier) ---------------------------

func consumable_effect(id: String, tier: int) -> Dictionary:
	var tags: Array = ITEMS.get(id, {}).get("tags", [])
	if "CON" in tags:
		return {"stat": "CON", "amount": (1 + tier) * 20}
	if "INT" in tags:
		return {"stat": "INT", "amount": (1 + tier) * 10}
	return {"stat": "", "amount": 0}

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
