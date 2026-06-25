extends TestCase
# Contestant passives (race + class): has_passive resolves from EITHER, and the Wave-1 multiplier
# helpers return the granting factor (and a clean 1.0 default otherwise).
func _init() -> void: test_name = "passives"

func run() -> void:
	var saved_race := GameManager.current_race
	var saved_class := GameManager.current_class
	var saved_ratings := GameManager.run_ratings
	var saved_hype := GameManager.hype_meter

	# Brawler = Iron Fist (melee); Human = Viewer's Choice (loot).
	GameManager.current_race = "Human"
	GameManager.current_class = "Brawler"
	check(GameManager.has_passive("iron_fist"), "Brawler grants Iron Fist")
	check(GameManager.has_passive("viewers_choice"), "Human grants Viewer's Choice")
	approx(GameManager.melee_damage_mult(), 1.2, "Iron Fist = +20% melee")
	approx(GameManager.mana_cost_mult(), 1.0, "no mana discount without Efficient Code")
	approx(GameManager.move_speed_mult(), 1.0, "no speed penalty without Ponderous Might")

	# Technomancer = Efficient Code (mana).
	GameManager.current_class = "Technomancer"
	approx(GameManager.mana_cost_mult(), 0.85, "Efficient Code = -15% mana")
	check(not GameManager.has_passive("iron_fist"), "Technomancer is not Iron Fist")

	# Ogre = Ponderous Might (knockback AND speed, from one passive).
	GameManager.current_race = "Ogre"
	GameManager.current_class = "Scavenger"
	approx(GameManager.knockback_mult(), 2.0, "Ponderous Might doubles knockback")
	approx(GameManager.move_speed_mult(), 0.8, "Ponderous Might = -20% speed")
	check(not GameManager.has_passive("viewers_choice"), "Ogre is not Human's Viewer's Choice")

	# GravityGlitcher = Low-G Training (dash).
	GameManager.current_class = "GravityGlitcher"
	approx(GameManager.dash_dist_mult(), 1.35, "Low-G Training extends the dash")

	# Audience Darling (Cat) — Hype gen multiplier.
	GameManager.current_race = "Cat"
	GameManager.current_class = "Brawler"
	approx(GameManager.hype_mult(), 1.5, "Audience Darling speeds Hype gen")

	# Martyr's Hype (BioPaladin) — taking a hit pays Ratings + Hype.
	GameManager.current_race = "Human"
	GameManager.current_class = "BioPaladin"
	var r0 := GameManager.run_ratings
	GameManager.hype_meter = 0.0   # start from a known floor (hype wraps at 100)
	GameManager.award_martyr_hype()
	check(GameManager.run_ratings > r0, "Martyr's Hype awards Ratings on a hit")
	check(GameManager.hype_meter > 0.0, "Martyr's Hype awards Hype on a hit")

	# An unrelated build (no melee/dash/hype passive) triggers none; the mult helpers default to 1.0.
	GameManager.current_race = "Trollkin"
	GameManager.current_class = "GlitchWitch"
	check(not GameManager.has_passive("iron_fist"), "unrelated build has no Iron Fist")
	check(GameManager.has_passive("data_corruption"), "GlitchWitch grants Data Corruption")
	approx(GameManager.melee_damage_mult(), 1.0, "default melee mult is 1.0")
	approx(GameManager.dash_dist_mult(), 1.0, "default dash mult is 1.0")
	approx(GameManager.hype_mult(), 1.0, "default hype mult is 1.0")

	GameManager.current_race = saved_race
	GameManager.current_class = saved_class
	GameManager.run_ratings = saved_ratings
	GameManager.hype_meter = saved_hype
