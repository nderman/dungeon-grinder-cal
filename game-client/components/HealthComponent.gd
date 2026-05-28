# HealthComponent.gd
# The "Small Pool" heart system + permadeath ("Cancelled") state.
# Hearts are stored as float to support half-heart weapon/spell damage (0.5, 1.5).
# 1 heart per 5 CON is computed by the Player and passed to initialize_health().
extends Node2D
class_name HealthComponent

var max_hearts: float = 3.0
var current_hearts: float = 3.0
var is_player: bool = false

# Enemies set this in their scene to self-initialize their pool.
# The Player leaves it 0 and instead calls initialize_health() from CON.
@export var configured_hearts: float = 0.0
@export var xp_reward: int = 0               # XP this mob pays on death (bosses set higher)
@export var iframe_seconds: float = 0.4      # brief post-hit invulnerability (player)
var _invuln: bool = false

signal health_changed(current: float, maximum: float)
signal health_depleted

func _ready() -> void:
	if configured_hearts > 0.0:
		initialize_health(configured_hearts)

func initialize_health(heart_count: float) -> void:
	max_hearts = maxf(1.0, heart_count)
	current_hearts = max_hearts
	is_player = get_parent().is_in_group("player")
	health_changed.emit(current_hearts, max_hearts)

# Damage arrives in HEARTS, already filtered through the ProtectionComponent.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_hearts <= 0.0 or _invuln:
		return
	current_hearts = clampf(current_hearts - amount, 0.0, max_hearts)
	health_changed.emit(current_hearts, max_hearts)
	if is_player:
		SignalBus.player_damaged.emit(int(ceil(current_hearts)))
	if current_hearts <= 0.0:
		_on_cancelled()
	elif is_player and iframe_seconds > 0.0:
		_grant_iframes()

func is_invulnerable() -> bool:
	return _invuln

# Used by the Player to grant i-frames during a Dash.
func set_invulnerable(v: bool) -> void:
	_invuln = v

func _grant_iframes() -> void:
	_invuln = true
	await get_tree().create_timer(iframe_seconds).timeout
	_invuln = false

func heal(amount: float) -> void:
	current_hearts = minf(current_hearts + amount, max_hearts)
	health_changed.emit(current_hearts, max_hearts)

func _on_cancelled() -> void:
	health_depleted.emit()
	if is_player:
		GameManager.end_run()   # Save meta-progression, fade to the Green Room.
	else:
		SignalBus.enemy_cancelled.emit(global_position, 10)   # audience/Ratings rail
		if xp_reward > 0:
			SignalBus.xp_awarded.emit(xp_reward)              # character-growth rail
		get_parent().queue_free()
