# AIComponent.gd
# Modular FSM "brain" for mobs. Issues directions to the MovementComponent and
# fires a mandatory Telegraph window so the player can dodge — the Threat Manual rule.
# Make an Elite by exporting a lower telegraph_duration (e.g. 0.15s).
extends Node2D
class_name AIComponent

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, COOLDOWN }
var current_state: State = State.IDLE

@export var detection_range: float = 400.0       # sight range — needs clear line-of-sight
@export var hearing_radius: float = 140.0         # through-wall aggro only when really close
@export var alert_radius: float = 260.0          # a freshly-aggroed mob rallies buddies within this
@export var attack_range: float = 60.0
@export var telegraph_duration: float = 0.3   # Glitch-Goblin baseline
@export var attack_cooldown: float = 1.2
@export var damage_hearts: float = 20.0         # damage dealt to the player, in HP (20 = 1 old heart)
@export var move_speed: float = 240.0           # chase speed (bosses set this low)
@export var start_active: bool = true           # bosses start dormant until the arena locks
@export var lunge: bool = true                  # commit a forward lunge on attack so it connects
@export var lunge_speed: float = 950.0
@export var ranged: bool = false                # ranged mobs fire a projectile instead of lunging
@export var projectile_scene: PackedScene       # the bolt a ranged mob launches
@export var stun_resist: float = 0.0            # 0 = full stun; bosses set ~0.4-0.6 (chance to shrug + shorter)

var _active: bool = true
var _stun_until: float = 0.0    # wall-clock (s) the mob can act again (Ground Slam etc.)
var _stun_tw: Tween             # active stun-flash tween, killed before re-stunning
var _last_health: float = 0.0   # tracked to detect "I just took damage" → aggro
var target: CharacterBody2D = null
var parent: CharacterBody2D
var _agent: NavigationAgent2D   # paths through doorways instead of beelining into walls
var _player: CharacterBody2D    # cached so we don't group-scan every frame
@onready var move_comp: MovementComponent = get_parent().get_node_or_null("MovementComponent")

# Cached player lookup (re-resolves only if the cached node was freed, e.g. respawn).
func _get_player() -> CharacterBody2D:
	if not is_instance_valid(_player):
		var ps := get_tree().get_nodes_in_group("player")
		_player = ps[0] as CharacterBody2D if not ps.is_empty() else null
	return _player

func _ready() -> void:
	parent = get_parent() as CharacterBody2D
	_active = start_active
	_agent = NavigationAgent2D.new()
	_agent.path_desired_distance = 16.0
	_agent.target_desired_distance = 24.0
	add_child(_agent)   # child of the AIComponent (same global pos as the mob; safe during _ready)
	# Aggro-on-damage: a hit drags the mob onto you even from beyond detection_range —
	# no more free sniping from across the floor.
	var hc := get_parent().get_node_or_null("HealthComponent")
	if hc:
		_last_health = hc.current_hearts
		hc.health_changed.connect(_on_health_changed)
	_change_state(State.IDLE)

# Clear line-of-sight to t? Raycast against the environment layer ONLY (walls + cover), so
# other mobs and the player never block the ray — a clear shot hits nothing, a blocked one
# hits a wall/cover. (Cover correctly breaks LoS, which is the point.)
func _has_los(t: Node2D) -> bool:
	if parent == null or not is_instance_valid(t):
		return false
	var space := parent.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, t.global_position)
	q.collision_mask = Room.LOS_LAYER
	return space.intersect_ray(q).is_empty()

func activate() -> void:
	_active = true

# Crowd control (Ground Slam etc.): freeze the mob's chase/attack drive for `seconds`. Stacks by
# taking the later expiry, halts current movement, and flashes a cyan tell. stun_resist (bosses)
# gives a chance to shrug it off entirely AND shortens any stun that does land.
func stun(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var resist := clampf(stun_resist, 0.0, 0.95)   # never fully immune; never negative (would lengthen)
	if resist > 0.0:
		if randf() < resist:
			SignalBus.toast.emit("RESISTED", global_position)
			return
		seconds *= (1.0 - resist)
	_stun_until = maxf(_stun_until, Time.get_ticks_msec() / 1000.0 + seconds)
	if is_instance_valid(parent):
		parent.velocity = Vector2.ZERO
		_flash_stun(seconds)

func is_stunned() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _stun_until

func _flash_stun(seconds: float) -> void:
	if _stun_tw and _stun_tw.is_valid():
		_stun_tw.kill()   # re-stun (e.g. nova spam) shouldn't stack tints / leave the mob stuck cyan
	_stun_tw = create_tween()
	_stun_tw.tween_property(parent, "modulate", Color(0.5, 0.85, 1.0), 0.1)
	_stun_tw.tween_interval(maxf(0.0, seconds - 0.2))
	_stun_tw.tween_property(parent, "modulate", Color.WHITE, 0.1)   # matches the telegraph reset

# Route this mob's pathfinding through a specific nav map (the boss uses its own boss-sized mesh).
func set_nav_map(map: RID) -> void:
	if _agent:
		_agent.set_navigation_map(map)

# Damage acquires the player as target regardless of distance. Dormant bosses ignore it
# (they stay inert until the arena locks); healing (current rising) never aggros.
func _on_health_changed(current: float, _maximum: float) -> void:
	var took_damage := current < _last_health
	_last_health = current
	if took_damage and _active and not is_instance_valid(target):
		_acquire_player()

func _acquire_player() -> void:
	target = _get_player()
	if target == null:
		return
	if current_state == State.IDLE:
		_change_state(State.CHASE)
		_rally_nearby()

# Alert idle mobs near me to the same target — sniping/sighting one wakes its cluster.
# Alerted mobs do NOT re-rally (one hop), so a pack wakes, not the whole floor.
func _rally_nearby() -> void:
	if not is_instance_valid(target):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == parent or not (e is Node2D):
			continue
		if global_position.distance_to((e as Node2D).global_position) > alert_radius:
			continue
		var ai := e.get_node_or_null("AIComponent") as AIComponent
		if ai:
			ai.alert(target)

func alert(t: CharacterBody2D) -> void:
	if not _active or is_instance_valid(target):
		return   # dormant, or already engaged
	target = t
	if current_state == State.IDLE:
		_change_state(State.CHASE)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if is_stunned():
		if is_instance_valid(parent):
			parent.velocity = Vector2.ZERO   # held in place; chase/attack drive suspended
		return
	match current_state:
		State.IDLE: _find_target()
		State.CHASE: _handle_chase(delta)
		_: pass   # TELEGRAPH/ATTACK/COOLDOWN driven by timers

func _find_target() -> void:
	var p := _get_player()
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	# Wake on close proximity (heard through walls) OR sight within detection_range (clear LoS).
	if d < hearing_radius or (d < detection_range and _has_los(p)):
		target = p
		_change_state(State.CHASE)
		_rally_nearby()

func _handle_chase(delta: float) -> void:
	if not is_instance_valid(target):
		_change_state(State.IDLE)
		return
	# Attack only with a clear shot + in range — no telegraphing/firing through a wall.
	if global_position.distance_to(target.global_position) <= attack_range and _has_los(target):
		_change_state(State.TELEGRAPH)
		return
	if move_comp:
		# Path toward the player through doorways. If the navmesh can't reach the player's spot
		# (too tight for this agent's clearance) or returns no step, BEELINE so a kiting player
		# behind cover can't sit safely out of reach.
		_agent.target_position = target.global_position
		var dir := _agent.get_next_path_position() - global_position
		if dir.length() <= 1.0 or not _agent.is_target_reachable():
			dir = target.global_position - global_position
		if dir.length() > 1.0:
			move_comp.handle_movement(delta, dir.normalized(), move_speed)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.TELEGRAPH: _start_telegraph()
		State.ATTACK: _execute_attack()
		State.COOLDOWN:
			await get_tree().create_timer(attack_cooldown).timeout
			_change_state(State.CHASE)

func _start_telegraph() -> void:
	SignalBus.ratings_spike.emit("TELEGRAPH_START")
	if parent:
		parent.velocity = Vector2.ZERO
		_flash_tell()   # very visible "about to hit you" cue on the mob itself
	await get_tree().create_timer(telegraph_duration).timeout
	if parent: parent.modulate = Color.WHITE
	_change_state(State.ATTACK)

# Pulse the whole mob red for the telegraph window. (A dedicated visual component
# could own this later; inline is fine for the bootstrap.)
func _flash_tell() -> void:
	var tw := create_tween()
	tw.tween_property(parent, "modulate", Color(1, 0.2, 0.2), telegraph_duration * 0.5)
	tw.tween_property(parent, "modulate", Color(1, 0.5, 0.5), telegraph_duration * 0.5)

func _execute_attack() -> void:
	if ranged:
		_fire_projectile()
	elif lunge and is_instance_valid(parent) and is_instance_valid(target):
		# Commit a forward lunge toward the target — this is what makes the hit land
		# (a stationary telegraph whiffs against a moving player). Dash to dodge it.
		var dir := (target.global_position - parent.global_position).normalized()
		var elapsed := 0.0
		while elapsed < 0.2:
			# The mob (or target) can be killed mid-lunge — bail before touching a freed node.
			if not is_instance_valid(parent) or not is_instance_valid(target):
				break
			parent.velocity = dir * lunge_speed
			parent.move_and_slide()
			if global_position.distance_to(target.global_position) <= attack_range:
				_hit_target()
				break
			elapsed += get_physics_process_delta_time()
			await get_tree().physics_frame
		if is_instance_valid(parent):
			parent.velocity = Vector2.ZERO
	elif is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range + 20.0:
		_hit_target()
	if is_instance_valid(parent):
		_change_state(State.COOLDOWN)   # skip if the mob died during the lunge

func _hit_target() -> void:
	if not is_instance_valid(target):
		return
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	var prot := target.get_node_or_null("ProtectionComponent") as ProtectionComponent
	var dmg := damage_hearts
	if prot:
		dmg = prot.handle_incoming_damage(dmg)
	if health:
		health.take_damage(dmg)

# Ranged attack: launch a projectile at the target, grouped onto "player" so it damages the
# contestant (and ignores other mobs + the shooter via the Hitbox group filter).
func _fire_projectile() -> void:
	if projectile_scene == null or not is_instance_valid(parent) or not is_instance_valid(target):
		return
	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = parent.global_position
	var dir: Vector2 = (target.global_position - parent.global_position).normalized()
	if proj.has_method("setup"):
		proj.setup(dir, damage_hearts, &"player")
