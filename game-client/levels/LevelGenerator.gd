# LevelGenerator.gd
# Builds an "Open Floor": a Random Walk over a grid, instancing one parametric Room per
# cell, opening doors between neighbours, scattering enemies + Phase-Doors, dropping a
# sub-dimensional Safe Room off-grid, and spawning the player in the Spawn room.
# Wire the PackedScene exports in Floor.tscn.
extends Node2D

@export var room_scene: PackedScene
@export var enemy_scene: PackedScene
@export var player_scene: PackedScene
@export var safe_room_scene: PackedScene
@export var phase_door_scene: PackedScene
@export var boss_scene: PackedScene
@export var room_count: int = 16
@export var grid_size: int = 16
@export var neighborhood_bosses: int = 2   # DCC: a floor has several bosses, not one

# Boss tiers. On Floor 1 every boss is arena-locked (per DCC lore).
const FLOOR_BOSS := {"hearts": 20.0, "damage": 2.0, "scale": 1.0, "tint": Color(1, 1, 1), "telegraph": 0.55, "speed": 340.0, "xp": 300}
const NEIGHBORHOOD_BOSS := {"hearts": 8.0, "damage": 1.0, "scale": 0.8, "tint": Color(1.0, 0.7, 0.4), "telegraph": 0.7, "speed": 290.0, "xp": 120}

var grid: Dictionary = {}                 # Vector2i -> type string
var rooms: Dictionary = {}                # Vector2i -> Room
var order: Array[Vector2i] = []           # walk order; [0] = spawn, back() = boss

func _ready() -> void:
	_walk()
	_designate()
	_instantiate_rooms()
	_place_safe_room()
	_spawn_player()

func _walk() -> void:
	var pos := Vector2i(grid_size / 2, grid_size / 2)
	grid[pos] = "Spawn"
	order.append(pos)
	while grid.size() < room_count:
		var step: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].pick_random()
		var next := pos + step
		if next.x < 0 or next.x >= grid_size or next.y < 0 or next.y >= grid_size:
			continue
		pos = next
		if not grid.has(pos):
			grid[pos] = "Combat"
			order.append(pos)

func _designate() -> void:
	grid[order.back()] = "Boss"   # the Floor Boss = furthest-walked room
	# Neighborhood bosses scattered across the floor (DCC: multiple bosses per floor).
	var combat := order.filter(func(p): return grid[p] == "Combat")
	for c in _pick_spread(combat, [order[0], order.back()], neighborhood_bosses):
		grid[c] = "MiniBoss"
	# Phase-Doors spread among what's left, away from spawn + the boss rooms.
	combat = order.filter(func(p): return grid[p] == "Combat")
	var anchors: Array = [order[0], order.back()]
	for p in order:
		if grid[p] == "MiniBoss":
			anchors.append(p)
	for c in _pick_spread(combat, anchors, 2, 4.0):   # ≥4 cells apart — real travel to safety
		grid[c] = "PhaseDoor"

# Greedily choose up to k Combat cells maximising the min distance to the anchors
# (and to each other), so the picks end up spread across the floor.
func _pick_spread(candidates: Array, anchors: Array, k: int, min_sep: float = 0.0) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	for _i in range(k):
		var best := Vector2i.ZERO
		var best_d := -1.0
		for c in candidates:
			if grid.get(c) != "Combat" or c in chosen:
				continue
			var d := _min_dist(c, anchors + chosen)
			if d > best_d:
				best_d = d
				best = c
		if best_d < 0.0:
			break                       # nothing left
		if not chosen.is_empty() and best_d < min_sep:
			break                       # remaining picks are too close — keep them spread out
		chosen.append(best)
	return chosen

func _min_dist(c: Vector2i, pts: Array) -> float:
	var m := INF
	for p in pts:
		m = minf(m, Vector2(c - p).length())
	return m

func _instantiate_rooms() -> void:
	for cell in grid.keys():
		var room: Room = room_scene.instantiate()
		room.setup(grid[cell])
		add_child(room)
		room.global_position = Vector2(cell.x, cell.y) * Room.CELL
		rooms[cell] = room
	# Second pass once every room exists: open shared doors + populate.
	for cell in grid.keys():
		var room: Room = rooms[cell]
		for dir in Room.DIRS:
			var n: Vector2 = Room.DIRS[dir]
			if grid.has(cell + Vector2i(int(n.x), int(n.y))):
				room.open_exit(dir)
		_populate(cell, room)

func _populate(cell: Vector2i, room: Room) -> void:
	match grid[cell]:
		"Combat":
			for _i in range(randi_range(2, 4)):
				_spawn_enemy(room)
		"Boss":
			_spawn_boss(room, FLOOR_BOSS)
		"MiniBoss":
			_spawn_boss(room, NEIGHBORHOOD_BOSS)
		"PhaseDoor":
			if phase_door_scene:
				room.add_child(phase_door_scene.instantiate())   # at room centre

func _spawn_boss(room: Room, tier: Dictionary) -> void:
	if boss_scene == null:
		_spawn_enemy(room)
		return
	var b := boss_scene.instantiate()
	var hc := b.get_node_or_null("HealthComponent")
	if hc:
		hc.configured_hearts = tier["hearts"]
		hc.xp_reward = tier["xp"]   # bosses are the big XP payout — the grind-gate reward
	var ai := b.get_node_or_null("AIComponent")
	if ai:
		ai.damage_hearts = tier["damage"]
		ai.telegraph_duration = tier["telegraph"]
		ai.move_speed = tier["speed"]
		ai.start_active = false   # dormant until the arena locks
	b.scale = Vector2(tier["scale"], tier["scale"])
	b.modulate = tier["tint"]
	room.enemies_root.add_child(b)
	b.global_position = room.global_position
	room.arm_boss_lock(b)   # Floor 1: bosses are arena-locked (DCC lore)

func _spawn_enemy(room: Room) -> void:
	if enemy_scene == null:
		return
	var e := enemy_scene.instantiate()
	room.enemies_root.add_child(e)
	e.global_position = room.interior_point()

func _place_safe_room() -> void:
	if safe_room_scene == null:
		return
	var sr := safe_room_scene.instantiate()
	add_child(sr)
	sr.global_position = Vector2(0, -Room.CELL * (grid_size + 2))   # parked off the grid

func _spawn_player() -> void:
	if player_scene == null:
		return
	var p := player_scene.instantiate()
	add_child(p)
	p.global_position = rooms[order[0]].global_position   # Spawn room centre
