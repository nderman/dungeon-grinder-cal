# LootData.gd (Autoload)
# Loot-box tiers + the item pool, and the Director's Algorithm roll (build-aware).
# DCC tiers, low→high: Bronze, Silver, Gold, Platinum, Legendary, Celestial.
extends Node

enum Tier { BRONZE, SILVER, GOLD, PLATINUM, LEGENDARY, CELESTIAL }
const TIER_NAMES := ["Bronze", "Silver", "Gold", "Platinum", "Legendary", "Celestial"]

# id -> { name, tags (stat affinities), min_tier (lowest box that can contain it),
#         kind (optional: "consumable" — anything else is auto-applied passive gear) }
# Gear grants +(1+box_tier) to each tagged stat. Consumables (CON→heal, INT→mana) are
# used from the quick bar; their magnitude also scales with the box tier.
const ITEMS := {
	"health_potion":       {"name": "Health Potion",                "tags": ["CON"],        "min_tier": 0, "kind": "consumable"},
	"mana_battery":        {"name": "Mana Battery",                 "tags": ["INT"],        "min_tier": 0, "kind": "consumable"},
	"spiked_pauldrons":    {"name": "Spiked Pauldrons",             "tags": ["STR"],        "min_tier": 0},
	"hype_stim":           {"name": "Hype Stim",                    "tags": ["CHA"],        "min_tier": 0},
	"lead_lined_vest":     {"name": "Lead-Lined Vest",              "tags": ["CON"],        "min_tier": 1},
	"sponsors_monocle":    {"name": "Sponsor's Monocle",            "tags": ["CHA"],        "min_tier": 1},
	"overclocked_greaves": {"name": "Overclocked Greaves",          "tags": ["DEX"],        "min_tier": 1},
	"chain_lightning":     {"name": "Chain Lightning",              "tags": ["INT"],        "min_tier": 2},
	"hazard_boots":        {"name": "Hazard Boots",                 "tags": ["CON", "DEX"], "min_tier": 2},
	"gravity_spike":       {"name": "Gravity Spike",                "tags": ["INT"],        "min_tier": 3},
	"golden_toaster":      {"name": "God-Emperor's Golden Toaster", "tags": ["INT", "STR"], "min_tier": 4},
}

func tier_name(t: int) -> String:
	return TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)]

func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)

func is_consumable(id: String) -> bool:
	return ITEMS.get(id, {}).get("kind", "gear") == "consumable"

# Single source of truth for a consumable's effect: {stat, amount}. CON heals (1+tier)
# hearts; INT restores (1+tier)*10 mana. Used by both apply (Player) and describe (tooltip).
func consumable_effect(id: String, tier: int) -> Dictionary:
	var tags: Array = ITEMS.get(id, {}).get("tags", [])
	if "CON" in tags:
		return {"stat": "CON", "amount": 1 + tier}
	if "INT" in tags:
		return {"stat": "INT", "amount": (1 + tier) * 10}
	return {"stat": "", "amount": 0}

# Passive gear bonus: each tagged stat gets +(1 + box tier). Returned as a {stat: amount}
# dict so the bonus can be subtracted cleanly when equip-slots / dropping arrive.
func gear_bonus(id: String, tier: int) -> Dictionary:
	var out: Dictionary = {}
	var amount := 1 + tier
	for s in ITEMS.get(id, {}).get("tags", []):
		out[s] = amount
	return out

# Human-readable bonus line, e.g. "+3 STR, +3 INT" or "Heal 3♥" / "+30 Mana".
func describe(id: String, tier: int) -> String:
	if is_consumable(id):
		var e := consumable_effect(id, tier)
		match e["stat"]:
			"CON": return "Heal %d♥" % int(e["amount"])
			"INT": return "+%d Mana" % int(e["amount"])
			_: return "Consumable"
	var parts: PackedStringArray = []
	var b := gear_bonus(id, tier)
	for s in b:
		parts.append("+%d %s" % [int(b[s]), s])
	return ", ".join(parts)

# Pick an item fit for the box tier, weighted toward the crawler's build.
func roll(tier: int, stats: Dictionary) -> String:
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

func _top_stat(stats: Dictionary) -> String:
	var best := ""
	var best_val := -1.0
	for s in stats:
		if float(stats[s]) > best_val:
			best_val = float(stats[s])
			best = s
	return best
