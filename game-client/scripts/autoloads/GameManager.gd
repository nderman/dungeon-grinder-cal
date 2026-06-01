# GameManager.gd (Autoload)
# Conductor of the current "Episode" (run): floor depth, Ratings, Hype, and the
# "Cancellation" hand-off back to the Green Room.
# Register in Project Settings > Autoload as "GameManager".
extends Node

const GREEN_ROOM_PATH := "res://ui/GreenRoom.tscn"
const FLOOR_PATH := "res://Floor.tscn"

# Floor progression (DCC): the **stairs open** at STAIRS_OPEN_TIME elapsed OR the instant the
# Floor Boss dies — whichever comes first. So you can rush the boss for its XP/loot and leave
# early, or skip it and take the timer-opened stairs (forfeiting the boss rewards). Either way a
# **collapse** deadline at COLLAPSE_TIME ends the floor (lethal DoT if you're still on it).
const STAIRS_OPEN_TIME := 120.0        # stairs auto-open at this elapsed time (skip-boss path)
const COLLAPSE_TIME := 300.0           # floor collapses (lethal) at this elapsed time
const COLLAPSE_DMG := 20.0             # HP per tick once collapsing (= 1 old heart)
const COLLAPSE_INTERVAL := 0.5         # seconds between collapse ticks
const FLOOR_DMG_PER_DEPTH := 0.2       # enemy hearts/damage scale: ×(1 + 0.2·(floor−1))

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
const CHA_RATINGS_PER := 0.05      # +5% Ratings per CHA point (DCC scale: CHA 4 → +20%, as before)

func _cha_mult() -> float:
	return 1.0 + (int(current_run_stats.get("CHA", 0)) + int(_item_bonuses.get("CHA", 0))) * CHA_RATINGS_PER

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

# --- FLOOR CLOCK ---
var floor_elapsed: float = 0.0       # seconds on the current floor
var stairs_open: bool = false        # can the player descend yet?
var _collapse_accum: float = 0.0     # collapse-DoT tick accumulator

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

# --- ITEMS (full-body equip slots + a bag + consumable quick bar) ---
# Gear is rolled into INSTANCES (LootData). One item per body slot is equipped; the rest sit in
# the bag for manual swapping. _item_bonuses is the summed stat bonus from everything equipped.
var equipped: Dictionary = {}        # slot:String -> gear instance
var bag: Array = []                  # unequipped gear instances
var _item_bonuses: Dictionary = {}   # stat -> summed bonus from equipped gear
var quickbar: Array = []             # [{kind,base,tier}] consumables, used from the quick bar

signal rating_changed(new_value: int)
signal hype_changed(new_value: float)
signal floor_changed(floor: int)
signal items_changed()
signal loot_boxes_changed(count: int)   # pending boxes waiting to open at a Safe Room
signal floor_clock(elapsed: float, stairs_open: bool)   # HUD countdown
signal stairs_opened()                  # stairs are now usable (timer or boss kill)

# Enemy stat multiplier for the current depth (deeper floors hit harder / have more HP).
func floor_mult() -> float:
	return 1.0 + FLOOR_DMG_PER_DEPTH * float(current_floor - 1)

# Reset the floor clock — called on every floor load (first floor + each descent).
func begin_floor() -> void:
	floor_elapsed = 0.0
	stairs_open = false
	_collapse_accum = 0.0
	floor_clock.emit(floor_elapsed, stairs_open)

# Drives the stairs-open + collapse clock. Only ticks during an active run on a floor.
func _process(delta: float) -> void:
	if not is_run_active:
		return
	floor_elapsed += delta
	if not stairs_open and floor_elapsed >= STAIRS_OPEN_TIME:
		open_stairs()   # timer path (skip-boss)
	if floor_elapsed >= COLLAPSE_TIME:
		_tick_collapse(delta)
	floor_clock.emit(floor_elapsed, stairs_open)

func open_stairs() -> void:
	if stairs_open:
		return
	stairs_open = true
	stairs_opened.emit()
	SignalBus.toast.emit("THE STAIRS ARE OPEN", Vector2.ZERO)

# Floor's collapsing and you're still here — lethal DoT until you descend or die.
func _tick_collapse(delta: float) -> void:
	_collapse_accum += delta
	if _collapse_accum < COLLAPSE_INTERVAL:
		return
	_collapse_accum = 0.0
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var hc := p.get_node_or_null("HealthComponent")
	if hc:
		hc.take_damage(COLLAPSE_DMG)

# Descend to the next floor — keeps run state (XP/level/items), regenerates a deeper floor.
func descend() -> void:
	if not stairs_open:
		return
	begin_floor()   # reset the clock NOW so collapse can't tick on the descending player, and
	                # stairs_open=false guards against a second descend() this frame
	current_floor += 1
	floor_changed.emit(current_floor)
	get_tree().change_scene_to_file(FLOOR_PATH)

# Queue a loot box (from an achievement) and ping the HUD so the player knows it's waiting.
func add_loot_box(tier: int) -> void:
	earned_loot_boxes.append(tier)
	loot_boxes_changed.emit(earned_loot_boxes.size())

# Effective stats = base run-stats (race/class + skill points) + equipped gear bonuses.
func get_effective_stats() -> Dictionary:
	var eff: Dictionary = current_run_stats.duplicate()
	for s in _item_bonuses:
		eff[s] = int(eff.get(s, 0)) + int(_item_bonuses[s])
	return eff

# Looted gear: auto-equip if its slot is empty (friendly first pickup), else to the bag to swap.
func add_loot_instance(inst: Dictionary) -> void:
	var slot := String(inst.get("slot", ""))
	if slot != "" and not equipped.has(slot):
		equipped[slot] = inst
		_recompute_bonuses()
	else:
		bag.append(inst)
		items_changed.emit()

# Equip a bag instance into its slot; the displaced item (if any) goes back to the bag.
func equip(inst: Dictionary) -> void:
	var slot := String(inst.get("slot", ""))
	if slot == "":
		return
	bag.erase(inst)
	if equipped.has(slot):
		bag.append(equipped[slot])
	equipped[slot] = inst
	_recompute_bonuses()

func unequip(slot: String) -> void:
	if equipped.has(slot):
		bag.append(equipped[slot])
		equipped.erase(slot)
		_recompute_bonuses()

func drop(inst: Dictionary) -> void:
	bag.erase(inst)
	items_changed.emit()

# Recompute the summed equipped-gear bonus and tell the Player to re-derive vitals.
func _recompute_bonuses() -> void:
	_item_bonuses.clear()
	for slot in equipped:
		for s in LootData.instance_bonus(equipped[slot]):
			_item_bonuses[s] = int(_item_bonuses.get(s, 0)) + int(LootData.instance_bonus(equipped[slot])[s])
	SignalBus.stat_injected.emit("ITEM", 0)   # Player re-derives effective vitals
	items_changed.emit()

func add_consumable(base: String, tier: int) -> void:
	quickbar.append({"kind": "consumable", "base": base, "tier": tier})
	items_changed.emit()

# Use the oldest consumable in the quick bar on the player.
func use_consumable() -> void:
	if quickbar.is_empty():
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var c: Dictionary = quickbar.pop_front()
	p.apply_consumable(String(c["base"]), int(c["tier"]))
	items_changed.emit()

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
	equipped.clear()
	bag.clear()
	_item_bonuses.clear()
	quickbar.clear()
	is_run_active = true
	MetaManager.reset_run_cache()
	current_run_stats = MetaManager.get_current_contestant_stats(current_race, current_class)
	# Weapon-gated start: begin with a basic melee weapon only — no ranged, no spells. Find/equip
	# ranged weapons (and learn spells) as you progress.
	equipped["Weapon"] = {"kind": "gear", "base": "rusty_shiv", "slot": "Weapon", "rarity": 0, "affixes": []}
	_recompute_bonuses()
	SignalBus.run_started.emit()   # resets per-run achievement dedup
	SignalBus.xp_changed.emit(xp, xp_to_next(level), level)


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
	await get_tree().create_timer(1.2).timeout   # brief "Cancelled" beat, then cut to Green Room
	get_tree().change_scene_to_file(GREEN_ROOM_PATH)
