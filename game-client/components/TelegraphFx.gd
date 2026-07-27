# TelegraphFx.gd
# A ground-danger indicator drawn during an enemy's wind-up so the incoming attack READS before it
# lands (WoW-style): a CONE for a swing, a LANE for a lunge/charge, a LINE for a ranged shot, a CIRCLE
# for an AoE. Translucent red that intensifies as the strike nears. Purely cosmetic — no collision.
#
# Shapes are drawn along +X and aimed with `point_at()`, which sets NODE ROTATION. That matters: node
# rotation doesn't dirty the cached draw commands, so the shape can TRACK a moving target every frame
# for free, then freeze when the attack commits. The freeze is the dodge cue.
class_name TelegraphFx
extends Node2D

const DANGER := Color(1.0, 0.25, 0.2)
const ALPHA_MIN := 0.20    # at wind-up start
const ALPHA_MAX := 0.55    # at the strike
const ALPHA_LOCKED := 0.7  # snapped to at the commit — a visible "this is where it lands" step
# Must match AIComponent.TELEGRAPH_TRACK_FRAC: the point in the wind-up where the aim stops tracking.
const LOCK_AT := 0.5

var _kind: String = ""     # "cone" | "lane" | "line" | "circle"
var _arc: float = 0.0      # radians (cone)
var _len: float = 0.0      # cone/line reach, lane length, circle radius
var _wid: float = 0.0      # lane width
var _t: float = 0.0
var _dur: float = 0.0

func _ready() -> void:
	z_index = 1          # above the floor + mob body; translucency keeps the mob readable
	visible = false
	set_process(false)

# Aim the shape. Free to call every frame — it only sets rotation, never a redraw.
func point_at(dir: Vector2) -> void:
	if dir.length_squared() > 0.000001:
		rotation = dir.angle()

func show_cone(arc_rad: float, radius: float, duration: float) -> void:
	_arc = arc_rad; _len = radius
	_begin("cone", duration)

func show_lane(length: float, width: float, duration: float) -> void:
	_len = length; _wid = width
	_begin("lane", duration)

func show_line(length: float, duration: float) -> void:
	_len = length
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
	rotation = 0.0        # never inherit a previous wind-up's aim; callers point_at() immediately
	visible = true
	set_process(true)
	_apply_ramp()
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		clear()
		return
	_apply_ramp()   # NOT queue_redraw: the geometry is static (aiming is rotation), so redrawing purely
	                # to change alpha would rebuild + re-triangulate the polygon and churn a GPU buffer
	                # EVERY frame — a genuinely bad pattern on the WebGL build. self_modulate is one
	                # property set, and multiplies through identically.

# Intensity ramp + the COMMIT cue. The shape brightens as the strike nears, and steps sharply at the
# lock so the freeze is legible even to a player who never moved (against whom the shape never rotated,
# so "it stopped tracking" would otherwise be invisible — and the guide promises that cue).
func _apply_ramp() -> void:
	var p := clampf(_t / _dur, 0.0, 1.0)
	var a := lerpf(ALPHA_MIN, ALPHA_MAX, p)
	if p >= LOCK_AT:
		a = maxf(a, ALPHA_LOCKED)
	self_modulate = Color(1, 1, 1, a)

func _draw() -> void:
	# Drawn at FULL alpha and dimmed by self_modulate — so the intensity ramp never touches this
	# command list. Runs once per wind-up, not once per frame.
	var col := DANGER
	match _kind:
		"cone":
			var pts := PackedVector2Array([Vector2.ZERO])
			var steps := 14
			for i in range(steps + 1):
				pts.append(Vector2.RIGHT.rotated(-_arc * 0.5 + _arc * (float(i) / steps)) * _len)
			draw_colored_polygon(pts, col)
		"lane":
			var perp := Vector2.DOWN * (_wid * 0.5)
			var end := Vector2.RIGHT * _len
			draw_colored_polygon(PackedVector2Array([-perp, perp, end + perp, end - perp]), col)
		"line":
			draw_line(Vector2.ZERO, Vector2.RIGHT * _len, col, 4.0)
		"circle":
			draw_circle(Vector2.ZERO, _len, col)
			draw_arc(Vector2.ZERO, _len, 0.0, TAU, 40, Color(DANGER.r, DANGER.g, DANGER.b, 0.9), 3.0)
