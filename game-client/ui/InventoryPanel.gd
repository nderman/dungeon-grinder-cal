# InventoryPanel.gd
# Toggle-able holdings screen (press the inventory key). Lists auto-equipped gear with its
# bonuses + the quick-bar consumables. Read-only for now (equip slots / drop come later).
# Built in code like LevelUpPanel so the .tscn stays trivial; the list rebuilds on each open.
extends ModalPanel
class_name InventoryPanel

var _list: VBoxContainer

func _ready() -> void:
	var box := _build_frame(440.0, 11)
	add_title(box, "INVENTORY")
	_list = VBoxContainer.new()
	box.add_child(_list)
	add_hint(box, "Press I to close")

func _on_show() -> void:
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_header("Equipped Gear")
	if GameManager.equipped_gear.is_empty():
		_line("  (none)")
	for g in GameManager.equipped_gear:
		_line("  %s  [%s]  %s" % [_name(g["id"]), LootData.tier_name(int(g["tier"])), LootData.describe(g["id"], int(g["tier"]))])
	_header("Quick Bar  [1] to use")
	if GameManager.quickbar.is_empty():
		_line("  (none)")
	for c in GameManager.quickbar:
		_line("  %s  [%s]  %s" % [_name(c["id"]), LootData.tier_name(int(c["tier"])), LootData.describe(c["id"], int(c["tier"]))])

func _name(id: String) -> String:
	return LootData.ITEMS.get(id, {}).get("name", id)

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
