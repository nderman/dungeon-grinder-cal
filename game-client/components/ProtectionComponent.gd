# ProtectionComponent.gd
# Probabilistic Damage Resistance (DR). On a successful roll, ONE heart is ignored
# (the satisfying "Clink!"). Sits between the Hitbox and the HealthComponent.
#   Total DR% = (CON * 3.6) + flat gear DR, capped at 75%.  (DCC scale: CON ~5 -> 18%, as before.)
extends Node2D
class_name ProtectionComponent

const DR_PER_CON := 3.6   # CON 5 -> 18% (held from the old CON 12 × 1.5); caps at 75% (~CON 21+)
const DR_CAP := 75.0
const DODGE_PER_DEX := 1.2   # % full-dodge per DEX (DCC: DEX = reflexes/agility); caps at DODGE_CAP
const DODGE_CAP := 35.0      # high-DEX/Nimble dodges a lot, but never half (it stacks ON TOP of DR)

var base_dr: float = 0.0   # set by Player from CON: CON * DR_PER_CON
var gear_dr: float = 0.0   # flat % from armour (e.g. Lead-Lined Vest = 15)
var dodge_chance: float = 0.0   # % to negate a hit entirely; set by Player from DEX (enemies leave 0)
var aura_dr: float = 0.0        # transient % DR granted by a nearby support (Shield-Bot Cleric)
var _aura_until: float = 0.0    # wall-clock (s) the aura buff expires (fades when the cleric dies)

# A support buff grants this much DR for `duration`, re-applied each tick while in range.
func apply_aura(amount: float, duration: float) -> void:
	aura_dr = amount
	_aura_until = Time.get_ticks_msec() / 1000.0 + duration

# Returns the damage (in hearts) that should actually reach the HealthComponent.
func handle_incoming_damage(incoming: float) -> float:
	# DEX reflexes: a clean dodge negates the whole hit before DR even matters.
	if dodge_chance > 0.0 and randf_range(0.0, 100.0) <= dodge_chance:
		SignalBus.toast.emit("DODGE", global_position)
		return 0.0
	var aura := aura_dr if Time.get_ticks_msec() / 1000.0 < _aura_until else 0.0
	var chance := clampf(base_dr + gear_dr + aura, 0.0, DR_CAP)
	if randf_range(0.0, 100.0) <= chance:
		SignalBus.dr_triggered.emit(global_position)   # "Clink!"
		return maxf(0.0, incoming - 1.0)   # mob 1->0, boss 2->1
	return incoming

func update_gear_dr(value: float) -> void:
	gear_dr = value
