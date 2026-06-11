# AbilityFx.gd
# Art-free, reusable VFX for non-projectile ability effects (mirrors MeleeSwing): an expanding
# nova ring, a heal pulse, and a blink streak. Lives as a child of the player, drawn in local space
# centred on the body; call the matching play_* method per cast. No textures — immediate-mode _draw.
extends Node2D
class_name AbilityFx

const DUR := 0.35

var _mode := ""
var _t := 1.0                  # 0→1 progress; >=1 = idle (nothing drawn)
var _radius := 160.0
var _color := Color.WHITE
var _streak := Vector2.ZERO    # local end-point for the blink streak
var _tw: Tween

func _ready() -> void:
	z_index = 11   # above bodies + the melee slash

func play_nova(radius: float, color: Color) -> void:
	_mode = "nova"; _radius = radius; _color = color; _start()

func play_pulse(color: Color) -> void:
	_mode = "pulse"; _radius = 80.0; _color = color; _start()

# local_end = where you came FROM, in this node's local space (player origin = 0,0).
func play_streak(local_end: Vector2, color: Color) -> void:
	_mode = "streak"; _streak = local_end; _color = color; _start()

# A SUSTAINED aura ring for `seconds` (Holy Shield's "you're protected" indicator) — pulses while up
# and fades out as it expires so you can time it. Re-cast restarts it (the buff refreshes too).
func play_shield(seconds: float, color: Color) -> void:
	_mode = "shield"; _color = color; _start(maxf(0.1, seconds))

func _start(seconds: float = DUR) -> void:
	_t = 0.0
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_advance, 0.0, 1.0, seconds)

func _advance(p: float) -> void:
	_t = p
	queue_redraw()

func _draw() -> void:
	if _t >= 1.0:
		return
	var fade := 1.0 - _t
	match _mode:
		"nova":
			var r := _radius * _t   # ring sweeps out to the true AoE radius
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, fade * 0.9), 6.0, true)
			draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 36, Color(_color.r, _color.g, _color.b, fade * 0.4), 3.0, true)
		"pulse":
			var rr := _radius * (0.4 + 0.6 * _t)
			draw_circle(Vector2.ZERO, rr, Color(_color.r, _color.g, _color.b, fade * 0.4))
		"streak":
			draw_line(Vector2.ZERO, _streak, Color(_color.r, _color.g, _color.b, fade * 0.85), 8.0)
		"shield":
			# A pulsing golden ring hugging the body for the whole buff; stays strong, then fades over
			# the final ~quarter so the drop is telegraphed. _t runs 0→1 across the buff's duration.
			var pulse := 0.7 + 0.3 * sin(_t * TAU * 9.0)
			var edge := minf(1.0, fade * 4.0)              # full until the last 25%, then fade out
			var a := (0.4 + 0.45 * pulse) * edge
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(_color.r, _color.g, _color.b, a), 3.0, true)
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, a * 0.5), 2.0, true)
