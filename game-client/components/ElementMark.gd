# ElementMark.gd
# A persistent at-a-glance indicator that a mob deals an ELEMENT on hit: a soft pulsing glow ring
# under the body — orange for burn, icy-blue for chill — so you can read the threat (and gear/play
# around it) before it lands. Art-free immediate-mode draw, like StatusEffect/AbilityFx. Attached to
# elemental mobs in LevelGenerator; scales with the body (boss vs trash) since it's a child.
class_name ElementMark
extends Node2D

const COLORS := {"burn": Color(1.0, 0.45, 0.1), "chill": Color(0.5, 0.8, 1.0)}

var element := "burn"
var _r := 18.0

func _ready() -> void:
	z_index = -1   # the glow sits BEHIND the body's Visual
	var cs := get_parent().get_node_or_null("CollisionShape2D")
	if cs is CollisionShape2D and cs.shape is CircleShape2D:
		_r = (cs.shape as CircleShape2D).radius

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c: Color = COLORS.get(element, Color.WHITE)
	var pulse := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.006)
	draw_circle(Vector2.ZERO, _r * 1.5, Color(c.r, c.g, c.b, 0.13 * pulse))                        # soft glow
	draw_arc(Vector2.ZERO, _r * 1.35, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.55 * pulse), 2.0, true)  # ring
