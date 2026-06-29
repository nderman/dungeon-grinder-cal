# NonCombatantNPC.gd
# A friendly, non-combat townsfolk you walk up to and interact with (E) — the populated half of a
# Settlement. Two roles: "shop" opens the town vendor, "talk" barks a flavour line. Reuses the
# InteractablePad enter/exit/interact plumbing (same as the Safe-Room terminals); it never attacks
# and isn't in the "enemies" group, so nothing targets it and it has no AI.
extends InteractablePad
class_name NonCombatantNPC

@export var role: String = "talk"          # "shop" (opens the vendor) | "talk" (flavour bark)
@export var display_name: String = "Local"
@export var lines: PackedStringArray = ["Mind the lower floors."]

func _ready() -> void:
	super._ready()   # InteractablePad wires body enter/exit + the interact button
	# Role-based look so the prefab only has to set `role`: vendor reads gold, townsfolk reads green.
	var vis := get_node_or_null("Visual")
	if vis is Polygon2D:
		vis.color = Color(1.0, 0.8, 0.3, 0.9) if role == "shop" else Color(0.5, 0.8, 0.6, 0.85)
	var label := get_node_or_null("Label")
	if label is Label:
		label.text = "%s — TRADE [E]" % display_name if role == "shop" else "%s [E]" % display_name
		label.modulate = Color(1.0, 0.85, 0.3) if role == "shop" else Color(0.7, 0.9, 0.7)

func _on_interact() -> void:
	if role == "shop":
		if _player != null and _player.has_method("show_shop"):
			_player.show_shop()
		return
	var line := "..." if lines.is_empty() else lines[randi() % lines.size()]
	SignalBus.toast.emit("%s: %s" % [display_name, line], global_position)
