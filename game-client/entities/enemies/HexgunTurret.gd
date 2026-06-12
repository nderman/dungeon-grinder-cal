# HexgunTurret.gd
# "The Hexgun" — artillery boss. The shared components handle HP and a slow keep-your-distance
# ranged chase (AIComponent ranged=true); this thin entity script adds the SIGNATURE: telegraphed
# RADIAL bullet volleys on a timer — a ring of bolts that you have to move out of, the polar
# opposite of the melee Golem. At <=50% HP it ENRAGES: faster, denser volleys + an angrier tint.
extends CharacterBody2D

const BOLT := preload("res://entities/projectiles/GlitchBolt.tscn")

const VOLLEY_INTERVAL := 2.8          # seconds between volleys
const VOLLEY_INTERVAL_ENRAGED := 1.6
const BOLTS := 12                     # bolts per ring
const BOLTS_ENRAGED := 18
const TELEGRAPH := 0.45               # wind-up flash before a ring fires (time to read + dodge)
const PROJECTILE_DMG_MULT := 0.35     # tier damage is tuned for ONE melee slam; split it for many bolts

@onready var ai: AIComponent = $AIComponent
@onready var health: HealthComponent = $HealthComponent
var _enraged := false
var _cd := VOLLEY_INTERVAL
var _base_tint := Color.WHITE

func _ready() -> void:
	add_to_group("enemies")
	_base_tint = modulate   # capture the tier tint set by _spawn_boss so telegraphs return to it
	ai.damage_hearts *= PROJECTILE_DMG_MULT   # both aimed shots AND volley bolts read this — keep it fair
	health.health_changed.connect(_on_health_changed)
	health.health_depleted.connect(_on_defeated)

func _physics_process(delta: float) -> void:
	if not ai.is_active():
		return   # dormant until the arena locks — no firing while asleep
	_cd -= delta
	if _cd <= 0.0:
		_cd = VOLLEY_INTERVAL_ENRAGED if _enraged else VOLLEY_INTERVAL
		_volley()

# Wind-up flash, then a PATTERN — not always the same ring, so it's not a metronome you can stand
# next to. Rolls between a gap-rotating ring and a spinning 2-/3-arm spiral that sweeps the arena.
func _volley() -> void:
	var pattern := randi() % 3   # 0 ring · 1 double-spiral · 2 triple-spiral
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.7, 1.7, 0.7), TELEGRAPH * 0.65)
	tw.tween_callback(func(): _fire_pattern(pattern))
	tw.tween_property(self, "modulate", _base_tint, 0.2)

func _fire_pattern(pattern: int) -> void:
	match pattern:
		1: _fire_spiral(2)
		2: _fire_spiral(3)
		_: _fire_ring(BOLTS_ENRAGED if _enraged else BOLTS)

func _spawn_bolt(dir: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return   # mid scene-transition (e.g. death during a spiral) — no parent to spawn into
	var b := BOLT.instantiate()
	scene.add_child(b)
	b.global_position = global_position
	if b.has_method("setup"):
		b.setup(dir, ai.damage_hearts, &"player")

# A full ring fired at once; the random spin moves the safe gaps between volleys.
func _fire_ring(n: int) -> void:
	if not is_inside_tree():
		return
	var spin := randf() * TAU
	for i in range(n):
		_spawn_bolt(Vector2.RIGHT.rotated(spin + TAU * float(i) / float(n)))
	SignalBus.spell_cast.emit("Volley", global_position)

# A spinning spiral: `arms` bolts each tick while the aim ROTATES, over ~0.5s — the arms sweep the
# floor so there's no static safe gap, you have to circle-strafe. Denser/faster when enraged.
func _fire_spiral(arms: int) -> void:
	if not is_inside_tree():
		return
	SignalBus.spell_cast.emit("Volley", global_position)
	var shots := 10 if _enraged else 8
	var spin := randf() * TAU
	var step := TAU / float(shots) * 1.5   # >1 full turn so it spirals out, never closing into a ring
	for s in range(shots):
		if not is_inside_tree():
			return
		for a in range(arms):
			_spawn_bolt(Vector2.RIGHT.rotated(spin + step * s + TAU * float(a) / float(arms)))
		await get_tree().create_timer(0.06).timeout

func _on_health_changed(current: float, maximum: float) -> void:
	if _enraged or current <= 0.0 or current > maximum * 0.5:
		return
	_enraged = true
	ai.move_speed *= 1.3
	_base_tint = Color(1.0, 0.6, 0.5)   # overheating — telegraphs now return to this
	modulate = _base_tint
	SignalBus.ratings_spike.emit("DRAMA_SPIKE")

func _on_defeated() -> void:
	SignalBus.ratings_spike.emit("FATALITY")
	SignalBus.toast.emit("HEXGUN OFFLINE!", global_position)
