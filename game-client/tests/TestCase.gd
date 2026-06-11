# TestCase.gd
# Base class for the regression suite. A test extends this, sets `test_name`, and overrides `run()`
# with its assertions (run() MAY await frames/timers — it's a coroutine). The TestRunner instantiates
# each test as a child (so get_tree()/autoloads work), awaits run(), and tallies `fails`.
# Tests must be SCENE-driven (the runner is a real scene) — `godot -s` SceneTree scripts don't load
# autoloads, so anything touching GameManager/SignalBus won't even compile that way.
class_name TestCase
extends Node

var fails := 0
var test_name := "test"

# Override with the test body. Use check()/eq()/approx(). May `await get_tree().physics_frame` etc.
func run() -> void:
	pass

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("    ✗ [%s] %s" % [test_name, msg])

func eq(a, b, msg: String) -> void:
	check(a == b, "%s — got %s, want %s" % [msg, a, b])

func approx(a: float, b: float, msg: String) -> void:
	check(is_equal_approx(a, b), "%s — got %s, want %s" % [msg, a, b])

# Truthy for any type: a non-null Object, a true bool, a non-zero number, a non-empty string.
# (GDScript forbids cross-type comparisons and bool(Object), so branch on the type.)
func truthy(v, msg: String) -> void:
	var ok := false
	match typeof(v):
		TYPE_NIL: ok = false
		TYPE_BOOL: ok = v
		TYPE_INT, TYPE_FLOAT: ok = v != 0
		TYPE_STRING, TYPE_STRING_NAME: ok = v != ""
		TYPE_OBJECT: ok = v != null
		_: ok = true
	check(ok, msg)
