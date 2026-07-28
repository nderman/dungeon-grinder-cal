extends TestCase
# Anti-wedge recovery. A boss knocked between two cover blocks (or cover and a wall) still has a valid
# PATH to the player — its body just doesn't fit through the gap — so the old "no path for N seconds"
# safe-spot check never fired and it ground against the geometry forever. Recovery steers it back onto
# its own (boss-sized) nav mesh; with no mesh to consult it must at least shove away from the player,
# since a boss almost always wedges while pressing toward you.
func _init() -> void: test_name = "unwedge"

func run() -> void:
	var mob := (load("res://entities/enemies/GlitchGoblin.tscn") as PackedScene).instantiate()
	add_child(mob)
	mob.global_position = Vector2.ZERO
	var player := TestStubs.player(self, Vector2(100, 0))
	var ai := mob.get_node_or_null("AIComponent")
	check(ai != null, "mob exposes an AIComponent")
	if ai:
		ai.target = player
		var out: Vector2 = ai._unwedge_dir()
		check(out != Vector2.ZERO, "wedged with nowhere on-mesh to go, it still picks a direction")
		check(out.dot(player.global_position - mob.global_position) < 0.0,
			"…and it backs AWAY from the player rather than further into the geometry")

		# Even long past the last-resort threshold, with NO nav mesh to consult it must not teleport —
		# there'd be nowhere known-valid to land, so blind-porting could drop the boss inside a wall.
		# It keeps shoving instead. (The mesh-backed placement path needs a baked floor; the live sim
		# covers it.)
		ai._wedged_for = float(ai.WEDGE_TELEPORT_TIME) + 1.0
		var here: Vector2 = mob.global_position
		ai._unwedge_dir()
		check(mob.global_position.is_equal_approx(here), "with no nav mesh it never blind-teleports")
	mob.queue_free()
