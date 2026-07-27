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
	var saved_uses := GameManager.ability_uses.duplicate(true)
	var saved_glv := GameManager.granted_levels.duplicate(true)

	GameManager.equipped = {}
	GameManager.bag = []
	GameManager.hotbar = [null, null, null, null]
	GameManager.granted_abilities = []
	GameManager.known_abilities = []
	GameManager.selected_ability = ""
	GameManager.secondary_ability = ""

	# The desc reads as a "+1 to skill" affix (it teaches the ability OR levels the one you have).
	var weap := {"kind": "gear", "base": "broadsword", "slot": "Weapon", "rarity": 3, "affixes": [{"grant": "scrap_bomb"}]}
	var d := LootData.instance_desc(weap, {"STR": 10})
	truthy("+1" in d and AbilityLibrary.ability_name("scrap_bomb") in d, "desc surfaces the +1 skill affix")

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

	# "+1 SKILL" semantics — the affix must never be dead loot.
	GameManager.equipped = {}
	GameManager.granted_abilities = []
	GameManager.granted_levels = {}
	GameManager.known_abilities = []
	GameManager.ability_uses = {}
	# (a) You DON'T know it: the first grant spends itself teaching you the ability, at level 1.
	var w1 := {"kind": "gear", "base": "broadsword", "slot": "Weapon", "rarity": 3, "affixes": [{"grant": "ground_slam"}]}
	GameManager.equip(w1)
	eq(GameManager.ability_level("ground_slam"), 1, "an unknown ability is granted at level 1")
	# (b) A SECOND grant of the same ability stacks instead of being wasted.
	var r1 := {"kind": "gear", "base": "lucky_charm", "slot": "Trinket", "rarity": 3, "affixes": [{"grant": "ground_slam"}]}
	GameManager.equip(r1)
	eq(GameManager.ability_level("ground_slam"), 2, "a second grant of the same ability is +1 level, not wasted")
	# Magnitude scales with BOTH rarity and box tier, so the affix keeps growing with loot quality.
	eq(LootData.grant_levels(0, LootData.EFFECT_MIN_RARITY), 1, "a Rare Bronze grant is +1")
	check(LootData.grant_levels(5, 4) > LootData.grant_levels(0, 2), "a Legendary Celestial grant beats a Rare Bronze one")
	eq(LootData.grant_levels(5, 4), 5, "the very best gear rolls +5")
	check(LootData.grant_levels(9, 9) <= 5, "the bonus is capped, however absurd the inputs")

	# A multi-level grant applies all of its levels (first one still teaches an unknown ability).
	GameManager.unequip("Trinket")
	GameManager.unequip("Weapon")
	var big := {"kind": "gear", "base": "broadsword", "slot": "Weapon", "rarity": 4,
		"affixes": [{"grant": "holy_shield", "levels": 3}]}
	GameManager.equip(big)
	eq(GameManager.ability_level("holy_shield"), 3, "a +3 grant teaches an unknown ability AND levels it (1 taught + 2)")
	GameManager.unequip("Weapon")

	# (c) You ALREADY know it: every grant is a straight +1 (this was the dead-loot case).
	GameManager.unequip("Trinket")
	GameManager.unequip("Weapon")
	GameManager.learn_ability("ground_slam")
	var base_lv := GameManager.ability_level("ground_slam")
	GameManager.equip(w1)
	eq(GameManager.ability_level("ground_slam"), base_lv + 1, "granting an ability you already know is +1 level")
	GameManager.unequip("Weapon")
	eq(GameManager.ability_level("ground_slam"), base_lv, "…and the bonus goes away with the item")
	GameManager.known_abilities = []
	GameManager.ability_uses = {}
	GameManager.equipped = {}
	GameManager.granted_abilities = []
	GameManager.granted_levels = {}

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
	GameManager.ability_uses = saved_uses
	GameManager.granted_levels = saved_glv

func _hotbar_has(id: String) -> bool:
	for s in GameManager.hotbar:
		if s != null and s.get("kind") == "ability" and String(s.get("id", "")) == id:
			return true
	return false
