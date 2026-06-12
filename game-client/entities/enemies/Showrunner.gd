# Showrunner.gd
# "The Showrunner" — summoner boss. A backline director that hangs back, fires RANGED potshots at
# you, and SUMMONS waves of adds on a timer — each wave pops the ratings for the audience. So it's a
# dual threat: dodge its shots while you fight through the swarm to reach it, and it floods faster +
# shoots through enrage (<=50% HP). The ranged attack is the shared AIComponent (ranged=true); this
# script owns the summon. Reuses existing enemy scenes as adds (set in the .tscn).
extends CharacterBody2D

const SUMMON_INTERVAL := 6.0
const SUMMON_INTERVAL_ENRAGED := 3.5
const WAVE := 2                 # adds per wave
const WAVE_ENRAGED := 3
const MAX_ADDS := 8             # arena cap — skip a wave rather than flood infinitely
const SHOT_DMG_MULT := 0.45     # tier damage is tuned for one big melee hit — soften it per shot
const FIRST_WAVE_DELAY := 2.0

@export var add_scenes: Array[PackedScene] = []   # goblins / screamers to summon

@onready var ai: AIComponent = $AIComponent
@onready var health: HealthComponent = $HealthComponent
var _enraged := false
var _cd := FIRST_WAVE_DELAY
var _adds: Array = []   # this boss's own living summons — the MAX_ADDS cap counts THESE, not the floor

func _ready() -> void:
	add_to_group("enemies")
	ai.damage_hearts *= SHOT_DMG_MULT
	health.health_changed.connect(_on_health_changed)
	health.health_depleted.connect(_on_defeated)

func _physics_process(delta: float) -> void:
	if not ai.is_active():
		return   # dormant until the arena locks
	_cd -= delta
	if _cd <= 0.0:
		_cd = SUMMON_INTERVAL_ENRAGED if _enraged else SUMMON_INTERVAL
		_summon()

func _summon() -> void:
	# Cap on THIS boss's own living swarm — NOT the floor-wide enemy count (which, on a busy floor,
	# was always > MAX_ADDS and silently blocked every wave). Prune dead adds, then top up.
	_adds = _adds.filter(func(a): return is_instance_valid(a))
	if add_scenes.is_empty() or _adds.size() >= MAX_ADDS:
		return
	var n := WAVE_ENRAGED if _enraged else WAVE
	SignalBus.ratings_spike.emit("DRAMA_SPIKE")
	SignalBus.toast.emit("ROLL THE ADDS!", global_position)
	for _i in range(n):
		var scene: PackedScene = add_scenes.pick_random()
		if scene == null:
			continue
		var a := scene.instantiate()
		get_tree().current_scene.add_child(a)
		a.global_position = global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
		_adds.append(a)

func _on_health_changed(current: float, maximum: float) -> void:
	if _enraged or current <= 0.0 or current > maximum * 0.5:
		return
	_enraged = true
	modulate = Color(1.0, 0.55, 0.7)   # frantic — calling in everyone
	SignalBus.ratings_spike.emit("DRAMA_SPIKE")

func _on_defeated() -> void:
	SignalBus.ratings_spike.emit("FATALITY")
	SignalBus.toast.emit("SHOW'S OVER!", global_position)
