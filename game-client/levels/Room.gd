# Room.gd
# A room's floor + cover + enemy container, sized to an arbitrary rect handed in by the
# LevelGenerator (which owns the walls — they're built globally by edge-sampling the whole
# walkable layout, so doorways form automatically where corridors meet rooms). The one
# exception is `seal` mode: a standalone sealed box (the Safe Room prefab) builds its own
# four solid walls since it isn't part of the generated layout.
extends Node2D
class_name Room

const WALL := 24.0
const COVER_COLOR := Color(0.30, 0.33, 0.42)
const LOS_LAYER := 2   # collision bit walls/cover also sit on, so LoS rays hit ONLY environment
const SEAL_LAYER := 4  # boss-arena seal barriers ALSO sit here; Phasing Flight keeps colliding with this
                       # bit (only) during a phase, so an AeroWraith can't dash out of a locked boss room
                       # (not the player or other mobs, which stay on layer 1)
const SIDES := {
	"North": Vector2(0, -1), "South": Vector2(0, 1),
	"East": Vector2(1, 0), "West": Vector2(-1, 0),
}

@export var room_type: String = "Combat"
@export var seal: bool = false   # standalone sealed box (Safe Room); generator rooms leave false

var size: Vector2 = Vector2(768, 768)
var enemies_root: Node2D
var _cover_rects: Array[Rect2] = []   # local-space footprints so spawns avoid cover
var _cover_bodies: Array[Node] = []   # the cover StaticBody2Ds (so a stair can clear nearby ones)

# Generator calls this BEFORE add_child so _ready paints the right floor/size.
func setup(type: String, sz: Vector2) -> void:
	room_type = type
	size = sz

func _ready() -> void:
	_build_floor()
	if seal:
		_build_seal_walls()
	_build_cover()
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

func _build_floor() -> void:
	var h := size * 0.5
	add_child(make_floor(PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]), _floor_color()))

# Shared builders (static so the LevelGenerator reuses them for corridor floors + walls).
static func make_floor(corners: PackedVector2Array, color: Color) -> Polygon2D:
	var f := Polygon2D.new()
	f.polygon = corners
	f.color = color
	f.z_index = -10
	# Faint grid inside the slab — sells the simulated-dungeon look and gives movement something to
	# slide past (a flat untextured floor makes a top-down game feel like it's drifting).
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		bounds = bounds.expand(c)
	var grid := FloorGrid.new()
	grid.rect = bounds
	grid.line_color = color.lightened(0.16)
	f.add_child(grid)
	return f

static func make_rect_body(pos: Vector2, block_size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1 | LOS_LAYER   # layer 1 = physics; layer 2 = line-of-sight rays
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = block_size
	cs.shape = shape
	body.add_child(cs)
	var hw := block_size.x * 0.5
	var hh := block_size.y * 0.5
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	vis.color = color
	body.add_child(vis)
	# Fake a light source from the north: a bright cap on the top edge and a dark skirt on the bottom.
	# Two flat quads, but they give the block a sense of HEIGHT — the cheapest depth cue in 2D, and the
	# closest thing a flat top-down scene gets to the shading a 3D renderer would hand you for free.
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 5.0), Vector2(-hw, -hh + 5.0)])
	cap.color = color.lightened(0.34)
	body.add_child(cap)
	var skirt := Polygon2D.new()
	skirt.polygon = PackedVector2Array([Vector2(-hw, hh - 4.0), Vector2(hw, hh - 4.0), Vector2(hw, hh), Vector2(-hw, hh)])
	skirt.color = color.darkened(0.45)
	body.add_child(skirt)
	return body

func _floor_color() -> Color:
	match room_type:
		# Deliberately DARK + desaturated: the mobs are the only saturated, glowing things on screen, so
		# they read instantly against the ground. A room tinted the same hue as its occupants (the old
		# bright-red boss room vs red goblins) camouflages the very thing you need to see.
		"Spawn": return Color(0.10, 0.13, 0.17)
		"Boss": return Color(0.17, 0.075, 0.10)
		"MiniBoss": return Color(0.16, 0.115, 0.075)
		"PhaseDoor": return Color(0.075, 0.15, 0.13)
		"Safe": return Color(0.075, 0.135, 0.15)
		_: return Color(0.105, 0.105, 0.14)

# Sealed box: four solid walls with no openings (Safe Room).
func _build_seal_walls() -> void:
	for side in SIDES:
		var n: Vector2 = SIDES[side]
		var horizontal := absf(n.y) > 0.5
		var half_n := (size.y if horizontal else size.x) * 0.5
		var run := (size.x if horizontal else size.y) + WALL * 2.0
		var seg := Vector2(run, WALL) if horizontal else Vector2(WALL, run)
		_add_block(n * half_n, seg, Color(0.40, 0.40, 0.52))

# Add a solid rect block as a child (seal walls + cover use this).
func _add_block(pos: Vector2, block_size: Vector2, color: Color) -> StaticBody2D:
	var body := make_rect_body(pos, block_size, color)
	add_child(body)
	return body

# Combat rooms get a random cover layout in the corner quadrants — placed and sized RELATIVE to
# the room so cover actually shows up in the varied BSP rooms (a fixed offset skipped most of
# them). The central cross stays clear-ish so doorways aren't walled. Other room types stay clear.
func _build_cover() -> void:
	if room_type not in ["Combat", "Boss", "MiniBoss"]:
		return   # combat-ish rooms get cover (boss arenas too — strategic, lets you juke the boss
		         # around it); Spawn/Safe/PhaseDoor stay clear. Bosses path AROUND cover (navmesh-only,
		         # no beeline) so cover both works as cover AND stops them wedging.
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	if minf(hx, hy) < 150.0:
		return   # only the genuinely tiny rooms stay clear
	var bs := clampf(minf(hx, hy) * 0.30, 64.0, 150.0)   # block size scales with the room
	var max_ox := hx - WALL - bs * 0.5 - 8.0
	var max_oy := hy - WALL - bs * 0.5 - 8.0
	if max_ox < 90.0 or max_oy < 90.0:
		return
	var ox := clampf(hx * 0.5, 90.0, max_ox)   # quadrant offset, kept inside the walls
	var oy := clampf(hy * 0.5, 90.0, max_oy)
	match ["quad", "diagonal", "scatter"].pick_random():   # ('open' rooms return with the cover-variety pass)
		"quad":
			for s in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				_add_cover(Vector2(s.x * ox, s.y * oy), Vector2(bs, bs))
		"diagonal":
			_add_cover(Vector2(ox, oy), Vector2(bs, bs))
			_add_cover(Vector2(-ox, -oy), Vector2(bs, bs))
		"scatter":
			for _i in range(randi_range(3, 5)):
				var sx := 1.0 if randf() < 0.5 else -1.0
				var sy := 1.0 if randf() < 0.5 else -1.0
				var px := randf_range(110.0, ox) if ox > 110.0 else ox
				var py := randf_range(110.0, oy) if oy > 110.0 else oy
				_add_cover(Vector2(sx * px, sy * py), Vector2(randf_range(80.0, bs), randf_range(80.0, bs)))
		"open":
			pass

func _add_cover(pos: Vector2, block_size: Vector2) -> void:
	_cover_bodies.append(_add_block(pos, block_size, COVER_COLOR))
	_cover_rects.append(Rect2(pos - block_size * 0.5 - Vector2(40, 40), block_size + Vector2(80, 80)))

# Cover footprints in WORLD space (for baking nav-mesh obstructions so agents path AROUND cover).
func cover_world_rects() -> Array:
	var out := []
	for r in _cover_rects:
		out.append(Rect2(global_position + r.position, r.size))
	return out

# Free any cover blocks near a point (so a stair / feature dropped in after isn't walled off).
func clear_cover_at(local_pos: Vector2, radius: float) -> void:
	for b in _cover_bodies:
		if is_instance_valid(b) and b.position.distance_to(local_pos) < radius:
			b.queue_free()

# A random point inside the walls (for spawning), avoiding cover footprints.
func interior_point() -> Vector2:
	var rx := size.x * 0.5 - WALL - 60.0
	var ry := size.y * 0.5 - WALL - 60.0
	for _try in range(8):
		var p := Vector2(randf_range(-rx, rx), randf_range(-ry, ry))
		if not _in_cover(p):
			return global_position + p
	return global_position + Vector2(randf_range(-rx, rx), randf_range(-ry, ry))

func _in_cover(local_p: Vector2) -> bool:
	for rect in _cover_rects:
		if rect.has_point(local_p):
			return true
	return false
