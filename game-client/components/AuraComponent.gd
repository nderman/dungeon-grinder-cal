# AuraComponent.gd
# Support enemy aura: every tick, helps nearby ALLY enemies (not itself, not the player) — a DR buff
# (Shield-Bot Cleric) and/or HP regen (Healer). The DR buff re-applies with a short expiry so it
# fades when the support dies / an ally leaves range. Draws a faint ring so the zone is readable.
# Kill the support first or its cluster won't die. Reused by both the Cleric and the Healer.
extends Node2D
class_name AuraComponent

@export var aura_dr: float = 0.0        # % DR granted to allies in range (0 = none)
@export var heal_per_tick: float = 0.0  # HP restored to each ally in range per tick (0 = none)
@export var radius: float = 200.0
@export var tick: float = 0.3           # how often the aura pulses
@export var buff_duration: float = 0.6  # ally keeps the DR this long after the last refresh
@export var ring_color: Color = Color(0.4, 0.7, 1.0, 0.22)

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
		if aura_dr > 0.0:
			var prot := e.get_node_or_null("ProtectionComponent")
			if prot and prot.has_method("apply_aura"):
				prot.apply_aura(aura_dr, buff_duration)
		if heal_per_tick > 0.0:
			var hc := e.get_node_or_null("HealthComponent")
			if hc and hc.has_method("heal"):
				hc.heal(heal_per_tick)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring_color, 2.0, true)
