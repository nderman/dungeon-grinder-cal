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

# Combat rooms get a random cover layout in the corner quadrants (clear of the central door
# cross), scaled to the room's size. Other room types stay clear.
func _build_cover() -> void:
	if room_type != "Combat":
		return
	var lo := 220.0                                   # > door half-width: keeps the cross clear
	var hi_x := size.x * 0.5 - WALL - 95.0
	var hi_y := size.y * 0.5 - WALL - 95.0
	if hi_x <= lo or hi_y <= lo:
		return   # room too small for cover
	match ["quad", "diagonal", "scatter", "open"].pick_random():
		"quad":
			for s in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				_add_cover(Vector2(s.x * lo, s.y * lo), Vector2(130, 130))
		"diagonal":
			_add_cover(Vector2(lo, lo), Vector2(150, 150))
			_add_cover(Vector2(-lo, -lo), Vector2(150, 150))
		"scatter":
			for _i in range(randi_range(3, 5)):
				var sz := randf_range(90.0, 150.0)
				_add_cover(_scatter_pos(lo, hi_x, hi_y), Vector2(sz, sz))
		"open":
			pass

func _scatter_pos(lo: float, hi_x: float, hi_y: float) -> Vector2:
	var sx := 1.0 if randf() < 0.5 else -1.0
	var sy := 1.0 if randf() < 0.5 else -1.0
	return Vector2(randf_range(lo, hi_x) * sx, randf_range(lo, hi_y) * sy)

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
