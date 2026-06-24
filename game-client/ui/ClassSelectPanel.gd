# ClassSelectPanel.gd
# Floor-3 Race & Class pick (DCC: classless/locked for floors 1-2, the System sets you up on the
# third). Offers only UNLOCKED races/classes (roguelite meta-gate — unlock more in the Green Room),
# flags the classes it recommends from your top stat. Mandatory: no close key; it dismisses once you
# lock in a CLASS. Race defaults to your current one (Human) and can be re-picked among unlocked.
extends ModalPanel
class_name ClassSelectPanel

var _body: VBoxContainer

func _ready() -> void:
	var box := _build_frame(620.0, 12)   # layer 12 — above the regular modals
	add_title(box, "FLOOR 3: RACE & CLASS")
	add_hint(box, "The System has assessed your run. Choosing a class is permanent.")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, clampf(get_viewport().get_visible_rect().size.y - 220.0, 240.0, 1000.0))
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_refresh()

func _refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	# --- Race (optional; default = keep current) ---
	_section("RACE  (default: keep)")
	var race_row := HBoxContainer.new()
	race_row.add_theme_constant_override("separation", 6)
	_body.add_child(race_row)
	for r in MetaManager.unlocked_races:
		race_row.add_child(_race_chip(String(r)))
	# --- Class (mandatory) ---
	_section("CLASS  (pick one — permanent)")
	var top := _top_stat()
	for c in MetaManager.unlocked_classes:
		_body.add_child(_class_card(String(c), top))
	_locked_note()

func _section(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(0.6, 0.9, 1.0)
	_body.add_child(l)

func _race_chip(r: String) -> Control:
	var selected := r == GameManager.current_race
	var b := Button.new()
	b.text = ("● " if selected else "") + r
	b.disabled = selected
	b.pressed.connect(func() -> void:
		GameManager.choose_race(r)
		_refresh())
	return b

func _top_stat() -> String:
	var best := ""
	var best_v := -1
	for s in GameManager.current_run_stats:
		if int(GameManager.current_run_stats[s]) > best_v:
			best_v = int(GameManager.current_run_stats[s])
			best = String(s)
	return best

func _class_card(c: String, top: String) -> Control:
	var data: Dictionary = ClassData.CLASSES[c]
	var recommended := int(data.get("bonuses", {}).get(top, 0)) > 0

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.18, 0.95)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.35) if recommended else Color(0.3, 0.3, 0.36)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)

	var head := Label.new()
	head.text = "%s%s%s" % ["* " if recommended else "", c, "   (recommended)" if recommended else ""]
	head.add_theme_font_size_override("font_size", 18)
	head.modulate = Color(0.95, 0.85, 0.5) if recommended else Color(0.7, 0.85, 1.0)
	v.add_child(head)

	var bon: PackedStringArray = []
	for s in data.get("bonuses", {}):
		bon.append("+%d %s" % [int(data["bonuses"][s]), s])
	var sub := Label.new()
	sub.text = "%s   ·   Active: %s" % [" ".join(bon), String(data.get("active", ""))]
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.8, 0.8, 0.86)
	v.add_child(sub)

	var pas := Label.new()
	pas.text = String(data.get("passive", ""))
	pas.add_theme_font_size_override("font_size", 12)
	pas.modulate = Color(0.65, 0.65, 0.72)
	v.add_child(pas)

	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			GameManager.choose_class(c)
			close())
	return card

# Tease what's still locked so the meta-progression is visible (unlock it in the Green Room).
func _locked_note() -> void:
	var locked: PackedStringArray = []
	for c in ClassData.CLASSES:
		if c not in MetaManager.unlocked_classes:
			locked.append(String(c))
	if locked.is_empty():
		return
	var l := Label.new()
	l.text = "Locked: %s  —  unlock in the Green Room" % ", ".join(locked)
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(0.5, 0.5, 0.56)
	_body.add_child(l)
