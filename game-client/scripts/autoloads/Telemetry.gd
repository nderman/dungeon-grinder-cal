# Telemetry.gd (Autoload)
# The audience-research department. Rides `SignalBus` + `GameManager` and quietly forwards the show's
# beats to PostHog — gameplay code never knows it's being watched (analytics as a pure listener, same
# pattern as AchievementManager/FeedbackManager). Fire-and-forget: the PostHog SDK batches, swallows
# network errors, and NO-OPS without an API key — so dev, CI, and random clones transmit nothing.
# Anonymous distinct_id only; primitive props only (never a Vector2 or a node ref). Opt out via
# MetaManager.analytics_enabled. Register AFTER PostHog + GameManager in project.godot.
extends Node

func _ready() -> void:
	_apply_opt_out()
	PostHog.register({"game": "dungeon-grinder-cal"})   # stamped onto every event by the SDK
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	GameManager.floor_changed.connect(_on_floor_changed)
	SignalBus.ratings_spike.connect(_on_spike)
	SignalBus.leveled_up.connect(_on_leveled_up)
	SignalBus.item_acquired.connect(_on_item)
	SignalBus.box_opened.connect(_on_box)
	SignalBus.achievement_unlocked.connect(_on_achievement)
	SignalBus.stat_injected.connect(_on_stat)
	MetaManager.meta_changed.connect(func(): _apply_opt_out())   # honour an in-game opt-out toggle

# Mirror the player's privacy choice onto the SDK (it persists opt-out for the session).
func _apply_opt_out() -> void:
	if MetaManager.analytics_enabled:
		PostHog.opt_in()
	else:
		PostHog.opt_out()

# ACTIVE play time (GameManager sums it per-frame only while a run is live), NOT wall-clock — so an
# idle/backgrounded browser tab can't inflate it into a bogus multi-hour "run".
func _elapsed_s() -> float:
	return snappedf(GameManager.run_active_seconds, 0.1)

func _on_run_started() -> void:
	PostHog.reload_feature_flags()   # pull the boss-hp-tuning variant once per run, cached on the SDK
	GameManager.boss_hp_mult = boss_hp_mult()   # PUSH the experiment value into gameplay (one-way: analytics -> game)
	PostHog.capture("run_started", {
		"class": GameManager.current_class,
		"race": GameManager.current_race,
		"meta_level": GameManager.level,
		"syndication_points": MetaManager.syndication_points,
		"nightmare": GameManager.nightmare,
	})

func _on_floor_changed(floor: int) -> void:
	PostHog.capture("floor_changed", {"floor": floor, "run_elapsed_s": _elapsed_s()})

func _on_spike(type: String) -> void:
	if type == "FATALITY":   # a boss (or the Champion) just died
		PostHog.capture("boss_killed", {"floor": GameManager.current_floor})

func _on_run_ended(outcome: String) -> void:
	var props := {
		"outcome": outcome,   # "died" | "won"
		"floor_reached": GameManager.current_floor,
		"rating": GameManager.run_ratings,
		"gold": GameManager.gold,
		"level": GameManager.level,
		"run_time_s": _elapsed_s(),       # ACTIVE seconds (not wall-clock)
		"kills": GameManager.run_kills,
		"abandoned": GameManager.run_kills == 0,   # "opened the tab and wandered off" — no kills = not a real attempt; filter these out
	}
	PostHog.capture("run_completed", props)
	if outcome == "died":
		PostHog.capture("player_died", props)

func _on_leveled_up(level: int, skill_points: int) -> void:
	PostHog.capture("leveled_up", {"level": level, "skill_points": skill_points})

func _on_item(item) -> void:   # item_acquired is Variant-typed at the source — coerce to a primitive
	PostHog.capture("item_acquired", {"item": str(item), "floor": GameManager.current_floor})

func _on_box(label: String) -> void:
	PostHog.capture("box_opened", {"box": label, "floor": GameManager.current_floor})

func _on_achievement(title: String) -> void:
	PostHog.capture("achievement_unlocked", {"title": title, "floor": GameManager.current_floor, "run_time_s": _elapsed_s()})

func _on_stat(stat: String, value: int) -> void:
	if stat in LootData.STAT_KEYS:   # skip the "ITEM"/gear-refresh churn — only real stat spends
		PostHog.capture("stat_injected", {"stat_name": stat, "new_value": value})

# The remote balance experiment: feature flag `boss-hp-tuning` (control | test), read once per run
# and cached on the SDK. The `test` cohort fights bosses with +15% HP. LevelGenerator reads the
# pushed GameManager.boss_hp_mult when spawning -> compare boss_killed rate per variant in Experiments.
func boss_hp_mult() -> float:
	return 1.15 if PostHog.get_feature_flag("boss-hp-tuning", "control") == "test" else 1.0
