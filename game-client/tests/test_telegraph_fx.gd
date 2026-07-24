extends TestCase
# TelegraphFx: the show_* API selects the right shape and becomes visible; clear() hides it; a zero
# direction is sanitised so _draw can't NaN. (The live cone/lane/line rendering is validated by the
# headless floor sim, where enemies wind up on the player.)
func _init() -> void: test_name = "telegraph_fx"

func run() -> void:
	var fx := TelegraphFx.new()
	add_child(fx)   # runs _ready → hidden, z above the mob
	check(not fx.visible, "starts hidden")

	fx.show_cone(Vector2.RIGHT, deg_to_rad(90.0), 100.0, 0.3)
	check(fx.visible, "a wind-up shows the shape")
	eq(fx._kind, "cone", "swing → cone")
	fx.show_lane(Vector2.LEFT, 120.0, 60.0, 0.3)
	eq(fx._kind, "lane", "lunge → lane")
	fx.show_line(Vector2.UP, 200.0, 0.3)
	eq(fx._kind, "line", "ranged → line")
	fx.show_circle(150.0, 0.3)
	eq(fx._kind, "circle", "AoE → circle")

	fx.clear()
	check(not fx.visible, "clear() hides it")

	fx.show_cone(Vector2.ZERO, 1.0, 50.0, 0.2)   # degenerate direction
	check(fx._dir.is_normalized(), "a zero direction is sanitised to a unit vector")

	fx.queue_free()
