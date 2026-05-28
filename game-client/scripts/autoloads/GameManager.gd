# GameManager.gd (Autoload)
# Conductor of the current "Episode" (run): floor depth, Ratings, Hype, and the
# "Cancellation" hand-off back to the Green Room.
# Register in Project Settings > Autoload as "GameManager".
extends Node

const GREEN_ROOM_PATH := "res://ui/GreenRoom.tscn"

# Ratings Spike reward table — {hype_pct, ratings} per achievement type.
const SPIKE_TABLE := {
	"SPEED_DEMON":   {"hype": 10.0, "ratings": 50},
	"NEAR_DEATH":    {"hype": 25.0, "ratings": 150},
	"UNTOUCHABLE":   {"hype": 5.0,  "ratings": 25},
	"DRAMA_SPIKE":   {"hype": 15.0, "ratings": 100},
	"FATALITY":      {"hype": 20.0, "ratings": 200},
	"CROWD_PLEASER": {"hype": 8.0,  "ratings": 75},   # the steady meat-grinder kill drip
}

# Kill-feat tuning.
const SPEED_DEMON_KILLS := 3       # kills within the window → Speed Demon
const SPEED_DEMON_WINDOW := 2.0    # seconds
const KILLS_PER_BOX := 6           # every Nth kill drops a Crowd Pleaser box (grind reward)

# CHA → Ratings generation: the audience-appeal stat multiplies every Ratings payout.
const CHA_RATINGS_PER := 0.02      # +2% Ratings per CHA point (CHA 10 → +20%)

func _cha_mult() -> float:
	return 1.0 + int(current_run_stats.get("CHA", 0)) * CHA_RATINGS_PER

# --- RUN STATE ---
var current_floor: int = 1
var run_ratings: int = 0
var hype_meter: float = 0.0          # 0–100; overflow past 100 triggers a Sponsor Pod
var is_run_active: bool = false
var earned_loot_boxes: Array = []     # {tier, source} flagged by the achievement system
var last_safe_room_entrance_pos: Vector2 = Vector2.ZERO   # where a Phase-Door spat you in
var run_inventory: Array = []                             # items pulled from Loot Boxes this run
var run_kills: int = 0                                    # mobs cancelled this run
var _kill_times: Array[float] = []                        # recent kill timestamps (speed-demon detector)

# --- PROGRESSION (XP / LEVELS / SKILL POINTS) — the character-growth rail ---
# Per DCC: kills grant XP; every level hands you 3 stat points to spend, and you may only
# spend them in a Safe Room. Levels reset per run (roguelite); you re-grow each Season.
const XP_PER_LEVEL_BASE := 80          # XP for L1→L2; scales linearly with level
const SKILL_POINTS_PER_LEVEL := 3      # DCC canon
var xp: int = 0
var level: int = 1
var skill_points: int = 0              # unspent — banked until you reach a Safe-Room terminal

func xp_to_next(lvl: int) -> int:
	return XP_PER_LEVEL_BASE * maxi(1, lvl)   # L1→80, L2→160, L3→240 … (never 0 → no infinite loop)

# --- ACTIVE CONTRACT ---
var current_race: String = "Human"
var current_class: String = "Brawler"
var current_run_stats: Dictionary = {}

signal rating_changed(new_value: int)
signal hype_changed(new_value: float)
signal floor_changed(floor: int)

func _ready() -> void:
	SignalBus.ratings_spike.connect(_on_ratings_spike)
	SignalBus.enemy_cancelled.connect(_on_enemy_cancelled)
	SignalBus.xp_awarded.connect(add_xp)

# Every kill pays Ratings — the AUDIENCE rail (drives loot drops + fan/sponsor boxes).
# Character growth rides the separate XP rail (see add_xp); shops will use Gold.
func _on_enemy_cancelled(_loc: Vector2, ratings_earned: int) -> void:
	run_ratings += int(round(ratings_earned * _cha_mult()))   # CHA boosts the audience payout
	rating_changed.emit(run_ratings)
	_track_kill()

# Turns raw kills into the reward drip the "meat grinder" promises: a steady box every
# KILLS_PER_BOX kills, plus a Speed Demon spike for SPEED_DEMON_KILLS in quick succession.
# Both route through ratings_spike → AchievementManager grants the box.
func _track_kill() -> void:
	run_kills += 1
	if run_kills % KILLS_PER_BOX == 0:
		SignalBus.ratings_spike.emit("CROWD_PLEASER")
	var now := Time.get_ticks_msec() / 1000.0
	_kill_times.append(now)
	_kill_times = _kill_times.filter(func(t): return now - t <= SPEED_DEMON_WINDOW)
	if _kill_times.size() >= SPEED_DEMON_KILLS:
		_kill_times.clear()   # require a fresh burst, don't re-fire every subsequent kill
		SignalBus.ratings_spike.emit("SPEED_DEMON")

# Kills feed the XP rail. Banks 3 skill points per level gained (spendable in a Safe Room).
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		skill_points += SKILL_POINTS_PER_LEVEL
		SignalBus.leveled_up.emit(level, skill_points)
	SignalBus.xp_changed.emit(xp, xp_to_next(level), level)

# Spend one banked point on a core stat. Mutates the live run-stats dict (the Player shares
# this reference) and pings stat_injected so the Player re-derives hearts/mana/speed.
func spend_skill_point(stat: String) -> bool:
	if skill_points <= 0 or not current_run_stats.has(stat):
		return false
	skill_points -= 1
	current_run_stats[stat] = int(current_run_stats[stat]) + 1
	SignalBus.stat_injected.emit(stat, int(current_run_stats[stat]))
	SignalBus.xp_changed.emit(xp, xp_to_next(level), level)   # refresh the points pip
	return true

func start_new_run() -> void:
	current_floor = 1
	run_ratings = 0
	hype_meter = 0.0
	xp = 0
	level = 1
	skill_points = 0
	run_kills = 0
	_kill_times.clear()
	earned_loot_boxes.clear()
	run_inventory.clear()
	is_run_active = true
	MetaManager.reset_run_cache()
	current_run_stats = MetaManager.get_current_contestant_stats(current_race, current_class)
	SignalBus.run_started.emit()   # resets per-run achievement dedup
	SignalBus.xp_changed.emit(xp, xp_to_next(level), level)

func advance_floor() -> void:
	current_floor += 1
	floor_changed.emit(current_floor)

# Cal's Note: every entertaining act pays out in Ratings + Hype.
func _on_ratings_spike(type: String) -> void:
	if not SPIKE_TABLE.has(type):
		return  # Non-payout spikes (e.g. TELEGRAPH_START, CANCELLED) are handled elsewhere.
	var payout: Dictionary = SPIKE_TABLE[type]
	run_ratings += int(round(payout["ratings"] * _cha_mult()))   # CHA boosts the audience payout
	hype_meter += float(payout["hype"])
	rating_changed.emit(run_ratings)
	_check_hype_thresholds()

func _check_hype_thresholds() -> void:
	if hype_meter >= 100.0:
		hype_meter = fmod(hype_meter, 100.0)
		SignalBus.sponsor_pod_incoming.emit(Vector2.ZERO)   # LevelManager picks the Marker2D
	elif hype_meter >= 90.0:
		SignalBus.hype_threshold_reached.emit(2)
	elif hype_meter >= 75.0:
		SignalBus.hype_threshold_reached.emit(1)
	elif hype_meter >= 50.0:
		SignalBus.hype_threshold_reached.emit(0)
	hype_changed.emit(hype_meter)

# Called by the player's HealthComponent when hearts hit zero.
func end_run() -> void:
	is_run_active = false
	SignalBus.ratings_spike.emit("CANCELLED")

	# The Syndicate's cut: 10% of Ratings become permanent Syndication Points.
	MetaManager.syndication_points += int(floor(run_ratings * 0.1))

	# Milestone tokens: one per qualifying depth reached this run.
	if current_floor >= 9:
		MetaManager.add_milestone_token(3)
	elif current_floor >= 6:
		MetaManager.add_milestone_token(2)
	elif current_floor >= 3:
		MetaManager.add_milestone_token(1)

	MetaManager.save_persistence()
	await get_tree().create_timer(2.0).timeout   # let the "Cancelled" static play
	get_tree().change_scene_to_file(GREEN_ROOM_PATH)
