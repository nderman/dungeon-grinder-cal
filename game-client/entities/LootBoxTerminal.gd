# LootBoxTerminal.gd
# Safe-Room terminal. Press interact (E) while standing on it to decrypt ALL pending
# Loot Boxes at once — the only place boxes can be opened (DCC rule).
extends Area2D

var _player: Node = null

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player = b

func _on_exited(b: Node) -> void:
	if b == _player:
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event.is_action_pressed("interact"):
		return
	var stats: Dictionary = _player.current_stats if "current_stats" in _player else {}
	AchievementManager.open_all_boxes(stats)
