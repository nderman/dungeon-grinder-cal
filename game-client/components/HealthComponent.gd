# HealthComponent.gd
# Continuous HP pool + permadeath ("Cancelled") state. (Vars named *_hearts for history; they're
# HP now.) The Player passes HP = CON×10 to initialize_health(); enemies set configured_hearts.
extends Node2D
class_name HealthComponent

var max_hearts: float = 3.0
var current_hearts: float = 3.0
var is_player: bool = false

# Enemies set this in their scene to self-initialize their pool.
# The Player leaves it 0 and instead calls initialize_health() from CON.
@export var configured_hearts: float = 0.0
@export var xp_reward: int = 0               # XP this mob pays on death (bosses set higher)
@export var ratings_reward: int = 10         # Ratings this mob pays on death (audience rail)
@export var iframe_seconds: float = 0.4      # brief post-hit invulnerability (player)
# Two INDEPENDENT invuln sources — they used to share one bool, so a post-hit i-frame timer expiring
# could silently end a dash (or a dormant boss's) invuln, and vice-versa. Kept separate now.
var _held_invuln: bool = false       # explicitly held on/off: dash i-frames AND boss dormancy (set_invulnerable)
var _hit_invuln_until: float = 0.0   # timed post-hit i-frame window (player only); wall-clock expiry in seconds

const REGEN_PER_CON := 0.2   # HP/sec per CON point (DCC: CON drives health regen); set by the Player
var regen_rate: float = 0.0  # passive HP/sec; 0 = none (enemies leave it 0)

signal health_changed(current: float, maximum: float)
signal health_depleted

func _ready() -> void:
	if configured_hearts > 0.0:
		initialize_health(configured_hearts)

# Passive regen toward max (CON-scaled, set by the Player). Throttles the HUD emit to whole-HP
# changes, mirroring ManaComponent. Never revives a corpse (current must already be > 0).
func _physics_process(delta: float) -> void:
	if regen_rate <= 0.0 or current_hearts <= 0.0 or current_hearts >= max_hearts:
		return
	var prev := current_hearts
	current_hearts = minf(current_hearts + regen_rate * delta, max_hearts)
	if floor(prev) != floor(current_hearts):
		health_changed.emit(current_hearts, max_hearts)

func initialize_health(heart_count: float) -> void:
	max_hearts = maxf(1.0, heart_count)
	current_hearts = max_hearts
	is_player = get_parent().is_in_group("player")
	health_changed.emit(current_hearts, max_hearts)

# Re-derive max from a stat change WITHOUT a free full heal: current grows by however
# much max grew (you keep the new heart) but the rest of the bar isn't topped off.
func set_max_hearts(heart_count: float) -> void:
	var new_max := maxf(1.0, heart_count)
	var delta := new_max - max_hearts
	max_hearts = new_max
	current_hearts = clampf(current_hearts + maxf(0.0, delta), 0.0, max_hearts)
	health_changed.emit(current_hearts, max_hearts)

# Damage arrives in HEARTS, already filtered through the ProtectionComponent.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_hearts <= 0.0 or is_invulnerable():
		return
	_deal(amount, false)   # a discrete hit
	if is_player and current_hearts > 0.0 and iframe_seconds > 0.0:
		_grant_iframes()

# Damage-over-time (poison): bypasses i-frames AND armour — it's already inside you. Still counts
# toward death and the HUD, but never grants the post-hit i-frame window a normal hit would.
func apply_dot(amount: float) -> void:
	if amount <= 0.0 or current_hearts <= 0.0:
		return
	_deal(amount, true)   # damage-over-time tick

# Shared HP mutation: clamp, signal the HUD, fire death. Callers decide DR/i-frame policy and pass
# is_dot so listeners can tell a discrete hit from a poison/burn/collapse tick.
func _deal(amount: float, is_dot: bool = false) -> void:
	current_hearts = clampf(current_hearts - amount, 0.0, max_hearts)
	health_changed.emit(current_hearts, max_hearts)
	if is_player:
		SignalBus.player_damaged.emit(int(ceil(current_hearts)), is_dot)
	if current_hearts <= 0.0:
		_on_cancelled()

func is_invulnerable() -> bool:
	return _held_invuln or Time.get_ticks_msec() / 1000.0 < _hit_invuln_until

# Held invuln — the Player toggles it for the Dash window; LevelGenerator holds it on a dormant boss.
func set_invulnerable(v: bool) -> void:
	_held_invuln = v

# Open the timed post-hit i-frame window (no coroutine — just stamp an expiry, checked by is_invulnerable).
func _grant_iframes() -> void:
	_hit_invuln_until = Time.get_ticks_msec() / 1000.0 + iframe_seconds

func heal(amount: float) -> void:
	if current_hearts <= 0.0:
		return   # never revives a corpse (matches take_damage/apply_dot/regen) — e.g. a Healer ticking
	current_hearts = minf(current_hearts + amount, max_hearts)
	health_changed.emit(current_hearts, max_hearts)

func _on_cancelled() -> void:
	health_depleted.emit()
	if is_player:
		GameManager.end_run()   # Save meta-progression, fade to the Green Room.
	else:
		SignalBus.enemy_cancelled.emit(global_position, ratings_reward)   # audience/Ratings rail
		if xp_reward > 0:
			SignalBus.xp_awarded.emit(xp_reward)              # character-growth rail
		get_parent().queue_free()
