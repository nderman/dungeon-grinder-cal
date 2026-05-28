# LootBoxTerminal.gd
# Safe-Room pad. Press interact (E) while standing on it to decrypt ALL pending Loot
# Boxes at once — the only place boxes can be opened (DCC rule).
extends InteractablePad

func _on_interact() -> void:
	var stats: Dictionary = _player.current_stats if "current_stats" in _player else {}
	AchievementManager.open_all_boxes(stats)
