extends TestCase
# New-player onboarding: the early-floor gentleness ramp + the aim-assist nearest-target math (the two
# pure helpers behind "gentler start + keyboard auto-aim").
func _init() -> void: test_name = "npe"

const LG = preload("res://levels/LevelGenerator.gd")
const PL = preload("res://entities/player/Player.gd")

func run() -> void:
	# Gentleness ramp: full at floor 1, half at 2, gone from 3 on.
	approx(LG.early_gentle_factor(1), 1.0, "floor 1 is fully gentled")
	approx(LG.early_gentle_factor(2), 0.5, "floor 2 is half gentled")
	approx(LG.early_gentle_factor(3), 0.0, "floor 3 is full difficulty")
	approx(LG.early_gentle_factor(9), 0.0, "deep floors are never gentled")

	# Aim assist: unit direction to the NEAREST target; empty / on-top-of-you → ZERO (no assist, no NaN).
	var from := Vector2.ZERO
	var pts := PackedVector2Array([Vector2(300, 0), Vector2(50, 0), Vector2(0, -400)])
	check(PL._pick_nearest_dir(from, pts).is_equal_approx(Vector2(1, 0)), "assist aims the nearest target (dist 50, to the right)")
	check(PL._pick_nearest_dir(from, PackedVector2Array()).is_zero_approx(), "no enemies → no assist")
	check(PL._pick_nearest_dir(from, PackedVector2Array([from])).is_zero_approx(), "a target on top of you → ZERO (no NaN)")
