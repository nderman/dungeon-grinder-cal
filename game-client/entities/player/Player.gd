# Player.gd
# The contestant controller. Reads the active contract from GameManager, initializes
# its components from stats, and bridges mobile twin-stick input to movement/combat.
# Expected child nodes: HealthComponent, MovementComponent, ProtectionComponent,
# ManaComponent, WeaponAnchor (Node2D). Player must be in the "player" group.
extends CharacterBody2D

var base_speed: float = 300.0
var speed_mult: float = 1.0    # transient move-speed multiplier; an enemy Chill (StatusEffect) drops it <1
var _defense: Dictionary = {}  # cached defensive effect-affixes (incl. fire/frost resist) from gear
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

# Aim assist (laptop / keyboard-only): with no explicit aim (arrows/stick) AND no recent mouse movement,
# lock aim to the nearest enemy so you can play WASD + a fire key without a mouse. A real mouse move
# reclaims aim instantly; explicit arrow-aim always wins. Mouse tracked in SCREEN space so it only counts
# actual movement, not the player sliding under a following camera.
const AUTOAIM_MOUSE_IDLE_MS := 1500
var _last_mouse_ms: int = 0
var _last_screen_mouse: Vector2 = Vector2.ZERO
var _mouse_seen: bool = false   # baseline the mouse on the FIRST live frame, so a stale spawn value isn't misread as a move (which would gate assist for 1.5s right when a keyboard player needs it)

# Combat is driven by the EQUIPPED WEAPON (GameManager.equipped["Weapon"] -> LootData.weapon_stats).
# Its `type` (melee/ranged) decides the primary attack; damage/cooldown/range/arc/spread come from
# the weapon. No weapon -> FISTS. STR scales melee, INT scales ranged, DEX tightens spread + i-frames.
const BOLT_SCENE := preload("res://entities/projectiles/GlitchBolt.tscn")
const BOMB_SCENE := preload("res://entities/Bomb.tscn")
var _can_fire: bool = true
var _can_melee: bool = true
# Coefficients are on the DCC stat scale (start ~4-7): chosen so a starting build's outputs match
# the old base-10 balance, but each point now matters ~2.5× more and stats climb to 100+.
# Weapon damage scaling lives in LootData (single source, shared with the inventory's DPS readout):
# LootData.effective_weapon_damage (scales off the weapon's stat) + LootData.MELEE_KNOCK_PER_STR.
const SPREAD_PER_DEX := 1.1         # DEX tightens the weapon's base spread (DEX ~8 ≈ old DEX 10)
const TOTAL_REGEN_CAP := 3.0        # max HP/sec regen from ALL sources (CON + Mending gear). High CON
                                    # alone (0.2/CON) blew past this and out-healed everything.
const DASH_IFRAME_PER_DEX := 0.025  # +0.1s i-frames at DEX 4
const MELEE_SWEEP_TIME := 0.18      # melee hit-sample window (matches the MeleeSwing VFX)
var _melee_fx: MeleeSwing            # reused sweep VFX, created on spawn
var _ability_fx: AbilityFx           # reused ability VFX (nova ring / heal pulse / blink streak)
var _inventory_panel: InventoryPanel  # toggled with the inventory key
var _abilities_panel: AbilitiesPanel  # toggled with the abilities key
var _class_panel: ClassSelectPanel    # floor-3 class pick (DCC); created only when owed
var _loot_reveal_panel: LootRevealPanel   # the Safe-Room box-opening reveal
var _shop_panel: ShopPanel                # the town-vendor storefront (opened by a Shopkeeper NPC)
var _pause_menu: PauseMenu                # Esc/P pause overlay + controls help (self-manages input)
var _ability_cd_until: Dictionary = {}   # ability id -> wall-clock (s) it's castable again

# Potion sickness: drinking a potion before its cool-down (GameManager) ends inflicts Poison —
# a DoT that ticks a % of max HP, ignoring armour/i-frames. Antidote clears it.
const POISON_DURATION := 5.0
const POISON_INTERVAL := 1.0
const POISON_PCT_PER_TICK := 0.04    # ~20% of max HP over the full 5s if left untreated
var _poison_ticks: int = 0

# --- Race/class passive triggers (the ones that hook combat events) ---
const BIO_REGEN_DELAY := 10.0        # Trollkin — Biological Patch: seconds untouched before it kicks in
const BIO_REGEN_PER_SEC := 10.0      # …then heals ~1 heart/sec until you're hit again
var _untouched_s: float = 0.0        # time since the player last took damage
const HISS_STUN_CHANCE := 0.25       # Cat — Audience Darling: chance, on being hit, to hiss-stun…
const HISS_STUN_RADIUS := 160.0      # …every mob this close…
const HISS_STUN_SECONDS := 1.0       # …for this long.
const DATA_CORRUPT_CHILL := 0.3      # GlitchWitch — Data Corruption: slow fraction your nova abilities apply
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
	_loot_reveal_panel = LootRevealPanel.new()
	add_child(_loot_reveal_panel)
	_shop_panel = ShopPanel.new()
	add_child(_shop_panel)
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	health_comp.health_depleted.connect(_on_death)
	SignalBus.player_damaged.connect(_on_player_hit)   # drives the on-hit passive triggers
	# DCC: reaching Floor 3 classless -> the System makes you pick a class now (mandatory modal).
	if GameManager.needs_class_selection():
		_class_panel = ClassSelectPanel.new()
		add_child(_class_panel)
		_class_panel.toggle()

# Open the Safe-Room loot reveal for a freshly-opened haul (driven by LootBoxTerminal).
func show_loot_reveal(results: Array) -> void:
	if not results.is_empty():
		_loot_reveal_panel.reveal(results)

# Open the town vendor (driven by a Shopkeeper NonCombatantNPC). Stock was rolled on town entry.
func show_shop() -> void:
	_shop_panel.open_shop()

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

# Single source of truth for stat -> vitals. full=true sets pools to max (spawn);
# full=false grows them to the new max while preserving current fill.
func _derive_vitals(full: bool) -> void:
	var con := int(current_stats["CON"])
	var intel := int(current_stats["INT"])
	# HP pool = CON × 10 on the DCC stat scale (CON ~5 at start -> ~50 HP, same as before; grows a
	# lot as CON climbs). Mana = INT × 12 (INT ~4 -> ~48). A continuous pool keeps heals/regen granular.
	if full:
		health_comp.initialize_health(con * 10)
		mana_comp.initialize_mana(intel)
	else:
		health_comp.set_max_hearts(con * 10)
		mana_comp.set_max_mana(intel)
	# Defensive effect-affixes (armor/regen/dodge/fire_resist/frost_resist) stack on top of CON/DEX.
	var def := LootData.defensive_effects(GameManager.equipped)
	_defense = def   # cached so elemental_resist() can read fire/frost resist on incoming statuses
	protection_comp.base_dr = con * ProtectionComponent.DR_PER_CON
	protection_comp.gear_dr = float(def.get("armor", 0.0))   # flat DR% from "Plated" gear
	# Cap TOTAL regen (CON-based + Mending gear): at high CON the CON regen alone (~4.6/s at CON 23)
	# out-healed all incoming damage. Capping the sum keeps regen meaningful without being immortal.
	health_comp.regen_rate = minf(con * HealthComponent.REGEN_PER_CON + float(def.get("regen", 0.0)), TOTAL_REGEN_CAP)
	var dex := int(current_stats["DEX"])
	protection_comp.dodge_chance = minf(ProtectionComponent.DODGE_CAP, dex * ProtectionComponent.DODGE_PER_DEX + float(def.get("dodge", 0.0)))
	base_speed = (300.0 + (dex * 12.5)) * GameManager.move_speed_mult()   # Ponderous Might: −20%

# How much an incoming elemental status is mitigated (0..~0.9), from resist gear. StatusEffect reads
# this when an enemy tries to Burn/Chill you, scaling the status's power AND duration down.
func elemental_resist(kind: String) -> float:
	match kind:
		StatusEffect.BURN:  return float(_defense.get("fire_resist", 0.0))
		StatusEffect.CHILL: return float(_defense.get("frost_resist", 0.0))
	return 0.0

func _physics_process(delta: float) -> void:
	_tick_poison(delta)
	_tick_bio_regen(delta)
	if _is_dashing:
		move_comp.apply_dash_friction(delta)
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Note real mouse movement (screen-space) so aim assist knows whether a mouse is in use.
	var sm := get_viewport().get_mouse_position()
	if not _mouse_seen:
		_mouse_seen = true
		_last_screen_mouse = sm   # first live frame = baseline, NOT a move (assist stays on until a real move)
	elif sm != _last_screen_mouse:
		_last_screen_mouse = sm
		_last_mouse_ms = Time.get_ticks_msec()
	# Aim priority: explicit arrows/stick > a recently-used mouse > aim-assist to the nearest enemy.
	var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim.length() > 0.1:
		aim_dir = aim.normalized()
	elif Time.get_ticks_msec() - _last_mouse_ms < AUTOAIM_MOUSE_IDLE_MS:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			aim_dir = to_mouse.normalized()
	else:
		var assist := _nearest_enemy_dir()   # laptop / keyboard-only: lock the closest enemy
		if assist != Vector2.ZERO:
			aim_dir = assist
	weapon_anchor.rotation = aim_dir.angle()
	# Don't fire while a modal (Stat-Injection / inventory) is open — a click on its buttons
	# shouldn't also trigger the weapon (fire is polled, not consumed by the GUI).
	if Input.is_action_pressed("fire") and not ModalPanel.any_open():
		_primary_attack()
	move_comp.handle_movement(delta, move, base_speed * speed_mult)   # speed_mult <1 while Chilled

func _unhandled_input(event: InputEvent) -> void:
	# A pending Floor-3 class pick is mandatory: freeze actions (and other panels) until it's made.
	# Movement still works (it's polled), but you can't dash/cast/use/open menus behind the modal.
	if GameManager.needs_class_selection():
		return
	if event.is_action_pressed("dash") and _can_dash:
		_perform_dash()
	elif event.is_action_pressed("use_item"):
		GameManager.use_slot(0)   # key 1
	elif event.is_action_pressed("slot_2"):
		GameManager.use_slot(1)
	elif event.is_action_pressed("slot_3"):
		GameManager.use_slot(2)
	elif event.is_action_pressed("slot_4"):
		GameManager.use_slot(3)
	elif event.is_action_pressed("inventory"):
		_inventory_panel.toggle()
	elif event.is_action_pressed("abilities"):
		_abilities_panel.toggle()
	elif event.is_action_pressed("nano"):
		cast_active_ability()
	elif event.is_action_pressed("cast_secondary"):
		cast_ability(GameManager.secondary_ability)   # Right-Mouse: the second bindable cast ("" = unbound, no-op)

# The equipped weapon's type decides the attack — ranged weapons fire, melee weapons swing.
func _current_weapon() -> Dictionary:
	var w: Dictionary = GameManager.equipped.get("Weapon", {})
	return LootData.weapon_stats(String(w["base"])) if not w.is_empty() else LootData.FISTS

# The equipped weapon's base id ("" = bare fists) — feeds LootData.effective_weapon_damage so combat
# and the inventory's DPS readout share ONE scaling source (melee->STR, ranged->DEX, magic->INT).
func _current_weapon_base() -> String:
	var w: Dictionary = GameManager.equipped.get("Weapon", {})
	return String(w.get("base", "")) if not w.is_empty() else ""

# The equipped weapon instance's rolled rarity damage multiplier (1.0 for fists / a plain weapon).
func _current_weapon_mult() -> float:
	return LootData.weapon_damage_mult(GameManager.equipped.get("Weapon", {}))

func _primary_attack() -> void:
	var w := _current_weapon()
	if w["type"] == "ranged":
		if _can_fire:
			_fire(w)
	elif _can_melee:
		_melee_attack(w)

# Aim-assist target: unit vector to the nearest LIVE enemy (skips invulnerable/dormant bosses), or ZERO.
func _nearest_enemy_dir() -> Vector2:
	var pts := PackedVector2Array()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		var hc := e.get_node_or_null("HealthComponent")
		if hc and hc.has_method("is_invulnerable") and hc.is_invulnerable():
			continue   # dormant boss / i-framed — don't waste assist on something you can't hurt yet
		pts.append((e as Node2D).global_position)
	return _pick_nearest_dir(global_position, pts)

# Pure helper (testable): unit direction from `from` to the nearest of `points`, or ZERO if none.
static func _pick_nearest_dir(from: Vector2, points: PackedVector2Array) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for p in points:
		var d := from.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	if best == Vector2.INF:
		return Vector2.ZERO
	var dir := best - from
	return dir.normalized() if dir.length() > 0.001 else Vector2.ZERO

func _perform_dash() -> void:
	_is_dashing = true
	_can_dash = false
	health_comp.set_invulnerable(true)   # i-frames for the dash window
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = aim_dir
	# AeroWraith — Phasing Flight: for the dash window, collide ONLY with the SEAL layer so you slip through
	# walls/cover/bodies but are still stopped by a boss arena's seal (no phasing out of a locked fight);
	# then eject safely on the far side so you can never strand inside geometry.
	var phasing := GameManager.has_passive("phasing_flight")
	var dash_start := global_position
	var saved_mask := collision_mask
	if phasing:
		collision_mask = Room.SEAL_LAYER
	move_comp.execute_dash(dir, GameManager.dash_dist_mult())   # Low-G Training extends the dash
	await get_tree().create_timer(dash_duration).timeout
	_is_dashing = false
	if not is_inside_tree():
		return   # floor change / death landed mid-dash
	if phasing:
		collision_mask = saved_mask
		_eject_from_wall(dir, dash_start)
	# DEX extends the i-frame window past the dash movement (GDD: DEX -> dash i-frames).
	var extra := int(current_stats["DEX"]) * DASH_IFRAME_PER_DEX
	if extra > 0.0:
		await get_tree().create_timer(extra).timeout
	if is_inside_tree():
		health_comp.set_invulnerable(false)
	await get_tree().create_timer(dash_cooldown).timeout
	_can_dash = true

# Cast the currently-SELECTED active ability (the Q key). Spells gate on mana, every ability gates
# on its own cooldown; effectiveness scales with the ability's stat and its use-earned level.
func cast_active_ability() -> void:
	cast_ability(GameManager.selected_ability)

# Cast a SPECIFIC ability by id (Q casts the selected one; hotbar slots cast theirs). Gated by its
# own cooldown + mana; effectiveness scales with the ability's stat and its use-earned level.
func cast_ability(id: String) -> void:
	if id == "" or not AbilityLibrary.has_ability(id):
		return
	var a := AbilityLibrary.get_ability(id)
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_ability_cd_until.get(id, 0.0)):
		return   # still on cooldown
	var cost := float(a.get("mana_cost", 0.0)) * GameManager.mana_cost_mult()   # Efficient Code: −15%
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
	var cost := float(AbilityLibrary.get_ability(id).get("mana_cost", 0.0)) * GameManager.mana_cost_mult()   # match cast_ability
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
		"bomb":
			# Drop a timed charge at your feet — big delayed blast that also hurts YOU (drop & run).
			var bomb := BOMB_SCENE.instantiate()
			get_tree().current_scene.add_child(bomb)
			bomb.global_position = global_position
			bomb.setup(value, float(a.get("radius", 150.0)), float(a.get("fuse", 1.2)), bool(a.get("friendly_fire", false)))
		"self_heal":
			health_comp.heal(value)
			_ability_fx.play_pulse(Color(0.4, 1.0, 0.5))
		"shield":
			# Holy Shield: a heal burst PLUS a timed DR aura — and a golden glow that lasts the buff
			# so you can see (and time) when you're protected. Re-cast refreshes it.
			health_comp.heal(value)
			var dur := float(a.get("duration", 4.0))
			protection_comp.apply_aura(float(a.get("aura_dr", 30.0)), dur)
			_ability_fx.play_shield(dur, Color(1.0, 0.85, 0.3))
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
		if e.get_node_or_null("HealthComponent") == null:
			continue
		Combat.deal(e, damage)
		if GameManager.has_passive("data_corruption"):
			StatusEffect.apply(e, StatusEffect.CHILL, DATA_CORRUPT_CHILL, CombatEffects.CHILL_SECONDS)   # GlitchWitch
		if stun_seconds > 0.0:
			var ai := e.get_node_or_null("AIComponent")
			if ai and ai.has_method("stun"):
				ai.stun(stun_seconds)

# Phase toward the aim direction. move_and_collide repositions the body, stopping at the first
# wall, so you can't blink out of the map.
func _ability_blink(reach: float) -> void:
	move_and_collide(aim_dir * reach)

# Phasing Flight safety net: after a phase-dash, if you ended somewhere INVALID — inside a wall OR off
# the navigable floor (e.g. phased clean through the outer boundary into the void) — step out the far
# side along the dash heading until you're back on solid ground; if there's no valid spot within reach,
# snap back to where the dash began. Worst case is always the valid pre-dash position: you can phase
# THROUGH the dungeon edge, but never end up OUTSIDE it.
func _eject_from_wall(dir: Vector2, fallback: Vector2) -> void:
	if not _bad_dash_end():
		return
	var step := (dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT) * 12.0
	for _i in range(48):   # ~576px of forward search out the far side
		global_position += step
		if not _bad_dash_end():
			return
	global_position = fallback

func _bad_dash_end() -> bool:
	return _in_wall() or _off_navmesh()

# Is the body overlapping environment (walls/cover)? Queries Room.LOS_LAYER, which is environment-ONLY,
# so standing on an enemy or an Area2D never reads as "stuck in a wall".
func _in_wall() -> bool:
	var cs := get_node_or_null("CollisionShape2D")
	if cs == null or cs.shape == null:
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = Room.LOS_LAYER
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()

# Off the navigable floor — i.e. beyond the dungeon edge (or deep in geometry). FAIL-SAFE: with no baked
# navmesh to judge against, returns false so it can never falsely revert a dash; the threshold is generous
# so valid floor hugging a wall isn't flagged.
func _off_navmesh() -> bool:
	var map := get_world_2d().navigation_map
	if not map.is_valid() or NavigationServer2D.map_get_regions(map).is_empty():
		return false
	return global_position.distance_to(NavigationServer2D.map_get_closest_point(map, global_position)) > 64.0

# On-hit EFFECTS from all equipped gear (LootData effect-affixes — burn/leech/crit/chill/chain).
# Recomputed once per attack: cheap (a few dict reads) and means swapping gear takes effect at once
# with no cache to invalidate. Spells deliberately don't carry these — they're weapon-hit procs.
func _attack_effects() -> Dictionary:
	return LootData.combat_effects(GameManager.equipped)

# Fire the equipped ranged weapon: damage scales with the weapon's stat (DEX for guns, INT only for
# magic), spread = weapon base tightened by DEX. A crit fattens the bolt; the shot carries gear effects.
func _fire(w: Dictionary) -> void:
	_can_fire = false
	var base_dmg := LootData.effective_weapon_damage(_current_weapon_base(), current_stats, _current_weapon_mult())
	var fx := _attack_effects()
	var res := CombatEffects.resolve_damage(base_dmg, fx)
	var crit: bool = res[1]
	_spawn_projectile(res[0], float(w.get("spread", 6.0)),
		1.3 if crit else 1.0, Color(1.0, 0.9, 0.3) if crit else Color.TRANSPARENT, fx)
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
	var fx := _attack_effects()   # gear on-hit effects, fixed for the whole swing
	var base_dmg := LootData.effective_weapon_damage(_current_weapon_base(), current_stats, _current_weapon_mult()) * GameManager.melee_damage_mult()   # Iron Fist
	var already: Array = []   # enemies hit this swing (don't double-hit)
	var elapsed := 0.0
	while elapsed < MELEE_SWEEP_TIME:
		if not _alive or not is_inside_tree():
			return   # player died / floor changed mid-swing — stop touching the world
		_melee_tick(w, swing_aim, already, fx, base_dmg)
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(maxf(0.0, float(w["cooldown"]) - MELEE_SWEEP_TIME)).timeout
	_can_melee = true

func _melee_tick(w: Dictionary, swing_aim: Vector2, already: Array, effects: Dictionary, base_dmg: float) -> void:
	var knock := (float(w["knock"]) + int(current_stats["STR"]) * LootData.MELEE_KNOCK_PER_STR) * GameManager.knockback_mult()   # Ponderous Might ×2
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
		if e.get_node_or_null("HealthComponent") == null:
			continue
		already.append(e)
		# Crit is rolled per-enemy, then routed through the enemy's DR via Combat.deal (same pipeline
		# as every other damage source); the actual HP removed feeds the gear's on-hit effects (leech/chain).
		var res := CombatEffects.resolve_damage(base_dmg, effects)
		var dealt := Combat.deal(e, res[0])
		if res[1]:
			SignalBus.toast.emit("CRIT!", e.global_position)
		CombatEffects.apply_on_hit(e, dealt, effects, health_comp)
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
	SignalBus.potion_sickness.emit()   # first time, TutorialManager explains how to avoid it

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

# Fired whenever the player loses HP (SignalBus.player_damaged): the on-hit passive triggers.
func _on_player_hit(_hearts: int, is_dot: bool) -> void:
	_untouched_s = 0.0   # Biological Patch: ANY damage (incl. DoT) resets the out-of-combat regen timer
	if is_dot:
		return   # poison/burn/collapse ticks don't pay Martyr's Hype or roll hiss-stun (no DoT farming)
	if GameManager.has_passive("martyrs_hype"):
		GameManager.award_martyr_hype()
	if GameManager.has_passive("audience_darling") and randf() < HISS_STUN_CHANCE:
		_hiss_stun()

# Trollkin — Biological Patch: after a stretch untouched, regen ~1 heart/sec until the next hit.
func _tick_bio_regen(delta: float) -> void:
	if not GameManager.has_passive("biological_patch"):
		return
	_untouched_s += delta
	if _untouched_s >= BIO_REGEN_DELAY and _alive:
		health_comp.heal(BIO_REGEN_PER_SEC * delta)

# Cat — Audience Darling: a defensive hiss that briefly stuns nearby mobs when you take a hit.
func _hiss_stun() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is CharacterBody2D):
			continue
		if e.global_position.distance_to(global_position) - _enemy_radius(e) > HISS_STUN_RADIUS:
			continue   # edge-aware, same as _ability_nova — big bosses on the boundary still count
		var ai := e.get_node_or_null("AIComponent")
		if ai and ai.has_method("stun"):
			ai.stun(HISS_STUN_SECONDS)
	SignalBus.toast.emit("HISS!", global_position)

func _spawn_projectile(damage: float, base_spread: float, scale_mult: float = 1.0, color: Color = Color.TRANSPARENT, effects: Dictionary = {}) -> void:
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = weapon_anchor.global_position
	bolt.setup(_spread_dir(base_spread), damage, &"enemies", scale_mult, color)
	if not effects.is_empty():
		bolt.arm_effects(effects, health_comp)   # weapon fire procs gear effects; spells don't

# DEX -> accuracy: the weapon's base spread cone tightens as DEX rises; high DEX fires near-true.
func _spread_dir(base_spread: float) -> Vector2:
	var dex := int(current_stats["DEX"])
	var half := deg_to_rad(maxf(0.0, base_spread - dex * SPREAD_PER_DEX))
	return aim_dir.rotated(randf_range(-half, half))

