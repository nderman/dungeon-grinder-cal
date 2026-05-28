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
@export var room_count: int = 8
@export var grid_size: int = 12

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
	grid[order.back()] = "Boss"   # furthest-walked room
	var combat := order.filter(func(p): return grid[p] == "Combat")
	combat.shuffle()
	for i in range(mini(2, combat.size())):
		grid[combat[i]] = "PhaseDoor"

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
			for _i in range(randi_range(1, 2)):
				_spawn_enemy(room)
		"Boss":
			_spawn_enemy(room)   # placeholder until the Meat-Grinder Golem exists
		"PhaseDoor":
			if phase_door_scene:
				room.add_child(phase_door_scene.instantiate())   # at room centre

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
