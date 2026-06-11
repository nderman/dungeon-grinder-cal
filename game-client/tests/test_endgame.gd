extends TestCase
# Endgame: the final floor is gated correctly, and the Champion is a genuine step up from a Floor Boss.
# (win_run() itself changes scene + writes the save, so it's left to playtest, not unit-tested.)
func _init() -> void: test_name = "endgame"

const GEN := preload("res://levels/LevelGenerator.gd")

func run() -> void:
	var saved := GameManager.current_floor
	GameManager.current_floor = GameManager.FINAL_FLOOR - 1
	check(not GameManager.is_final_floor(), "the floor before the last is not the final floor")
	GameManager.current_floor = GameManager.FINAL_FLOOR
	check(GameManager.is_final_floor(), "reaching FINAL_FLOOR is the final floor")
	GameManager.current_floor = GameManager.FINAL_FLOOR + 1
	check(GameManager.is_final_floor(), "past the final floor still counts as final")
	GameManager.current_floor = saved   # restore shared autoload state for later tests

	check(float(GEN.FINAL_BOSS["hearts"]) > float(GEN.FLOOR_BOSS["hearts"]), "the Champion has more HP than a Floor Boss")
	check(float(GEN.FINAL_BOSS["damage"]) >= float(GEN.FLOOR_BOSS["damage"]), "the Champion hits at least as hard")
	truthy(GameManager.has_method("win_run"), "win_run() exists as the victory path")
