# AuraComponent.gd
# Support buff (Shield-Bot Cleric): every tick, grants a DR aura to nearby ALLY enemies (not itself,
# not the player). The buff is re-applied with a short expiry, so it fades shortly after the cleric
# dies or an ally leaves range. Draws a faint ring so the protected zone is readable.
extends Node2D
class_name AuraComponent

@export var aura_dr: float = 50.0       # % DR granted to allies in range
@export var radius: float = 200.0
@export var tick: float = 0.3           # how often the buff is refreshed
@export var buff_duration: float = 0.6  # ally keeps it this long after the last refresh

var _accum: float = 0.0

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < tick:
		return
	_accum = 0.0
	var here := global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == get_parent() or not (e is Node2D):
			continue
		if here.distance_to((e as Node2D).global_position) > radius:
			continue
		var prot := e.get_node_or_null("ProtectionComponent")
		if prot and prot.has_method("apply_aura"):
			prot.apply_aura(aura_dr, buff_duration)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 0.7, 1.0, 0.22), 2.0, true)
