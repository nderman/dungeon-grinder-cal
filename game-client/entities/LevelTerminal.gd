# LevelTerminal.gd
# Safe-Room pad: stand on it and press interact (E) to open the Stat-Injection panel and
# spend banked skill points. Stepping off the pad closes it.
extends InteractablePad

@onready var panel := $LevelUpPanel

func _on_interact() -> void:
	panel.toggle()

func _on_player_left() -> void:
	panel.close()
