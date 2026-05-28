# HealthBar.gd
# A tiny floating HP bar drawn above an entity. Reads its sibling HealthComponent and
# redraws on change. Cheap (immediate-mode _draw, no extra nodes).
extends Node2D

@export var width: float = 40.0
@export var height: float = 5.0
@export var y_offset: float = -40.0

var _cur: float = 1.0
var _max: float = 1.0

func _ready() -> void:
	var hc := get_parent().get_node_or_null("HealthComponent")
	if hc:
		hc.health_changed.connect(_on_changed)
		_cur = hc.current_hearts
		_max = hc.max_hearts
	queue_redraw()

func _on_changed(current: float, maximum: float) -> void:
	_cur = current
	_max = maximum
	queue_redraw()

func _draw() -> void:
	if _max <= 0.0:
		return
	var x := -width * 0.5
	draw_rect(Rect2(x - 1.0, y_offset - 1.0, width + 2.0, height + 2.0), Color(0, 0, 0, 0.7))
	var frac := clampf(_cur / _max, 0.0, 1.0)
	if frac > 0.0:
		draw_rect(Rect2(x, y_offset, width * frac, height), Color(1.0, 0.25, 0.32))
