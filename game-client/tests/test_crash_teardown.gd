extends TestCase
# REGRESSION: dying mid-combat (death → Green Room scene swap) detaches enemies that are mid-attack.
# Their coroutines used to fault on get_tree().physics_frame (null). A detached enemy must bail
# cleanly instead. Reaching the end without a crash = the is_inside_tree() guards hold.
func _init() -> void: test_name = "crash_teardown"

const BRUTE := preload("res://entities/enemies/Brute.tscn")

func run() -> void:
	var brute := BRUTE.instantiate()
	add_child(brute)
	var ai = brute.get_node("AIComponent")
	var dummy := TestStubs.player(self, Vector2(40, 0))
	ai.target = dummy
	ai._swing_aim = Vector2.RIGHT
	ai._do_swing()        # starts the coroutine; suspends at the first await get_tree().physics_frame
	remove_child(brute)   # DETACH mid-swing — simulates the Floor freeing on death
	# Resume the detached coroutine across a few physics frames; the guard must catch it (no crash).
	for _i in range(5):
		await get_tree().physics_frame
	check(true, "a detached enemy mid-swing does not crash on get_tree()")
	brute.queue_free()
