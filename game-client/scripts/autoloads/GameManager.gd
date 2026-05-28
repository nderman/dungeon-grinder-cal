# GameManager.gd (Autoload)
# Conductor of the current "Episode" (run): floor depth, Ratings, Hype, and the
# "Cancellation" hand-off back to the Green Room.
# Register in Project Settings > Autoload as "GameManager".
extends Node

const GREEN_ROOM_PATH := "res://ui/GreenRoom.tscn"

# Ratings Spike reward table — {hype_pct, ratings} per achievement type.
const SPIKE_TABLE := {
	"SPEED_DEMON": {"hype": 10.0, "ratings": 50},
	"NEAR_DEATH":  {"hype": 25.0, "ratings": 150},
	"UNTOUCHABLE": {"hype": 5.0,  "ratings": 25},
	"DRAMA_SPIKE": {"hype": 15.0, "ratings": 100},
	"FATALITY":    {"hype": 20.0, "ratings": 200},
}

# --- RUN STATE ---
var current_floor: int = 1
var run_ratings: int = 0
var hype_meter: float = 0.0          # 0–100; overflow past 100 triggers a Sponsor Pod
var is_run_active: bool = false
var earned_loot_boxes: Array = []     # {tier, source} flagged by the achievement system

# --- ACTIVE CONTRACT ---
var current_race: String = "Human"
var current_class: String = "Brawler"
var current_run_stats: Dictionary = {}

signal rating_changed(new_value: int)
signal hype_changed(new_value: float)
signal floor_changed(floor: int)

func _ready() -> void:
	SignalBus.ratings_spike.connect(_on_ratings_spike)

func start_new_run() -> void:
	current_floor = 1
	run_ratings = 0
	hype_meter = 0.0
	earned_loot_boxes.clear()
	is_run_active = true
	MetaManager.reset_run_cache()
	current_run_stats = MetaManager.get_current_contestant_stats(current_race, current_class)

func advance_floor() -> void:
	current_floor += 1
	floor_changed.emit(current_floor)

# Cal's Note: every entertaining act pays out in Ratings + Hype.
func _on_ratings_spike(type: String) -> void:
	if not SPIKE_TABLE.has(type):
		return  # Non-payout spikes (e.g. TELEGRAPH_START, CANCELLED) are handled elsewhere.
	var payout: Dictionary = SPIKE_TABLE[type]
	run_ratings += int(payout["ratings"])
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
