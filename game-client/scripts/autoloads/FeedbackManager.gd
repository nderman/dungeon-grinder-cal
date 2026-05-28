# FeedbackManager.gd (Autoload)
# The "Juice." Listens on SignalBus and produces code-driven feedback (no art assets yet):
# camera shake + floating world text. Swap these for real VFX/SFX particles later.
# Register in Project Settings > Autoload as "FeedbackManager" (after SignalBus).
extends Node

func _ready() -> void:
	SignalBus.dr_triggered.connect(_on_dr)
	SignalBus.player_damaged.connect(_on_player_damaged)
	SignalBus.enemy_cancelled.connect(_on_enemy_cancelled)

func _on_dr(location: Vector2) -> void:
	_floating_text("CLINK!", location, Color(0.8, 0.9, 1.0))
	_shake(3.0)

func _on_player_damaged(_hearts: int) -> void:
	_shake(8.0)

func _on_enemy_cancelled(location: Vector2, ratings: int) -> void:
	_floating_text("+%d" % ratings, location, Color(1.0, 0.85, 0.2))

func _shake(amount: float) -> void:
	var cam := _camera()
	if cam == null:
		return
	var tw := create_tween()
	for _i in 4:
		tw.tween_property(cam, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

# World-space floating text = Node2D holder (follows the camera) + a Label child.
func _floating_text(text: String, pos: Vector2, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = 100
	scene.add_child(holder)
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = Vector2(-18, -12)
	holder.add_child(label)
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "position", holder.position + Vector2(0, -28), 0.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(holder.queue_free)

func _camera() -> Camera2D:
	var vp := get_viewport()
	return vp.get_camera_2d() if vp else null
