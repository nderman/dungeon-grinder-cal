extends TestCase
# Holy Shield is a timed DR buff (heal + aura), and the elemental ElementMark reads the body radius.
func _init() -> void: test_name = "holy_shield"

func run() -> void:
	var hs := AbilityLibrary.get_ability("holy_shield")
	eq(hs.get("effect"), "shield", "Holy Shield is a 'shield' effect (not just a heal)")
	check(float(hs.get("aura_dr", 0)) > 0.0 and float(hs.get("duration", 0)) > 0.0, "Holy Shield has aura_dr + duration")

	# apply_aura grants temporary DR that sometimes mitigates incoming damage.
	var prot := ProtectionComponent.new()
	add_child(prot)
	prot.apply_aura(40.0, 5.0)
	approx(prot.aura_dr, 40.0, "apply_aura sets the DR aura")
	var reduced := 0
	for _i in range(400):
		if prot.handle_incoming_damage(2.0) < 2.0: reduced += 1
	check(reduced > 0, "the aura mitigates some hits")

	# ElementMark reads the mob's collision radius for sizing.
	var enemy := CharacterBody2D.new()
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	cs.shape = shape
	enemy.add_child(cs)
	add_child(enemy)
	var mark := ElementMark.new()
	mark.element = "burn"
	enemy.add_child(mark)
	approx(mark._r, 24.0, "ElementMark reads the body radius")
