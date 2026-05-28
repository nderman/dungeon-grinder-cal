# AIComponent.gd
# Modular FSM "brain" for mobs. Issues directions to the MovementComponent and
# fires a mandatory Telegraph window so the player can dodge — the Threat Manual rule.
# Make an Elite by exporting a lower telegraph_duration (e.g. 0.15s).
extends Node2D
class_name AIComponent

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, COOLDOWN }
var current_state: State = State.IDLE

@export var detection_range: float = 400.0
@export var attack_range: float = 60.0
@export var telegraph_duration: float = 0.3   # Glitch-Goblin baseline
@export var attack_cooldown: float = 1.2
@export var damage_hearts: float = 1.0          # mobs 1, bosses 2
@export var move_speed: float = 240.0           # chase speed (bosses set this low)
@export var start_active: bool = true           # bosses start dormant until the arena locks
@export var lunge: bool = true                  # commit a forward lunge on attack so it connects
@export var lunge_speed: float = 950.0

var _active: bool = true
var _last_health: float = 0.0   # tracked to detect "I just took damage" → aggro
var target: CharacterBody2D = null
var parent: CharacterBody2D
@onready var move_comp: MovementComponent = get_parent().get_node_or_null("MovementComponent")

func _ready() -> void:
	parent = get_parent() as CharacterBody2D
	_active = start_active
	# Aggro-on-damage: a hit drags the mob onto you even from beyond detection_range —
	# no more free sniping from across the floor.
	var hc := get_parent().get_node_or_null("HealthComponent")
	if hc:
		_last_health = hc.current_hearts
		hc.health_changed.connect(_on_health_changed)
	_change_state(State.IDLE)

func activate() -> void:
	_active = true

# Damage acquires the player as target regardless of distance. Dormant bosses ignore it
# (they stay inert until the arena locks); healing (current rising) never aggros.
func _on_health_changed(current: float, _maximum: float) -> void:
	var took_damage := current < _last_health
	_last_health = current
	if took_damage and _active and target == null:
		_acquire_player()

func _acquire_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	target = players[0] as CharacterBody2D
	if current_state == State.IDLE:
		_change_state(State.CHASE)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	match current_state:
		State.IDLE: _find_target()
		State.CHASE: _handle_chase(delta)
		_: pass   # TELEGRAPH/ATTACK/COOLDOWN driven by timers

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as CharacterBody2D
	if p and global_position.distance_to(p.global_position) < detection_range:
		target = p
		_change_state(State.CHASE)

func _handle_chase(delta: float) -> void:
	if target == null:
		_change_state(State.IDLE)
		return
	if global_position.distance_to(target.global_position) <= attack_range:
		_change_state(State.TELEGRAPH)
	elif move_comp:
		move_comp.handle_movement(delta, (target.global_position - global_position).normalized(), move_speed)

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
	if lunge and parent != null and is_instance_valid(target):
		# Commit a forward lunge toward the target — this is what makes the hit land
		# (a stationary telegraph whiffs against a moving player). Dash to dodge it.
		var dir := (target.global_position - parent.global_position).normalized()
		var elapsed := 0.0
		while elapsed < 0.2:
			parent.velocity = dir * lunge_speed
			parent.move_and_slide()
			if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range:
				_hit_target()
				break
			elapsed += get_physics_process_delta_time()
			await get_tree().physics_frame
		if parent != null:
			parent.velocity = Vector2.ZERO
	elif is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range + 20.0:
		_hit_target()
	_change_state(State.COOLDOWN)

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
