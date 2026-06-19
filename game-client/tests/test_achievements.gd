extends TestCase
# A repeatable feat (Chain Reaction) fires once, then is throttled within REPEAT_COOLDOWN so it
# doesn't spam the ticker while you clear a room.
func _init() -> void: test_name = "achievements"

func run() -> void:
	var titles: Array = []
	var cb := func(t): titles.append(t)
	SignalBus.achievement_unlocked.connect(cb)
	AchievementManager._repeat_cd.erase("chain_react")   # clear any cooldown for a deterministic start

	SignalBus.ratings_spike.emit("CHAIN_KILL")
	var after_first := titles.size()
	check(after_first >= 1, "a repeatable feat fires (box or heckle) the first time")

	SignalBus.ratings_spike.emit("CHAIN_KILL")   # immediately again
	check(titles.size() == after_first, "the same feat is throttled within the cooldown — no ticker spam")

	# Michael Bay (the AoE-spam fix): tier 1 (a real Weapon Box) throttled by a long personal cooldown.
	# tier 1 pays through floor 6 (floor gate), heckles at floor 7+; its cooldown is its own 45s, not 12s.
	var saved_floor: int = GameManager.current_floor
	titles.clear()
	GameManager.current_floor = 3
	AchievementManager._repeat_cd.erase("michael_bay")
	SignalBus.ratings_spike.emit("BOOM")
	check(titles.size() == 1 and "Box" in String(titles[-1]), "BOOM pays a Weapon Box on floor 3")
	var cd_at := float(AchievementManager._repeat_cd.get("michael_bay", 0.0))
	var now := Time.get_ticks_msec() / 1000.0
	check(cd_at - now > float(AchievementManager.REPEAT_COOLDOWN), "michael_bay uses its own longer cooldown, not the 12s default")

	titles.clear()
	GameManager.current_floor = 7
	AchievementManager._repeat_cd.erase("michael_bay")
	SignalBus.ratings_spike.emit("BOOM")
	check(titles.size() == 1 and not ("Box" in String(titles[-1])), "tier-1 BOOM heckles past floor 6 (deep floors demand bigger feats) — no box")

	GameManager.current_floor = saved_floor
	AchievementManager._repeat_cd.erase("michael_bay")
	SignalBus.achievement_unlocked.disconnect(cb)
