# Player.gd
# The contestant controller. Reads the active contract from GameManager, initializes
# its components from stats, and bridges mobile twin-stick input to movement/combat.
# Expected child nodes: HealthComponent, MovementComponent, ProtectionComponent,
# ManaComponent, WeaponAnchor (Node2D). Player must be in the "player" group.
extends CharacterBody2D

var base_speed: float = 300.0
var current_stats: Dictionary = {"STR": 10, "DEX": 10, "INT": 10, "CON": 10, "CHA": 10}

@onready var health_comp: HealthComponent = $HealthComponent
@onready var move_comp: MovementComponent = $MovementComponent
@onready var protection_comp: ProtectionComponent = $ProtectionComponent
@onready var mana_comp: ManaComponent = $ManaComponent
@onready var weapon_anchor: Node2D = $WeaponAnchor

# Dash
@export var dash_cooldown: float = 1.0
@export var dash_duration: float = 0.2
var _can_dash: bool = true
var _is_dashing: bool = false
var aim_dir: Vector2 = Vector2.RIGHT

# Primary fire: a Glitch Bolt projectile (the universal starter spell).
const BOLT_SCENE := preload("res://entities/projectiles/GlitchBolt.tscn")
@export var fire_cooldown: float = 0.25
var _can_fire: bool = true

func _ready() -> void:
	add_to_group("player")
	_initialize_contestant()

func _initialize_contestant() -> void:
	if not GameManager.current_run_stats.is_empty():
		current_stats = GameManager.current_run_stats
	_calculate_vitals()
	base_speed = 300.0 + (current_stats["DEX"] * 5.0)

func _calculate_vitals() -> void:
	health_comp.initialize_health(floor(current_stats["CON"] / 5.0))   # 1 heart / 5 CON
	protection_comp.base_dr = current_stats["CON"] * ProtectionComponent.DR_PER_CON
	mana_comp.initialize_mana(int(current_stats["INT"]))               # 5 mana / INT

func _physics_process(delta: float) -> void:
	if _is_dashing:
		move_comp.apply_dash_friction(delta)
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim.length() > 0.1:
		aim_dir = aim
		weapon_anchor.rotation = aim.angle()
	if Input.is_action_pressed("fire") and _can_fire:
		_fire()
	move_comp.handle_movement(delta, move, base_speed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and _can_dash:
		_perform_dash()
	elif event.is_action_pressed("nano"):
		execute_nano_magic("glitch_bolt")

func _perform_dash() -> void:
	_is_dashing = true
	_can_dash = false
	# TODO: flip HurtboxComponent monitoring off here for true i-frames.
	move_comp.execute_dash(velocity.normalized())
	await get_tree().create_timer(dash_duration).timeout
	_is_dashing = false
	await get_tree().create_timer(dash_cooldown).timeout
	_can_dash = true

# Universal spell cast — INT scales damage up and cost down.
func execute_nano_magic(spell_id: String) -> void:
	if not NanoMagicLibrary.SPELLS.has(spell_id):
		return
	var spell: Dictionary = NanoMagicLibrary.SPELLS[spell_id]
	var int_stat: int = int(current_stats["INT"])
	var scaled_cost: float = spell["mana_cost"] * (1.0 - (int_stat * 0.01))
	if mana_comp.consume_mana(scaled_cost):
		var scaled_damage: float = spell["damage"] * (1.0 + (int_stat * 0.05))
		SignalBus.spell_cast.emit(spell["name"], global_position)
		_cast_effect(spell["effect_type"], scaled_damage)

func _fire() -> void:
	_can_fire = false
	execute_nano_magic("glitch_bolt")
	await get_tree().create_timer(fire_cooldown).timeout
	_can_fire = true

func _cast_effect(effect_type: String, damage: float) -> void:
	match effect_type:
		"projectile":
			var bolt := BOLT_SCENE.instantiate()
			get_tree().current_scene.add_child(bolt)
			bolt.global_position = weapon_anchor.global_position
			bolt.setup(aim_dir, damage)
		_:
			pass  # TODO: chain_lightning / beam / aoe_pull effects

