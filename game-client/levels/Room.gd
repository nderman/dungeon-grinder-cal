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
	return body

func _floor_color() -> Color:
	match room_type:
		"Spawn": return Color(0.12, 0.17, 0.22)
		"Boss": return Color(0.24, 0.10, 0.13)
		"MiniBoss": return Color(0.22, 0.15, 0.10)
		"PhaseDoor": return Color(0.10, 0.20, 0.17)
		"Safe": return Color(0.10, 0.18, 0.20)
		_: return Color(0.14, 0.14, 0.18)

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
	if room_type != "Combat":
		return
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
	_add_block(pos, block_size, COVER_COLOR)
	_cover_rects.append(Rect2(pos - block_size * 0.5 - Vector2(40, 40), block_size + Vector2(80, 80)))

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
