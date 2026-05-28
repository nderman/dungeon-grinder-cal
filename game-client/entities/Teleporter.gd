# Teleporter.gd
# Interact-to-use pad (press the interact key while standing on it — no walk-into loops).
# TO_SAFE_ROOM: a Phase-Door. Records your return spot and warps you to the shared Safe Room.
# FROM_SAFE_ROOM: the Safe Room's exit portal. Warps you back to where you phased in.
extends Area2D
class_name Teleporter

enum Mode { TO_SAFE_ROOM, FROM_SAFE_ROOM }
@export var mode: Mode = Mode.TO_SAFE_ROOM

var _player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event.is_action_pressed("interact"):
		return
	if mode == Mode.TO_SAFE_ROOM:
		var entry := get_tree().get_first_node_in_group("safe_room_entry") as Node2D
		if entry:
			GameManager.last_safe_room_entrance_pos = global_position
			_player.global_position = entry.global_position
			SignalBus.phasedoor_discovered.emit(global_position)
	else:
		_player.global_position = GameManager.last_safe_room_entrance_pos
