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
const FLOOR_DMG_PER_DEPTH := 0.25      # enemy hearts/damage scale: ×(1 + 0.25·(floor−1)). Moderate —
                                       # deep-floor difficulty comes mainly from ELITES, not stat inflation

# Ratings Spike reward table — {hype_pct, ratings} per achievement type.
const SPIKE_TABLE := {
	"SPEED_DEMON":   {"hype": 10.0, "ratings": 50},
	"NEAR_DEATH":    {"hype": 25.0, "ratings": 150},
	"UNTOUCHABLE":   {"hype": 5.0,  "ratings": 25},
	"DRAMA_SPIKE":   {"hype": 15.0, "ratings": 100},
	"FATALITY":      {"hype": 20.0, "ratings": 200},
	"CROWD_PLEASER": {"hype": 8.0,  "ratings": 75},   # multi-kill: 2+ cancelled in one blow (gore-pop)
}

# Kill-feat tuning. Two independent detectors run on the same kill stream:
#   Speed Demon — sequential tempo (kills in quick succession)
#   Multi-Kill  — one blow wiping a group (kills in a single-swing window)
const SPEED_DEMON_KILLS := 3       # kills within the window → Speed Demon
const SPEED_DEMON_WINDOW := 2.0    # seconds
const MULTIKILL_KILLS := 2         # kills inside one blow → Crowd Pleaser (multi-kill flex)
const MULTIKILL_WINDOW := 0.3      # seconds — tight enough to mean "the same attack"

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
var gold: int = 0                                         # run currency from corpses; spent at shops (future)
var _kill_times: Array[float] = []                        # recent kill timestamps (speed-demon detector)
var _blow_times: Array[float] = []                        # tight-window kill timestamps (multi-kill detector)

# --- FLOOR CLOCK ---
var floor_elapsed: float = 0.0       # seconds on the current floor
var stairs_open: bool = false        # can the player descend yet?
var _collapse_accum: float = 0.0     # collapse-DoT tick accumulator

# --- PROGRESSION (XP / LEVELS / SKILL POINTS) — the character-growth rail ---
# Per DCC: kills grant XP; every level hands you 3 stat points to spend, and you may only
# spend them in a Safe Room. Levels reset per run (roguelite); you re-grow each Season.
const XP_PER_LEVEL_BASE := 80          # XP for L1→L2
const XP_GROWTH := 1.4                 # geometric: each level costs 1.4× the last (grindier deep)
const SKILL_POINTS_PER_LEVEL := 3      # DCC canon
var xp: int = 0
var level: int = 1
var skill_points: int = 0              # unspent — banked until you reach a Safe-Room terminal

func xp_to_next(lvl: int) -> int:
	# Geometric ramp: L1→80, L2→112, L3→157, L5→307, L10→1653 … each level a real grind step deeper.
	return int(round(XP_PER_LEVEL_BASE * pow(XP_GROWTH, maxi(0, lvl - 1))))

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

# Learnable active abilities (AbilityLibrary). Hybrid model: the class starter is re-granted every
# run (permanent identity); tomes found mid-crawl are learned per-run. Abilities level by USE.
var known_abilities: Array[String] = []   # AbilityLibrary ids the contestant can cast this run
var selected_ability: String = ""         # the one the cast key (Q) fires
var ability_uses: Dictionary = {}          # id -> times cast this run (drives level-on-use)

signal rating_changed(new_value: int)
signal abilities_changed()              # known set / selection / level changed (HUD + panel)
signal hype_changed(new_value: float)
signal floor_changed(floor: int)
signal items_changed()
signal loot_boxes_changed(count: int)   # pending boxes waiting to open at a Safe Room
signal floor_clock(elapsed: float, stairs_open: bool)   # HUD countdown
signal stairs_opened()                  # stairs are now usable (timer or boss kill)
signal gold_changed(total: int)         # corpse loot picked up

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

# Corpse loot: common-tier currency picked up off the floor. Spent at shops (future arc).
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

# Effective stats = base run-stats (race/class + skill points) + equipped gear bonuses.
func get_effective_stats() -> Dictionary:
	var eff: Dictionary = current_run_stats.duplicate()
	for s in _item_bonuses:
		eff[s] = int(eff.get(s, 0)) + int(_item_bonuses[s])
	return eff

# Equip-slot keys that accept this item's type, in paper-doll order (e.g. a "Ring" fits both
# "Ring" and "Ring 2"). Empty if the item has no slot or no slot accepts it.
func slots_for_item(inst: Dictionary) -> Array:
	var t := String(inst.get("slot", ""))
	if t == "":
		return []
	var out: Array = []
	for key in LootData.SLOTS:
		if LootData.slot_accepts(key) == t:
			out.append(key)
	return out

# Looted gear: auto-equip into the first OPEN slot of its type (friendly first pickup), else bag.
func add_loot_instance(inst: Dictionary) -> void:
	for key in slots_for_item(inst):
		if not equipped.has(key):
			equipped[key] = inst
			_recompute_bonuses()
			return
	bag.append(inst)
	items_changed.emit()

# The equip-slot an item would occupy: an `into` override if valid, else the first EMPTY matching
# slot, else the first matching slot (a swap). "" if nothing accepts it. Single source of truth so
# the inventory's compare preview always names the slot equip() will actually use.
func resolve_equip_slot(inst: Dictionary, into: String = "") -> String:
	var keys := slots_for_item(inst)
	if keys.is_empty():
		return ""
	if into in keys:
		return into
	for key in keys:
		if not equipped.has(key):
			return String(key)
	return String(keys[0])

# Equip a bag instance into its resolved slot; if that slot was full, its occupant goes to the bag.
func equip(inst: Dictionary, into: String = "") -> void:
	var target := resolve_equip_slot(inst, into)
	if target == "":
		return
	bag.erase(inst)
	if equipped.has(target):
		bag.append(equipped[target])
	equipped[target] = inst
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

# DCC potion sickness: after any potion there's a cool-down; higher CON shortens it. Drink a potion
# while it's still ticking and the player is Poisoned (the Player handles the debuff).
const POTION_CD_BASE := 12.0       # seconds at low CON
const POTION_CD_PER_CON := 0.4     # shaved per CON point
const POTION_CD_MIN := 2.5         # floor — a hardy crawler still can't chain-chug instantly
var _potion_ready_at: float = 0.0  # wall-clock (s) the next potion is safe

func potion_cooldown_seconds() -> float:
	var con := int(get_effective_stats().get("CON", 4))
	return maxf(POTION_CD_MIN, POTION_CD_BASE - con * POTION_CD_PER_CON)

# Seconds until a potion is safe again (0 = ready). Drives the HUD sickness indicator.
func potion_cooldown_remaining() -> float:
	return maxf(0.0, _potion_ready_at - Time.get_ticks_msec() / 1000.0)

# --- Abilities (learnable spells + skills) -----------------------------------------------------

# Learn an ability; the first one learned auto-becomes the active cast. No-op if unknown/duplicate.
func learn_ability(id: String) -> bool:
	if not AbilityLibrary.has_ability(id) or id in known_abilities:
		return false
	known_abilities.append(id)
	if selected_ability == "":
		selected_ability = id
	abilities_changed.emit()
	return true

# Bind the cast key to a known ability.
func select_ability(id: String) -> void:
	if id in known_abilities and id != selected_ability:
		selected_ability = id
		abilities_changed.emit()

# Tally a cast; emit only when it crosses a level boundary (HUD/panel refresh).
func register_ability_use(id: String) -> void:
	var before := ability_level(id)
	ability_uses[id] = int(ability_uses.get(id, 0)) + 1
	if ability_level(id) > before:
		abilities_changed.emit()

func ability_level(id: String) -> int:
	return AbilityLibrary.level_for_uses(int(ability_uses.get(id, 0)))

# --- Class (chosen on Floor 3, DCC) ------------------------------------------------------------

const CLASS_FLOOR := 3   # the floor the System makes you pick a class

# True while the crawler still owes the System a class pick (Floor 3+, none chosen).
func needs_class_selection() -> bool:
	return current_class == "" and current_floor >= CLASS_FLOOR

# Lock in a class mid-run: stack its stat bonuses onto the live stats (re-deriving vitals) and grant
# its starter ability. Permanent for the crawl. Only an UNLOCKED class can be chosen (roguelite
# meta-gate). No-op if already classed or the class isn't unlocked.
func choose_class(c: String) -> void:
	if current_class != "" or not ClassData.CLASSES.has(c) or c not in MetaManager.unlocked_classes:
		return
	current_class = c
	for s in ClassData.get_bonuses(c):
		current_run_stats[s] = int(current_run_stats.get(s, 0)) + int(ClassData.get_bonuses(c)[s])
		SignalBus.stat_injected.emit(s, int(current_run_stats[s]))   # Player re-derives HP/mana/etc.
	var starter := ClassData.get_starter_ability(c)
	learn_ability(starter)
	if starter != "":
		select_ability(starter)   # bind the class's signature ability to the cast key (its headline)
	SignalBus.toast.emit("CLASS UNLOCKED: %s" % c, Vector2.ZERO)

# Change race mid-run (Floor 3, DCC: most keep Human). Applies the DELTA between the old and new
# race bonuses so spent attribute points are preserved. Only an UNLOCKED race can be picked.
func choose_race(r: String) -> void:
	if r == current_race or not RaceData.RACES.has(r) or r not in MetaManager.unlocked_races:
		return
	var old_b := RaceData.get_bonuses(current_race)
	var new_b := RaceData.get_bonuses(r)
	var keys := {}   # union of both races' stat keys — robust if a race ever boosts a non-base stat
	for s in old_b: keys[s] = true
	for s in new_b: keys[s] = true
	for s in keys:
		var delta := int(new_b.get(s, 0)) - int(old_b.get(s, 0))
		if delta != 0:
			current_run_stats[s] = int(current_run_stats.get(s, 0)) + delta
			SignalBus.stat_injected.emit(s, int(current_run_stats[s]))
	current_race = r
	SignalBus.toast.emit("RACE: %s" % r, Vector2.ZERO)

# Use the oldest consumable in the quick bar on the player.
func use_consumable() -> void:
	if quickbar.is_empty():
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var c: Dictionary = quickbar.pop_front()
	var base := String(c["base"])
	var sick := false
	if LootData.is_potion(base):
		var now := Time.get_ticks_msec() / 1000.0
		sick = now < _potion_ready_at   # still on cool-down → this drink poisons you
		_potion_ready_at = now + potion_cooldown_seconds()
	p.apply_consumable(base, int(c["tier"]), sick)
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

# Turns kills into show-off feats the audience pays for. Two independent detectors on the same
# stream: Speed Demon (a fast sequential burst) and Multi-Kill/Crowd Pleaser (a group wiped in one
# blow). Each fires at most once per burst — Speed Demon clears its window, Multi-Kill fires only on
# the exact threshold kill — so neither spams every later kill. Both route through ratings_spike →
# AchievementManager grants the box (floor-gated).
func _track_kill() -> void:
	run_kills += 1
	var now := Time.get_ticks_msec() / 1000.0

	_blow_times.append(now)
	_blow_times = _blow_times.filter(func(t): return now - t <= MULTIKILL_WINDOW)
	# Fire once, on the kill that *reaches* the threshold — a bigger blow (3rd, 4th kill) pushes
	# size past it without re-firing, so one blow = one feat. The window self-clears once kills
	# stop landing inside it, re-arming the next discrete group.
	if _blow_times.size() == MULTIKILL_KILLS:
		SignalBus.ratings_spike.emit("CROWD_PLEASER")

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
	gold = 0
	_kill_times.clear()
	_blow_times.clear()
	earned_loot_boxes.clear()
	run_inventory.clear()
	equipped.clear()
	bag.clear()
	_item_bonuses.clear()
	quickbar.clear()
	_potion_ready_at = 0.0
	known_abilities.clear()
	selected_ability = ""
	ability_uses.clear()
	is_run_active = true
	MetaManager.reset_run_cache()
	# DCC: crawlers are CLASSLESS for the first two floors. Stats are race + base only; the class
	# (its stat bonuses + starter ability) is chosen on Floor 3 via choose_class().
	current_class = ""
	current_run_stats = MetaManager.get_current_contestant_stats(current_race, "")
	# Weapon-gated start: begin with a basic melee weapon only — no ranged, no spells. Find/equip
	# ranged weapons (and learn spells/skills) as you progress.
	equipped["Weapon"] = {"kind": "gear", "base": "rusty_shiv", "slot": "Weapon", "rarity": 0, "affixes": []}
	_recompute_bonuses()
	# One starter heal — enough to not be bone-dry early, without a potion glut (corpses + boxes add more).
	quickbar.append({"kind": "consumable", "base": "health_potion", "tier": 0})
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
