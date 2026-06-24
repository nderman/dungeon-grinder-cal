extends TestCase
# Right-Mouse secondary ability binding: only a KNOWN ability binds, re-binding the same one toggles
# it off, and an unknown id is ignored. (Primary/Q binding is select_ability, covered by play.)
func _init() -> void: test_name = "ability_bind"

func run() -> void:
	var saved_known := GameManager.known_abilities.duplicate()
	var saved_sec := GameManager.secondary_ability
	GameManager.known_abilities = ["ground_slam", "blink"]
	GameManager.secondary_ability = ""

	GameManager.select_secondary_ability("blink")
	eq(GameManager.secondary_ability, "blink", "right-click binds a known ability to the secondary cast")
	GameManager.select_secondary_ability("ground_slam")
	eq(GameManager.secondary_ability, "ground_slam", "binding a different ability rebinds it")
	GameManager.select_secondary_ability("ground_slam")
	eq(GameManager.secondary_ability, "", "re-binding the same ability toggles the secondary off")
	GameManager.select_secondary_ability("fireball")   # not in known_abilities
	eq(GameManager.secondary_ability, "", "an unknown ability can't be bound")

	GameManager.known_abilities = saved_known
	GameManager.secondary_ability = saved_sec
