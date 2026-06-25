extends TestCase
# Contestant passives (race + class): has_passive resolves from EITHER, and the Wave-1 multiplier
# helpers return the granting factor (and a clean 1.0 default otherwise).
func _init() -> void: test_name = "passives"

func run() -> void:
	var saved_race := GameManager.current_race
	var saved_class := GameManager.current_class

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

	# An unrelated build triggers none; the mult helpers default to 1.0.
	GameManager.current_race = "Cat"
	GameManager.current_class = "GlitchWitch"
	check(not GameManager.has_passive("iron_fist"), "unrelated build has no Iron Fist")
	approx(GameManager.melee_damage_mult(), 1.0, "default melee mult is 1.0")
	approx(GameManager.dash_dist_mult(), 1.0, "default dash mult is 1.0")

	GameManager.current_race = saved_race
	GameManager.current_class = saved_class
