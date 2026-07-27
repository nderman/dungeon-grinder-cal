extends TestCase
# TelegraphFx: the show_* API selects the right shape and becomes visible; clear() hides it; a zero
# direction is sanitised so _draw can't NaN. (The live cone/lane/line rendering is validated by the
# headless floor sim, where enemies wind up on the player.)
func _init() -> void: test_name = "telegraph_fx"

func run() -> void:
	var fx := TelegraphFx.new()
	add_child(fx)   # runs _ready → hidden, z above the mob
	check(not fx.visible, "starts hidden")

	fx.show_cone(deg_to_rad(90.0), 100.0, 0.3)
	check(fx.visible, "a wind-up shows the shape")
	eq(fx._kind, "cone", "swing → cone")
	fx.show_lane(120.0, 60.0, 0.3)
	eq(fx._kind, "lane", "lunge → lane")
	fx.show_line(200.0, 0.3)
	eq(fx._kind, "line", "ranged → line")
	fx.show_circle(150.0, 0.3)
	eq(fx._kind, "circle", "AoE → circle")

	fx.clear()
	check(not fx.visible, "clear() hides it")

	# Aiming is NODE ROTATION (so tracking a moving target costs no redraw), and a degenerate
	# direction must leave the last good aim alone rather than snapping to zero.
	fx.point_at(Vector2.UP)
	approx(fx.rotation, Vector2.UP.angle(), "point_at aims via rotation")
	fx.point_at(Vector2.ZERO)
	approx(fx.rotation, Vector2.UP.angle(), "a zero direction leaves the aim untouched")

	# The intensity ramp rides self_modulate (NOT a per-frame redraw — rebuilding the polygon every
	# frame just for alpha churns a GPU buffer, which is the bad pattern on the web build), and it must
	# STEP UP at the lock so the commit is legible even to a player the shape never rotated toward.
	fx.show_line(100.0, 1.0)
	fx._process(0.1)                      # 10% in — still tracking
	var early := fx.self_modulate.a
	fx._process(0.5)   # cross the lock
	# epsilon: Color stores 32-bit floats, so 0.7 reads back as 0.69999998 and a bare >= would fail.
	check(fx.self_modulate.a >= TelegraphFx.ALPHA_LOCKED - 0.001, "the shape steps brighter at the commit")
	check(fx.self_modulate.a > early, "…and that's a visible step up from the tracking phase")

	# Auto-clears once the wind-up window elapses (the leak-prevention path).
	fx.show_line(100.0, 0.2)
	check(fx.visible, "shown during the wind-up")
	fx._process(0.5)   # advance past _dur
	check(not fx.visible, "auto-clears when the wind-up window elapses")

	fx.queue_free()

	# REGRESSION: the telegraph was invisible in-game for days because AIComponent built its TelegraphFx
	# and called parent.add_child() while the MOB was still setting up — Godot rejects that ("parent node
	# is busy setting up children"), so the node existed but never entered the tree and never drew. The
	# component held a valid reference the whole time, which is why nothing looked broken. Assert it's
	# actually IN THE TREE, not merely constructed.
	var mob := (load("res://entities/enemies/GlitchGoblin.tscn") as PackedScene).instantiate()
	add_child(mob)   # runs AIComponent._ready
	var ai := mob.get_node_or_null("AIComponent")
	check(ai != null, "the mob has an AIComponent")
	if ai:
		check(ai._tele_fx != null, "AIComponent builds a TelegraphFx")
		check(ai._tele_fx.is_inside_tree(), "the TelegraphFx is actually IN THE TREE (or it can never draw)")
	mob.queue_free()

	# TRACK-THEN-LOCK contract: while unlocked the aim follows the target; once LOCKED it must not move
	# again. If a locked aim could still drift, the frozen danger shape would be lying about where the
	# hit lands — which is the whole bug this mechanic exists to fix.
	var mob2 := (load("res://entities/enemies/GlitchGoblin.tscn") as PackedScene).instantiate()
	add_child(mob2)
	mob2.global_position = Vector2.ZERO
	# MUST be a CharacterBody2D — AIComponent.target is typed, so assigning a bare Node2D fails at
	# RUNTIME and aborts run(), which TestCase would report as a green zero-failure pass.
	var dummy := TestStubs.player(self, Vector2(100, 0))
	var ai2 := mob2.get_node_or_null("AIComponent")
	check(ai2 != null, "goblin exposes an AIComponent for the lock test")
	if ai2:
		ai2.target = dummy
		ai2.current_state = ai2.State.TELEGRAPH
		ai2._aim_locked = false
		ai2._attack_aim = Vector2.UP   # a wrong start value, so a passing check can't be a coincidence
		ai2._face_target(0.016)
		check(ai2._attack_aim.is_equal_approx(Vector2.RIGHT), "unlocked: aim tracks the target")
		dummy.global_position = Vector2(0, 100)
		ai2._face_target(0.016)
		check(ai2._attack_aim.is_equal_approx(Vector2.DOWN), "unlocked: aim keeps following as the target moves")
		ai2._aim_locked = true
		dummy.global_position = Vector2(-100, 0)
		ai2._face_target(0.016)
		check(ai2._attack_aim.is_equal_approx(Vector2.DOWN), "LOCKED: aim does NOT follow — the frozen shape stays honest")
	mob2.queue_free()
