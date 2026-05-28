# LevelTerminal.gd
# Safe-Room pad: stand on it and press interact (E) to open the Stat-Injection panel and
# spend banked skill points. Sibling of the LootBoxTerminal; both are Safe-Room-only.
extends Area2D

@onready var panel := $LevelUpPanel
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
		panel.close()   # leaving the pad closes the screen

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event.is_action_pressed("interact"):
		return
	panel.toggle()
