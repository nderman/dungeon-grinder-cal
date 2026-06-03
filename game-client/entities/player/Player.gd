# Player.gd
# The contestant controller. Reads the active contract from GameManager, initializes
# its components from stats, and bridges mobile twin-stick input to movement/combat.
# Expected child nodes: HealthComponent, MovementComponent, ProtectionComponent,
# ManaComponent, WeaponAnchor (Node2D). Player must be in the "player" group.
extends CharacterBody2D

var base_speed: float = 300.0
var current_stats: Dictionary = {"STR": 4, "DEX": 4, "INT": 4, "CON": 4, "CHA": 4}   # fallback (test bench); real stats come from GameManager

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
var _ability_fx: AbilityFx           # reused ability VFX (nova ring / heal pulse / blink streak)
var _inventory_panel: InventoryPanel  # toggled with the inventory key
var _abilities_panel: AbilitiesPanel  # toggled with the abilities key
var _class_panel: ClassSelectPanel    # floor-3 class pick (DCC); created only when owed
var _ability_cd_until: Dictionary = {}   # ability id -> wall-clock (s) it's castable again

# Potion sickness: drinking a potion before its cool-down (GameManager) ends inflicts Poison —
# a DoT that ticks a % of max HP, ignoring armour/i-frames. Antidote clears it.
const POISON_DURATION := 5.0
const POISON_INTERVAL := 1.0
const POISON_PCT_PER_TICK := 0.04    # ~20% of max HP over the full 5s if left untreated
var _poison_ticks: int = 0
var _poison_accum: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_initialize_contestant()
	# Safe-Room skill-point spends mutate the shared run-stats dict; re-derive vitals.
	SignalBus.stat_injected.connect(_on_stat_injected)
	_melee_fx = MeleeSwing.new()
	add_child(_melee_fx)
	_ability_fx = AbilityFx.new()
	add_child(_ability_fx)
	_inventory_panel = InventoryPanel.new()
	add_child(_inventory_panel)
	_abilities_panel = AbilitiesPanel.new()
	add_child(_abilities_panel)
	health_comp.health_depleted.connect(_on_death)
	# DCC: reaching Floor 3 classless → the System makes you pick a class now (mandatory modal).
	if GameManager.needs_class_selection():
		_class_panel = ClassSelectPanel.new()
		add_child(_class_panel)
		_class_panel.toggle()

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
	health_comp.regen_rate = con * HealthComponent.REGEN_PER_CON   # CON → passive HP regen
	var dex := int(current_stats["DEX"])
	protection_comp.dodge_chance = minf(ProtectionComponent.DODGE_CAP, dex * ProtectionComponent.DODGE_PER_DEX)
	base_speed = 300.0 + (dex * 12.5)

func _physics_process(delta: float) -> void:
	_tick_poison(delta)
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
	# A pending Floor-3 class pick is mandatory: freeze actions (and other panels) until it's made.
	# Movement still works (it's polled), but you can't dash/cast/use/open menus behind the modal.
	if GameManager.needs_class_selection():
		return
	if event.is_action_pressed("dash") and _can_dash:
		_perform_dash()
	elif event.is_action_pressed("use_item"):
		GameManager.use_consumable()
	elif event.is_action_pressed("inventory"):
		_inventory_panel.toggle()
	elif event.is_action_pressed("abilities"):
		_abilities_panel.toggle()
	elif event.is_action_pressed("nano"):
		cast_active_ability()

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

# Cast the currently-SELECTED active ability (the Q key). Spells gate on mana, every ability gates
# on its own cooldown; effectiveness scales with the ability's stat and its use-earned level.
func cast_active_ability() -> void:
	var id := GameManager.selected_ability
	if id == "" or not AbilityLibrary.has_ability(id):
		return
	var a := AbilityLibrary.get_ability(id)
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_ability_cd_until.get(id, 0.0)):
		return   # still on cooldown
	var cost := float(a.get("mana_cost", 0.0))
	if cost > 0.0:
		if mana_comp.current_mana < cost:
			SignalBus.mana_depleted.emit()
			return
		mana_comp.consume_mana(cost)
	_ability_cd_until[id] = now + float(a.get("cooldown", 0.5))
	GameManager.register_ability_use(id)
	SignalBus.spell_cast.emit(String(a["name"]), global_position)
	_apply_ability(a, GameManager.ability_level(id))

# True when the selected ability can be cast right now (off cooldown + enough mana). Drives the
# HUD greying-out the ability readout when it's unavailable.
func selected_ability_ready() -> bool:
	var id := GameManager.selected_ability
	if id == "" or not AbilityLibrary.has_ability(id):
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_ability_cd_until.get(id, 0.0)):
		return false
	var cost := float(AbilityLibrary.get_ability(id).get("mana_cost", 0.0))
	return cost <= 0.0 or mana_comp.current_mana >= cost

# Resolve an ability's magnitude (base × scaling-stat × use-level) and run its effect + VFX.
func _apply_ability(a: Dictionary, level: int) -> void:
	var stat := int(current_stats.get(String(a.get("scale", "INT")), 4))
	var value := float(a.get("power", 0.0)) * (1.0 + stat * AbilityLibrary.SCALE_PER_STAT) * AbilityLibrary.power_mult(level)
	# Spell casts read cool blue, skills warm orange — so the burst tells you what just fired.
	var col := Color(0.55, 0.8, 1.0) if String(a.get("kind", "skill")) == "spell" else Color(1.0, 0.62, 0.3)
	match String(a.get("effect", "")):
		"projectile":
			_spawn_projectile(value, 6.0, float(a.get("proj_scale", 1.0)), a.get("proj_color", Color.TRANSPARENT))
		"nova":
			var radius := float(a.get("radius", 160.0))
			_ability_nova(value, radius, float(a.get("stun", 0.0)))
			_ability_fx.play_nova(radius, col)
		"self_heal":
			health_comp.heal(value)
			_ability_fx.play_pulse(Color(0.4, 1.0, 0.5))
		"blink":
			var from := global_position
			_ability_blink(float(a.get("reach", 240.0)))
			_ability_fx.play_streak(from - global_position, Color(0.7, 0.8, 1.0))

# AoE burst centred on the player: damages every enemy within radius (through its DR), like melee.
# stun_seconds > 0 also briefly freezes each mob hit (crowd control, e.g. Ground Slam).
func _ability_nova(damage: float, radius: float, stun_seconds: float = 0.0) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is CharacterBody2D):
			continue
		if e.global_position.distance_to(global_position) - _enemy_radius(e) > radius:
			continue
		var hc := e.get_node_or_null("HealthComponent") as HealthComponent
		if hc == null:
			continue
		var prot := e.get_node_or_null("ProtectionComponent") as ProtectionComponent
		hc.take_damage(prot.handle_incoming_damage(damage) if prot else damage)
		if stun_seconds > 0.0:
			var ai := e.get_node_or_null("AIComponent")
			if ai and ai.has_method("stun"):
				ai.stun(stun_seconds)

# Phase toward the aim direction. move_and_collide repositions the body, stopping at the first
# wall, so you can't blink out of the map.
func _ability_blink(reach: float) -> void:
	move_and_collide(aim_dir * reach)

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
	var arc_half := deg_to_rad(float(w["arc"]) * 0.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is CharacterBody2D) or e in already:
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist := to_e.length()
		if dist <= 0.0:
			continue
		# Reach the enemy's body edge, not just its centre (graphic == hit zone).
		var er := _enemy_radius(e)
		var gap := dist - er
		if gap > melee_range:
			continue
		# Stay DIRECTIONAL (full forward reach, won't clip enemies beside/behind you), but widen the
		# swing cone by the angle the enemy's body subtends at this distance — so a close enemy whose
		# CENTRE sits a hair off a narrow cone still connects, instead of whiffing in your face.
		var subtend := asin(clampf(er / dist, 0.0, 1.0))
		var off := acos(clampf(swing_aim.dot(to_e / dist), -1.0, 1.0))
		if off > arc_half + subtend:
			continue   # outside the (body-widened) swing arc
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

# Use a consumable from the quick bar: heal / restore mana / cure poison (effect from LootData),
# magnitude scaled by the box tier. The effect still applies even when sickness is induced (DCC: the
# potion works, you just get Poisoned for double-dipping); induces_sickness comes from GameManager.
func apply_consumable(id: String, tier: int, induces_sickness: bool = false) -> void:
	var e := LootData.consumable_effect(id, tier)
	match e.get("effect", ""):
		"heal": health_comp.heal(int(e["amount"]))
		"mana": mana_comp.restore_mana(int(e["amount"]))
		"cure_poison":
			if _poison_ticks > 0:
				_clear_poison()
			else:
				SignalBus.toast.emit("Nothing to cure.", global_position)
		"learn":
			var aid := String(e.get("ability", ""))
			if GameManager.learn_ability(aid):
				SignalBus.toast.emit("Learned %s!" % AbilityLibrary.ability_name(aid), global_position)
			else:
				SignalBus.toast.emit("%s already known." % AbilityLibrary.ability_name(aid), global_position)
	if induces_sickness:
		_apply_poison()

func _apply_poison() -> void:
	_poison_ticks = int(POISON_DURATION / POISON_INTERVAL)
	_poison_accum = 0.0
	SignalBus.toast.emit("Potion Sickness — Poisoned!", global_position)

func _clear_poison() -> void:
	_poison_ticks = 0
	SignalBus.toast.emit("Antidote — cured!", global_position)

# Ticks poison damage on the interval; a % of max HP so it scales with the contestant.
func _tick_poison(delta: float) -> void:
	if _poison_ticks <= 0 or not _alive:
		return
	_poison_accum += delta
	if _poison_accum >= POISON_INTERVAL:
		_poison_accum -= POISON_INTERVAL
		_poison_ticks -= 1
		health_comp.apply_dot(health_comp.max_hearts * POISON_PCT_PER_TICK)

func _spawn_projectile(damage: float, base_spread: float, scale_mult: float = 1.0, color: Color = Color.TRANSPARENT) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = weapon_anchor.global_position
	bolt.setup(_spread_dir(base_spread), damage, &"enemies", scale_mult, color)

# DEX → accuracy: the weapon's base spread cone tightens as DEX rises; high DEX fires near-true.
func _spread_dir(base_spread: float) -> Vector2:
	var dex := int(current_stats["DEX"])
	var half := deg_to_rad(maxf(0.0, base_spread - dex * SPREAD_PER_DEX))
	return aim_dir.rotated(randf_range(-half, half))

