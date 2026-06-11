extends TestCase
# Floor element themes: gated to floor 3+; elites are ALWAYS elemental at elite power, keeping any
# signature element.
func _init() -> void: test_name = "floor_themes"

const GEN := preload("res://levels/LevelGenerator.gd")
const GOBLIN := preload("res://entities/enemies/GlitchGoblin.tscn")
const BRUTE := preload("res://entities/enemies/Brute.tscn")

func run() -> void:
	var gen = GEN.new()   # not added to tree → generation _ready never runs
	GameManager.current_floor = 1
	var themed_low := false
	for _i in range(40):
		gen._roll_floor_theme()
		if gen.floor_element != "": themed_low = true
	check(not themed_low, "floors below 3 never roll a theme")

	GameManager.current_floor = 5
	var themed := 0
	for _i in range(200):
		gen._roll_floor_theme()
		if gen.floor_element != "":
			themed += 1
			check(gen.floor_element in gen.ELEMENTS, "themed element is a known element")
	check(themed > 0 and themed < 200, "floor 5 is sometimes themed (got %d/200)" % themed)

	# Elite gains the floor element at elite power; a signature element survives.
	gen.floor_element = "burn"
	var gob := GOBLIN.instantiate()
	gen._make_elite(gob, gob.get_node("HealthComponent"), gob.get_node("AIComponent"))
	eq(gob.get_node("AIComponent").on_hit_effect, "burn", "elite gains the floor element")
	approx(gob.get_node("AIComponent").on_hit_effect_power, gen.ELITE_POWER["burn"], "elite uses elite power")
	var br := BRUTE.instantiate()
	gen._make_elite(br, br.get_node("HealthComponent"), br.get_node("AIComponent"))
	eq(br.get_node("AIComponent").on_hit_effect, "chill", "elite Brute keeps its chill signature on a burn floor")
	gob.queue_free()
	br.queue_free()
	gen.free()
