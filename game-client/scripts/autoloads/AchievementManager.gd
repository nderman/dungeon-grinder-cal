# AchievementManager.gd (Autoload)
# The "System AI": watches SignalBus, unlocks achievements, and grants Loot Boxes.
# Boxes queue on GameManager.earned_loot_boxes and open only in a Safe Room (DCC rule),
# all at once, low tier -> high, via open_all_boxes().
# Register AFTER SignalBus / MetaManager / GameManager / LootData / AchievementData.
extends Node

var _run_unlocked: Array[String] = []   # "run"-scope achievements already granted this Episode

func _ready() -> void:
	SignalBus.enemy_cancelled.connect(_on_enemy_cancelled)
	SignalBus.ratings_spike.connect(_on_spike)
	SignalBus.phasedoor_discovered.connect(_on_phasedoor)
	SignalBus.run_started.connect(func(): _run_unlocked.clear())

func _on_enemy_cancelled(_loc: Vector2, _ratings: int) -> void:
	unlock("first_blood")

func _on_phasedoor(_loc: Vector2) -> void:
	unlock("phase_finder")

func _on_spike(type: String) -> void:
	match type:
		"SPEED_DEMON": unlock("speed_demon")
		"NEAR_DEATH": unlock("near_death")
		"UNTOUCHABLE": unlock("untouchable")
		"FATALITY": unlock("boss_slayer")
		"CROWD_PLEASER": unlock("crowd_pleaser")

# Award an achievement + its Loot Box. Dedup depends on scope:
#   run        → once per run (reset on run_started)
#   lifetime   → once ever (persisted to disk)
#   repeatable → always fires, but the BOX is floor-gated (see below)
func unlock(id: String) -> void:
	if not AchievementData.ACHIEVEMENTS.has(id):
		return
	var a: Dictionary = AchievementData.ACHIEVEMENTS[id]
	match a.get("scope", "repeatable"):
		"lifetime":
			if id in MetaManager.unlocked_achievements:
				return
			MetaManager.unlocked_achievements.append(id)
			MetaManager.save_persistence()
		"run":
			if id in _run_unlocked:
				return
			_run_unlocked.append(id)
		_:
			# Repeatable performance feats are the loot drip. The System spoils rookies (DCC canon:
			# floors 1-3 spam low-tier boxes to get them experimenting), then raises its standards —
			# a small feat that paid a box up top earns only a heckle once you're deep. Real
			# milestones (run/lifetime) are exempt: a first is always a first, at any depth.
			if int(a["tier"]) < _min_rewarded_tier():
				SignalBus.achievement_unlocked.emit("%s — %s" % [a["title"], _heckle()])
				return
	GameManager.add_loot_box(int(a["tier"]))
	# Name the box tier so the ticker tells you what you actually won.
	SignalBus.achievement_unlocked.emit("%s — %s Box" % [a["title"], LootData.tier_name(int(a["tier"]))])

# The System's boredom threshold: the lowest box tier it still bothers awarding for a *repeat*
# feat at the current depth. Floors 1-3 reward everything (tutorial drip); it demands bigger feats
# the deeper you go, so the early-game loot fountain tapers into "impress me" without ever drying up
# (boss kills are tier 2 and always pay).
func _min_rewarded_tier() -> int:
	var f: int = GameManager.current_floor
	if f <= 3:
		return 0
	elif f <= 6:
		return 1
	return 2

const HECKLES: Array[String] = [
	"seen it.", "the audience yawns.", "cute, no box.",
	"do better.", "old news.", "unimpressed.", "try harder, meatbag.",
]

func _heckle() -> String:
	return HECKLES.pick_random()

# Safe-Room only: open every pending box at once, low tier -> high (DCC).
func open_all_boxes(stats: Dictionary) -> void:
	if GameManager.earned_loot_boxes.is_empty():
		SignalBus.toast.emit("No boxes to open.", _player_pos())
		return
	var boxes: Array = GameManager.earned_loot_boxes.duplicate()
	GameManager.earned_loot_boxes.clear()
	GameManager.loot_boxes_changed.emit(0)   # pending counter back to zero
	boxes.sort()
	for tier in boxes:
		SignalBus.box_opened.emit(LootData.tier_name(int(tier)))
		var inst := LootData.roll(int(tier), stats)
		if inst.is_empty():
			continue
		# Consumables stock the quick bar; gear becomes an instance (auto-equip empty slot, else bag).
		if inst["kind"] == "consumable":
			GameManager.add_consumable(String(inst["base"]), int(tier))
			SignalBus.item_acquired.emit(LootData.item_name(inst["base"]))
		else:
			GameManager.add_loot_instance(inst)
			SignalBus.item_acquired.emit("%s %s" % [LootData.rarity_name(int(inst["rarity"])), LootData.instance_name(inst)])

func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p.global_position if p else Vector2.ZERO
