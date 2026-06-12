extends TestCase
# The Showrunner summons even on a busy floor (the MAX_ADDS cap counts ITS OWN swarm, not every
# enemy on the floor), and that swarm cap holds.
func _init() -> void: test_name = "showrunner"

const SHOW := preload("res://entities/enemies/Showrunner.tscn")

func run() -> void:
	# Flood the "enemies" group with 20 unrelated mobs — the OLD floor-wide count would block summons.
	for _i in range(20):
		var e := CharacterBody2D.new()
		e.add_to_group("enemies")
		add_child(e)

	var s := SHOW.instantiate()
	add_child(s)
	s.global_position = Vector2(7000, 7000)
	s._summon()
	check(s._adds.size() >= s.WAVE, "summons fire despite a busy floor (cap is its OWN adds)")

	for _i in range(20):
		s._summon()
	check(s._adds.size() <= s.MAX_ADDS, "the own-swarm cap holds at MAX_ADDS")

	for a in s._adds:
		if is_instance_valid(a):
			a.queue_free()
	s.queue_free()
