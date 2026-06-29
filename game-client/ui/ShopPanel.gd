# ShopPanel.gd
# The town vendor's storefront. The economy lives in GameManager (stock/pricing/buy); this just
# lists the wares with Gold prices, greys out what you can't afford, and buys on click. Stock is
# rolled on town entry, so this only ever displays + spends — it never rolls. Rarity-coloured names;
# the Scavenger's discount shows in the prices automatically (GameManager.shop_price folds it in).
class_name ShopPanel
extends ModalPanel

var _gold_lbl: Label
var _rows_holder: VBoxContainer
var _note: Label

func _ready() -> void:
	var box := _build_frame(560.0)
	add_title(box, "VENDOR")
	_gold_lbl = Label.new()
	_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_lbl.modulate = Color(1.0, 0.85, 0.3)
	box.add_child(_gold_lbl)
	_rows_holder = VBoxContainer.new()
	_rows_holder.add_theme_constant_override("separation", 6)
	box.add_child(_rows_holder)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.modulate = Color(1, 1, 1, 0.55)
	box.add_child(_note)
	add_hint(box, "Click to buy  ·  E / SPACE to leave")
	# Refresh on any shelf/wallet change. Gold only moves via buying here (which emits shop_changed),
	# so one listener covers both — no double rebuild per purchase.
	GameManager.shop_changed.connect(_refresh)

func open_shop() -> void:
	if not visible:
		toggle()   # ModalPanel.toggle() calls _on_show()

func _on_show() -> void:
	_refresh()

func _refresh() -> void:
	if not visible:
		return
	for r in _rows_holder.get_children():
		r.queue_free()
	_gold_lbl.text = "Gold: %d" % GameManager.gold
	_note.text = "Extreme Coupons: −20%" if GameManager.has_passive("extreme_coupons") else ""
	if GameManager.shop_stock.is_empty():
		var sold := Label.new()
		sold.text = "— sold out —"
		sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sold.modulate = Color(0.6, 0.6, 0.65)
		_rows_holder.add_child(sold)
		return
	for i in range(GameManager.shop_stock.size()):
		_rows_holder.add_child(_make_row(i))

func _make_row(index: int) -> Button:
	var inst: Dictionary = GameManager.shop_stock[index]
	var price := GameManager.shop_price(inst)
	var dead: bool = GameManager.shop_item_is_dead(inst)   # a tome you've already maxed
	var btn := Button.new()
	btn.text = "%s   —   %s" % [_item_label(inst), "OWNED" if dead else "%dg" % price]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = dead or GameManager.gold < price
	if not dead and inst.get("kind") != "consumable":
		btn.add_theme_color_override("font_color", LootData.rarity_color(int(inst.get("rarity", 0))))
	btn.pressed.connect(_buy.bind(index))
	return btn

func _item_label(inst: Dictionary) -> String:
	if inst.get("kind") == "consumable":
		return LootData.item_name(String(inst.get("base", "")))
	return LootData.instance_name(inst)

func _buy(index: int) -> void:
	if index < 0 or index >= GameManager.shop_stock.size():
		return
	if GameManager.buy_shop_item(index):   # emits shop_changed -> _refresh()
		SignalBus.toast.emit("Bought!", _player_pos())
	elif GameManager.gold < GameManager.shop_price(GameManager.shop_stock[index]):
		SignalBus.toast.emit("Not enough gold", _player_pos())
	else:
		SignalBus.toast.emit("No use for that", _player_pos())   # dead purchase (already maxed)

func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player")
	return (p as Node2D).global_position if p is Node2D else Vector2.ZERO

# Captured in _input (before _unhandled_input) so E doesn't re-trigger the vendor NPC behind it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
