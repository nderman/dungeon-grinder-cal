# ArtPreview.gd (dev tool, not shipped in gameplay)
# Renders every Silhouette archetype in a labelled grid and saves a PNG, so the art pass can be
# eyeballed without launching a run. Usage:
#   Godot --rendering-driver opengl3 --resolution 1100x460 res://tools/ArtPreview.tscn
extends Node2D

const SHOWCASE := [
	["player", Color(0.35, 0.85, 1), 17.0], ["goblin", Color(1, 0.36, 0.36), 15.0],
	["screamer", Color(0.72, 1, 0.32), 12.0], ["brute", Color(0.85, 0.48, 0.22), 25.0],
	["sniper", Color(0.95, 0.38, 0.9), 17.0], ["cleric", Color(0.92, 0.92, 0.72), 19.0],
	["healer", Color(0.45, 0.95, 0.62), 17.0], ["npc", Color(0.5, 0.8, 0.6), 30.0],
	["boss", Color(0.75, 0.17, 0.21), 46.0], ["turret", Color(0.98, 0.82, 0.18), 30.0],
	["showrunner", Color(0.68, 0.34, 0.9), 30.0],
]
const COLS := 6
const CELL := Vector2(180, 200)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.10, 0.13))
	for i in range(SHOWCASE.size()):
		var s: Array = SHOWCASE[i]
		var at := Vector2(100 + (i % COLS) * CELL.x, 110 + (i / COLS) * CELL.y)
		var art := Silhouette.new()
		art.shape = String(s[0]); art.tint = s[1]; art.radius = float(s[2])
		art.position = at
		add_child(art)
		var lbl := Label.new()
		lbl.text = String(s[0])
		lbl.position = at + Vector2(-60, 62)
		lbl.size = Vector2(120, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(0.75, 0.78, 0.85)
		add_child(lbl)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/art_preview.png")
	print("SAVED /tmp/art_preview.png")
	get_tree().quit()
