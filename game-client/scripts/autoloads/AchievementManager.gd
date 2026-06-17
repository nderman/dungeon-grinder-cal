# AchievementManager.gd (Autoload)
# The "System AI": watches SignalBus, unlocks achievements, and grants Loot Boxes.
# Boxes queue on GameManager.earned_loot_boxes and open only in a Safe Room (DCC rule),
# all at once, low tier -> high, via open_all_boxes().
# Register AFTER SignalBus / MetaManager / GameManager / LootData / AchievementData.
extends Node

var _run_unlocked: Array[String] = []   # "run"-scope achievements already granted this Episode
const REPEAT_COOLDOWN := 12.0           # min seconds between firings of the SAME repeatable feat (anti-spam)
var _repeat_cd: Dictionary = {}         # repeatable id → wall-clock time it may fire again

func _ready() -> void:
	SignalBus.enemy_cancelled.connect(_on_enemy_cancelled)
	SignalBus.ratings_spike.connect(_on_spike)
	SignalBus.phasedoor_discovered.connect(_on_phasedoor)
	SignalBus.mana_depleted.connect(func(): unlock("tapped_out"))   # cast on an empty tank
	SignalBus.stat_injected.connect(_on_stat_injected)              # stat milestones (→ 20)
	SignalBus.run_started.connect(func(): _run_unlocked.clear())

func _on_enemy_cancelled(_loc: Vector2, _ratings: int) -> void:
	unlock("first_blood")

func _on_phasedoor(_loc: Vector2) -> void:
	unlock("phase_finder")

func _on_spike(type: String) -> void:
	match type:
		"SPEED_DEMON": unlock("speed_demon")
		"NEAR_DEATH": unlock("near_death")
		"UNTOUCHABLE": unlock("untouchable")
		"FATALITY": unlock("boss_slayer")
		"CROWD_PLEASER": unlock("crowd_pleaser")
		"IGNITE": unlock("pyromaniac")          # set an enemy on fire (Burn affix)
		"BOOM": unlock("michael_bay")           # a Bomb blast killed an enemy
		"CHAIN_KILL": unlock("chain_react")     # a Chain arc killed the second enemy
		"GRAVE_ROBBER": unlock("grave_robber")  # walked over a corpse to loot it
		"DOUSED": unlock("stop_drop_roll")      # a fire DoT on the player expired while still alive
		"CANCELLED": unlock("cancelled")        # the player died (end_run already emits this)

# Stat milestones: pumping a stat to 20 is a re-earnable per-run feat. The STR title adapts to your
# Race — the System loves a "strongest [thing] that ever lived" gag (hi, Princess Donut).
func _on_stat_injected(stat: String, value: int) -> void:
	if stat not in LootData.STAT_KEYS or value < 20:
		return   # "ITEM"/gear refreshes and sub-20 spends don't count
	if stat == "STR":
		unlock("stat_max_str", "Strongest %s That Ever Lived" % GameManager.current_race)
	else:
		unlock("stat_max_" + stat.to_lower())

# Award an achievement + its Loot Box. Dedup depends on scope:
#   run        → once per run (reset on run_started)
#   lifetime   → once ever (persisted to disk)
#   repeatable → always fires, but the BOX is floor-gated (see below)
# `title_override` lets a dynamic feat name itself at unlock time (e.g. the race-adaptive STR title);
# empty = use the definition's static title.
func unlock(id: String, title_override: String = "") -> void:
	if not AchievementData.ACHIEVEMENTS.has(id):
		return
	var a: Dictionary = AchievementData.ACHIEVEMENTS[id]
	var title: String = title_override if title_override != "" else String(a["title"])
	match a.get("scope", "repeatable"):
		"lifetime":
			if id in MetaManager.unlocked_achievements:
				return
			MetaManager.unlocked_achievements.append(id)
			MetaManager.save_persistence()
		"run":
			if id in _run_unlocked:
				return
			_run_unlocked.append(id)
		_:
			# Per-feat COOLDOWN: a spammy repeatable (Chain Reaction, Speed Demon) fires constantly
			# while you clear a room — box OR heckle — and turns into ticker noise. Throttle each one
			# so it stays a treat, not a stream (run/lifetime milestones exempt). Most share the 12s
			# default; a feat whose trigger trips on every kill (AoE/bomb "BOOM") sets its own longer
			# `cooldown` so it can't flood loot.
			var cd := float(a.get("cooldown", REPEAT_COOLDOWN))
			var now := Time.get_ticks_msec() / 1000.0
			if now < float(_repeat_cd.get(id, 0.0)):
				return   # still cooling down — skip silently
			_repeat_cd[id] = now + cd
			# Repeatable performance feats are the loot drip. The System spoils rookies (DCC canon:
			# floors 1-3 spam low-tier boxes to get them experimenting), then raises its standards —
			# a small feat that paid a box up top earns only a heckle once you're deep. Real
			# milestones (run/lifetime) are exempt: a first is always a first, at any depth.
			if int(a["tier"]) < _min_rewarded_tier():
				SignalBus.achievement_unlocked.emit("%s — %s" % [title, _heckle()])
				return
	var box_type := String(a.get("box_type", "gear"))
	GameManager.add_loot_box(int(a["tier"]), box_type)
	# Name the box tier + type so the ticker tells you what you actually won (e.g. "Gold Weapon Box").
	SignalBus.achievement_unlocked.emit("%s — %s %s Box" % [title, LootData.tier_name(int(a["tier"])), LootData.box_type_name(box_type)])

# The System's boredom threshold: the lowest box tier it still bothers awarding for a *repeat*
# feat at the current depth. Floors 1-3 reward everything (tutorial drip); it demands bigger feats
# the deeper you go, so the early-game loot fountain tapers into "impress me" without ever drying up
# (boss kills are tier 2 and always pay).
func _min_rewarded_tier() -> int:
	var f: int = GameManager.current_floor
	if f <= 3:
		return 0
	elif f <= 6:
		return 1
	return 2

const HECKLES: Array[String] = [
	"seen it.", "the audience yawns.", "cute, no box.",
	"do better.", "old news.", "unimpressed.", "try harder, meatbag.",
]

func _heckle() -> String:
	return HECKLES.pick_random()

# Safe-Room only: open every pending box at once, low tier -> high (DCC).
func open_all_boxes(stats: Dictionary) -> void:
	if GameManager.earned_loot_boxes.is_empty():
		SignalBus.toast.emit("No boxes to open.", _player_pos())
		return
	var boxes: Array = GameManager.earned_loot_boxes.duplicate()
	GameManager.earned_loot_boxes.clear()
	GameManager.loot_boxes_changed.emit(0)   # pending counter back to zero
	boxes.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]))   # open low tier → high
	for box in boxes:
		var tier := int(box["tier"])
		var btype := String(box.get("type", "gear"))
		SignalBus.box_opened.emit("%s %s" % [LootData.tier_name(tier), LootData.box_type_name(btype)])
		var inst := LootData.roll(tier, stats, btype)
		if inst.is_empty():
			continue
		# Consumables stock the quick bar; gear becomes an instance (auto-equip empty slot, else bag).
		if inst["kind"] == "consumable":
			GameManager.add_consumable(String(inst["base"]), tier)
			SignalBus.item_acquired.emit(LootData.item_name(inst["base"]))
		else:
			GameManager.add_loot_instance(inst)
			SignalBus.item_acquired.emit("%s %s" % [LootData.rarity_name(int(inst["rarity"])), LootData.instance_name(inst)])

func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p.global_position if p else Vector2.ZERO
