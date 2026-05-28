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

# Melee (STR): a short, strong close-range swing — you must close the gap to use it.
# Both the damage and the knockback shove scale with STR.
@export var melee_cooldown: float = 0.5
const MELEE_RANGE := 96.0
const MELEE_ARC_DEG := 120.0
const MELEE_BASE_DMG := 0.5         # hearts, before STR scaling
const MELEE_DMG_PER_STR := 0.1      # STR 10 → ×2.0 = 1.0 heart
const MELEE_KNOCK_BASE := 48.0      # px shove on hit
const MELEE_KNOCK_PER_STR := 4.0    # STR 10 → +40px
var _can_melee: bool = true
var _melee_fx: MeleeSwing            # reused sweep VFX, created on spawn

# Weapon mode — the PRIMARY attack button performs whichever mode is active, so going
# melee doesn't change which button you press. Right-click swaps modes.
enum WeaponMode { RANGED, MELEE }
var weapon_mode: WeaponMode = WeaponMode.RANGED

# DEX: accuracy (bolt spread shrinks as DEX rises) + dash i-frames (extend with DEX).
const MAX_SPREAD_DEG := 14.0
const SPREAD_PER_DEX := 0.9         # DEX ≈ 16 → near-zero spread
const DASH_IFRAME_PER_DEX := 0.01   # +0.1s i-frames at DEX 10

func _ready() -> void:
	add_to_group("player")
	_initialize_contestant()
	# Safe-Room skill-point spends mutate the shared run-stats dict; re-derive vitals.
	SignalBus.stat_injected.connect(_on_stat_injected)
	_melee_fx = MeleeSwing.new()
	add_child(_melee_fx)

func _initialize_contestant() -> void:
	if not GameManager.current_run_stats.is_empty():
		current_stats = GameManager.current_run_stats
	_derive_vitals(true)   # spawn at full

# A point was injected into a stat (Stat-Injection terminal). Re-derive vitals but
# WITHOUT a free heal — gaining CON grants the new heart, it doesn't top off the bar.
func _on_stat_injected(_stat: String, _new_value: int) -> void:
	_derive_vitals(false)

# Single source of truth for stat → vitals. full=true sets pools to max (spawn);
# full=false grows them to the new max while preserving current fill.
func _derive_vitals(full: bool) -> void:
	var con := int(current_stats["CON"])
	var intel := int(current_stats["INT"])
	if full:
		health_comp.initialize_health(floor(con / 5.0))   # 1 heart / 5 CON
		mana_comp.initialize_mana(intel)                   # 5 mana / INT
	else:
		health_comp.set_max_hearts(floor(con / 5.0))
		mana_comp.set_max_mana(intel)
	protection_comp.base_dr = con * ProtectionComponent.DR_PER_CON
	base_speed = 300.0 + (current_stats["DEX"] * 5.0)

func _physics_process(delta: float) -> void:
	if _is_dashing:
		move_comp.apply_dash_friction(delta)
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Aim with the right stick / arrows if used, otherwise track the mouse (desktop).
	var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim.length() > 0.1:
		aim_dir = aim.normalized()
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			aim_dir = to_mouse.normalized()
	weapon_anchor.rotation = aim_dir.angle()
	if Input.is_action_pressed("fire"):
		_primary_attack()
	move_comp.handle_movement(delta, move, base_speed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and _can_dash:
		_perform_dash()
	elif event.is_action_pressed("swap_weapon"):
		_swap_weapon()
	elif event.is_action_pressed("nano"):
		execute_nano_magic("glitch_bolt")

# The primary attack button fires the ACTIVE weapon mode (each mode self-gates on its
# own cooldown), so a melee build keeps the same button — it just swings instead of shoots.
func _primary_attack() -> void:
	if weapon_mode == WeaponMode.MELEE:
		if _can_melee:
			_melee_attack()
	elif _can_fire:
		_fire()

func _swap_weapon() -> void:
	weapon_mode = WeaponMode.RANGED if weapon_mode == WeaponMode.MELEE else WeaponMode.MELEE
	SignalBus.toast.emit("Weapon: " + ("MELEE" if weapon_mode == WeaponMode.MELEE else "RANGED"), global_position)

func _perform_dash() -> void:
	_is_dashing = true
	_can_dash = false
	health_comp.set_invulnerable(true)   # i-frames for the dash window
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = aim_dir
	move_comp.execute_dash(dir)
	await get_tree().create_timer(dash_duration).timeout
	_is_dashing = false
	# DEX extends the i-frame window past the dash movement (GDD: DEX → dash i-frames).
	var extra := int(current_stats["DEX"]) * DASH_IFRAME_PER_DEX
	if extra > 0.0:
		await get_tree().create_timer(extra).timeout
	health_comp.set_invulnerable(false)
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

# Left-click: a FREE basic Glitch Bolt (a weapon, not a spell — no mana cost).
func _fire() -> void:
	_can_fire = false
	var int_stat := int(current_stats["INT"])
	var dmg: float = NanoMagicLibrary.SPELLS["glitch_bolt"]["damage"] * (1.0 + int_stat * 0.05)
	_spawn_projectile(dmg)
	SignalBus.spell_cast.emit("Glitch Bolt", global_position)
	await get_tree().create_timer(fire_cooldown).timeout
	_can_fire = true

# A STR-scaled melee swing (the primary attack while in MELEE mode) — a short arc in the
# aim direction that hits hard and shoves survivors back. High risk (in their face), high reward.
func _melee_attack() -> void:
	_can_melee = false
	var str_stat := int(current_stats["STR"])
	var dmg := MELEE_BASE_DMG * (1.0 + str_stat * MELEE_DMG_PER_STR)
	var knock := MELEE_KNOCK_BASE + str_stat * MELEE_KNOCK_PER_STR
	var cos_half := cos(deg_to_rad(MELEE_ARC_DEG * 0.5))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is CharacterBody2D):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist := to_e.length()
		if dist <= 0.0:
			continue
		# Reach the enemy's body edge, not just its centre, so the blade connects with
		# anything the sweep visibly overlaps (graphic == hit zone).
		if dist - _enemy_radius(e) > MELEE_RANGE:
			continue
		if aim_dir.dot(to_e / dist) < cos_half:
			continue   # outside the swing arc
		var hc := e.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.take_damage(dmg)
		if is_instance_valid(e):
			e.global_position += (to_e / dist) * knock   # shove back
	SignalBus.spell_cast.emit("Melee", global_position)   # SFX / feedback hook
	_melee_fx.play(aim_dir, MELEE_RANGE, MELEE_ARC_DEG)   # the visible sweep
	await get_tree().create_timer(melee_cooldown).timeout
	_can_melee = true

# Radius of an enemy's circular collision shape (0 if none) — lets melee reach the body
# edge rather than only the centre.
func _enemy_radius(e: Node) -> float:
	var cs := e.get_node_or_null("CollisionShape2D")
	if cs is CollisionShape2D and cs.shape is CircleShape2D:
		return (cs.shape as CircleShape2D).radius
	return 0.0

func _cast_effect(effect_type: String, damage: float) -> void:
	match effect_type:
		"projectile":
			_spawn_projectile(damage)
		_:
			pass  # TODO: chain_lightning / beam / aoe_pull effects

func _spawn_projectile(damage: float) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = weapon_anchor.global_position
	bolt.setup(_spread_dir(), damage)

# DEX → accuracy: low DEX scatters shots within a cone; high DEX fires near-true.
func _spread_dir() -> Vector2:
	var dex := int(current_stats["DEX"])
	var half := deg_to_rad(maxf(0.0, MAX_SPREAD_DEG - dex * SPREAD_PER_DEX))
	return aim_dir.rotated(randf_range(-half, half))

