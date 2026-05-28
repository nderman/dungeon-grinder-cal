# LevelGenerator.gd
# "Open Floor" sortie maps via a Random Walk over a 2D grid. Stitches prefab
# PackedScene rooms, designates the Boss + Phase-Door rooms, and opens shared
# doors between adjacent rooms. Each room prefab implements open_exit(dir: String).
extends Node2D

@export_group("Floor Settings")
@export var room_count: int = 15
@export var grid_size: int = 12
@export var room_offset: int = 1000   # px between room centers

@export_group("Room Prefabs")
@export var spawn_room: PackedScene
@export var combat_rooms: Array[PackedScene] = []
@export var phase_door_room: PackedScene
@export var boss_room: PackedScene

var grid: Dictionary = {}            # Vector2i -> room type string
var room_order: Array[Vector2i] = []  # placement order (last = furthest = boss)

func _ready() -> void:
	generate_floor()

func generate_floor() -> void:
	grid.clear()
	room_order.clear()
	var walker := Vector2i(grid_size / 2, grid_size / 2)
	_add_room(walker, "Spawn")

	var placed := 1
	while placed < room_count:
		var dir: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].pick_random()
		var next := walker + dir
		if next.x < 0 or next.x >= grid_size or next.y < 0 or next.y >= grid_size:
			continue
		walker = next
		if not grid.has(walker):
			_add_room(walker, "Combat")
			placed += 1

	_designate_special_rooms()
	_instantiate_rooms()

func _add_room(pos: Vector2i, type: String) -> void:
	grid[pos] = type
	room_order.append(pos)

func _designate_special_rooms() -> void:
	# Boss sits at the furthest-walked room.
	grid[room_order.back()] = "Boss"
	# Scatter 2 Phase-Doors (shared Safe Room access) among combat rooms.
	var combat := room_order.filter(func(p): return grid[p] == "Combat")
	combat.shuffle()
	for i in range(mini(2, combat.size())):
		grid[combat[i]] = "PhaseDoor"

func _instantiate_rooms() -> void:
	for pos in grid.keys():
		var scene: PackedScene = _scene_for(grid[pos])
		if scene == null:
			continue
		var room := scene.instantiate() as Node2D
		add_child(room)
		room.global_position = Vector2(pos.x * room_offset, pos.y * room_offset)
		_connect_room_exits(room, pos)

func _scene_for(type: String) -> PackedScene:
	match type:
		"Spawn": return spawn_room
		"PhaseDoor": return phase_door_room
		"Boss": return boss_room
		_: return combat_rooms.pick_random() if not combat_rooms.is_empty() else null

func _connect_room_exits(room: Node, pos: Vector2i) -> void:
	if not room.has_method("open_exit"):
		return
	if grid.has(pos + Vector2i.UP): room.open_exit("North")
	if grid.has(pos + Vector2i.DOWN): room.open_exit("South")
	if grid.has(pos + Vector2i.RIGHT): room.open_exit("East")
	if grid.has(pos + Vector2i.LEFT): room.open_exit("West")
