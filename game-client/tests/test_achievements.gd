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

	SignalBus.achievement_unlocked.disconnect(cb)
