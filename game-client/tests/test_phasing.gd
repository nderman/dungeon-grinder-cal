extends TestCase
# Phasing Flight (AeroWraith): the passive is wired, and the eject's stuck-check — a Room.LOS_LAYER
# shape query — detects WALLS but NOT enemy-layer bodies, so a phase-dash ejects from geometry, never
# from merely standing on a mob. (The dash/eject motion itself is playtest-validated; this guards the
# query the safety net depends on.)
func _init() -> void: test_name = "phasing"

func run() -> void:
	var saved := GameManager.current_race
	GameManager.current_race = "AeroWraith"
	check(GameManager.has_passive("phasing_flight"), "AeroWraith grants Phasing Flight")
	GameManager.current_race = saved

	# The phase collides with SEAL_LAYER only (so it stops at a boss seal but slips through normal walls).
	# That ONLY works if the seal bit is disjoint from the physics (1) + LOS layers — guard the invariant.
	check(Room.SEAL_LAYER & (1 | Room.LOS_LAYER) == 0, "SEAL_LAYER is its own bit (phase mask won't catch normal walls)")

	var space := get_tree().root.get_world_2d().direct_space_state
	# Real walls sit on layer 1 | LOS_LAYER; an enemy-style body sits on physics layer 1 only.
	var wall := _body(1 | Room.LOS_LAYER, Vector2(9000, 9000))
	var mob := _body(1, Vector2(9000, 9600))
	add_child(wall)
	add_child(mob)
	await get_tree().physics_frame
	await get_tree().physics_frame

	check(_in_wall_at(space, Vector2(9000, 9000)), "overlapping a wall reads as in-wall")
	check(not _in_wall_at(space, Vector2(9400, 9000)), "open space does NOT read as in-wall")
	check(not _in_wall_at(space, Vector2(9000, 9600)), "an enemy-layer body does NOT read as in-wall")

	wall.queue_free()
	mob.queue_free()

func _body(layer: int, pos: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(120, 120)
	cs.shape = r
	b.add_child(cs)
	b.global_position = pos
	return b

# Mirrors Player._in_wall: a LOS_LAYER shape probe at `pos`.
func _in_wall_at(space: PhysicsDirectSpaceState2D, pos: Vector2) -> bool:
	var probe := RectangleShape2D.new()
	probe.size = Vector2(24, 24)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = probe
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = Room.LOS_LAYER
	q.collide_with_areas = false
	return not space.intersect_shape(q, 1).is_empty()
