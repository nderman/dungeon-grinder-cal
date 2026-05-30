# InventoryPanel.gd
# Equipment management screen (toggle with the inventory key). Shows the full-body equip slots
# (Unequip each) and the bag (Equip / Drop each), with rarity colours + rolled stat bonuses.
# Rebuilt on every change so equip/unequip/drop reflect immediately.
extends ModalPanel
class_name InventoryPanel

var _list: VBoxContainer

func _ready() -> void:
	var box := _build_frame(520.0, 11)
	add_title(box, "INVENTORY")
	_list = VBoxContainer.new()
	box.add_child(_list)
	add_hint(box, "Press I to close")
	GameManager.items_changed.connect(func(): if visible: _refresh())

func _on_show() -> void:
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_header("Equipped")
	for slot in LootData.SLOTS:
		var inst: Dictionary = GameManager.equipped.get(slot, {})
		if inst.is_empty():
			_slot_row(slot, "— empty —", Color(0.5, 0.5, 0.55), "", Callable())
		else:
			_slot_row(slot, "%s  (%s)" % [LootData.instance_name(inst), LootData.instance_desc(inst)],
				LootData.rarity_color(int(inst.get("rarity", 0))), "Unequip", _unequip.bind(slot))
	_header("Bag")
	if GameManager.bag.is_empty():
		_line("  (empty)")
	for inst in GameManager.bag:
		_bag_row(inst)
	_header("Quick Bar  [1] to use")
	if GameManager.quickbar.is_empty():
		_line("  (none)")
	for c in GameManager.quickbar:
		_line("  %s  [%s]" % [LootData.item_name(c["base"]), LootData.tier_name(int(c["tier"]))])

# A "Slot: item  [button]" row.
func _slot_row(slot: String, text: String, color: Color, btn: String, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "%-7s %s" % [slot, text]
	lbl.modulate = color
	lbl.custom_minimum_size.x = 380
	row.add_child(lbl)
	if btn != "":
		var b := Button.new()
		b.text = btn
		b.pressed.connect(cb)
		row.add_child(b)
	_list.add_child(row)

# A bag item: "[rarity] Name (bonus)  [Equip] [Drop]"
func _bag_row(inst: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "%s %s (%s) → %s" % [LootData.rarity_name(int(inst.get("rarity", 0))), LootData.instance_name(inst), LootData.instance_desc(inst), inst.get("slot", "")]
	lbl.modulate = LootData.rarity_color(int(inst.get("rarity", 0)))
	lbl.custom_minimum_size.x = 360
	row.add_child(lbl)
	var eq := Button.new()
	eq.text = "Equip"
	eq.pressed.connect(_equip.bind(inst))
	row.add_child(eq)
	var dr := Button.new()
	dr.text = "Drop"
	dr.pressed.connect(_drop.bind(inst))
	row.add_child(dr)
	_list.add_child(row)

func _equip(inst: Dictionary) -> void:
	GameManager.equip(inst)

func _unequip(slot: String) -> void:
	GameManager.unequip(slot)

func _drop(inst: Dictionary) -> void:
	GameManager.drop(inst)

func _header(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(0.6, 0.9, 1.0)
	_list.add_child(l)

func _line(t: String) -> void:
	var l := Label.new()
	l.text = t
	_list.add_child(l)
