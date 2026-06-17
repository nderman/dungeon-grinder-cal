# MeatGrinderGolem.gd
# Floor boss. Reuses the standard components (Health/Movement/AI); this thin entity
# script only adds the 2-phase behaviour: at <=50% HP it ENRAGES (faster telegraphs,
# shorter cooldown, quicker chase) and pops a DRAMA_SPIKE for the audience.
extends CharacterBody2D

@onready var ai: AIComponent = $AIComponent

func _ready() -> void:
	add_to_group("enemies")
	var phase := BossPhaseComponent.new()   # shared enrage/defeat lifecycle (DRAMA_SPIKE + FATALITY + toast)
	phase.defeat_toast = "BOSS DOWN!"
	add_child(phase)
	phase.enraged.connect(_on_enraged)

func _on_enraged() -> void:
	ai.telegraph_duration *= 0.5      # enraged slams come faster
	ai.attack_cooldown *= 0.6
	ai.move_speed *= 1.5
	modulate = Color(1.0, 0.55, 0.55)  # visibly pissed off
