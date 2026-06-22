extends TestCase
# Hotbar management API (tap-to-arrange): swap reorders losslessly, clear empties a slot (ability →
# back to the unslotted pool, consumable discarded), assign places a pool ability without overwriting
# a consumable + de-dupes, and unslotted_abilities lists known/granted that aren't on the bar.
func _init() -> void: test_name = "hotbar"

func run() -> void:
	var saved_hb := GameManager.hotbar.duplicate(true)
	var saved_known := GameManager.known_abilities.duplicate()
	var saved_granted := GameManager.granted_abilities.duplicate()

	GameManager.known_abilities = ["blink", "ground_slam"]
	GameManager.granted_abilities = []
	GameManager.hotbar = [{"kind": "ability", "id": "blink"}, {"kind": "consumable", "base": "health_potion", "tier": 0, "count": 3}, null, null]

	# Swap is a lossless reorder.
	GameManager.swap_hotbar_slots(0, 2)
	check(GameManager.hotbar[0] == null and GameManager.hotbar[2] != null and String(GameManager.hotbar[2]["id"]) == "blink", "swap moves a slot's contents")
	GameManager.swap_hotbar_slots(0, 2)   # back

	# Unslotted pool = known/granted not currently on the bar (blink IS slotted → only ground_slam).
	var pool := GameManager.unslotted_abilities()
	check("ground_slam" in pool and "blink" not in pool, "unslotted pool excludes already-slotted abilities")

	# Assign into the first empty slot; de-dupes (an ability lands in exactly one slot).
	GameManager.assign_ability_to_slot("ground_slam")
	check(_count_ability("ground_slam") == 1, "assign places the ability exactly once")
	check("ground_slam" not in GameManager.unslotted_abilities(), "an assigned ability leaves the pool")

	# Assign never OVERWRITES a consumable: preferring the potion slot (1) routes to an empty slot instead.
	GameManager.hotbar = [{"kind": "ability", "id": "blink"}, {"kind": "consumable", "base": "health_potion", "tier": 0, "count": 3}, null, null]
	GameManager.assign_ability_to_slot("ground_slam", 1)
	check(String(GameManager.hotbar[1].get("kind", "")) == "consumable", "assign won't clobber a consumable slot")
	check(_count_ability("ground_slam") == 1, "the ability landed in a free slot instead")

	# Clear: an ability returns to the pool; a consumable is discarded.
	GameManager.hotbar = [{"kind": "ability", "id": "blink"}, {"kind": "consumable", "base": "health_potion", "tier": 0, "count": 3}, null, null]
	GameManager.clear_hotbar_slot(0)
	check(GameManager.hotbar[0] == null and "blink" in GameManager.unslotted_abilities(), "clearing an ability slot frees it back to the pool")
	GameManager.clear_hotbar_slot(1)
	check(GameManager.hotbar[1] == null, "clearing a consumable slot discards it")

	# A bar full of CONSUMABLES → a not-yet-slotted ability can't be placed and stays in the pool
	# (no consumable is clobbered).
	GameManager.hotbar = [
		{"kind": "consumable", "base": "health_potion", "tier": 0, "count": 1},
		{"kind": "consumable", "base": "mana_battery", "tier": 0, "count": 1},
		{"kind": "consumable", "base": "health_potion", "tier": 1, "count": 1},
		{"kind": "consumable", "base": "antidote", "tier": 1, "count": 1},
	]
	GameManager.assign_ability_to_slot("ground_slam", 0)   # prefer a consumable slot, no empty slot anywhere
	check(_count_ability("ground_slam") == 0 and "ground_slam" in GameManager.unslotted_abilities(), "a consumable-full bar leaves the ability in the pool, never clobbers a consumable")
	for s in GameManager.hotbar:
		check(s != null and s.get("kind") == "consumable", "every consumable slot is intact after the failed assign")

	# prefer pointing at a DIFFERENT ability slot overwrites it; the bumped ability returns to the pool.
	GameManager.hotbar = [{"kind": "ability", "id": "blink"}, null, null, null]
	GameManager.assign_ability_to_slot("ground_slam", 0)
	check(_count_ability("ground_slam") == 1 and _count_ability("blink") == 0, "assigning onto an ability slot replaces it (old one back to the pool)")

	GameManager.hotbar = saved_hb
	GameManager.known_abilities = saved_known
	GameManager.granted_abilities = saved_granted

func _count_ability(id: String) -> int:
	var n := 0
	for s in GameManager.hotbar:
		if s != null and s.get("kind") == "ability" and String(s.get("id", "")) == id:
			n += 1
	return n
