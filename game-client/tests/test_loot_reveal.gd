extends TestCase
# Loot reveal: open_all_boxes returns the sorted haul ([{box,item,rarity,tier}]) AND banks it (clears
# the pending queue + adds to inventory); the LootRevealPanel builds one row per result headlessly.
func _init() -> void: test_name = "loot_reveal"

func run() -> void:
	var saved_ng := GameManager.ng_plus
	GameManager.ng_plus = 0   # don't let an NG+ tier-bump skew the queued tiers
	GameManager.earned_loot_boxes.clear()
	GameManager.add_loot_box(2, "weapon")
	GameManager.add_loot_box(0, "supply")
	var stats := {"STR": 10, "DEX": 6, "INT": 4, "CON": 8, "CHA": 4}
	var results := AchievementManager.open_all_boxes(stats)
	eq(results.size(), 2, "open_all_boxes returns one result per opened box")
	check(GameManager.earned_loot_boxes.is_empty(), "the pending box queue is cleared after opening")
	check(int(results[0]["tier"]) <= int(results[1]["tier"]), "results are ordered low tier → high")
	for r in results:
		truthy(String(r.get("box", "")) != "", "each result carries a box label")
		truthy(String(r.get("item", "")) != "", "each result names the rolled item")
		check(r.has("rarity"), "each result carries a rarity (-1 for a consumable)")

	GameManager.earned_loot_boxes.clear()
	eq(AchievementManager.open_all_boxes(stats).size(), 0, "opening with no pending boxes returns []")

	# The reveal panel builds a row per result headlessly (tween + rows, no crash) and tracks open_count.
	var before_open := ModalPanel.open_count
	var panel := LootRevealPanel.new()
	add_child(panel)
	panel.reveal(results)
	eq(panel._rows.size(), results.size(), "reveal builds one row per result")
	check(panel.visible, "reveal shows the panel")
	eq(ModalPanel.open_count, before_open + 1, "showing the reveal bumps the modal open_count")
	panel.close()
	eq(ModalPanel.open_count, before_open, "closing the reveal restores open_count")
	panel.queue_free()

	GameManager.ng_plus = saved_ng   # leave global run state as we found it
	GameManager.earned_loot_boxes.clear()
