# MeatGrinderGolem.gd
# Floor boss. Reuses the standard components (Health/Movement/AI); this thin entity
# script only adds the 2-phase behaviour: at <=50% HP it ENRAGES (faster telegraphs,
# shorter cooldown, quicker chase) and pops a DRAMA_SPIKE for the audience.
extends CharacterBody2D

@onready var ai: AIComponent = $AIComponent
@onready var health: HealthComponent = $HealthComponent
var _enraged: bool = false

func _ready() -> void:
	add_to_group("enemies")
	health.health_changed.connect(_on_health_changed)
	health.health_depleted.connect(_on_defeated)

func _on_defeated() -> void:
	SignalBus.ratings_spike.emit("FATALITY")          # +200 ratings + audience pop
	SignalBus.toast.emit("BOSS DOWN!", global_position)

func _on_health_changed(current: float, maximum: float) -> void:
	if _enraged or current <= 0.0 or current > maximum * 0.5:
		return
	_enraged = true
	ai.telegraph_duration *= 0.5      # enraged slams come faster
	ai.attack_cooldown *= 0.6
	ai.move_speed *= 1.5
	modulate = Color(1.0, 0.55, 0.55)  # visibly pissed off
	SignalBus.ratings_spike.emit("DRAMA_SPIKE")
