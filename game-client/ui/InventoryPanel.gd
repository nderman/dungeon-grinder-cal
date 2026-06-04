# InventoryPanel.gd
# Equipment screen: a paper-doll of equip slots (click to remove) beside the bag (click to equip,
# ✕ to drop), with rarity-framed cards, an effective-stats summary, and compare-on-hover — the
# detail bar shows a hovered bag item's bonuses plus the NET stat change vs whatever it'd replace.
# Rebuilt on every change so equip/unequip/drop reflect immediately.
extends ModalPanel
class_name InventoryPanel

var _scroll: ScrollContainer
var _equip_col: VBoxContainer
var _bag_grid: GridContainer
var _stats_lbl: Label
var _quick_lbl: Label
var _detail: RichTextLabel
var _eff: Dictionary = {}   # effective stats this refresh — feeds weapon effective-DPS in descs

const NAME_FONT := 16
const SMALL_FONT := 13

func _ready() -> void:
	var box := _build_frame(900.0, 11)
	add_title(box, "INVENTORY")

	# The two columns can run taller than the screen (9 equip slots + a full bag), so they live in a
	# height-capped ScrollContainer — title, stats, quick bar, detail and hint stay pinned outside it.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cols)

	# Left column — the paper-doll + a live effective-stats readout.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 380
	cols.add_child(left)
	_section(left, "EQUIPPED")
	_equip_col = VBoxContainer.new()
	_equip_col.add_theme_constant_override("separation", 6)
	left.add_child(_equip_col)
	_stats_lbl = Label.new()
	_stats_lbl.add_theme_font_size_override("font_size", SMALL_FONT)
	_stats_lbl.modulate = Color(0.65, 0.85, 0.65)
	left.add_child(_stats_lbl)

	# Right column — the bag grid.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 484
	cols.add_child(right)
	_section(right, "BAG")
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 2
	_bag_grid.add_theme_constant_override("h_separation", 8)
	_bag_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_bag_grid)

	_quick_lbl = Label.new()
	_quick_lbl.add_theme_font_size_override("font_size", SMALL_FONT)
	_quick_lbl.modulate = Color(0.7, 0.8, 0.95)
	box.add_child(_quick_lbl)

	# Detail / compare bar — updated on hover, persists the last item examined.
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	_detail.custom_minimum_size = Vector2(0, 48)
	box.add_child(_detail)

	add_hint(box, "Click a bag item to equip · click equipped to remove · ✕ drops · I closes")
	GameManager.items_changed.connect(func(): if visible: _refresh())

func _on_show() -> void:
	_apply_size()
	_refresh()

# Cap the scroll viewport to the screen so a tall inventory scrolls instead of overflowing. Leaves
# headroom for the title + stats/quick/detail/hint rows and the panel's own margins.
func _apply_size() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	_scroll.custom_minimum_size.y = clampf(vh - 230.0, 220.0, 1000.0)

func _refresh() -> void:
	_eff = GameManager.get_effective_stats()   # shared by every card's effective-DPS readout
	_clear(_equip_col)
	_clear(_bag_grid)
	for slot in LootData.SLOTS:
		_equip_col.add_child(_equipped_card(slot))
	if GameManager.bag.is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		empty.modulate = Color(0.55, 0.55, 0.6)
		_bag_grid.add_child(empty)
	else:
		for inst in GameManager.bag:
			_bag_grid.add_child(_bag_card(inst))
	_update_stats()
	_update_quick()
	_set_detail("")

func _update_stats() -> void:
	var parts: PackedStringArray = []
	for s in LootData.STAT_KEYS:
		parts.append("%s %d" % [s, int(_eff.get(s, 0))])
	_stats_lbl.text = "Effective:  " + "    ".join(parts)

func _update_quick() -> void:
	var parts: PackedStringArray = []
	for i in range(GameManager.hotbar.size()):
		parts.append("[%d] %s" % [i + 1, GameManager.hotbar_slot_label(i)])
	_quick_lbl.text = "Hotbar:  " + "   ".join(parts)

# --- Cards ------------------------------------------------------------------------------------

# An equipped slot: SLOT label + item (rarity-coloured) or "empty". Click removes; hover details.
func _equipped_card(slot: String) -> Control:
	var inst: Dictionary = GameManager.equipped.get(slot, {})
	var card := _card_panel(inst)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)

	var head := Label.new()
	head.text = slot.to_upper()
	head.add_theme_font_size_override("font_size", SMALL_FONT)
	head.modulate = Color(0.55, 0.7, 0.95)
	v.add_child(head)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", NAME_FONT)
	if inst.is_empty():
		name_lbl.text = "— empty —"
		name_lbl.modulate = Color(0.45, 0.45, 0.5)
		v.add_child(name_lbl)
		return card
	name_lbl.text = LootData.instance_name(inst)
	name_lbl.modulate = LootData.rarity_color(int(inst.get("rarity", 0)))
	v.add_child(name_lbl)

	var desc := Label.new()
	desc.text = LootData.instance_desc(inst, _eff)
	desc.add_theme_font_size_override("font_size", SMALL_FONT)
	desc.modulate = Color(0.8, 0.8, 0.85)
	v.add_child(desc)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			GameManager.unequip(slot))
	card.mouse_entered.connect(func() -> void: _set_detail(_item_detail(inst)))
	return card

# A bag item: name + rarity/slot tag + bonus, ✕ to drop. Click equips; hover shows compare.
func _bag_card(inst: Dictionary) -> Control:
	var card := _card_panel(inst)
	card.custom_minimum_size = Vector2(228, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	card.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = LootData.instance_name(inst)
	name_lbl.add_theme_font_size_override("font_size", NAME_FONT)
	name_lbl.modulate = LootData.rarity_color(int(inst.get("rarity", 0)))
	v.add_child(name_lbl)

	var tag := Label.new()
	tag.text = "%s · %s" % [LootData.rarity_name(int(inst.get("rarity", 0))), String(inst.get("slot", ""))]
	tag.add_theme_font_size_override("font_size", SMALL_FONT)
	tag.modulate = Color(0.6, 0.6, 0.66)
	v.add_child(tag)

	var bonus := Label.new()
	bonus.text = LootData.instance_desc(inst, _eff)
	bonus.add_theme_font_size_override("font_size", SMALL_FONT)
	bonus.modulate = Color(0.82, 0.82, 0.88)
	v.add_child(bonus)

	var drop := Button.new()
	drop.text = "✕"
	drop.tooltip_text = "Drop"
	drop.add_theme_font_size_override("font_size", SMALL_FONT)
	drop.pressed.connect(func() -> void: GameManager.drop(inst))
	row.add_child(drop)

	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			GameManager.equip(inst))
	card.mouse_entered.connect(func() -> void: _set_detail(_compare_detail(inst)))
	return card

# A rarity-bordered card background (grey border when empty).
func _card_panel(inst: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.18, 0.95)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.3, 0.36) if inst.is_empty() else LootData.rarity_color(int(inst.get("rarity", 0)))
	p.add_theme_stylebox_override("panel", sb)
	return p

# --- Detail / compare -------------------------------------------------------------------------

func _item_detail(inst: Dictionary) -> String:
	return "[b]%s[/b]  (%s · %s)\n%s" % [
		LootData.instance_name(inst), LootData.rarity_name(int(inst.get("rarity", 0))),
		String(inst.get("slot", "")), LootData.instance_desc(inst, _eff)]

# Shows where the item would equip and the per-stat delta vs the item it'd displace (or empty).
func _compare_detail(inst: Dictionary) -> String:
	var target := GameManager.resolve_equip_slot(inst)   # exactly where equip() would put it
	var head := "[b]%s[/b]  %s" % [LootData.instance_name(inst), LootData.instance_desc(inst, _eff)]
	if target == "":
		return head

	var cur: Dictionary = GameManager.equipped.get(target, {})
	var new_b := LootData.instance_bonus(inst)
	var cur_b: Dictionary = LootData.instance_bonus(cur) if not cur.is_empty() else {}
	var deltas: PackedStringArray = []
	for s in LootData.STAT_KEYS:
		var d := int(new_b.get(s, 0)) - int(cur_b.get(s, 0))
		if d != 0:
			var col := "55dd88" if d > 0 else "dd5555"
			deltas.append("[color=#%s]%+d %s[/color]" % [col, d, s])
	var occ := "replaces %s" % LootData.instance_name(cur) if not cur.is_empty() else "fills empty slot"
	var change := "   ".join(deltas) if not deltas.is_empty() else "no net change"
	return "%s\n→ %s — %s    %s" % [head, target, occ, change]

func _set_detail(t: String) -> void:
	_detail.text = t

# --- Helpers ----------------------------------------------------------------------------------

func _section(parent: Node, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color(0.6, 0.9, 1.0)
	parent.add_child(l)

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
