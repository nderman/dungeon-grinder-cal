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

func _update_nightmare_btn(btn: Button) -> void:
	var on := MetaManager.nightmare_enabled
	btn.text = "☠ NIGHTMARE: %s   (enemies hit ×%.1f)" % ["ON" if on else "OFF", GameManager.NIGHTMARE_DMG_MULT]
	btn.modulate = Color(1.0, 0.4, 0.4) if on else Color(0.7, 0.7, 0.75)

func _refresh_summary() -> void:
	if GameManager.run_won:
		# Champion screen — you beat the final floor's boss instead of getting Cancelled.
		$Title.text = "SEASON CHAMPION!"
		$Title.modulate = Color(1.0, 0.85, 0.2)
		$Subtitle.text = "You took the Champion's head on Floor %d!     Seasons won %d     Syndication %d     Tokens %d" % [
			GameManager.current_floor, MetaManager.seasons_won, MetaManager.syndication_points, MetaManager.milestone_tokens
		]
	else:
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
	holder.anchor_top = 0.34   # below the top-anchored title + summary; the ScrollContainer clips the rest
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

	# PERMANENT INJECTORS — the Syndication sink. Always shown (Syndication never "runs out" of uses).
	var inj_header := Label.new()
	inj_header.text = "INJECTORS — spend Syndication (you have %d)" % MetaManager.syndication_points
	inj_header.add_theme_font_size_override("font_size", 18)
	inj_header.modulate = Color(0.6, 1.0, 0.7)
	inj_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop.add_child(inj_header)
	for s in ["STR", "DEX", "INT", "CON", "CHA"]:
		_shop.add_child(_injector_row(s))

	# SPONSOR A WEAPON — the Token sink (post-roster). Favour a weapon in every future Season's drops.
	var spon_header := Label.new()
	spon_header.text = "SPONSOR A WEAPON — spend Tokens (you have %d)" % MetaManager.milestone_tokens
	spon_header.add_theme_font_size_override("font_size", 18)
	spon_header.modulate = Color(0.85, 0.8, 1.0)
	spon_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop.add_child(spon_header)
	for id in LootData.ITEMS:
		var it: Dictionary = LootData.ITEMS[id]
		if String(it.get("slot", "")) == "Weapon" and id not in LootData.STARTER_WEAPONS:
			_shop.add_child(_sponsor_row(String(id)))

	# DIFFICULTY — Nightmare toggle + Prestige/NG+, both unlocked once you've won a Season. Lives INSIDE
	# the scroll so it can't overlap the shop or the continue hint (the old floating button did).
	if MetaManager.seasons_won >= 1:
		var diff_header := Label.new()
		diff_header.text = "DIFFICULTY — Nightmare + New Game+ (harder Season, richer loot)"
		diff_header.add_theme_font_size_override("font_size", 18)
		diff_header.modulate = Color(1.0, 0.55, 0.55)
		diff_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop.add_child(diff_header)
		_shop.add_child(_nightmare_row())
		_shop.add_child(_ng_plus_row())

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

# One stat's permanent-injector row: current buff + the escalating Syndication price.
func _injector_row(stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var owned := int(MetaManager.permanent_stat_buffs.get(stat, 0))
	var lbl := Label.new()
	lbl.text = "%s  (+%d)" % [stat, owned]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(0.6, 1.0, 0.7)
	row.add_child(lbl)
	var cost := MetaManager.stat_injector_cost(stat)
	var btn := Button.new()
	btn.text = "+1  (%d syn)" % cost
	btn.disabled = MetaManager.syndication_points < cost
	btn.focus_mode = Control.FOCUS_NONE   # don't eat the SPACE/E "new Season" key
	btn.pressed.connect(func() -> void: MetaManager.buy_stat_injector(stat))
	row.add_child(btn)
	return row

# One weapon's sponsor row: a buy button, or a ★ tag once it's permanently in the drop pool.
func _sponsor_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = LootData.item_name(id)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(0.85, 0.8, 1.0)
	row.add_child(lbl)
	if MetaManager.is_sponsored(id):
		var tag := Label.new()
		tag.text = "★ Sponsored"
		tag.modulate = Color(1.0, 0.85, 0.3)
		row.add_child(tag)
	else:
		var btn := Button.new()
		btn.text = "Sponsor (%d token)" % MetaManager.SPONSOR_TOKEN_COST
		btn.disabled = MetaManager.milestone_tokens < MetaManager.SPONSOR_TOKEN_COST
		btn.focus_mode = Control.FOCUS_NONE   # don't eat the SPACE/E "new Season" key
		btn.pressed.connect(func() -> void: MetaManager.sponsor_item(id))
		row.add_child(btn)
	return row

# NIGHTMARE toggle as a shop row (was a floating button that overlapped the shop). Click to flip;
# the choice persists and locks in at the next run's start. Updates its own text inline.
func _nightmare_row() -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE   # don't eat the SPACE/E "new Season" key
	_update_nightmare_btn(btn)
	btn.pressed.connect(func() -> void:
		MetaManager.nightmare_enabled = not MetaManager.nightmare_enabled
		MetaManager.save_persistence()
		_update_nightmare_btn(btn))
	return btn

# New Game+ controls: a current-tier readout, a −/+ active-tier selector (once anything's unlocked),
# and the buy-the-next-tier button. All buttons skip focus so they don't eat the new-Season key.
func _ng_plus_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Active NG+%d / unlocked NG+%d" % [MetaManager.ng_plus_active, MetaManager.ng_plus_unlocked]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(1.0, 0.6, 0.6)
	row.add_child(lbl)
	if MetaManager.ng_plus_unlocked >= 1:
		var minus := Button.new()
		minus.text = "−"
		minus.focus_mode = Control.FOCUS_NONE
		minus.disabled = MetaManager.ng_plus_active <= 0
		minus.pressed.connect(func() -> void: MetaManager.set_ng_plus_active(MetaManager.ng_plus_active - 1))
		row.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.disabled = MetaManager.ng_plus_active >= MetaManager.ng_plus_unlocked
		plus.pressed.connect(func() -> void: MetaManager.set_ng_plus_active(MetaManager.ng_plus_active + 1))
		row.add_child(plus)
	var unlock := Button.new()
	unlock.text = "Unlock NG+%d (%d tokens)" % [MetaManager.ng_plus_unlocked + 1, MetaManager.ng_plus_cost()]
	unlock.disabled = MetaManager.milestone_tokens < MetaManager.ng_plus_cost()
	unlock.focus_mode = Control.FOCUS_NONE
	unlock.pressed.connect(func() -> void: MetaManager.unlock_ng_plus())
	row.add_child(unlock)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		GameManager.start_new_run()
		get_tree().change_scene_to_file("res://Floor.tscn")
