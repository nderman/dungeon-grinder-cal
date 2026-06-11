extends TestCase
# CombatEffects: crit resolution + on-hit procs (leech heals attacker, burn attaches a status).
func _init() -> void: test_name = "combat_effects"

func run() -> void:
	# Crit: 0 never crits, 1 always doubles + flags.
	for _i in range(50):
		var no := CombatEffects.resolve_damage(10.0, {})
		check(no[0] == 10.0 and no[1] == false, "no crit chance passes damage through")
		var yes := CombatEffects.resolve_damage(10.0, {"crit": 1.0})
		check(yes[0] == 20.0 and yes[1] == true, "crit 1.0 doubles and flags")

	# Leech heals the attacker; burn attaches a status to the victim.
	var victim := TestStubs.body(self, &"enemies", Vector2(100, 0), 50.0)
	var attacker := HealthComponent.new()
	attacker.name = "HealthComponent"
	attacker.configured_hearts = 100.0
	add_child(attacker)
	attacker._deal(40.0)   # drop attacker to 60 so leech healing is observable
	var before := attacker.current_hearts
	CombatEffects.apply_on_hit(victim, 20.0, {"leech": 0.5}, attacker)
	approx(attacker.current_hearts, before + 10.0, "leech heals attacker for 50% of damage dealt")
	CombatEffects.apply_on_hit(victim, 10.0, {"burn": 1.0}, attacker)
	truthy(victim.get_node_or_null("Status_burn"), "burn affix attaches a fire DoT to the victim")

	# No procs on an INVULNERABLE target (a dormant boss before the arena locks).
	var dormant := TestStubs.body(self, &"enemies", Vector2(300, 0), 50.0)
	dormant.get_node("HealthComponent").set_invulnerable(true)
	var heal_before := attacker.current_hearts
	CombatEffects.apply_on_hit(dormant, 20.0, {"burn": 1.0, "leech": 0.5}, attacker)
	check(dormant.get_node_or_null("Status_burn") == null, "no burn procs on a dormant/invulnerable target")
	approx(attacker.current_hearts, heal_before, "no leech off a phantom hit on an invulnerable target")
