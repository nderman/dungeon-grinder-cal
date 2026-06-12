extends TestCase
# Telemetry rides SignalBus → PostHog: events fire with primitive props, the run_ended fan-out works,
# the feature-flag accessor reads the variant, and NOTHING hits the network (the runner forces
# PostHog.test_mode; events are recorded locally for these assertions).
func _init() -> void: test_name = "telemetry"

func run() -> void:
	check(PostHog.test_mode, "the suite runs in PostHog test_mode (no network)")
	PostHog.clear_captured()

	SignalBus.run_started.emit()
	check(PostHog.was_captured("run_started"), "run_started signal → run_started event")

	GameManager.floor_changed.emit(3)
	check(PostHog.was_captured("floor_changed"), "floor_changed signal → floor_changed event")

	# run_ended('died') fans out to BOTH run_completed and player_died.
	SignalBus.run_ended.emit("died")
	check(PostHog.was_captured("run_completed"), "run_ended → run_completed")
	check(PostHog.was_captured("player_died"), "run_ended('died') → player_died")

	# Every property must be a primitive — no Vector2 / node refs leak into analytics.
	var ev := PostHog.last_captured("run_completed")
	for k in ev.get("properties", {}):
		check(typeof(ev["properties"][k]) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT, TYPE_FLOAT, TYPE_BOOL],
			"property '%s' is a primitive" % k)

	# "ITEM"/gear-refresh stat churn is filtered; real stat spends are captured.
	PostHog.clear_captured()
	SignalBus.stat_injected.emit("ITEM", 0)
	check(not PostHog.was_captured("stat_injected"), "gear-refresh stat_injected is NOT captured")
	SignalBus.stat_injected.emit("STR", 12)
	check(PostHog.was_captured("stat_injected"), "a real stat spend IS captured")

	# The boss-hp feature flag: defaults to control offline, applies the variant when set, and is
	# PUSHED into gameplay (GameManager.boss_hp_mult) on run_started — gameplay never reads analytics.
	PostHog.set_feature_flags_for_test({})
	approx(Telemetry.boss_hp_mult(), 1.0, "boss-hp flag defaults to control (×1.0)")
	PostHog.set_feature_flags_for_test({"boss-hp-tuning": "+15pct"})
	approx(Telemetry.boss_hp_mult(), 1.15, "boss-hp '+15pct' variant scales HP")
	SignalBus.run_started.emit()
	approx(GameManager.boss_hp_mult, 1.15, "run_started PUSHES the experiment value into GameManager")

	PostHog.set_feature_flags_for_test({})   # reset shared SDK state
	GameManager.boss_hp_mult = 1.0
	PostHog.clear_captured()
