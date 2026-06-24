# PauseMenu.gd
# Esc / P pauses the Episode and shows this overlay — which doubles as the controls/help screen
# (handy for web players who land cold). PROCESS_MODE_ALWAYS so it keeps taking input while the rest
# of the tree is frozen; it owns the get_tree().paused flag. Won't open over another menu (inventory/
# abilities) — close that first — so the pause key never stacks modals.
extends ModalPanel
class_name PauseMenu

const CONTROLS := [
	["Move", "W A S D"],
	["Aim", "Mouse  /  Arrow keys"],
	["Fire weapon", "Left Mouse"],
	["Cast ability", "Q  (primary)"],
	["Cast ability", "Right Mouse  (secondary)"],
	["Dash", "Space"],
	["Interact / open door", "E"],
	["Use hotbar slot", "1  2  3  4"],
	["Inventory", "I"],
	["Abilities (bind casts)", "K"],
	["Pause / Help", "Esc  /  P"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running input while the game is paused
	var box := _build_frame(460.0, 12)
	add_title(box, "PAUSED")

	var head := Label.new()
	head.text = "CONTROLS"
	head.add_theme_font_size_override("font_size", 16)
	head.modulate = Color(0.6, 0.75, 0.95)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)

	for pair in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var act := Label.new()
		act.text = String(pair[0])
		act.custom_minimum_size.x = 190
		act.modulate = Color(0.82, 0.82, 0.88)
		row.add_child(act)
		var bind := Label.new()
		bind.text = String(pair[1])
		bind.modulate = Color(0.95, 0.85, 0.5)
		row.add_child(bind)
		box.add_child(row)

	add_hint(box, "Esc / P to resume")

# Always listening (PROCESS_MODE_ALWAYS): toggle pause on Esc / P, in or out of a paused state.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
		if _toggle_pause():
			get_viewport().set_input_as_handled()   # only swallow the key when we actually acted on it

# Returns true if it paused or resumed; false if blocked (another menu open) so the key falls through.
func _toggle_pause() -> bool:
	if visible:
		get_tree().paused = false   # clear the flag BEFORE hiding, so un-pause never hinges on `visible`
		close()
		return true
	elif not ModalPanel.any_open():   # don't stack the pause overlay over an open inventory/abilities menu
		toggle()
		get_tree().paused = true
		return true
	return false

# Safety: clear the SceneTree pause flag whenever this menu leaves the tree (floor change / death) —
# it survives change_scene_to_file, so a stale `paused=true` would boot the next scene frozen. Cleared
# unconditionally (this menu owns the flag) rather than hinging on `visible`.
func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
	super()
