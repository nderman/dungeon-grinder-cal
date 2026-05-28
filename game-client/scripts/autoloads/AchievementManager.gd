# AchievementManager.gd (Autoload)
# The "System AI": watches SignalBus, unlocks achievements, and grants Loot Boxes.
# Boxes queue on GameManager.earned_loot_boxes and open only in a Safe Room (DCC rule),
# all at once, low tier -> high, via open_all_boxes().
# Register AFTER SignalBus / MetaManager / GameManager / LootData / AchievementData.
extends Node

func _ready() -> void:
	SignalBus.enemy_cancelled.connect(_on_enemy_cancelled)
	SignalBus.ratings_spike.connect(_on_spike)
	SignalBus.phasedoor_discovered.connect(_on_phasedoor)

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

# Award an achievement + its Loot Box. One-time ones persist; repeatable ones re-grant.
func unlock(id: String) -> void:
	if not AchievementData.ACHIEVEMENTS.has(id):
		return
	var a: Dictionary = AchievementData.ACHIEVEMENTS[id]
	if not a["repeatable"]:
		if id in MetaManager.unlocked_achievements:
			return
		MetaManager.unlocked_achievements.append(id)
		MetaManager.save_persistence()
	GameManager.earned_loot_boxes.append(int(a["tier"]))
	SignalBus.achievement_unlocked.emit(a["title"])

# Safe-Room only: open every pending box at once, low tier -> high (DCC).
func open_all_boxes(stats: Dictionary) -> void:
	if GameManager.earned_loot_boxes.is_empty():
		SignalBus.toast.emit("No boxes to open.", _player_pos())
		return
	var boxes: Array = GameManager.earned_loot_boxes.duplicate()
	GameManager.earned_loot_boxes.clear()
	boxes.sort()
	for tier in boxes:
		SignalBus.box_opened.emit(LootData.tier_name(int(tier)))
		var item := LootData.roll(int(tier), stats)
		if item != "":
			GameManager.run_inventory.append(item)
			SignalBus.item_acquired.emit(LootData.ITEMS[item]["name"])

func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p.global_position if p else Vector2.ZERO
