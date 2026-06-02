# CombatHUD.gd
# Reads game state purely from signals (SignalBus + GameManager) — never pokes at
# combat logic. Binds to the player's Health/Mana components once, on a deferred call,
# so it works no matter the _ready order.
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var ratings: Label = $Ratings
@onready var hype_bar: ProgressBar = $HypeBar
@onready var level_label: Label = $Level
@onready var xp_bar: ProgressBar = $XPBar
@onready var ticker: Label = $Ticker
@onready var weapon_label: Label = $Weapon
@onready var quickbar_label: Label = $QuickBar
@onready var boxes_label: Label = $Boxes
@onready var floor_label: Label = $Floor
@onready var clock_label: Label = $Clock
var _potion_cd: Label   # code-built potion-sickness cool-down indicator (above the quick bar)
var _ability_label: Label   # code-built "Q: <active ability>" readout
var _player: Node2D          # bound on spawn; polled for ability availability
var _gold_label: Label       # code-built corpse-gold readout (top-left, under Boxes)
const ABILITY_READY := Color(0.7, 0.85, 1.0)
const ABILITY_DIM := Color(0.45, 0.45, 0.52, 0.6)   # greyed when on cooldown / out of mana

const SPIKE_TEXT := {
	"SPEED_DEMON": "SPEED DEMON!", "NEAR_DEATH": "NEAR DEATH!",
	"UNTOUCHABLE": "UNTOUCHABLE!", "DRAMA_SPIKE": "DRAMA SPIKE!",
	"FATALITY": "FATALITY!", "CANCELLED": "CANCELLED",
	"CROWD_PLEASER": "MULTI-KILL!",
}

func _ready() -> void:
	SignalBus.mana_updated.connect(_on_mana)
	SignalBus.ratings_spike.connect(_on_spike)
	GameManager.rating_changed.connect(_on_rating)
	GameManager.hype_changed.connect(_on_hype)
	SignalBus.achievement_unlocked.connect(_on_achievement)
	SignalBus.item_acquired.connect(_on_item)
	SignalBus.xp_changed.connect(_on_xp)
	SignalBus.leveled_up.connect(_on_levelup)
	GameManager.items_changed.connect(_refresh_quickbar)
	GameManager.items_changed.connect(_refresh_weapon)
	GameManager.loot_boxes_changed.connect(_on_boxes)
	GameManager.floor_clock.connect(_on_clock)
	GameManager.floor_changed.connect(func(f): floor_label.text = "FLOOR %d" % f)
	floor_label.text = "FLOOR %d" % GameManager.current_floor
	_on_rating(GameManager.run_ratings)
	_on_hype(GameManager.hype_meter)
	_on_xp(GameManager.xp, GameManager.xp_to_next(GameManager.level), GameManager.level)
	_refresh_quickbar()
	_refresh_weapon()
	_on_boxes(GameManager.earned_loot_boxes.size())
	ticker.modulate.a = 0.0
	_build_potion_cd()
	_build_ability_label()
	_build_gold_label()
	GameManager.gold_changed.connect(_on_gold)
	_on_gold(GameManager.gold)
	GameManager.abilities_changed.connect(_refresh_ability)
	_refresh_ability()
	_bind_player.call_deferred()

# "Q: <ability> Lv N" readout, just above the potion-sickness indicator (bottom-left action stack).
func _build_ability_label() -> void:
	_ability_label = Label.new()
	_ability_label.anchor_top = 1.0
	_ability_label.anchor_bottom = 1.0
	_ability_label.offset_left = 16.0
	_ability_label.offset_top = -82.0
	_ability_label.offset_right = 600.0
	_ability_label.offset_bottom = -58.0
	_ability_label.add_theme_font_size_override("font_size", 14)
	_ability_label.modulate = Color(0.7, 0.85, 1.0)
	add_child(_ability_label)

func _build_gold_label() -> void:
	_gold_label = Label.new()
	_gold_label.offset_left = 16.0
	_gold_label.offset_top = 96.0
	_gold_label.offset_right = 200.0
	_gold_label.offset_bottom = 118.0
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.modulate = Color(1.0, 0.85, 0.25)
	add_child(_gold_label)

func _on_gold(total: int) -> void:
	_gold_label.text = "Gold: %d" % total

func _refresh_ability() -> void:
	var id := GameManager.selected_ability
	if id == "":
		_ability_label.text = "Q: (no ability)"
	else:
		_ability_label.text = "Q: %s  Lv %d" % [AbilityLibrary.ability_name(id), GameManager.ability_level(id)]

# A code-built sickness indicator sitting just above the quick bar. Shows the remaining potion
# cool-down (drink before it clears → Poisoned); hidden when a potion is safe to drink.
func _build_potion_cd() -> void:
	_potion_cd = Label.new()
	_potion_cd.anchor_top = 1.0
	_potion_cd.anchor_bottom = 1.0
	_potion_cd.offset_left = 16.0
	_potion_cd.offset_top = -58.0
	_potion_cd.offset_right = 600.0
	_potion_cd.offset_bottom = -34.0
	_potion_cd.add_theme_font_size_override("font_size", 14)
	_potion_cd.modulate = Color(1.0, 0.55, 0.3)
	_potion_cd.visible = false
	add_child(_potion_cd)

func _process(_delta: float) -> void:
	var rem := GameManager.potion_cooldown_remaining()
	if rem > 0.0:
		_potion_cd.visible = true
		_potion_cd.text = "⚠ Potion sickness  %.1fs" % rem
	elif _potion_cd.visible:
		_potion_cd.visible = false
	# Grey the ability readout when it can't be cast (on cooldown / out of mana).
	if GameManager.selected_ability != "" and _player != null and is_instance_valid(_player):
		_ability_label.modulate = ABILITY_READY if _player.selected_ability_ready() else ABILITY_DIM

# Show the equipped weapon's name + type (e.g. "Rusty Shiv (melee)").
func _refresh_weapon() -> void:
	var w: Dictionary = GameManager.equipped.get("Weapon", {})
	if w.is_empty():
		weapon_label.text = "Fists (melee)"
	else:
		weapon_label.text = "%s (%s)" % [LootData.item_name(w["base"]), LootData.weapon_stats(w["base"])["type"]]

# Persistent reminder of loot boxes waiting to be opened at the next Safe Room.
# Stairs-open countdown, then the collapse countdown once stairs are open.
func _on_clock(elapsed: float, stairs_open: bool) -> void:
	if not stairs_open:
		var rem: float = maxf(0.0, GameManager.STAIRS_OPEN_TIME - elapsed)
		clock_label.text = "STAIRS IN %s" % _mmss(rem)
		clock_label.modulate = Color(0.7, 0.85, 1, 1)
	else:
		var rem: float = GameManager.COLLAPSE_TIME - elapsed
		if rem <= 0.0:
			clock_label.text = "FLOOR COLLAPSING!"
			clock_label.modulate = Color(1, 0.3, 0.3)
		else:
			clock_label.text = "COLLAPSE IN %s" % _mmss(rem)
			clock_label.modulate = Color(1, 0.5, 0.4) if rem < 30.0 else Color(0.95, 0.8, 0.4)

func _mmss(s: float) -> String:
	var t := int(ceil(s))
	return "%d:%02d" % [t / 60, t % 60]

func _on_boxes(count: int) -> void:
	boxes_label.text = "📦 %d loot box%s — open at a Safe Room" % [count, "" if count == 1 else "es"] if count > 0 else ""

func _refresh_quickbar() -> void:
	if GameManager.quickbar.is_empty():
		quickbar_label.text = ""
		return
	var names: PackedStringArray = []
	for c in GameManager.quickbar:
		names.append(LootData.item_name(c["base"]))
	quickbar_label.text = "[1] " + ", ".join(names)

# Hearts + initial mana come straight off the player's components.
var _bound: bool = false

func _bind_player() -> void:
	if _bound:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		get_tree().create_timer(0.1).timeout.connect(_bind_player)   # spawn race — retry
		return
	_bound = true
	_player = p as Node2D
	_refresh_weapon()   # seed the equipped-weapon label
	var hc := p.get_node_or_null("HealthComponent")
	if hc:
		hc.health_changed.connect(_on_health)
		_on_health(hc.current_hearts, hc.max_hearts)
	var mc := p.get_node_or_null("ManaComponent")
	if mc:
		_on_mana(mc.current_mana, mc.max_mana)

func _on_health(current: float, maximum: float) -> void:
	health_bar.max_value = maxf(1.0, maximum)
	health_bar.value = current

func _on_mana(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current

func _on_rating(v: int) -> void:
	ratings.text = "RATINGS %d" % v

func _on_hype(v: float) -> void:
	hype_bar.value = v

func _on_xp(current: int, to_next: int, level: int) -> void:
	xp_bar.max_value = maxf(1.0, to_next)
	xp_bar.value = current
	var txt := "LVL %d" % level
	var sp: int = GameManager.skill_points
	if sp > 0:
		txt += "   ★%d" % sp   # banked, unspent skill points — your cue to hit a Safe-Room terminal
	level_label.text = txt

func _on_levelup(level: int, _points: int) -> void:
	_flash_ticker("LEVEL UP!  LVL %d  (+%d pts)" % [level, GameManager.SKILL_POINTS_PER_LEVEL])

func _on_spike(type: String) -> void:
	if SPIKE_TEXT.has(type):
		_flash_ticker(SPIKE_TEXT[type])

func _on_achievement(title: String) -> void:
	_flash_ticker("★ " + title)

func _on_item(item_name: String) -> void:
	_flash_ticker("Looted: " + item_name)

func _flash_ticker(text: String) -> void:
	ticker.text = text
	ticker.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(ticker, "modulate:a", 0.0, 0.6)
