# InteractablePad.gd
# Base for Safe-Room pads. Tracks the player standing on the pad and routes the interact
# button (E) to _on_interact(). Subclass and override _on_interact() — and optionally
# _on_player_left() for cleanup when the player steps off. Shared by LootBoxTerminal +
# LevelTerminal so the enter/exit/interact plumbing lives in exactly one place.
extends Area2D
class_name InteractablePad

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
		_on_player_left()

func _unhandled_input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed("interact"):
		_on_interact()

func _on_interact() -> void:
	pass   # override in subclass

func _on_player_left() -> void:
	pass   # override in subclass (optional)
