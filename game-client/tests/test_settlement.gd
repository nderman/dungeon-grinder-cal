extends TestCase
# The town Settlement prefab + its NPCs + the ShopPanel all load and are wired right. Guards the
# scene composition (paths, the safe_room_entry group the Phase-Door needs, the shop-role vendor) and
# that the new UI/entity scripts construct without error.
func _init() -> void: test_name = "settlement"

func run() -> void:
	var ps: PackedScene = load("res://levels/prefabs/Settlement.tscn")
	check(ps != null, "Settlement.tscn loads")
	var s := ps.instantiate()
	check(s != null, "Settlement instantiates")

	# The Phase-Door warps to the first node in "safe_room_entry" — the Settlement MUST provide one.
	var entry := s.get_node_or_null("Entry")
	check(entry != null and entry.is_in_group("safe_room_entry"), "has an Entry in the safe_room_entry group")
	check(s.get_node_or_null("ExitPortal") != null, "has an exit portal back to the floor")

	# A shop-role vendor + at least the loot/stat terminals carried over from the Safe Room.
	var keeper := s.get_node_or_null("Shopkeeper")
	check(keeper is NonCombatantNPC, "has a Shopkeeper NonCombatantNPC")
	check(keeper != null and keeper.role == "shop", "the Shopkeeper opens the vendor (role 'shop')")
	check(s.get_node_or_null("LootBoxTerminal") != null, "keeps the loot-box terminal")
	check(s.get_node_or_null("LevelTerminal") != null, "keeps the stat terminal")
	s.free()

	# The NPC + ShopPanel scripts construct (run _ready) without error.
	var npc := (load("res://entities/NonCombatantNPC.tscn") as PackedScene).instantiate()
	add_child(npc)   # runs _ready: InteractablePad wiring + role-based visuals
	check(npc != null, "NonCombatantNPC builds + _ready runs clean")
	npc.queue_free()

	var sp := ShopPanel.new()
	add_child(sp)    # runs _ready: builds the frame + connects shop/gold signals
	check(sp != null, "ShopPanel builds")
	sp.queue_free()
