# ManaComponent.gd
# Passive energy pool for universal Nano-Magic. INT drives both depth and refill rate.
#   max_mana = INT * 5     (10 INT = 50)
#   regen    = base * (1 + INT * 0.02)
extends Node2D
class_name ManaComponent

var max_mana: float = 50.0
var current_mana: float = 50.0
var base_regen_rate: float = 5.0   # mana/sec
var current_regen_rate: float = 5.0

func initialize_mana(int_stat: int) -> void:
	max_mana = int_stat * 12.0   # DCC scale: INT ~4 → ~48 (held from the old INT×5 at INT 10)
	current_mana = max_mana
	current_regen_rate = base_regen_rate * (1.0 + (int_stat * 0.05))
	SignalBus.mana_updated.emit(current_mana, max_mana)

# Grow the pool from an INT change without a free refill (mirrors HealthComponent.set_max_hearts).
func set_max_mana(int_stat: int) -> void:
	var new_max := int_stat * 12.0
	var delta := new_max - max_mana
	max_mana = new_max
	current_mana = clampf(current_mana + maxf(0.0, delta), 0.0, max_mana)
	current_regen_rate = base_regen_rate * (1.0 + (int_stat * 0.05))
	SignalBus.mana_updated.emit(current_mana, max_mana)

func _physics_process(delta: float) -> void:
	if current_mana < max_mana:
		var prev := current_mana
		current_mana = move_toward(current_mana, max_mana, current_regen_rate * delta)
		if floor(prev) != floor(current_mana):
			SignalBus.mana_updated.emit(current_mana, max_mana)

func consume_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		SignalBus.mana_updated.emit(current_mana, max_mana)
		return true
	SignalBus.mana_depleted.emit()   # HUD glitch + Cal's snark
	return false

func restore_mana(amount: float) -> void:
	current_mana = clampf(current_mana + amount, 0.0, max_mana)
	SignalBus.mana_updated.emit(current_mana, max_mana)
