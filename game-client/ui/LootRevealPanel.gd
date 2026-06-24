# LootRevealPanel.gd
# The payoff screen for cracking Loot Boxes in the Safe Room. The roll + inventory-add already
# happened (AchievementManager.open_all_boxes); this just REVEALS the haul one box at a time, low
# tier -> high, each line popping in rarity-coloured with a marker for the good stuff — so opening a
# Celestial box feels like an event, not a ticker blip. Tap E/SPACE to reveal the rest, then to close.
class_name LootRevealPanel
extends ModalPanel

const REVEAL_GAP := 0.4   # seconds between each box popping in

var _title: Label
var _rows_holder: VBoxContainer
var _hint: Label
var _rows: Array[Control] = []
var _shown: int = 0
var _revealing: bool = false

func _ready() -> void:
	var box := _build_frame(560.0)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate = Color(0.95, 0.85, 0.5)
	box.add_child(_title)
	_rows_holder = VBoxContainer.new()
	_rows_holder.add_theme_constant_override("separation", 8)
	box.add_child(_rows_holder)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_hint)

# Kick off the reveal for a freshly-opened haul ([{box, item, rarity, tier}], low->high).
func reveal(results: Array) -> void:
	for r in _rows_holder.get_children():
		r.queue_free()
	_rows.clear()
	_shown = 0
	_title.text = "DECRYPTING %d BOX%s" % [results.size(), "ES" if results.size() != 1 else ""]
	for res in results:
		var row := _make_row(res)
		row.modulate.a = 0.0   # hidden until its turn to pop
		_rows_holder.add_child(row)
		_rows.append(row)
	_hint.text = ""
	if not visible:
		toggle()   # ModalPanel: show + bump open_count
	_revealing = true
	_reveal_next()

# "Bronze Weapon Box   ->   * Epic Lead-Lined Vest" — box label muted, item in its rarity colour.
func _make_row(res: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var box_lbl := Label.new()
	box_lbl.text = "%s Box" % String(res.get("box", "?"))
	box_lbl.modulate = Color(0.7, 0.72, 0.8)
	box_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box_lbl)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.modulate = Color(0.6, 0.6, 0.65)
	row.add_child(arrow)
	var item_lbl := Label.new()
	var rarity := int(res.get("rarity", -1))
	item_lbl.text = "%s%s" % [_marker(rarity), String(res.get("item", "?"))]
	item_lbl.modulate = LootData.rarity_color(rarity) if rarity >= 0 else Color(0.8, 0.9, 0.8)
	item_lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(item_lbl)
	return row

# A little flair for the rare stuff (Epic = *, Legendary = **); plain otherwise.
func _marker(rarity: int) -> String:
	if rarity >= LootData.RARITY_NAMES.size() - 1:
		return "★★ "
	if rarity >= 3:
		return "★ "
	return ""

# Pop the next box in, then schedule the one after — a staggered reveal you can sit back and watch.
func _reveal_next() -> void:
	if _shown >= _rows.size():
		_revealing = false
		_hint.text = "Press E / SPACE to continue"
		return
	var row := _rows[_shown]
	_shown += 1
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.18)
	tw.tween_interval(REVEAL_GAP)
	tw.tween_callback(_reveal_next)

# Captured in _input (runs BEFORE _unhandled_input) so E doesn't also re-trigger the Safe-Room pad
# or leak to the player. First press fast-forwards the reveal; the next closes the screen.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if _revealing:
			for r in _rows:
				r.modulate.a = 1.0
			_shown = _rows.size()
			_revealing = false
			_hint.text = "Press E / SPACE to continue"
		else:
			close()
		get_viewport().set_input_as_handled()
