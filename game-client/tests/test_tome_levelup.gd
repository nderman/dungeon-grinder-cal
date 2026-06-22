extends TestCase
# A duplicate tome ranks up an already-known ability (DCC: train the skill) instead of being wasted —
# preserving partial progress, refusing an unknown ability, and never exceeding MAX_LEVEL.
func _init() -> void: test_name = "tome_levelup"

func run() -> void:
	var saved_known := GameManager.known_abilities.duplicate()
	var saved_uses := GameManager.ability_uses.duplicate()
	var saved_hb := GameManager.hotbar.duplicate(true)
	var saved_sel := GameManager.selected_ability

	GameManager.known_abilities = ["ground_slam"]
	GameManager.ability_uses = {}
	GameManager.hotbar = [null, null, null, null]
	GameManager.selected_ability = ""
	var upl := AbilityLibrary.USES_PER_LEVEL

	eq(GameManager.ability_level("ground_slam"), 1, "a known ability starts at level 1")

	# Full path: picking up a duplicate tome ranks it up instead of "already known".
	GameManager.add_consumable("tome_ground_slam", 1)
	eq(GameManager.ability_level("ground_slam"), 2, "a duplicate tome ranks the known ability up")

	# Partial progress toward the next level is preserved when a tome lands.
	GameManager.ability_uses["ground_slam"] = upl + 3   # level 2, +3 toward level 3
	eq(GameManager.level_ability_from_tome("ground_slam"), 3, "tome adds a full level on top of partial progress")
	eq(int(GameManager.ability_uses["ground_slam"]), 2 * upl + 3, "the partial progress carries over")

	# An ability you don't know can't be ranked by a tome (add_consumable would LEARN it instead).
	eq(GameManager.level_ability_from_tome("blink"), 0, "a tome can't rank an ability you don't know")

	# Never past MAX_LEVEL.
	GameManager.ability_uses["ground_slam"] = (AbilityLibrary.MAX_LEVEL - 1) * upl
	eq(GameManager.ability_level("ground_slam"), AbilityLibrary.MAX_LEVEL, "at the level cap")
	eq(GameManager.level_ability_from_tome("ground_slam"), 0, "a maxed ability can't rank further")

	GameManager.known_abilities = saved_known
	GameManager.ability_uses = saved_uses
	GameManager.hotbar = saved_hb
	GameManager.selected_ability = saved_sel
