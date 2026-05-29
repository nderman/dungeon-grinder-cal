# LevelGenerator.gd
# Builds a floor by BSP partition: recursively split the world into varied-size leaves, inset a
# room in each, connect siblings with L-corridors, then build ALL walls by edge-sampling the
# walkable union (rooms + corridors) — doorways form automatically wherever a corridor meets a
# room, with no manual door bookkeeping. Then it places spawn / boss / phase-doors / enemies /
# cover, drops the off-grid Safe Room, and spawns the player.
extends Node2D

@export var room_scene: PackedScene
@export var enemy_scene: PackedScene             # default (melee) mob
@export var ranged_enemy_scene: PackedScene      # mixed in at ranged_enemy_chance
@export var ranged_enemy_chance: float = 0.3
@export var player_scene: PackedScene
@export var safe_room_scene: PackedScene
@export var phase_door_scene: PackedScene
@export var boss_scene: PackedScene
@export var neighborhood_bosses: int = 2         # DCC: a floor has several bosses, not one

# World + BSP tuning.
const WORLD := Vector2(3800, 2800)
const MAX_DEPTH := 4
const MIN_CHILD := 620.0      # don't split if a child would be smaller than this on the split axis
const ROOM_MARGIN := 80.0     # inset from the leaf → the gap that corridors cross
const ROOM_MIN := Vector2(380, 360)
const DOOR := 150.0           # corridor / doorway width
const WALL := Room.WALL
const SIDES := Room.SIDES
const CORRIDOR_COLOR := Color(0.11, 0.11, 0.15)

# Boss tiers. Scale + tint read the tier at a glance (Floor Boss = giant deep-red brute).
const FLOOR_BOSS := {"hearts": 20.0, "damage": 2.0, "scale": 1.7, "tint": Color(1, 0.85, 0.85), "telegraph": 0.55, "speed": 340.0, "xp": 300}
const NEIGHBORHOOD_BOSS := {"hearts": 8.0, "damage": 1.0, "scale": 0.95, "tint": Color(1.0, 0.65, 0.3), "telegraph": 0.7, "speed": 290.0, "xp": 120}

var rooms: Array = []            # [{rect:Rect2, type:String, node:Room}]
var corridors: Array = []        # [{rect:Rect2, a:int, b:int}] — a,b = the room indices it links
var walkable: Array[Rect2] = []
var edges: Array = []            # MST room-pairs [i, j]
var degree: Array[int] = []      # connections per room (leaf = 1)

func _ready() -> void:
	# Floor.tscn is the main scene, so a fresh launch lands here without the Green Room —
	# start a run if none is active so current_run_stats is populated before the player spawns.
	if not GameManager.is_run_active:
		GameManager.start_new_run()
	var tree := _split(Rect2(Vector2.ZERO, WORLD), 0)
	_collect_rooms(tree)
	_connect_mst()
	_designate()
	walkable = []
	for c in corridors:
		walkable.append(c["rect"])
	for r in rooms:
		walkable.append(r["rect"])
	_build_corridor_floors()
	_instantiate_rooms()
	_build_walls()
	_build_navmesh()
	_populate()
	_place_safe_room()
	_spawn_player()

# --- BSP -------------------------------------------------------------------------------------

# Returns a tree node {rect, left, right, room}. Leaves carry a room rect; internal nodes
# bubble up one child's room so corridor carving always has a representative to connect.
func _split(rect: Rect2, depth: int) -> Dictionary:
	var node := {"rect": rect, "left": null, "right": null, "room": Rect2()}
	var split_h := rect.size.y >= rect.size.x          # split the longer axis
	if absf(rect.size.x - rect.size.y) < 0.2 * maxf(rect.size.x, rect.size.y):
		split_h = randf() < 0.5
	var extent := rect.size.y if split_h else rect.size.x
	var can_split := depth < MAX_DEPTH and extent >= MIN_CHILD * 2.0
	if can_split and (depth < 2 or randf() < 0.8):
		var t := randf_range(0.42, 0.58)
		var cut := extent * t
		if cut >= MIN_CHILD and extent - cut >= MIN_CHILD:
			var lrect: Rect2
			var rrect: Rect2
			if split_h:
				lrect = Rect2(rect.position, Vector2(rect.size.x, cut))
				rrect = Rect2(rect.position + Vector2(0, cut), Vector2(rect.size.x, rect.size.y - cut))
			else:
				lrect = Rect2(rect.position, Vector2(cut, rect.size.y))
				rrect = Rect2(rect.position + Vector2(cut, 0), Vector2(rect.size.x - cut, rect.size.y))
			node["left"] = _split(lrect, depth + 1)
			node["right"] = _split(rrect, depth + 1)
			node["room"] = node["left"]["room"] if randf() < 0.5 else node["right"]["room"]
			return node
	# Leaf: inset a varied-size room within the leaf, leaving ROOM_MARGIN all round.
	node["room"] = _inset_room(rect)
	return node

func _inset_room(leaf: Rect2) -> Rect2:
	var avail := leaf.size - Vector2(ROOM_MARGIN, ROOM_MARGIN) * 2.0
	var w := randf_range(ROOM_MIN.x, maxf(ROOM_MIN.x, avail.x))
	var h := randf_range(ROOM_MIN.y, maxf(ROOM_MIN.y, avail.y))
	var slack := leaf.size - Vector2(w, h)
	var pos := leaf.position + Vector2(randf_range(ROOM_MARGIN, maxf(ROOM_MARGIN, slack.x - ROOM_MARGIN)),
		randf_range(ROOM_MARGIN, maxf(ROOM_MARGIN, slack.y - ROOM_MARGIN)))
	return Rect2(pos, Vector2(w, h))

func _collect_rooms(node: Dictionary) -> void:
	if node["left"] == null and node["right"] == null:
		rooms.append({"rect": node["room"], "type": "Combat", "node": null})
		return
	if node["left"] != null:
		_collect_rooms(node["left"])
	if node["right"] != null:
		_collect_rooms(node["right"])

# Connect rooms with a Minimum Spanning Tree over their centers (Prim's). An MST gives
# corridor trunks with rooms branching off — and its leaves (degree 1) are dead-end rooms,
# which is what lets the boss sit off the critical path. Fully connected by construction.
func _connect_mst() -> void:
	var n := rooms.size()
	degree.resize(n)
	degree.fill(0)
	if n <= 1:
		return
	var in_tree := []
	in_tree.resize(n)
	in_tree.fill(false)
	in_tree[0] = true
	var added := 1
	while added < n:
		var bi := -1
		var bj := -1
		var bd := INF
		for i in range(n):
			if not in_tree[i]:
				continue
			for j in range(n):
				if in_tree[j]:
					continue
				var d: float = rooms[i]["rect"].get_center().distance_squared_to(rooms[j]["rect"].get_center())
				if d < bd:
					bd = d
					bi = i
					bj = j
		if bj == -1:
			break
		in_tree[bj] = true
		added += 1
		_carve(bi, bj)
		edges.append([bi, bj])
		degree[bi] += 1
		degree[bj] += 1

# Does a corridor that links two OTHER rooms pass through room i? (Such a stray corridor would
# punch an extra doorway and make the room walk-through-able — bad for the boss room.)
func _has_stray_corridor(i: int) -> bool:
	var rect: Rect2 = rooms[i]["rect"]
	for c in corridors:
		if c["a"] != i and c["b"] != i and rect.intersects(c["rect"]):
			return true
	return false

func _adjacency() -> Array:
	var adj := []
	adj.resize(rooms.size())
	for i in range(rooms.size()):
		adj[i] = []
	for e in edges:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	return adj

# BFS hop-distance from a room over the corridor graph.
func _distances(src: int) -> Array:
	var adj := _adjacency()
	var dist := []
	dist.resize(rooms.size())
	dist.fill(-1)
	dist[src] = 0
	var queue := [src]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in adj[cur]:
			if dist[nb] == -1:
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return dist

# An L-corridor (horizontal then vertical) between rooms ai and bj. Each leg overlaps its
# room interior harmlessly; walls form only on the outside-room portions via edge-sampling.
# Tagged with the linked room indices so we can detect corridors that stray through OTHER rooms.
func _carve(ai: int, bj: int) -> void:
	var ca: Vector2 = rooms[ai]["rect"].get_center()
	var cb: Vector2 = rooms[bj]["rect"].get_center()
	var hx0 := minf(ca.x, cb.x)
	var hx1 := maxf(ca.x, cb.x)
	corridors.append({"rect": Rect2(hx0, ca.y - DOOR * 0.5, hx1 - hx0, DOOR), "a": ai, "b": bj})
	var vy0 := minf(ca.y, cb.y)
	var vy1 := maxf(ca.y, cb.y)
	corridors.append({"rect": Rect2(cb.x - DOOR * 0.5, vy0, DOOR, vy1 - vy0), "a": ai, "b": bj})

# --- Room typing -----------------------------------------------------------------------------

func _designate() -> void:
	if rooms.is_empty():
		return
	var leaves := []      # dead-end rooms (degree 1)
	for i in range(rooms.size()):
		if degree[i] <= 1:
			leaves.append(i)
	# Spawn = a dead-end leaf nearest the top-left (you start at an end, not a hub).
	var spawn_i := 0
	var best_c := INF
	for i in (leaves if not leaves.is_empty() else range(rooms.size())):
		var c: Vector2 = rooms[i]["rect"].get_center()
		if c.x + c.y < best_c:
			best_c = c.x + c.y
			spawn_i = i
	rooms[spawn_i]["type"] = "Spawn"
	# Boss = the FARTHEST clean leaf from spawn. "Clean" = no corridor for OTHER rooms strays
	# through it (an MST leaf can still be physically crossed by an L-corridor between two other
	# rooms, which would make it walk-through-able and on a path). A clean leaf has exactly its
	# own single entrance → you only enter it deliberately.
	var dist := _distances(spawn_i)
	var clean := []
	for i in leaves:
		if i != spawn_i and not _has_stray_corridor(i):
			clean.append(i)
	var pool := clean if not clean.is_empty() else leaves
	var boss_i := spawn_i
	var best_d := -1
	for i in pool:
		if i != spawn_i and dist[i] > best_d:
			best_d = dist[i]
			boss_i = i
	# Fallback: if no distinct leaf was found, take the euclidean-farthest room so a floor with
	# ≥2 rooms always has a boss (never a no-boss / unbeatable floor).
	if boss_i == spawn_i and rooms.size() >= 2:
		var sc: Vector2 = rooms[spawn_i]["rect"].get_center()
		var bd := -1.0
		for i in range(rooms.size()):
			if i == spawn_i:
				continue
			var d := sc.distance_to(rooms[i]["rect"].get_center())
			if d > bd:
				bd = d
				boss_i = i
	if boss_i != spawn_i:
		rooms[boss_i]["type"] = "Boss"
	# MiniBosses prefer OTHER leaves (optional dead-end detours); phase-doors go on the main
	# path (interior, higher-degree rooms) so the Safe Room is always reachable without a boss.
	var combat := []
	for i in range(rooms.size()):
		if rooms[i]["type"] == "Combat":
			combat.append(i)
	combat.sort_custom(func(a, b): return degree[a] < degree[b])   # leaves first
	# Scale special rooms to floor size so small floors keep regular mob rooms to grind.
	var others_n := combat.size()
	var phasedoors := mini(2 if others_n >= 5 else 1, others_n)
	var minibosses := mini(neighborhood_bosses, maxi(0, others_n - phasedoors - 1))   # leave ≥1 Combat
	for _n in range(minibosses):
		rooms[combat.pop_front()]["type"] = "MiniBoss"   # from the leaf end
	for _p in range(phasedoors):
		rooms[combat.pop_back()]["type"] = "PhaseDoor"   # from the interior end

# --- Geometry build --------------------------------------------------------------------------

func _build_corridor_floors() -> void:
	for c in corridors:
		var rc: Rect2 = c["rect"]
		add_child(Room.make_floor(PackedVector2Array([rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]), CORRIDOR_COLOR))

func _instantiate_rooms() -> void:
	for r in rooms:
		var room: Room = room_scene.instantiate()
		room.setup(r["type"], r["rect"].size)
		add_child(room)
		room.global_position = r["rect"].get_center()
		r["node"] = room

# Walls = edge-sample every walkable rect; a span is solid where the point just outside isn't
# walkable, an opening where it is (a corridor mouth / junction). Coalesced into segments.
func _build_walls() -> void:
	for r in walkable:
		for side in SIDES:
			for span in _edge_spans(r, side, false):   # false = solid spans
				_add_wall(r, side, span, WALL, Color(0.40, 0.40, 0.52), WALL * 0.5)

func _edge_spans(rect: Rect2, side: String, want_open: bool) -> Array:
	var n: Vector2 = SIDES[side]
	var horizontal := absf(n.y) > 0.5
	var fixed := (rect.position.y if n.y < 0 else rect.end.y) if horizontal else (rect.position.x if n.x < 0 else rect.end.x)
	var t0 := rect.position.x if horizontal else rect.position.y
	var t1 := rect.end.x if horizontal else rect.end.y
	var spans := []
	var step := 8.0
	var run_start := INF
	var t := t0
	while t <= t1:
		var p := Vector2(t, fixed + n.y * 5.0) if horizontal else Vector2(fixed + n.x * 5.0, t)
		var matches := _is_walkable(p) == want_open
		if matches and run_start == INF:
			run_start = t
		elif not matches and run_start != INF:
			spans.append([run_start, t])
			run_start = INF
		t += step
	if run_start != INF:
		spans.append([run_start, t1])
	return spans

# Place a wall/barrier segment for [a,b] along `side`. `push` shifts it outward from the edge.
func _add_wall(rect: Rect2, side: String, span: Array, thick: float, color: Color, push: float) -> StaticBody2D:
	var n: Vector2 = SIDES[side]
	var horizontal := absf(n.y) > 0.5
	var fixed := (rect.position.y if n.y < 0 else rect.end.y) if horizontal else (rect.position.x if n.x < 0 else rect.end.x)
	var a: float = span[0]
	var b: float = span[1]
	if b - a < 4.0:
		return null
	var mid := (a + b) * 0.5
	var pos := Vector2(mid, fixed + n.y * push) if horizontal else Vector2(fixed + n.x * push, mid)
	var seg := Vector2(b - a, thick) if horizontal else Vector2(thick, b - a)
	var body := Room.make_rect_body(pos, seg, color)
	add_child(body)
	return body

func _is_walkable(p: Vector2) -> bool:
	for r in walkable:
		if r.grow(1.0).has_point(p):   # grow 1px so flush shared edges read as walkable (Rect2.has_point excludes far edge)
			return true
	return false

# Bake a navigation mesh over the walkable union so mobs path through doorways instead of
# beelining into walls. Each walkable rect is a traversable outline; baking unions them and
# insets by the agent radius (kept under DOOR width so corridor mouths stay passable).
func _build_navmesh() -> void:
	var src := NavigationMeshSourceGeometryData2D.new()
	for r in walkable:
		src.add_traversable_outline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	var np := NavigationPolygon.new()
	np.agent_radius = 22.0
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	var region := NavigationRegion2D.new()
	region.navigation_polygon = np
	add_child(region)

# --- Populate --------------------------------------------------------------------------------

func _populate() -> void:
	for r in rooms:
		match r["type"]:
			"Combat":
				for _i in range(randi_range(2, 4)):
					_spawn_enemy(r["node"])
			"Boss":
				_spawn_boss(r, FLOOR_BOSS)
			"MiniBoss":
				_spawn_boss(r, NEIGHBORHOOD_BOSS)
			"PhaseDoor":
				if phase_door_scene:
					var pd := phase_door_scene.instantiate()
					r["node"].add_child(pd)

func _spawn_enemy(room: Room) -> void:
	var scene := enemy_scene
	if ranged_enemy_scene != null and randf() < ranged_enemy_chance:
		scene = ranged_enemy_scene
	if scene == null:
		return
	var e := scene.instantiate()
	room.enemies_root.add_child(e)
	e.global_position = room.interior_point()

func _spawn_boss(r: Dictionary, tier: Dictionary) -> void:
	var room: Room = r["node"]
	if boss_scene == null:
		_spawn_enemy(room)
		return
	var b := boss_scene.instantiate()
	var hc := b.get_node_or_null("HealthComponent")
	if hc:
		hc.configured_hearts = tier["hearts"]
		hc.xp_reward = tier["xp"]
		hc.set_invulnerable(true)   # can't be sniped while dormant — must enter to fight it
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
	_arm_boss_lock(r, b)

# Floor-1 bosses are arena-locked (DCC): the room seals the instant the player steps past a
# doorway, until the boss falls. The trigger is inset so the seal lands just behind the player.
func _arm_boss_lock(r: Dictionary, boss: Node) -> void:
	var rect: Rect2 = r["rect"]
	var trigger := Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = (rect.size - Vector2(168, 168)).max(Vector2(80, 80))
	cs.shape = shape
	trigger.add_child(cs)
	add_child(trigger)
	trigger.global_position = rect.get_center()
	trigger.body_entered.connect(_on_boss_trigger.bind(r, boss))

func _on_boss_trigger(body: Node, r: Dictionary, boss: Node) -> void:
	if r.get("locked", false) or not body.is_in_group("player"):
		return
	r["locked"] = true
	if not is_instance_valid(boss):
		return
	# Seal the doorways: barrier every gap in THIS boss room's perimeter walls. Barriers are
	# stored per-room so killing one boss never unseals another's arena.
	var rect: Rect2 = r["rect"]
	var barriers: Array = []
	for side in SIDES:
		for span in _edge_spans(rect, side, true):   # true = open spans (corridor mouths)
			var bar := _add_wall(rect, side, span, WALL * 2.5, Color(0.9, 0.2, 0.3, 0.85), 0.0)
			if bar:
				barriers.append(bar)
	r["barriers"] = barriers
	var ai := boss.get_node_or_null("AIComponent")
	if ai and ai.has_method("activate"):
		ai.activate()
	var hc := boss.get_node_or_null("HealthComponent")
	if hc:
		hc.set_invulnerable(false)   # the fight's on — boss can now be hurt
		hc.health_depleted.connect(_unlock_boss.bind(r))
	boss.tree_exited.connect(_unlock_boss.bind(r))

func _unlock_boss(r: Dictionary) -> void:
	if r.get("unlocked", false):
		return   # guard: health_depleted + tree_exited both fire on a boss death
	r["unlocked"] = true
	for b in r.get("barriers", []):
		if is_instance_valid(b):
			b.queue_free()
	r["barriers"] = []

func _place_safe_room() -> void:
	if safe_room_scene == null:
		return
	var sr := safe_room_scene.instantiate()
	add_child(sr)
	sr.global_position = Vector2(WORLD.x * 0.5, -1400.0)   # parked off the layout

func _spawn_player() -> void:
	if player_scene == null or rooms.is_empty():
		return
	var p := player_scene.instantiate()
	add_child(p)
	# Spawn in the room actually typed "Spawn" — NOT rooms[0], which is just the first-collected
	# room and could be the Boss room (or a populated Combat room).
	var spawn_rect: Rect2 = rooms[0]["rect"]
	for r in rooms:
		if r["type"] == "Spawn":
			spawn_rect = r["rect"]
			break
	p.global_position = spawn_rect.get_center()
