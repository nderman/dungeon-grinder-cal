# BossPhaseComponent.gd
# The boss lifecycle all three bosses re-implemented by hand: a one-shot ENRAGE the first time HP
# crosses a threshold (with the audience DRAMA_SPIKE) and a FATALITY pop + toast on death. Watches the
# sibling HealthComponent; the boss script just connects `enraged` to its own escalation and sets
# `defeat_toast`. A COMPONENT, not a base class (composition mandate) — drop it on any future boss.
class_name BossPhaseComponent
extends Node

@export var enrage_threshold: float = 0.5   # enrage when current HP first drops to/below this fraction of max
@export var defeat_toast: String = "BOSS DOWN!"

signal enraged   # emitted once, the first time HP crosses the threshold

var _enraged: bool = false

func _ready() -> void:
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		push_warning("[BossPhaseComponent] no sibling HealthComponent on %s" % get_parent().name)
		return
	health.health_changed.connect(_on_health_changed)
	health.health_depleted.connect(_on_defeated)

func _on_health_changed(current: float, maximum: float) -> void:
	if _enraged or current <= 0.0 or current > maximum * enrage_threshold:
		return
	_enraged = true
	enraged.emit()                                   # boss applies its own escalation first…
	SignalBus.ratings_spike.emit("DRAMA_SPIKE")      # …then the audience loses it

func _on_defeated() -> void:
	SignalBus.ratings_spike.emit("FATALITY")
	var p := get_parent()
	SignalBus.toast.emit(defeat_toast, (p as Node2D).global_position if p is Node2D else Vector2.ZERO)
