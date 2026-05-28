# LevelUpPanel.gd
# The Stat-Injection screen. Opened from the Safe-Room LevelTerminal — the only place
# you may spend banked skill points (DCC: stat allocation happens in safe rooms).
# UI is built in code so the .tscn stays a single node and headless import never trips.
extends CanvasLayer

const STATS := ["STR", "DEX", "INT", "CON", "CHA"]

var _points_label: Label
var _value_labels: Dictionary = {}   # stat -> Label
var _plus_buttons: Dictionary = {}   # stat -> Button
var _preview: Label

func _ready() -> void:
	visible = false
	layer = 10
	_build()
	# Live-refresh while open: a fresh level mid-stay, or a point just spent.
	SignalBus.leveled_up.connect(func(_lvl, _pts): _refresh())
	SignalBus.xp_changed.connect(func(_x, _n, _lv): _refresh())

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks behind the panel
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "STAT INJECTION"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_points_label)

	for s in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_l := Label.new()
		name_l.text = s
		name_l.custom_minimum_size.x = 70
		name_l.add_theme_font_size_override("font_size", 22)
		var val_l := Label.new()
		val_l.custom_minimum_size.x = 60
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_l.add_theme_font_size_override("font_size", 22)
		var plus := Button.new()
		plus.text = "  +  "
		plus.pressed.connect(_on_plus.bind(s))
		row.add_child(name_l)
		row.add_child(val_l)
		row.add_child(plus)
		box.add_child(row)
		_value_labels[s] = val_l
		_plus_buttons[s] = plus

	_preview = Label.new()
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_preview)

	var hint := Label.new()
	hint.text = "Press E to step off the pad"
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _on_plus(stat: String) -> void:
	GameManager.spend_skill_point(stat)   # refresh arrives via xp_changed

func _refresh() -> void:
	if not is_inside_tree():
		return
	var sp: int = GameManager.skill_points
	_points_label.text = "Skill points: %d        Level %d" % [sp, GameManager.level]
	var stats: Dictionary = GameManager.current_run_stats
	for s in STATS:
		_value_labels[s].text = str(int(stats.get(s, 0)))
		_plus_buttons[s].disabled = sp <= 0
	var con: int = int(stats.get("CON", 0))
	var intel: int = int(stats.get("INT", 0))
	_preview.text = "→ Hearts %d    Mana %d" % [int(floor(con / 5.0)), intel * 5]
