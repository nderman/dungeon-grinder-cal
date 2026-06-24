# AbilitiesPanel.gd
# Active-abilities screen (toggle with the abilities key). Lists every ability the contestant knows
# this run — kind (Spell/Skill), scaling stat, use-earned level, mana cost / cooldown — and lets you
# pick which one the cast key (Q) fires. Rebuilt on every change so selection reflects immediately.
extends ModalPanel
class_name AbilitiesPanel

var _list: VBoxContainer

func _ready() -> void:
	var box := _build_frame(560.0, 11)
	add_title(box, "ABILITIES")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	add_hint(box, "Click to set the active cast (Q) · K closes")
	GameManager.abilities_changed.connect(func(): if visible: _refresh())

func _on_show() -> void:
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if GameManager.known_abilities.is_empty():
		var none := Label.new()
		none.text = "  (none learned yet — find a tome)"
		none.modulate = Color(0.6, 0.6, 0.65)
		_list.add_child(none)
		return
	for id in GameManager.known_abilities:
		_list.add_child(_ability_card(String(id)))

# A card per known ability; the active one gets a gold border + *. Click selects it.
func _ability_card(id: String) -> Control:
	var a := AbilityLibrary.get_ability(id)
	var is_spell := AbilityLibrary.is_spell(id)
	var selected := id == GameManager.selected_ability

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.18, 0.95)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.35) if selected else Color(0.3, 0.3, 0.36)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)

	var head := Label.new()
	head.text = "%s%s   Lv %d" % ["* " if selected else "", String(a.get("name", id)), GameManager.ability_level(id)]
	head.add_theme_font_size_override("font_size", 18)
	head.modulate = Color(0.55, 0.8, 1.0) if is_spell else Color(1.0, 0.7, 0.45)
	v.add_child(head)

	var cost := ("%d mana" % int(a.get("mana_cost", 0))) if is_spell else "no mana"
	var sub := Label.new()
	sub.text = "%s · scales %s · %s · %.1fs cd" % ["Spell" if is_spell else "Skill", String(a.get("scale", "INT")), cost, float(a.get("cooldown", 0.0))]
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = Color(0.7, 0.7, 0.76)
	v.add_child(sub)

	var desc := Label.new()
	desc.text = String(a.get("description", ""))
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.82, 0.82, 0.88)
	v.add_child(desc)

	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			GameManager.select_ability(id))
	return card
