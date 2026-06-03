# Bomb.gd
# A dropped charge that detonates after a fuse: a big AoE blast that damages enemies AND the player
# (friendly fire) — drop it and RETREAT. Art-free: draws a dark sphere with a red core that blinks
# faster as it nears the boom, then an expanding orange shockwave. Frees itself after the blast.
extends Node2D

const BOOM_DUR := 0.32   # explosion-ring animation length

var _damage: float = 1.0
var _radius: float = 150.0
var _fuse: float = 1.2
var _friendly_fire: bool = false

var _elapsed: float = 0.0
var _exploding: bool = false
var _boom_t: float = 0.0

func setup(damage: float, radius: float, fuse: float, friendly_fire: bool) -> void:
	_damage = damage
	_radius = radius
	_fuse = fuse
	_friendly_fire = friendly_fire

func _ready() -> void:
	z_index = 11

func _process(delta: float) -> void:
	if _exploding:
		_boom_t += delta / BOOM_DUR
		queue_redraw()
		if _boom_t >= 1.0:
			queue_free()
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _fuse:
		_detonate()

func _detonate() -> void:
	_exploding = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and global_position.distance_to((e as Node2D).global_position) <= _radius:
			_hit(e)
	if _friendly_fire:
		var p := get_tree().get_first_node_in_group("player")
		if p is Node2D and global_position.distance_to((p as Node2D).global_position) <= _radius:
			_hit(p)

func _hit(n: Node) -> void:
	var hc := n.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null:
		return
	var prot := n.get_node_or_null("ProtectionComponent") as ProtectionComponent
	hc.take_damage(prot.handle_incoming_damage(_damage) if prot else _damage)

func _draw() -> void:
	if _exploding:
		var r := _radius * _boom_t
		var fade := 1.0 - _boom_t
		draw_circle(Vector2.ZERO, r * 0.75, Color(1.0, 0.45, 0.08, fade * 0.35))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.6, 0.12, fade * 0.95), 6.0, true)
		return
	# Fuse: a dark charge with a core that blinks faster the closer it is to going off.
	draw_circle(Vector2.ZERO, 12.0, Color(0.14, 0.14, 0.18))
	var rate: float = lerpf(2.0, 12.0, clampf(_elapsed / _fuse, 0.0, 1.0))
	if fmod(_elapsed * rate, 1.0) < 0.5:
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.3, 0.2))
