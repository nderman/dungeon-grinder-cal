# GreenRoom.gd
# The between-Seasons screen shown on "Cancellation". Run summary + a roster shop where you spend
# Milestone Tokens (earned at floors 3/6/9) to permanently unlock new races/classes — the roguelite
# loop that makes the Floor-3 pick richer next run. Then drop into a fresh Season.
extends Control

var _shop: VBoxContainer

func _ready() -> void:
	_refresh_summary()
	_build_shop_frame()
	_build_continue_hint()
	MetaManager.meta_changed.connect(_on_meta_changed)

func _refresh_summary() -> void:
	$Subtitle.text = "Floor reached %d     Level %d     Syndication %d     Tokens %d" % [
		GameManager.current_floor, GameManager.level, MetaManager.syndication_points, MetaManager.milestone_tokens
	]

# "New Season" prompt pinned to the bottom, clear of the roster shop.
func _build_continue_hint() -> void:
	var hint := Label.new()
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.93
	hint.anchor_bottom = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "Press SPACE or E for a new Season"
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)

func _build_shop_frame() -> void:
	var holder := VBoxContainer.new()
	holder.anchor_left = 0.28
	holder.anchor_right = 0.72
	holder.anchor_top = 0.6
	holder.anchor_bottom = 0.9
	holder.add_theme_constant_override("separation", 6)
	add_child(holder)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(scroll)
	_shop = VBoxContainer.new()
	_shop.add_theme_constant_override("separation", 5)
	_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shop)
	_refresh_shop()

func _on_meta_changed() -> void:
	_refresh_summary()
	_refresh_shop()

func _refresh_shop() -> void:
	for c in _shop.get_children():
		_shop.remove_child(c)
		c.queue_free()
	var header := Label.new()
	header.text = "ROSTER — spend Milestone Tokens (you have %d)" % MetaManager.milestone_tokens
	header.add_theme_font_size_override("font_size", 18)
	header.modulate = Color(0.95, 0.85, 0.5)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop.add_child(header)

	var any := false
	for c in ClassData.CLASSES:
		if String(c) not in MetaManager.unlocked_classes:
			_shop.add_child(_unlock_row(String(c), "class"))
			any = true
	for r in RaceData.RACES:
		if String(r) not in MetaManager.unlocked_races:
			_shop.add_child(_unlock_row(String(r), "race"))
			any = true
	if not any:
		var done := Label.new()
		done.text = "Full roster unlocked — nothing left to contract."
		done.modulate = Color(0.6, 0.7, 0.6)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop.add_child(done)

func _unlock_row(id: String, type: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "%s: %s" % [type.capitalize(), id]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(0.55, 0.8, 1.0) if type == "class" else Color(1.0, 0.7, 0.45)
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "Unlock (1 token)"
	btn.disabled = MetaManager.milestone_tokens <= 0
	btn.pressed.connect(func() -> void: MetaManager.unlock_content(id, type))
	row.add_child(btn)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		GameManager.start_new_run()
		get_tree().change_scene_to_file("res://Floor.tscn")
