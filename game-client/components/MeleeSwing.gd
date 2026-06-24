# MeleeSwing.gd
# Art-free melee sweep VFX: a bright slash band that arcs across the swing cone and fades.
# Lives as a child of the attacker (drawn in local space, centred on the body). Reused —
# call play() each swing. No textures; immediate-mode _draw, like HealthBar.
extends Node2D
class_name MeleeSwing

var _range: float = 96.0
var _arc: float = deg_to_rad(120.0)   # full cone the slash sweeps through
var _facing: float = 0.0              # centre angle of the swing
var _progress: float = 1.0            # 0->1 sweep; >=1 means finished (nothing drawn)
var _tint: Color = Color(0.8, 0.95, 1.0)   # slash colour (player = blue; enemies pass red)

const SWEEP_TIME := 0.18
const BLADE_DEG := 30.0               # angular width of the bright slash band

var _tw: Tween

func _ready() -> void:
	z_index = 10   # draw the slash above bodies

func play(aim: Vector2, range_px: float, arc_deg: float, tint: Color = Color(0.8, 0.95, 1.0)) -> void:
	_facing = aim.angle()
	_range = range_px
	_arc = deg_to_rad(arc_deg)
	_tint = tint
	_progress = 0.0
	if _tw and _tw.is_valid():
		_tw.kill()   # robust if a faster cooldown ever overlaps swings
	_tw = create_tween()
	_tw.tween_method(_advance, 0.0, 1.0, SWEEP_TIME)

func _advance(p: float) -> void:
	_progress = p
	queue_redraw()

func _draw() -> void:
	if _progress >= 1.0:
		return
	# Leading edge travels from one side of the cone to the other as progress runs 0->1.
	var lead := _facing - _arc * 0.5 + _arc * _progress
	var blade := deg_to_rad(BLADE_DEG)
	var col := Color(_tint.r, _tint.g, _tint.b, (1.0 - _progress) * 0.85)
	var pts: PackedVector2Array = [Vector2.ZERO]
	var steps := 8
	for i in range(steps + 1):
		var a := lead - blade + blade * (float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * _range)
	draw_colored_polygon(pts, col)
