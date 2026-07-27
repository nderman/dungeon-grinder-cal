extends TestCase
# Item-granted abilities (the "Tripper" mechanic): a Rare+ gear affix {grant: id} puts an active
# ability on the hotbar WHILE EQUIPPED and pulls it OFF on unequip — without touching known_abilities,
# and a learned-AND-granted ability survives the item coming off. Snapshots/restores GameManager state.
func _init() -> void: test_name = "granted_abilities"

func run() -> void:
	var saved_eq := GameManager.equipped.duplicate(true)
	var saved_bag := GameManager.bag.duplicate(true)
	var saved_hb := GameManager.hotbar.duplicate(true)
	var saved_granted := GameManager.granted_abilities.duplicate()
	var saved_known := GameManager.known_abilities.duplicate()
	var saved_sel := GameManager.selected_ability
	var saved_sec := GameManager.secondary_ability

	GameManager.equipped = {}
	GameManager.bag = []
	GameManager.hotbar = [null, null, null, null]
	GameManager.granted_abilities = []
	GameManager.known_abilities = []
	GameManager.selected_ability = ""
	GameManager.secondary_ability = ""

	# The desc surfaces the granted ability.
	var weap := {"kind": "gear", "base": "broadsword", "slot": "Weapon", "rarity": 3, "affixes": [{"grant": "scrap_bomb"}]}
	truthy("Grants" in LootData.instance_desc(weap, {"STR": 10}), "desc surfaces the granted ability")

	# Equip → granted + auto-slotted; NOT added to known_abilities.
	GameManager.equip(weap)
	check("scrap_bomb" in GameManager.granted_abilities, "equipping a grant item grants the ability")
	check(_hotbar_has("scrap_bomb"), "the granted ability auto-slots onto the hotbar")
	check("scrap_bomb" not in GameManager.known_abilities, "granted ≠ learned — known_abilities untouched")

	# BINDABLE. A granted ability used to be hotbar-only, so a player with an ability-granting item
	# couldn't put it on Q or Right-Mouse and reasonably read that as broken.
	check("scrap_bomb" in GameManager.castable_abilities(), "a granted ability counts as castable")
	GameManager.select_ability("scrap_bomb")
	eq(GameManager.selected_ability, "scrap_bomb", "a granted ability can be bound to Q")
	GameManager.select_secondary_ability("scrap_bomb")
	eq(GameManager.secondary_ability, "scrap_bomb", "…and to Right-Mouse")

	# Unequip → lost from the granted set, the bar, AND both cast keys (a binding pointing at an
	# ability you no longer have would just silently do nothing when pressed).
	GameManager.unequip("Weapon")
	check("scrap_bomb" not in GameManager.granted_abilities, "unequipping loses the granted ability")
	check(not _hotbar_has("scrap_bomb"), "the granted ability leaves the hotbar on unequip")
	eq(GameManager.selected_ability, "", "unequipping clears it off Q")
	eq(GameManager.secondary_ability, "", "unequipping clears it off Right-Mouse")

	# A learned ability that's ALSO granted must survive on the bar when the granting item is removed.
	GameManager.learn_ability("blink")
	var ring := {"kind": "gear", "base": "lucky_charm", "slot": "Trinket", "rarity": 2, "affixes": [{"grant": "blink"}]}
	GameManager.equip(ring)
	GameManager.unequip("Trinket")
	check(_hotbar_has("blink"), "a learned ability survives on the bar after a granting item is removed")

	GameManager.equipped = saved_eq
	GameManager.bag = saved_bag
	GameManager.hotbar = saved_hb
	GameManager.granted_abilities = saved_granted
	GameManager.known_abilities = saved_known
	GameManager.selected_ability = saved_sel
	GameManager.secondary_ability = saved_sec

func _hotbar_has(id: String) -> bool:
	for s in GameManager.hotbar:
		if s != null and s.get("kind") == "ability" and String(s.get("id", "")) == id:
			return true
	return false
