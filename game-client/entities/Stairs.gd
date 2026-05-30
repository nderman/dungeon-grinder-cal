# Stairs.gd
# A floor exit. Several are scattered across non-boss rooms — always VISIBLE so you can see where
# the exits are, but LOCKED until the stairs open (Floor Boss dies OR the timer elapses, via
# GameManager.stairs_opened). Stepping onto an open stair descends to the next floor.
extends Area2D

@onready var _label: Label = $Label
var _open: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	GameManager.stairs_opened.connect(_unlock)
	if GameManager.stairs_open:
		_unlock()
	else:
		_set_locked()

func _set_locked() -> void:
	modulate = Color(0.55, 0.55, 0.6, 0.7)   # dimmed = not yet usable
	_label.text = "STAIRS (LOCKED)"

func _unlock() -> void:
	_open = true
	modulate = Color(1, 1, 1, 1)
	_label.text = "STAIRS DOWN"
	# If the player was parked here waiting for the timer, body_entered won't re-fire — descend now.
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			GameManager.descend()
			return

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _open:
		GameManager.descend()
	else:
		SignalBus.toast.emit("Stairs locked — clear the boss or wait", global_position)
