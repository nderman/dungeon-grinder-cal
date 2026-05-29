# Room.gd
# A parametric gray-box room, built entirely in code so there's no fragile hand-authored
# geometry. Each side is two wall segments leaving a centered GAP; the gap is plugged by a
# removable "door" so a side is solid UNLESS the LevelGenerator opens it toward a neighbour.
extends Node2D
class_name Room

const CELL := 768.0     # MUST match LevelGenerator's grid spacing
const WALL := 24.0
const GAP := 220.0

# Cover: solid blocks that break line-of-sight (bolts stop on StaticBody2D) and force movement.
# Kept in the four corner quadrants — out of the central door cross — so paths between any open
# doors always stay clear regardless of which sides the generator opens.
const COVER_COLOR := Color(0.30, 0.33, 0.42)
const COVER_CLEAR := 150.0   # half-width of the door cross channel left open (> GAP/2 = 110)

# Outward grid normals per side.
const DIRS := {
	"North": Vector2(0, -1), "South": Vector2(0, 1),
	"East": Vector2(1, 0), "West": Vector2(-1, 0),
}

var room_type: String = "Combat"
var enemies_root: Node2D
var _doors: Dictionary = {}          # dir -> StaticBody2D plugging the gap (present = closed)
var _open_dirs: Array[String] = []   # sides opened to neighbours (for boss lockdown)
var _barriers: Array[Node] = []      # temporary lockdown barriers across open doors
var _boss: Node = null
var _boss_triggered: bool = false
var _cover_rects: Array[Rect2] = []   # local-space cover footprints, so spawns can avoid them

# Call BEFORE the node enters the tree (the generator does) so _ready paints the right floor.
func setup(type: String) -> void:
	room_type = type

func _ready() -> void:
	_build_floor()
	for dir in DIRS:
		_build_wall(dir)
	_build_cover()
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
		"MiniBoss": return Color(0.22, 0.15, 0.10)
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

# Combat rooms get a random cover layout so each plays differently and ranged mobs can't
# just plink across an empty box. Other room types (Spawn/Boss/MiniBoss/PhaseDoor) stay clear.
func _build_cover() -> void:
	if room_type != "Combat":
		return
	match ["quad", "diagonal", "scatter", "open"].pick_random():
		"quad":   # a pillar in each quadrant
			for s in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				_add_cover(s * 210.0, Vector2(130, 130))
		"diagonal":   # two big blocks on one diagonal
			_add_cover(Vector2(205, 205), Vector2(150, 150))
			_add_cover(Vector2(-205, -205), Vector2(150, 150))
		"scatter":   # 3–5 crates of varied size in the quadrant ring
			for _i in range(randi_range(3, 5)):
				var sz := randf_range(90.0, 150.0)
				_add_cover(_scatter_pos(), Vector2(sz, sz))
		"open":   # some rooms are deliberately bare
			pass

# Place a cover block AND record its footprint (with a margin) so spawns steer clear.
func _add_cover(pos: Vector2, size: Vector2) -> void:
	_add_block(pos, size, COVER_COLOR)
	_cover_rects.append(Rect2(pos - size * 0.5 - Vector2(40, 40), size + Vector2(80, 80)))

# A cover position in a corner quadrant — clear of the central door cross AND the walls.
func _scatter_pos() -> Vector2:
	var lo := COVER_CLEAR + 70.0
	var hi := (CELL * 0.5) - WALL - 95.0
	var sx := 1.0 if randf() < 0.5 else -1.0
	var sy := 1.0 if randf() < 0.5 else -1.0
	return Vector2(randf_range(lo, hi) * sx, randf_range(lo, hi) * sy)

func _add_segment(pos: Vector2, dir: String, length: float, color: Color) -> StaticBody2D:
	var n: Vector2 = DIRS[dir]
	var horizontal := absf(n.y) > 0.5                  # N/S walls run horizontally
	var size := Vector2(length, WALL) if horizontal else Vector2(WALL, length)
	return _add_block(pos, size, color)

# Generic solid rectangle: StaticBody2D + collision + visual. Walls, lockdown barriers and
# cover all share this — they're the same body, only position/size/color/alpha differ.
func _add_block(pos: Vector2, size: Vector2, color: Color) -> StaticBody2D:
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
		if dir not in _open_dirs:
			_open_dirs.append(dir)

# A random point safely inside the walls (for spawning), avoiding cover footprints.
func interior_point() -> Vector2:
	var r := (CELL * 0.5) - WALL - 60.0
	for _try in range(8):
		var p := Vector2(randf_range(-r, r), randf_range(-r, r))
		if not _in_cover(p):
			return global_position + p
	return global_position + Vector2(randf_range(-r, r), randf_range(-r, r))

func _in_cover(local_p: Vector2) -> bool:
	for rect in _cover_rects:
		if rect.has_point(local_p):
			return true
	return false

# --- Boss lockdown: seal the room the moment the player steps in, until the boss falls. ---
func arm_boss_lock(boss: Node) -> void:
	_boss = boss
	# Trigger fills the interior but is inset from the walls, so it fires the instant the
	# player steps PAST a doorway — the barrier then seals just behind them, never on top.
	var trigger := Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var inset := (CELL * 0.5) - 84.0
	shape.size = Vector2(inset * 2.0, inset * 2.0)
	cs.shape = shape
	trigger.add_child(cs)
	add_child(trigger)
	trigger.body_entered.connect(_on_boss_trigger)

func _on_boss_trigger(body: Node) -> void:
	if _boss_triggered or not body.is_in_group("player"):
		return
	_boss_triggered = true
	if _boss == null or not is_instance_valid(_boss):
		return   # boss already beaten — no need to trap anyone
	lock()
	var ai := _boss.get_node_or_null("AIComponent")
	if ai and ai.has_method("activate"):
		ai.activate()       # the boss only wakes once you're sealed in
	var hc := _boss.get_node_or_null("HealthComponent")
	if hc:
		hc.health_depleted.connect(unlock)
	_boss.tree_exited.connect(unlock)   # safety: freed = beaten

func lock() -> void:
	for dir in _open_dirs:
		_barriers.append(_make_barrier(dir))

# A thick energy barrier across an open doorway (thicker than a wall so a Dash can't tunnel it).
func _make_barrier(dir: String) -> StaticBody2D:
	var n: Vector2 = DIRS[dir]
	var horizontal := absf(n.y) > 0.5
	var thick := WALL * 2.5
	var size := Vector2(GAP, thick) if horizontal else Vector2(thick, GAP)
	return _add_block(n * (CELL * 0.5), size, Color(0.9, 0.2, 0.3, 0.85))

func unlock() -> void:
	for b in _barriers:
		if is_instance_valid(b):
			b.queue_free()
	_barriers.clear()
