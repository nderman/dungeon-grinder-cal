# CombatHUD.gd
# Reads game state purely from signals (SignalBus + GameManager) — never pokes at
# combat logic. Binds to the player's Health/Mana components once, on a deferred call,
# so it works no matter the _ready order.
extends CanvasLayer

@onready var hearts: Label = $Hearts
@onready var mana_bar: ProgressBar = $ManaBar
@onready var mana_label: Label = $ManaLabel
@onready var ratings: Label = $Ratings
@onready var hype_bar: ProgressBar = $HypeBar
@onready var ticker: Label = $Ticker

const SPIKE_TEXT := {
	"SPEED_DEMON": "SPEED DEMON!", "NEAR_DEATH": "NEAR DEATH!",
	"UNTOUCHABLE": "UNTOUCHABLE!", "DRAMA_SPIKE": "DRAMA SPIKE!",
	"FATALITY": "FATALITY!", "CANCELLED": "CANCELLED",
}

func _ready() -> void:
	SignalBus.mana_updated.connect(_on_mana)
	SignalBus.ratings_spike.connect(_on_spike)
	GameManager.rating_changed.connect(_on_rating)
	GameManager.hype_changed.connect(_on_hype)
	SignalBus.achievement_unlocked.connect(_on_achievement)
	SignalBus.item_acquired.connect(_on_item)
	_on_rating(GameManager.run_ratings)
	_on_hype(GameManager.hype_meter)
	ticker.modulate.a = 0.0
	_bind_player.call_deferred()

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
	var hc := p.get_node_or_null("HealthComponent")
	if hc:
		hc.health_changed.connect(_on_health)
		_on_health(hc.current_hearts, hc.max_hearts)
	var mc := p.get_node_or_null("ManaComponent")
	if mc:
		_on_mana(mc.current_mana, mc.max_mana)

func _on_health(current: float, maximum: float) -> void:
	hearts.text = "%s   %s / %s" % [_hearts_glyphs(current, maximum), _fmt(current), _fmt(maximum)]

func _hearts_glyphs(current: float, maximum: float) -> String:
	var s := ""
	for i in range(int(ceil(maximum))):
		s += "♥" if current >= float(i + 1) else "♡"
	return s

func _on_mana(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "MANA %d / %d" % [int(current), int(maximum)]

func _on_rating(v: int) -> void:
	ratings.text = "RATINGS %d" % v

func _on_hype(v: float) -> void:
	hype_bar.value = v

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

func _fmt(v: float) -> String:
	return str(snappedf(v, 0.5))
