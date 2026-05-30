# ModalPanel.gd
# Shared scaffolding for code-built modal screens (dim backdrop + centered panel). Subclasses
# call _build_frame() in _ready to get the content VBox, add their rows, then drive visibility
# with show/hide/toggle. Keeps LevelUpPanel + InventoryPanel from repeating the dim/center/
# panel/box/title/hint chain.
extends CanvasLayer
class_name ModalPanel

# How many modal panels are open. The player checks this so a click on a panel button (e.g. the
# Stat-Injection "+") doesn't also fire the weapon (fire is polled, not event-consumed).
static var open_count: int = 0

static func any_open() -> bool:
	return open_count > 0

# Builds the backdrop + centered panel and returns the content VBox to fill. Also sets the
# panel hidden + on the given canvas layer.
func _build_frame(panel_width: float = 420.0, layer_index: int = 10) -> VBoxContainer:
	visible = false
	layer = layer_index
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks behind the panel
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func add_title(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func add_hint(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func close() -> void:
	_set_open(false)

func toggle() -> void:
	_set_open(not visible)
	if visible:
		_on_show()

# Single place that flips visibility AND keeps the open_count in sync.
func _set_open(v: bool) -> void:
	if v == visible:
		return
	visible = v
	open_count += 1 if v else -1

func _exit_tree() -> void:
	if visible:   # closed by being freed (e.g. floor reload) — don't leak the count
		open_count -= 1

# Override to refresh content each time the panel becomes visible.
func _on_show() -> void:
	pass
