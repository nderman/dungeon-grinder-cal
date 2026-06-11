extends TestCase
# A boss arena only SEALS for a true dead-end (degree-1 leaf, no stray corridor). A crossed leaf or a
# hub room must NOT seal (else you'd be trapped / forced to fight to explore).
func _init() -> void: test_name = "boss_seal"

const GEN := preload("res://levels/LevelGenerator.gd")

func _sealable(degree: Array[int], corridors: Array) -> bool:
	var g = GEN.new()
	g.rooms = [{"rect": Rect2(0, 0, 200, 200)}]
	g.degree = degree
	g.corridors = corridors
	g._arm_boss_lock(g.rooms[0], Node.new())
	return g._boss_locks[0]["sealable"]

func run() -> void:
	var leaf: Array[int] = [1]
	var hub: Array[int] = [2]
	check(_sealable(leaf, []), "a clean dead-end leaf seals")
	check(not _sealable(leaf, [{"a": 5, "b": 6, "rect": Rect2(50, 50, 100, 20)}]), "a leaf a corridor crosses does NOT seal")
	check(not _sealable(hub, []), "a hub room (cut vertex) does NOT seal")
