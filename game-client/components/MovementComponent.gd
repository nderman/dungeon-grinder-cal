# MovementComponent.gd
# Snappy, "Hotline Miami"-style traversal + the i-frame Dash burst.
# Drives a CharacterBody2D parent. Fed a direction by InputComponent (player) or
# AIComponent (mob) — the component itself doesn't decide WHERE to go.
extends Node2D
class_name MovementComponent

@export_group("Traversal")
@export var acceleration: float = 2500.0
@export var friction: float = 1200.0

@export_group("Dash")
@export var dash_speed: float = 1200.0
@export var dash_friction: float = 3000.0

var parent: CharacterBody2D

func _ready() -> void:
	parent = get_parent() as CharacterBody2D
	if parent == null:
		push_error("Cal: MovementComponent needs a CharacterBody2D parent. Bolt the legs on right.")

func handle_movement(delta: float, input_dir: Vector2, current_speed: float = 300.0) -> void:
	if input_dir.length() > 0.0:
		parent.velocity = parent.velocity.move_toward(input_dir.normalized() * current_speed, acceleration * delta)
	else:
		parent.velocity = parent.velocity.move_toward(Vector2.ZERO, friction * delta)
	parent.move_and_slide()

# One-shot velocity burst. Player.gd owns the i-frame window + cooldown timing.
func execute_dash(direction: Vector2) -> void:
	var dir := direction
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(parent.rotation)
	parent.velocity = dir.normalized() * dash_speed
	SignalBus.player_dashed.emit(parent.global_position)

func apply_dash_friction(delta: float) -> void:
	parent.velocity = parent.velocity.move_toward(Vector2.ZERO, dash_friction * delta)
	parent.move_and_slide()
