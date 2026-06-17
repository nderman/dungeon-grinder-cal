extends TestCase
# Meta sinks. Permanent stat injectors: the Syndication sink — escalating per-stat cost, debits on buy,
# refuses when broke / for a non-stat, and the bought +1 reaches a fresh contestant's starting stats.
# Snapshots + restores the real MetaManager state so running the suite never corrupts a dev's save.
func _init() -> void: test_name = "meta"

func run() -> void:
	var saved_syn := MetaManager.syndication_points
	var saved_buffs := MetaManager.permanent_stat_buffs.duplicate()
	var saved_tokens := MetaManager.milestone_tokens
	var saved_pool := MetaManager.permanent_loot_pool.duplicate()
	var saved_ng_unlocked := MetaManager.ng_plus_unlocked
	var saved_ng_active := MetaManager.ng_plus_active
	var saved_ng := GameManager.ng_plus

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

	# Loot sponsorship: the Token sink. Spends a token, marks the item sponsored, refuses dup / broke.
	MetaManager.permanent_loot_pool = []
	MetaManager.milestone_tokens = 2
	check(not MetaManager.is_sponsored("war_hammer"), "weapon not sponsored initially")
	check(MetaManager.sponsor_item("war_hammer"), "sponsor succeeds with a token")
	check(MetaManager.is_sponsored("war_hammer"), "item is now sponsored")
	eq(MetaManager.milestone_tokens, 1, "one token spent on the sponsor")
	check(not MetaManager.sponsor_item("war_hammer"), "can't sponsor the same item twice")
	eq(MetaManager.milestone_tokens, 1, "no token spent on a duplicate sponsor")
	MetaManager.milestone_tokens = 0
	check(not MetaManager.sponsor_item("broadsword"), "sponsor refused with no tokens")

	# Prestige / New Game+: the second Token sink. Escalating cost, active clamps to unlocked, and the
	# GameManager run mults scale off the active tier (0 = everything ×1.0).
	MetaManager.ng_plus_unlocked = 0
	MetaManager.ng_plus_active = 0
	MetaManager.milestone_tokens = 3
	eq(MetaManager.ng_plus_cost(), 3, "NG+1 costs the base 3 tokens")
	check(MetaManager.unlock_ng_plus(), "unlock NG+1 with enough tokens")
	eq(MetaManager.ng_plus_unlocked, 1, "NG+ unlocked tier rose to 1")
	eq(MetaManager.ng_plus_active, 1, "the freshly bought tier auto-arms")
	eq(MetaManager.milestone_tokens, 0, "tokens spent on the NG+ unlock")
	eq(MetaManager.ng_plus_cost(), 5, "NG+2 costs more (base + 2)")
	check(not MetaManager.unlock_ng_plus(), "can't unlock NG+2 while broke")
	MetaManager.set_ng_plus_active(9)
	eq(MetaManager.ng_plus_active, 1, "active tier clamps to the unlocked max")
	MetaManager.set_ng_plus_active(-3)
	eq(MetaManager.ng_plus_active, 0, "active tier clamps at 0 (NG+ off)")

	GameManager.ng_plus = 2
	approx(GameManager.ng_plus_dmg_mult(), 1.5, "NG+2 → enemies hit ×1.5")
	approx(GameManager.ng_plus_hp_mult(), 1.5, "NG+2 → enemies have ×1.5 HP")
	approx(GameManager.ng_plus_reward_mult(), 1.5, "NG+2 → ×1.5 ratings/XP")
	GameManager.ng_plus = 0
	approx(GameManager.ng_plus_dmg_mult(), 1.0, "NG+ off → no scaling")

	MetaManager.syndication_points = saved_syn
	MetaManager.permanent_stat_buffs = saved_buffs
	MetaManager.milestone_tokens = saved_tokens
	MetaManager.permanent_loot_pool = saved_pool
	MetaManager.ng_plus_unlocked = saved_ng_unlocked
	MetaManager.ng_plus_active = saved_ng_active
	GameManager.ng_plus = saved_ng
	MetaManager.save_persistence()
