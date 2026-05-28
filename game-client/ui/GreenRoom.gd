# GreenRoom.gd
# The between-Seasons screen shown on "Cancellation". Closes the loop: shows the run
# summary and lets the player drop into a fresh Season (a new Open Floor).
extends Control

func _ready() -> void:
	$Subtitle.text = "Floor reached %d     Level %d     Syndication %d     Tokens %d\n\nPress SPACE or E for a new Season" % [
		GameManager.current_floor, GameManager.level, MetaManager.syndication_points, MetaManager.milestone_tokens
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		GameManager.start_new_run()
		get_tree().change_scene_to_file("res://Floor.tscn")
