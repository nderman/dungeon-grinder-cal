# TestRunner.gd
# Runs the whole regression suite in ONE headless process (so autoloads load once). Each test in
# TESTS is instantiated as a child, its run() awaited, and its fail-count tallied. Prints a per-test
# line + a summary, then quits with exit code 1 if anything failed (so run_tests.sh / CI can gate).
# Add a test: write tests/test_foo.gd (extends TestCase), then preload it into TESTS below.
extends Node

const TESTS := [
	preload("res://tests/test_loot_boxes.gd"),
	preload("res://tests/test_loot_affixes.gd"),
	preload("res://tests/test_combat_effects.gd"),
	preload("res://tests/test_elemental.gd"),
	preload("res://tests/test_floor_themes.gd"),
	preload("res://tests/test_boss_seal.gd"),
	preload("res://tests/test_crash_teardown.gd"),
	preload("res://tests/test_holy_shield.gd"),
	preload("res://tests/test_endgame.gd"),
	preload("res://tests/test_hexgun.gd"),
	preload("res://tests/test_showrunner.gd"),
	preload("res://tests/test_achievements.gd"),
	preload("res://tests/test_telemetry.gd"),
	preload("res://tests/test_combat.gd"),
	preload("res://tests/test_boss_phase.gd"),
]

func _ready() -> void:
	PostHog.test_mode = true   # the suite records telemetry locally but NEVER hits the network
	print("\n=== Dungeon Grinder Cal — regression suite ===")
	var total_fails := 0
	var failed_files := 0
	for T in TESTS:
		var t: TestCase = T.new()
		add_child(t)
		await t.run()
		if t.fails == 0:
			print("  ✓ %s" % t.test_name)
		else:
			print("  ✗ %s (%d failed)" % [t.test_name, t.fails])
			failed_files += 1
		total_fails += t.fails
		t.queue_free()
	print("=== %d test files, %d assertion failure(s) ===\n" % [TESTS.size(), total_fails])
	if total_fails == 0:
		print("SUITE: PASS")
	else:
		print("SUITE: FAIL — %d file(s) with failures" % failed_files)
	get_tree().quit(1 if total_fails > 0 else 0)
