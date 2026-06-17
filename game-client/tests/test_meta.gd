extends TestCase
# Meta sinks. Permanent stat injectors: the Syndication sink — escalating per-stat cost, debits on buy,
# refuses when broke / for a non-stat, and the bought +1 reaches a fresh contestant's starting stats.
# Snapshots + restores the real MetaManager state so running the suite never corrupts a dev's save.
func _init() -> void: test_name = "meta"

func run() -> void:
	var saved_syn := MetaManager.syndication_points
	var saved_buffs := MetaManager.permanent_stat_buffs.duplicate()

	MetaManager.permanent_stat_buffs = {}
	MetaManager.syndication_points = 10000

	eq(MetaManager.stat_injector_cost("STR"), 500, "first STR injector costs the base 500")
	check(MetaManager.buy_stat_injector("STR"), "buy succeeds when affordable")
	eq(int(MetaManager.permanent_stat_buffs.get("STR", 0)), 1, "STR buff incremented")
	eq(MetaManager.syndication_points, 9500, "syndication debited by the cost")
	eq(MetaManager.stat_injector_cost("STR"), 750, "next STR injector in the SAME stat costs ×1.5")
	eq(MetaManager.stat_injector_cost("DEX"), 500, "a different stat is still at the base cost")

	MetaManager.syndication_points = 100
	check(not MetaManager.buy_stat_injector("STR"), "buy refused when you can't afford it")
	eq(MetaManager.syndication_points, 100, "no debit on a refused buy")
	check(not MetaManager.buy_stat_injector("LUCK"), "an unknown stat is refused")

	# The buff actually reaches a fresh contestant's starting stats (base 4 + class CON + the +3 injector).
	MetaManager.permanent_stat_buffs = {"CON": 3}
	var stats := MetaManager.get_current_contestant_stats("Human", "Brawler")
	check(int(stats["CON"]) >= 4 + 3, "a permanent CON injector feeds get_current_contestant_stats")

	MetaManager.syndication_points = saved_syn
	MetaManager.permanent_stat_buffs = saved_buffs
	MetaManager.save_persistence()
