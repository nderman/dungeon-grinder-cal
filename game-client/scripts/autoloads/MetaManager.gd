# MetaManager.gd (Autoload)
# The Network's persistent memory — the only thing that survives a "Cancellation".
# Handles meta-currency, milestone tokens, unlocked roster, and disk persistence.
# Register in Project Settings > Autoload as "MetaManager".
extends Node

const SAVE_PATH := "user://meta_progression.cfg"

# Baseline stats every contestant starts from before race/class bonuses.
const BASE_STATS := {"STR": 10, "DEX": 10, "INT": 10, "CON": 10, "CHA": 10}

# --- PERSISTENT (cross-run) ---
var syndication_points: int = 0
var milestone_tokens: int = 0
var unlocked_races: Array[String] = ["Human"]
var unlocked_classes: Array[String] = ["Brawler", "Scavenger"]
var permanent_loot_pool: Array[String] = []      # IDs available to the Director's Algorithm
var permanent_stat_buffs: Dictionary = {}         # +1s from Artifact-tier injectors
var unlocked_achievements: Array[String] = []     # one-time achievements already earned

# --- RUN CACHE (cleared on death) ---
var total_injections_this_run: int = 0

signal meta_changed

func _ready() -> void:
	load_persistence()

# Cal's Note: bank a milestone token. Floors 3/6/9 each pay one.
func add_milestone_token(_tier: int) -> void:
	milestone_tokens += 1
	save_persistence()
	meta_changed.emit()

# Spend one token to permanently contract a new race OR class (never both per token).
func unlock_content(id: String, type: String) -> bool:
	if milestone_tokens <= 0:
		print("Cal: No tokens, no toys. Survive deeper.")
		return false
	match type:
		"race":
			if id in unlocked_races: return false
			unlocked_races.append(id)
		"class":
			if id in unlocked_classes: return false
			unlocked_classes.append(id)
		_:
			push_warning("Cal: Unknown unlock type '%s'." % type)
			return false
	milestone_tokens -= 1
	save_persistence()
	meta_changed.emit()
	return true

# Final stat block for the current contract = base + race + class (+ permanent buffs).
func get_current_contestant_stats(race: String, contestant_class: String) -> Dictionary:
	var stats := BASE_STATS.duplicate()
	for s in RaceData.get_bonuses(race):
		stats[s] += RaceData.get_bonuses(race)[s]
	for s in ClassData.get_bonuses(contestant_class):
		stats[s] += ClassData.get_bonuses(contestant_class)[s]
	for s in permanent_stat_buffs:
		stats[s] = stats.get(s, 0) + permanent_stat_buffs[s]
	return stats

func add_to_inventory(item: Variant) -> void:
	if item is String and item not in permanent_loot_pool:
		permanent_loot_pool.append(item)
	save_persistence()

func reset_run_cache() -> void:
	total_injections_this_run = 0

func save_persistence() -> void:
	# Cal's Note: write the fans' money to disk so we never lose a cent.
	var cfg := ConfigFile.new()
	cfg.set_value("Progression", "syndication_points", syndication_points)
	cfg.set_value("Progression", "milestone_tokens", milestone_tokens)
	cfg.set_value("Unlocks", "races", unlocked_races)
	cfg.set_value("Unlocks", "classes", unlocked_classes)
	cfg.set_value("Unlocks", "loot_pool", permanent_loot_pool)
	cfg.set_value("Unlocks", "stat_buffs", permanent_stat_buffs)
	cfg.set_value("Progression", "achievements", unlocked_achievements)
	cfg.save(SAVE_PATH)

func load_persistence() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # Fresh meat, no history.
	syndication_points = cfg.get_value("Progression", "syndication_points", 0)
	milestone_tokens = cfg.get_value("Progression", "milestone_tokens", 0)
	# .assign() coerces ConfigFile's untyped Arrays into our typed Array[String]s.
	unlocked_races.assign(cfg.get_value("Unlocks", "races", ["Human"]))
	unlocked_classes.assign(cfg.get_value("Unlocks", "classes", ["Brawler", "Scavenger"]))
	permanent_loot_pool.assign(cfg.get_value("Unlocks", "loot_pool", []))
	permanent_stat_buffs = cfg.get_value("Unlocks", "stat_buffs", {})
	unlocked_achievements.assign(cfg.get_value("Progression", "achievements", []))
