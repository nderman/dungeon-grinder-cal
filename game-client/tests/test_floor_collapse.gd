extends TestCase
# Floor-collapse telegraph: the pre-collapse banner fires exactly once as the clock nears the floor's
# collapse deadline, re-arms each floor, and the FINAL floor gets a longer (8-min) deadline + a
# finish-the-Champion banner (no stairs to flee through).
func _init() -> void: test_name = "floor_collapse"

func run() -> void:
	var warns: Array = []
	var spy := func(msg: String, _pos): if "COLLAPSING" in msg: warns.append(msg)
	SignalBus.toast.connect(spy)

	var saved_active := GameManager.is_run_active
	var saved_floor := GameManager.current_floor

	GameManager.current_floor = 1
	GameManager.begin_floor()
	GameManager.is_run_active = true
	var ct := GameManager.collapse_time()   # 300 on a normal floor
	eq(ct, GameManager.COLLAPSE_TIME, "a normal floor uses the standard collapse time")

	# Comfortably before the lead window — no warning yet.
	GameManager.floor_elapsed = ct - GameManager.COLLAPSE_WARN_LEAD - 10.0
	GameManager._process(0.1)
	check(warns.is_empty(), "no collapse warning before the lead window")

	# Cross the lead threshold — exactly one banner, and it must NOT repeat on the next tick.
	GameManager.floor_elapsed = ct - GameManager.COLLAPSE_WARN_LEAD + 0.1
	GameManager._process(0.1)
	GameManager._process(0.1)
	eq(warns.size(), 1, "collapse warning fires exactly once per floor")
	check("FLOOR" in warns[0], "a normal floor warns you to GET OUT")

	# A fresh floor re-arms the one-shot.
	warns.clear()
	GameManager.begin_floor()
	GameManager.floor_elapsed = ct - 1.0
	GameManager._process(0.1)
	eq(warns.size(), 1, "the warning re-arms on a new floor")

	# Final floor: a LONGER deadline, and the banner frames it as finish-the-Champion.
	warns.clear()
	GameManager.current_floor = GameManager.FINAL_FLOOR
	GameManager.begin_floor()
	check(GameManager.collapse_time() > GameManager.COLLAPSE_TIME, "the final floor gets a longer collapse clock")
	GameManager.floor_elapsed = GameManager.collapse_time() - 1.0
	GameManager._process(0.1)
	eq(warns.size(), 1, "final floor still warns (no is_final_floor escape)")
	check("ARENA" in warns[0], "the final floor's warning is the Champion-fight banner")

	SignalBus.toast.disconnect(spy)
	GameManager.is_run_active = saved_active
	GameManager.current_floor = saved_floor
	GameManager.begin_floor()
