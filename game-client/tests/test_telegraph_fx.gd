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
