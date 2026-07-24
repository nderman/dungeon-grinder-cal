# TelegraphFx.gd
# A ground-danger indicator drawn during an enemy's wind-up so the incoming attack READS before it
# lands (WoW-style): a CONE for a locked swing, a LANE for a lunge/charge, a LINE for a ranged shot,
# a CIRCLE for an AoE. Translucent red that intensifies as the strike nears. The AIComponent drives it
# from _start_telegraph; bosses can call show_circle for their AoE. Purely cosmetic — no collision.
class_name TelegraphFx
extends Node2D

const DANGER := Color(1.0, 0.25, 0.2)
const ALPHA_MIN := 0.20   # at wind-up start
const ALPHA_MAX := 0.55   # at the strike

var _kind: String = ""     # "cone" | "lane" | "line" | "circle"
var _dir: Vector2 = Vector2.RIGHT
var _arc: float = 0.0      # radians (cone)
var _len: float = 0.0      # cone/line reach, lane length, circle radius
var _wid: float = 0.0      # lane width
var _t: float = 0.0
var _dur: float = 0.0

func _ready() -> void:
	z_index = 1          # above the floor + mob body; translucency keeps the mob readable
	visible = false
	set_process(false)

func show_cone(dir: Vector2, arc_rad: float, radius: float, duration: float) -> void:
	_dir = _safe_dir(dir); _arc = arc_rad; _len = radius
	_begin("cone", duration)

func show_lane(dir: Vector2, length: float, width: float, duration: float) -> void:
	_dir = _safe_dir(dir); _len = length; _wid = width
	_begin("lane", duration)

func show_line(dir: Vector2, length: float, duration: float) -> void:
	_dir = _safe_dir(dir); _len = length
	_begin("line", duration)

func show_circle(radius: float, duration: float) -> void:
	_len = radius
	_begin("circle", duration)

func clear() -> void:
	visible = false
	set_process(false)

func _begin(kind: String, duration: float) -> void:
	_kind = kind
	_dur = maxf(duration, 0.05)
	_t = 0.0
	visible = true
	set_process(true)
	queue_redraw()

func _safe_dir(d: Vector2) -> Vector2:
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT

func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		clear()
		return
	queue_redraw()

func _draw() -> void:
	var p := clampf(_t / _dur, 0.0, 1.0)
	var col := Color(DANGER.r, DANGER.g, DANGER.b, lerpf(ALPHA_MIN, ALPHA_MAX, p))
	match _kind:
		"cone":
			var pts := PackedVector2Array([Vector2.ZERO])
			var base := _dir.angle()
			var steps := 14
			for i in range(steps + 1):
				pts.append(Vector2.RIGHT.rotated(base - _arc * 0.5 + _arc * (float(i) / steps)) * _len)
			draw_colored_polygon(pts, col)
		"lane":
			var perp := _dir.orthogonal() * (_wid * 0.5)
			var end := _dir * _len
			draw_colored_polygon(PackedVector2Array([-perp, perp, end + perp, end - perp]), col)
		"line":
			draw_line(Vector2.ZERO, _dir * _len, col, 4.0)
		"circle":
			draw_circle(Vector2.ZERO, _len, col)
			draw_arc(Vector2.ZERO, _len, 0.0, TAU, 40, Color(DANGER.r, DANGER.g, DANGER.b, 0.9), 3.0)
