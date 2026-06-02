# LevelGenerator.gd
# Builds a floor by BSP partition: recursively split the world into varied-size leaves, inset a
# room in each, connect siblings with L-corridors, then build ALL walls by edge-sampling the
# walkable union (rooms + corridors) — doorways form automatically wherever a corridor meets a
# room, with no manual door bookkeeping. Then it places spawn / boss / phase-doors / enemies /
# cover, drops the off-grid Safe Room, and spawns the player.
extends Node2D

@export var room_scene: PackedScene
@export var enemy_scene: PackedScene             # default (melee) mob
@export var ranged_enemy_scene: PackedScene      # ranged mob in the spawn pool
@export var screamer_scene: PackedScene          # fast no-tell swarm
@export var cleric_scene: PackedScene            # support-elite (DR aura), floor 2+
@export var corpse_scene: PackedScene            # lootable drop spawned where a mob dies
@export var player_scene: PackedScene
@export var safe_room_scene: PackedScene
@export var phase_door_scene: PackedScene
@export var boss_scene: PackedScene
@export var neighborhood_bosses: int = 2         # DCC: a floor has several bosses, not one

# World + BSP tuning. Bigger world + one more split depth = larger floors with more rooms
# (→ more enemies); bigger ROOM_MARGIN = more space / longer corridors between rooms. Stairs (3)
# and phase-doors (2) stay capped in _designate/_place_stairs regardless of size.
const WORLD := Vector2(5200, 3800)
const MAX_DEPTH := 5
const MIN_CHILD := 640.0      # don't split if a child would be smaller than this on the split axis
const ROOM_MARGIN := 120.0    # inset from the leaf → the gap that corridors cross
const ROOM_MIN := Vector2(380, 360)
const DOOR := 150.0           # corridor / doorway width
const WALL := Room.WALL
const SIDES := Room.SIDES
const CORRIDOR_COLOR := Color(0.11, 0.11, 0.15)
const STAIRS_SCENE := preload("res://entities/Stairs.tscn")

# Boss tiers. Scale + tint read the tier at a glance (Floor Boss = giant deep-red brute).
# "hearts" = the boss's own HP (enemy pool, unscaled); "damage" = damage to the player in HP
# (×20 of the old per-heart value, matching the player's HP pool).
# damage is HP to the player: 64 ≈ one-shots a base CON-12 player (48 HP) — you must grind CON
# to survive a hit, or skip the boss via the timer. Bosses are a real gate, not a speed-bump.
const FLOOR_BOSS := {"hearts": 28.0, "damage": 64.0, "scale": 1.45, "tint": Color(1, 0.85, 0.85), "telegraph": 0.55, "speed": 340.0, "xp": 300, "stun_resist": 0.6, "ratings": 240}
const NEIGHBORHOOD_BOSS := {"hearts": 11.0, "damage": 34.0, "scale": 0.95, "tint": Color(1.0, 0.65, 0.3), "telegraph": 0.7, "speed": 290.0, "xp": 120, "stun_resist": 0.35, "ratings": 90}

var rooms: Array = []            # [{rect:Rect2, type:String, node:Room}]
var corridors: Array = []        # [{rect:Rect2, a:int, b:int}] — a,b = the room indices it links
var walkable: Array[Rect2] = []
var edges: Array = []            # MST room-pairs [i, j]
var degree: Array[int] = []      # connections per room (leaf = 1)
var boss_nav_map: RID            # separate, boss-sized nav map (bigger clearance around cover/walls)
var _boss_locks: Array = []      # [{zone:Rect2, room:Dictionary, boss:Node}] — un-sealed boss arenas, polled each frame

func _ready() -> void:
	# Floor.tscn is the main scene, so a fresh launch lands here without the Green Room —
	# start a run if none is active so current_run_stats is populated before the player spawns.
	if not GameManager.is_run_active:
		GameManager.start_new_run()
	GameManager.begin_floor()   # reset the stairs-open / collapse clock for this floor
	SignalBus.enemy_cancelled.connect(_spawn_corpse)   # mobs leave a lootable corpse where they die
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
	_place_stairs()
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

# Greedily pick k rooms from `pool` (room indices) that are spread out — each pick maximises the
# minimum distance to the anchor points (spawn/boss/already-placed specials). Keeps exits +
# safe-room entrances distributed across the floor for the sortie feel.
func _spread_pick(pool: Array, anchors: Array, k: int) -> Array:
	var chosen := []
	var pts := anchors.duplicate()
	for _i in range(mini(k, pool.size())):
		var best := -1
		var best_d := -1.0
		for idx in pool:
			if idx in chosen:
				continue
			var d := _min_dist(rooms[idx]["rect"].get_center(), pts)
			if d > best_d:
				best_d = d
				best = idx
		if best == -1:
			break
		chosen.append(best)
		pts.append(rooms[best]["rect"].get_center())
	return chosen

func _min_dist(c: Vector2, pts: Array) -> float:
	var m := INF
	for p in pts:
		m = minf(m, c.distance_to(p))
	return m

func _centers_of(types: Array) -> Array:
	var out := []
	for r in rooms:
		if r["type"] in types:
			out.append(r["rect"].get_center())
	return out

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
		rooms[combat.pop_front()]["type"] = "MiniBoss"   # mini-arenas at the leaf end
	# Phase-doors (safe-room entrances) spread across the remaining rooms, away from spawn + boss.
	var anchors := [rooms[spawn_i]["rect"].get_center(), rooms[boss_i]["rect"].get_center()]
	for idx in _spread_pick(combat, anchors, phasedoors):
		rooms[idx]["type"] = "PhaseDoor"

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

# Bake navigation meshes over the walkable union, with COVER carved out as obstructions so
# agents path AROUND cover instead of into it. Two meshes at different agent radii: a small one
# (default map) for mobs, and a boss-sized one (separate map) so the big boss keeps clearance and
# never wedges between cover and a wall.
func _build_navmesh() -> void:
	var src := NavigationMeshSourceGeometryData2D.new()
	for r in walkable:
		src.add_traversable_outline(_rect_outline(r))
	for r in rooms:
		for cr in r["node"].cover_world_rects():
			src.add_obstruction_outline(_rect_outline(cr))   # holes in the mesh where cover is
	# Mob mesh on the default map.
	_make_nav_region(src, 22.0, get_world_2d().navigation_map)
	# Boss mesh on its own map — 40px clearance: enough to keep the big boss off walls/cover
	# without making so many spots unreachable that a kiting player can hide. Beeline fallback
	# (AIComponent) covers anywhere the mesh still can't reach.
	boss_nav_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(boss_nav_map, true)
	NavigationServer2D.map_set_cell_size(boss_nav_map, NavigationServer2D.map_get_cell_size(get_world_2d().navigation_map))
	_make_nav_region(src, 40.0, boss_nav_map)

# Free the boss nav map when this floor is torn down (descent/death) so the RID doesn't leak.
func _exit_tree() -> void:
	if boss_nav_map.is_valid():
		NavigationServer2D.free_rid(boss_nav_map)

func _rect_outline(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

func _make_nav_region(src: NavigationMeshSourceGeometryData2D, agent_radius: float, map: RID) -> void:
	var np := NavigationPolygon.new()
	np.agent_radius = agent_radius
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	var region := NavigationRegion2D.new()
	region.navigation_polygon = np
	add_child(region)
	region.set_navigation_map(map)

# --- Populate --------------------------------------------------------------------------------

func _populate() -> void:
	for r in rooms:
		match r["type"]:
			"Combat":
				var extra := int((GameManager.current_floor - 1) / 2)   # a few more mobs deeper (elites add the bite)
				for _i in range(randi_range(2, 4) + extra):
					_spawn_enemy(r["node"])
			"Boss":
				_spawn_boss(r, FLOOR_BOSS, true)
				for _i in range(maxi(0, 4 - GameManager.current_floor)):   # adds, more on lower floors
					_spawn_enemy(r["node"], true)   # dormant — wake with the boss on lock
			"MiniBoss":
				_spawn_boss(r, NEIGHBORHOOD_BOSS, false)
				for _i in range(maxi(0, 2 - GameManager.current_floor)):
					_spawn_enemy(r["node"], true)
			"PhaseDoor":
				if phase_door_scene:
					var pd := phase_door_scene.instantiate()
					r["node"].add_child(pd)
					var a := _wall_anchor(r["rect"])   # safe-room door set into a wall
					pd.position = a["pos"]
					pd.rotation = a["rot"]
					_upright_label(pd, a["rot"])
					r["node"].clear_cover_at(pd.position, 140.0)

# Weighted archetype pick (replaces the flat melee/ranged coin-flip). Melee is the staple; ranged
# + screamer swarm mix in; the support-elite Cleric is rarer and gated to floor 2+. Missing scenes
# (null exports) just drop out of the pool, so it degrades gracefully.
func _pick_enemy_scene() -> PackedScene:
	var pool: Array = []   # [[scene, weight], …]
	if enemy_scene:
		pool.append([enemy_scene, 50])
	if ranged_enemy_scene:
		pool.append([ranged_enemy_scene, 20])
	if screamer_scene:
		pool.append([screamer_scene, 22])
	if cleric_scene and GameManager.current_floor >= 2:
		pool.append([cleric_scene, 8])
	if pool.is_empty():
		return enemy_scene
	var total := 0
	for entry in pool:
		total += int(entry[1])
	var roll := randi_range(1, total)
	for entry in pool:
		roll -= int(entry[1])
		if roll <= 0:
			return entry[0]
	return pool[0][0]

# Drop a lootable corpse where a mob died (fired by SignalBus.enemy_cancelled). Contents are the
# COMMON drip: gold scaled off the mob's ratings value, and an occasional basic potion. Tougher mobs
# (higher ratings) leave more gold; Loot Boxes remain the source of real gear.
func _spawn_corpse(loc: Vector2, ratings: int) -> void:
	if corpse_scene == null or not is_inside_tree():
		return
	var corpse := corpse_scene.instantiate()
	add_child(corpse)
	corpse.global_position = loc
	var g := maxi(1, int(ratings / 4.0)) + randi_range(0, 2)
	var potion := "health_potion" if randf() < 0.06 else ""
	corpse.setup(g, potion)

func _spawn_enemy(room: Room, dormant: bool = false) -> void:
	var scene := _pick_enemy_scene()
	if scene == null:
		return
	var e := scene.instantiate()
	var m := GameManager.floor_mult()   # deeper floors → tougher mobs
	var hc := e.get_node_or_null("HealthComponent")
	if hc:
		hc.configured_hearts *= m
		hc.xp_reward = int(hc.xp_reward * m)   # deeper (tougher) mobs are "higher level" → pay more XP
	var ai := e.get_node_or_null("AIComponent")
	if ai:
		ai.damage_hearts *= m
		if dormant:
			ai.start_active = false       # boss-room adds stay put until the arena locks…
			if hc:
				hc.set_invulnerable(true)   # …and can't be sniped down before you commit
	# Elite upgrade (floor 3+, scaling chance): a bigger, tankier, stun-resistant version of ANY
	# mob — the "harder enemy that forces you to adapt" rather than just inflated global stats.
	if not dormant and randf() < _elite_chance():
		_make_elite(e, hc, ai)
	room.enemies_root.add_child(e)
	e.global_position = room.interior_point()

const ELITE_MIN_FLOOR := 3
const ELITE_BASE_CHANCE := 0.10   # at the first elite floor
const ELITE_PER_FLOOR := 0.04     # +4% per floor deeper (GDD: ~+5%/floor)
const ELITE_MAX_CHANCE := 0.40

func _elite_chance() -> float:
	var f := GameManager.current_floor
	if f < ELITE_MIN_FLOOR:
		return 0.0
	return clampf(ELITE_BASE_CHANCE + ELITE_PER_FLOOR * (f - ELITE_MIN_FLOOR), 0.0, ELITE_MAX_CHANCE)

# Turn a freshly-rolled mob into an Elite: bigger + much tankier + hits harder + resists stun (so
# you can't just Ground-Slam-lock it) + a gold glow, and it pays out more XP/gold for the trouble.
# Applied BEFORE add_child so the HP/scale changes are live when the components initialise.
func _make_elite(e: Node, hc: Node, ai: Node) -> void:
	(e as Node2D).scale *= 1.4
	(e as Node2D).modulate = Color(1.4, 1.1, 0.5)   # bright gold tint reads as "buffed" on any base colour
	if hc:
		hc.configured_hearts *= 2.5
		hc.xp_reward *= 2
		hc.ratings_reward *= 2          # → more corpse gold too (gold scales off ratings)
	if ai:
		ai.damage_hearts *= 1.35
		ai.stun_resist = maxf(ai.stun_resist, 0.3)

func _spawn_boss(r: Dictionary, tier: Dictionary, is_floor_boss: bool) -> void:
	var room: Room = r["node"]
	if boss_scene == null:
		_spawn_enemy(room)
		return
	var m := GameManager.floor_mult()   # deeper floors → tougher bosses
	var b := boss_scene.instantiate()
	var hc := b.get_node_or_null("HealthComponent")
	if hc:
		hc.configured_hearts = tier["hearts"] * m
		hc.xp_reward = int(tier["xp"] * m)   # deeper bosses pay more XP (scales with their toughness)
		hc.ratings_reward = tier.get("ratings", hc.ratings_reward)   # boss = ratings + corpse-gold jackpot
		hc.set_invulnerable(true)   # can't be sniped while dormant — must enter to fight it
	var ai := b.get_node_or_null("AIComponent")
	if ai:
		ai.damage_hearts = tier["damage"] * m
		ai.telegraph_duration = tier["telegraph"]
		ai.move_speed = tier["speed"]
		ai.stun_resist = tier.get("stun_resist", 0.0)   # bosses shrug off / shorten Ground Slam etc.
		ai.chase_navmesh_only = true   # path AROUND cover (outmaneuverable, no wedging) — never beeline
		ai.start_active = false   # dormant until the arena locks
	b.scale = Vector2(tier["scale"], tier["scale"])
	b.modulate = tier["tint"]
	room.enemies_root.add_child(b)
	if ai and ai.has_method("set_nav_map") and boss_nav_map.is_valid():
		ai.set_nav_map(boss_nav_map)   # path with boss-sized clearance (no wedging on cover/walls)
	b.global_position = room.global_position
	_arm_boss_lock(r, b)
	# Killing the Floor Boss opens the (scattered) stairs EARLY — that plus its loot is the
	# reward for fighting it. Skip it and the stairs open on the timer anyway.
	if is_floor_boss and hc:
		hc.health_depleted.connect(GameManager.open_stairs)

# Floor-1 bosses are arena-locked (DCC): the room seals the instant the player steps past a
# doorway, until the boss falls. The lock zone is inset so the seal lands just behind the player,
# but only by a fraction of the room so a small arena can't shrink it to a patch the player skirts.
# Polled each physics frame (not an Area2D.body_entered) — a fast dash or odd entry angle used to
# slip the one-shot signal and leave the arena un-sealed.
func _arm_boss_lock(r: Dictionary, boss: Node) -> void:
	var rect: Rect2 = r["rect"]
	var inset := Vector2(minf(80.0, rect.size.x * 0.35), minf(80.0, rect.size.y * 0.35))
	var zone := Rect2(rect.position + inset, rect.size - inset * 2.0)
	_boss_locks.append({"zone": zone, "room": r, "boss": boss})

# Watch every un-sealed boss arena; lock the instant the player is inside its zone. Deterministic
# (position test) so it can never miss the way the old enter-signal could.
func _physics_process(_delta: float) -> void:
	if _boss_locks.is_empty():
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var pos := player.global_position
	for i in range(_boss_locks.size() - 1, -1, -1):
		var lock: Dictionary = _boss_locks[i]
		if (lock["zone"] as Rect2).has_point(pos):
			_boss_locks.remove_at(i)
			_lock_boss_arena(lock["room"], lock["boss"])

func _lock_boss_arena(r: Dictionary, boss: Node) -> void:
	if r.get("locked", false):
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
	# The fight's on — wake AND make vulnerable the boss + every dormant add in the arena.
	for e in r["node"].enemies_root.get_children():
		var eai: Node = e.get_node_or_null("AIComponent")
		if eai and eai.has_method("activate"):
			eai.activate()
		var ehc: Node = e.get_node_or_null("HealthComponent")
		if ehc and ehc.has_method("set_invulnerable"):
			ehc.set_invulnerable(false)
	var hc := boss.get_node_or_null("HealthComponent")
	if hc:
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

# Scatter several stairs across non-boss / non-spawn rooms so the floor has multiple exits
# reachable WITHOUT the boss (the boss only opens them early). Visible-but-locked until open.
# Placed on the room's central vertical axis (x=0 → clear of corner cover) and offset down so it
# misses any center occupant (a phase-door / mini-boss).
func _place_stairs() -> void:
	# Only plain Combat rooms (no boss/mini-boss lock, no phase-door clash) hold stairs, and they
	# spread away from spawn, boss, phase-doors AND mini-bosses so the exits feel distributed.
	var candidates := []
	for i in range(rooms.size()):
		if rooms[i]["type"] == "Combat":
			candidates.append(i)
	var anchors := _centers_of(["Spawn", "Boss", "PhaseDoor", "MiniBoss"])
	var picked := _spread_pick(candidates, anchors, 3)
	for idx in picked:
		_place_stair_door(rooms[idx])
	# Guarantee at least one exit: a pathological tiny floor (no plain Combat rooms) gets a stair
	# in the boss room rather than being unexitable.
	if picked.is_empty():
		for r in rooms:
			if r["type"] == "Boss":
				_place_stair_door(r)
				break

func _place_stair_door(r: Dictionary) -> void:
	var s := STAIRS_SCENE.instantiate()
	r["node"].add_child(s)
	var a := _wall_anchor(r["rect"])   # stairs door set into a wall, not a pad in the middle
	s.position = a["pos"]
	s.rotation = a["rot"]
	_upright_label(s, a["rot"])
	r["node"].clear_cover_at(s.position, 140.0)

# Keep a door's text label horizontal even when the door is rotated onto an E/W wall.
func _upright_label(door: Node, rot: float) -> void:
	var lbl := door.get_node_or_null("Label")
	if lbl:
		lbl.rotation = -rot

# Pick a spot for a wall-mounted door: the MIDDLE OF A SOLID WALL SEGMENT wide enough for the door,
# so it sits beside corridor mouths, never floating in a passage. (Corridors attach at the wall
# centre, so the old "centre of the wall" anchor landed right in the opening on multi-exit rooms.)
const DOOR_FIT := 140.0   # min solid-wall width a 124px door needs (with a little margin)

func _wall_anchor(rect: Rect2) -> Dictionary:
	var hx := rect.size.x * 0.5
	var hy := rect.size.y * 0.5
	var c := rect.get_center()
	var depth := 8.0   # straddle the wall line (~16px embedded, ~32px into the room)
	var opts := []     # [side, along-offset-local] for every solid span the door fits in
	for side in SIDES:
		for sp in _edge_spans(rect, side, false):   # false = SOLID spans (not corridor mouths)
			if sp[1] - sp[0] < DOOR_FIT:
				continue
			var mid: float = (sp[0] + sp[1]) * 0.5
			var along: float = (mid - c.x) if (side == "North" or side == "South") else (mid - c.y)
			opts.append([side, along])
	if opts.is_empty():
		# Pathological tiny room: no wall segment fits — fall back to a wall centre.
		return {"pos": Vector2(0, -hy + depth), "rot": 0.0}
	var pick: Array = opts.pick_random()
	var side: String = pick[0]
	var along: float = pick[1]
	match side:
		"North": return {"pos": Vector2(along, -hy + depth), "rot": 0.0}
		"South": return {"pos": Vector2(along, hy - depth), "rot": 0.0}
		"East": return {"pos": Vector2(hx - depth, along), "rot": PI * 0.5}
		_: return {"pos": Vector2(-hx + depth, along), "rot": PI * 0.5}   # West

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
