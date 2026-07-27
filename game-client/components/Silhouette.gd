# Silhouette.gd
# The art pass, in code. Replaces each entity's flat gray Polygon2D box with a readable neon-vector
# body: a soft glow halo, a filled shape, an inner core, a bright outline, plus per-archetype accents
# (eyes / plates / spikes). Every archetype gets a DISTINCT silhouette so a goblin, a screamer and a
# brute read apart at a glance — the "which one is dangerous?" problem, solved with shape, not detail.
#
# Why drawn, not sprites: it fits the fiction (a computer-simulated dungeon), needs no binary assets,
# version-controls as text, and renders identically on web. The glow is layered translucent polygons
# rather than WorldEnvironment bloom, which is unreliable across the mobile/GL web backends.
#
# Drawn ONCE (no per-frame _draw) so 40 mobs cost nothing. `modulate` on the parent still tints the
# whole thing, so the telegraph flash / elite gold / elemental tint all keep working untouched.
class_name Silhouette
extends Node2D

# THE shape vocabulary — one list, so `_points`, `_draw_accents` and the tests can't drift apart
# (they already had on the first cut: two archetypes missing from the doc, one listed that didn't exist).
const SHAPES := ["player", "goblin", "screamer", "brute", "sniper", "cleric", "healer",
	"boss", "turret", "showrunner", "npc", "blob"]

@export var shape: String = "blob"   # one of SHAPES; anything unknown falls back to the blob
@export var tint: Color = Color(0.6, 0.7, 0.8)   # alpha IS honoured (scales the whole body)
@export var radius: float = 16.0
@export var glow: bool = true

# Halo layers: [scale, alpha] — biggest/faintest first, so they stack into a soft falloff.
const GLOW_LAYERS: Array[Vector2] = [Vector2(1.55, 0.05), Vector2(1.34, 0.08), Vector2(1.16, 0.13)]
# Contact shadow. Deliberately a CENTRED CIRCLE: the body rotates to face its target, and an offset or
# squashed shadow would spin with it (making the fake light source orbit the mob). A centred circle is
# rotation-invariant, so facing is free and the grounding still reads.
const SHADOW_RADIUS := 0.88                 # × radius
const SHADOW_ALPHA := 0.32

func _ready() -> void:
	queue_redraw()

# Re-tint at runtime (the shop/townsfolk NPCs colour themselves by role).
func set_tint(c: Color) -> void:
	tint = c
	queue_redraw()

# --- Facing -------------------------------------------------------------------------------------
# Point the body along `dir`. This is NODE rotation, which does not dirty the cached draw commands —
# so turning to face a target every frame is free. The directional shapes (the player's kite, the
# sniper's muzzle, the goblin's eyes) only make sense once something calls these.
func face(dir: Vector2) -> void:
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()

# Eased turn for mobs, so they swing round to face you instead of snapping like a turret.
func face_smooth(dir: Vector2, delta: float, speed: float = 10.0) -> void:
	if dir.length_squared() > 0.0001:
		rotation = lerp_angle(rotation, dir.angle(), minf(1.0, speed * delta))

func _draw() -> void:
	var body := _points(shape, radius)
	# Contact shadow first (underneath everything). Flat top-down art floats without one — this is the
	# 2D stand-in for the grounding a 3D renderer gives you.
	draw_circle(Vector2.ZERO, radius * SHADOW_RADIUS, Color(0, 0, 0, SHADOW_ALPHA * tint.a))
	if glow:
		for layer in GLOW_LAYERS:
			draw_colored_polygon(_scaled(body, layer.x), _shade(0.0, layer.y))
	draw_colored_polygon(body, _shade(0.0, 0.92))                              # filled body
	# Inner core kept small — at 0.55 it swallowed the little mobs and they all read as pale discs.
	draw_colored_polygon(_scaled(body, 0.44), _shade(0.35))
	var edge := PackedVector2Array(body)
	edge.append(body[0])                                                       # close the loop
	draw_polyline(edge, _shade(0.7), 2.0, true)                                # crisp neon outline
	_draw_accents(radius)

# Tint lightened by `amount`, carrying the tint's own alpha (so an entity can be drawn semi-transparent).
# `alpha_override` >= 0 sets the alpha outright, still scaled by the tint's alpha.
func _shade(amount: float, alpha_override: float = -1.0) -> Color:
	var c := tint.lightened(amount) if amount > 0.0 else tint
	return Color(c.r, c.g, c.b, (alpha_override if alpha_override >= 0.0 else 1.0) * tint.a)

# --- Shapes -------------------------------------------------------------------------------------
# Unit-ish polygons (roughly -1..1), scaled by `radius`. Each archetype is a different SILHOUETTE —
# bulk, spikes and proportions do the reading, since everything is the same flat colour family.
# Shapes are authored pointing RIGHT (+x) and turned by `face()` / `face_smooth()`: the Player aims its
# body with the reticle, mobs swing round toward their target.
func _points(kind: String, r: float) -> PackedVector2Array:
	var p: PackedVector2Array
	match kind:
		"player":   # sleek forward-pointing kite — the only thing on screen shaped like an arrow
			p = PackedVector2Array([Vector2(1.05, 0), Vector2(0.1, 0.82), Vector2(-0.7, 0.62),
				Vector2(-0.42, 0), Vector2(-0.7, -0.62), Vector2(0.1, -0.82)])
		"goblin":   # squat lopsided grunt — small and unthreatening
			p = PackedVector2Array([Vector2(0.85, 0.15), Vector2(0.45, 0.8), Vector2(-0.5, 0.9),
				Vector2(-0.9, 0.2), Vector2(-0.68, -0.6), Vector2(0.0, -0.92), Vector2(0.7, -0.5)])
		"screamer": # jagged 9-point star — reads as FAST and spiky even at a glance
			p = _star(9, 1.0, 0.42)
		"brute":    # wide heavy octagon — visually the heaviest body on the floor
			p = PackedVector2Array([Vector2(0.92, -0.38), Vector2(0.92, 0.38), Vector2(0.38, 0.98),
				Vector2(-0.45, 0.95), Vector2(-0.98, 0.3), Vector2(-0.98, -0.3),
				Vector2(-0.45, -0.95), Vector2(0.38, -0.98)])
		"sniper":   # narrow dart with a long muzzle — "this one shoots you"
			p = PackedVector2Array([Vector2(1.3, -0.09), Vector2(1.3, 0.09), Vector2(0.25, 0.42),
				Vector2(-0.72, 0.72), Vector2(-0.88, 0.0), Vector2(-0.72, -0.72), Vector2(0.25, -0.42)])
		"cleric":   # rounded shield-bearer
			p = _regular(10, 0.95)
		"healer":   # rounded, softer + slightly smaller than the cleric
			p = _regular(12, 0.88)
		"boss":     # big jagged crown — the melee bruiser, unmistakably the thing in charge
			p = _star(12, 1.0, 0.72)
		"turret":   # squat armoured hexagon — the artillery boss reads as a machine, not a beast
			p = _regular(6, 1.0)
		"showrunner":   # sharp 5-point star — the summoner, all angles and theatre
			p = _star(5, 1.05, 0.5)
		"npc":      # upright townsfolk: tall, narrow, non-threatening (nothing else is a tall rectangle)
			p = PackedVector2Array([Vector2(0.45, -1.1), Vector2(0.62, 0.2), Vector2(0.4, 1.1),
				Vector2(-0.4, 1.1), Vector2(-0.62, 0.2), Vector2(-0.45, -1.1)])
		_:
			p = _regular(8, 0.9)
	# Normalise to a unit outer extent so `radius` means the TRUE drawn reach for every shape. Without
	# this the overhanging shapes (the sniper's muzzle at 1.3, the npc at 1.1) drew outside the body's
	# collision circle — i.e. you'd aim at pixels that aren't actually hittable.
	var longest := 0.0
	for v in p:
		longest = maxf(longest, v.length())
	return _scaled(p, r / longest if longest > 0.0 else r)

func _regular(n: int, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		out.append(Vector2.RIGHT.rotated(TAU * float(i) / n) * rad)
	return out

# Alternating outer/inner radius — the spiky archetypes (screamer, boss).
func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points * 2):
		var a := TAU * float(i) / float(points * 2)
		out.append(Vector2.RIGHT.rotated(a) * (outer if i % 2 == 0 else inner))
	return out

func _scaled(pts: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(v * s)
	return out

# --- Accents ------------------------------------------------------------------------------------
# A few cheap marks that sell each archetype's read (and give the body a "front").
func _draw_accents(r: float) -> void:
	var ink := Color(0.03, 0.03, 0.06, 0.85)
	match shape:
		"player":
			draw_circle(Vector2(r * 0.28, 0), r * 0.2, tint.lightened(0.85))   # bright core "visor"
		"goblin":   # big dark eyes — at 15px this is the only detail that survives
			draw_circle(Vector2(r * 0.34, -r * 0.3), r * 0.24, ink)
			draw_circle(Vector2(r * 0.34, r * 0.3), r * 0.24, ink)
		"screamer":
			# a gaping mouth — the no-telegraph swarmer looks like it's mid-shriek
			draw_circle(Vector2(r * 0.15, 0), r * 0.3, ink)
			draw_circle(Vector2(r * 0.15, 0), r * 0.16, tint.lightened(0.6))
		"brute":
			for dx in [-0.35, 0.0, 0.35]:   # armour plate seams across the bulk
				draw_line(Vector2(r * dx, -r * 0.7), Vector2(r * dx, r * 0.7), ink, 2.0)
		"sniper":
			draw_line(Vector2(r * 0.3, 0), Vector2(r * 1.25, 0), ink, 3.0)     # the barrel
			draw_circle(Vector2(-r * 0.15, 0), r * 0.18, tint.lightened(0.8))  # scope glint
		"cleric":   # the aura-projecting shield, dark-backed so it reads against a pale body
			draw_arc(Vector2.ZERO, r * 0.66, -PI * 0.55, PI * 0.55, 18, ink, 5.0)
			draw_arc(Vector2.ZERO, r * 0.66, -PI * 0.5, PI * 0.5, 18, Color(0.5, 0.8, 1.0), 3.0)
		"healer":
			draw_line(Vector2(-r * 0.4, 0), Vector2(r * 0.4, 0), tint.lightened(0.9), 3.0)
			draw_line(Vector2(0, -r * 0.4), Vector2(0, r * 0.4), tint.lightened(0.9), 3.0)
		"boss":
			draw_circle(Vector2.ZERO, r * 0.3, ink)
			draw_circle(Vector2.ZERO, r * 0.17, tint.lightened(0.9))           # a single baleful eye
		"turret":
			for i in range(6):                                                 # radiating gun barrels
				var d := Vector2.RIGHT.rotated(TAU * float(i) / 6.0)
				draw_line(d * r * 0.55, d * r * 1.15, ink, 3.0)
			draw_circle(Vector2.ZERO, r * 0.3, tint.lightened(0.8))            # overheating core
		"showrunner":
			draw_circle(Vector2.ZERO, r * 0.34, ink)
			draw_circle(Vector2.ZERO, r * 0.2, tint.lightened(0.9))            # broadcast lens
			draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 22, tint.lightened(0.75), 2.0)
		"npc":
			draw_circle(Vector2(0, -r * 0.72), r * 0.34, tint.lightened(0.55))  # head
