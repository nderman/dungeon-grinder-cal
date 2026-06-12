extends TestCase
# The Hexgun's volley patterns: a full ring fires at once; a spinning spiral fires multi-arm bolts
# over time (and bails cleanly if detached, like the rest of the AI).
func _init() -> void: test_name = "hexgun"

const HEXGUN := preload("res://entities/enemies/HexgunTurret.tscn")

func _bolts() -> int:
	var n := 0
	for c in get_tree().current_scene.get_children():
		if c.scene_file_path.ends_with("GlitchBolt.tscn"):
			n += 1
	return n

func run() -> void:
	var h := HEXGUN.instantiate()
	add_child(h)
	h.global_position = Vector2(5000, 5000)   # off in the corner so its bolts don't clutter other checks

	var before := _bolts()
	h._fire_ring(12)
	check(_bolts() - before >= 12, "a ring fires a full ring of bolts at once")

	before = _bolts()
	await h._fire_spiral(3)   # a 3-arm spinning spiral, fired over ~0.5s
	check(_bolts() - before >= 3, "a spinning spiral fires multi-arm bolts over time")

	h.queue_free()
