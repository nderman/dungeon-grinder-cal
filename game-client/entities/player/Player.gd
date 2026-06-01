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
var _alive: bool = true   # cleared on death so in-flight coroutines (melee sweep) bail
var aim_dir: Vector2 = Vector2.RIGHT

# Combat is driven by the EQUIPPED WEAPON (GameManager.equipped["Weapon"] → LootData.weapon_stats).
# Its `type` (melee/ranged) decides the primary attack; damage/cooldown/range/arc/spread come from
# the weapon. No weapon → FISTS. STR scales melee, INT scales ranged, DEX tightens spread + i-frames.
const BOLT_SCENE := preload("res://entities/projectiles/GlitchBolt.tscn")
var _can_fire: bool = true
var _can_melee: bool = true
# Coefficients are on the DCC stat scale (start ~4-7): chosen so a starting build's outputs match
# the old base-10 balance, but each point now matters ~2.5× more and stats climb to 100+.
const MELEE_DMG_PER_STR := 0.107    # STR 7 → ×1.75 melee (held from the old STR 15 ×1.75)
const MELEE_KNOCK_PER_STR := 8.0    # +8px knockback per STR (was 4 at the old scale)
const RANGED_DMG_PER_INT := 0.125   # INT 4 → ×1.5 ranged (held from old INT 10 ×1.5)
const SPREAD_PER_DEX := 1.1         # DEX tightens the weapon's base spread (DEX ~8 ≈ old DEX 10)
const DASH_IFRAME_PER_DEX := 0.025  # +0.1s i-frames at DEX 4
const MELEE_SWEEP_TIME := 0.18      # melee hit-sample window (matches the MeleeSwing VFX)
var _melee_fx: MeleeSwing            # reused sweep VFX, created on spawn
var _inventory_panel: InventoryPanel  # toggled with the inventory key

func _ready() -> void:
	add_to_group("player")
	_initialize_contestant()
	# Safe-Room skill-point spends mutate the shared run-stats dict; re-derive vitals.
	SignalBus.stat_injected.connect(_on_stat_injected)
	_melee_fx = MeleeSwing.new()
	add_child(_melee_fx)
	_inventory_panel = InventoryPanel.new()
	add_child(_inventory_panel)
	health_comp.health_depleted.connect(_on_death)

# Death ("Cancelled"): freeze the contestant at once so you can't keep playing during the
# brief Green-Room cut. GameManager.end_run (fired by HealthComponent) handles the hand-off.
func _on_death() -> void:
	_alive = false   # stops an in-flight melee sweep from ticking on a dead player
	set_physics_process(false)
	set_process_unhandled_input(false)
	velocity = Vector2.ZERO

func _initialize_contestant() -> void:
	if not GameManager.current_run_stats.is_empty():
		current_stats = GameManager.get_effective_stats()   # base + equipped gear
	_derive_vitals(true)   # spawn at full

# Stats changed — a skill point was spent OR gear was equipped (both emit stat_injected).
# Refresh the effective snapshot and re-derive vitals WITHOUT a free heal (a CON gain adds
# the new heart, it doesn't top off the rest of the bar).
func _on_stat_injected(_stat: String, _new_value: int) -> void:
	current_stats = GameManager.get_effective_stats()
	_derive_vitals(false)

# Single source of truth for stat → vitals. full=true sets pools to max (spawn);
# full=false grows them to the new max while preserving current fill.
func _derive_vitals(full: bool) -> void:
	var con := int(current_stats["CON"])
	var intel := int(current_stats["INT"])
	# HP pool = CON × 10 on the DCC stat scale (CON ~5 at start → ~50 HP, same as before; grows a
	# lot as CON climbs). Mana = INT × 12 (INT ~4 → ~48). A continuous pool keeps heals/regen granular.
	if full:
		health_comp.initialize_health(con * 10)
		mana_comp.initialize_mana(intel)
	else:
		health_comp.set_max_hearts(con * 10)
		mana_comp.set_max_mana(intel)
	protection_comp.base_dr = con * ProtectionComponent.DR_PER_CON
	base_speed = 300.0 + (current_stats["DEX"] * 12.5)

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
	# Don't fire while a modal (Stat-Injection / inventory) is open — a click on its buttons
	# shouldn't also trigger the weapon (fire is polled, not consumed by the GUI).
	if Input.is_action_pressed("fire") and not ModalPanel.any_open():
		_primary_attack()
	move_comp.handle_movement(delta, move, base_speed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and _can_dash:
		_perform_dash()
	elif event.is_action_pressed("use_item"):
		GameManager.use_consumable()
	elif event.is_action_pressed("inventory"):
		_inventory_panel.toggle()
	elif event.is_action_pressed("nano"):
		execute_nano_magic("glitch_bolt")

# The equipped weapon's type decides the attack — ranged weapons fire, melee weapons swing.
func _current_weapon() -> Dictionary:
	var w: Dictionary = GameManager.equipped.get("Weapon", {})
	return LootData.weapon_stats(String(w["base"])) if not w.is_empty() else LootData.FISTS

func _primary_attack() -> void:
	var w := _current_weapon()
	if w["type"] == "ranged":
		if _can_fire:
			_fire(w)
	elif _can_melee:
		_melee_attack(w)

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
	var scaled_cost: float = spell["mana_cost"] * (1.0 - (int_stat * 0.025))
	if mana_comp.consume_mana(scaled_cost):
		var scaled_damage: float = spell["damage"] * (1.0 + (int_stat * 0.125))
		SignalBus.spell_cast.emit(spell["name"], global_position)
		_cast_effect(spell["effect_type"], scaled_damage)

# Fire the equipped ranged weapon: damage scales with INT, spread = weapon base tightened by DEX.
func _fire(w: Dictionary) -> void:
	_can_fire = false
	var int_stat := int(current_stats["INT"])
	var dmg: float = float(w["damage"]) * (1.0 + int_stat * RANGED_DMG_PER_INT)
	_spawn_projectile(dmg, float(w.get("spread", 6.0)))
	SignalBus.spell_cast.emit("Shot", global_position)
	await get_tree().create_timer(float(w["cooldown"])).timeout
	_can_fire = true

# Swing the equipped melee weapon — a short arc in the aim direction. The hit is sampled across
# the whole sweep (not just frame 0), so anything the blade passes through (incl. enemies stepping
# into the arc mid-swing) takes damage once. Arc/damage/cooldown come from the weapon.
func _melee_attack(w: Dictionary) -> void:
	_can_melee = false
	var swing_aim := aim_dir
	_melee_fx.play(swing_aim, float(w["range"]), float(w["arc"]))   # the visible sweep
	SignalBus.spell_cast.emit("Melee", global_position)
	var already: Array = []   # enemies hit this swing (don't double-hit)
	var elapsed := 0.0
	while elapsed < MELEE_SWEEP_TIME:
		if not _alive or not is_inside_tree():
			return   # player died / floor changed mid-swing — stop touching the world
		_melee_tick(w, swing_aim, already)
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(maxf(0.0, float(w["cooldown"]) - MELEE_SWEEP_TIME)).timeout
	_can_melee = true

func _melee_tick(w: Dictionary, swing_aim: Vector2, already: Array) -> void:
	var str_stat := int(current_stats["STR"])
	var dmg := float(w["damage"]) * (1.0 + str_stat * MELEE_DMG_PER_STR)
	var knock := float(w["knock"]) + str_stat * MELEE_KNOCK_PER_STR
	var melee_range := float(w["range"])
	var cos_half := cos(deg_to_rad(float(w["arc"]) * 0.5))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is CharacterBody2D) or e in already:
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist := to_e.length()
		if dist <= 0.0:
			continue
		# Reach the enemy's body edge, not just its centre (graphic == hit zone).
		if dist - _enemy_radius(e) > melee_range:
			continue
		if swing_aim.dot(to_e / dist) < cos_half:
			continue   # outside the swing arc
		var hc := e.get_node_or_null("HealthComponent") as HealthComponent
		if hc == null:
			continue
		already.append(e)
		# Route through the enemy's DR (same pipeline as HitboxComponent / AIComponent._hit_target).
		var prot := e.get_node_or_null("ProtectionComponent") as ProtectionComponent
		var hit: float = prot.handle_incoming_damage(dmg) if prot else dmg
		hc.take_damage(hit)
		# Shove survivors only (not a corpse). Big bosses (scale ≥ 1.3) are too heavy to shove.
		# move_and_collide so the shove stops at walls — no punting enemies out of the map.
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.scale.x < 1.3:
			(e as CharacterBody2D).move_and_collide((to_e / dist) * knock)

# Radius of an enemy's circular collision shape (0 if none) — lets melee reach the body
# edge rather than only the centre.
func _enemy_radius(e: Node) -> float:
	var cs := e.get_node_or_null("CollisionShape2D")
	if cs is CollisionShape2D and cs.shape is CircleShape2D:
		var scl := (e as Node2D).scale.x if e is Node2D else 1.0
		return (cs.shape as CircleShape2D).radius * scl   # scaled bosses are bigger than the raw radius
	return 0.0

# Use a consumable from the quick bar — CON potions heal hearts, INT batteries restore mana.
# Magnitude scales with the box tier the item came from.
func apply_consumable(id: String, tier: int) -> void:
	var e := LootData.consumable_effect(id, tier)
	match e["stat"]:
		"CON": health_comp.heal(int(e["amount"]))
		"INT": mana_comp.restore_mana(int(e["amount"]))

func _cast_effect(effect_type: String, damage: float) -> void:
	match effect_type:
		"projectile":
			_spawn_projectile(damage, 6.0)
		_:
			pass  # TODO: chain_lightning / beam / aoe_pull effects

func _spawn_projectile(damage: float, base_spread: float) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = weapon_anchor.global_position
	bolt.setup(_spread_dir(base_spread), damage)

# DEX → accuracy: the weapon's base spread cone tightens as DEX rises; high DEX fires near-true.
func _spread_dir(base_spread: float) -> Vector2:
	var dex := int(current_stats["DEX"])
	var half := deg_to_rad(maxf(0.0, base_spread - dex * SPREAD_PER_DEX))
	return aim_dir.rotated(randf_range(-half, half))

