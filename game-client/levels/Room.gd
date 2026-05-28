# Room.gd
# A parametric gray-box room, built entirely in code so there's no fragile hand-authored
# geometry. Each side is two wall segments leaving a centered GAP; the gap is plugged by a
# removable "door" so a side is solid UNLESS the LevelGenerator opens it toward a neighbour.
extends Node2D
class_name Room

const CELL := 768.0     # MUST match LevelGenerator's grid spacing
const WALL := 24.0
const GAP := 220.0

# Outward grid normals per side.
const DIRS := {
	"North": Vector2(0, -1), "South": Vector2(0, 1),
	"East": Vector2(1, 0), "West": Vector2(-1, 0),
}

var room_type: String = "Combat"
var enemies_root: Node2D
var _doors: Dictionary = {}   # dir -> StaticBody2D plugging the gap (present = closed)

# Call BEFORE the node enters the tree (the generator does) so _ready paints the right floor.
func setup(type: String) -> void:
	room_type = type

func _ready() -> void:
	_build_floor()
	for dir in DIRS:
		_build_wall(dir)
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

func _build_floor() -> void:
	var h := CELL * 0.5
	var f := Polygon2D.new()
	f.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	f.color = _floor_color()
	f.z_index = -10
	add_child(f)

func _floor_color() -> Color:
	match room_type:
		"Spawn": return Color(0.12, 0.17, 0.22)
		"Boss": return Color(0.24, 0.10, 0.13)
		"PhaseDoor": return Color(0.10, 0.20, 0.17)
		_: return Color(0.14, 0.14, 0.18)

func _build_wall(dir: String) -> void:
	var n: Vector2 = DIRS[dir]
	var center := n * (CELL * 0.5)
	var tangent := Vector2(absf(n.y), absf(n.x))      # runs along the wall
	var seg_len := (CELL - GAP) * 0.5
	var off := (GAP * 0.5) + (seg_len * 0.5)
	_add_segment(center + tangent * off, dir, seg_len, Color(0.40, 0.40, 0.52))
	_add_segment(center - tangent * off, dir, seg_len, Color(0.40, 0.40, 0.52))
	_doors[dir] = _add_segment(center, dir, GAP, Color(0.46, 0.34, 0.52))   # closed door plug

func _add_segment(pos: Vector2, dir: String, length: float, color: Color) -> StaticBody2D:
	var n: Vector2 = DIRS[dir]
	var horizontal := absf(n.y) > 0.5                  # N/S walls run horizontally
	var size := Vector2(length, WALL) if horizontal else Vector2(WALL, length)
	var body := StaticBody2D.new()
	body.position = pos
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	vis.color = color
	body.add_child(vis)
	add_child(body)
	return body

# Open the gap toward a neighbouring room (remove the door plug).
func open_exit(dir: String) -> void:
	if _doors.has(dir):
		_doors[dir].queue_free()
		_doors.erase(dir)

# A random point safely inside the walls (for spawning).
func interior_point() -> Vector2:
	var r := (CELL * 0.5) - WALL - 60.0
	return global_position + Vector2(randf_range(-r, r), randf_range(-r, r))
