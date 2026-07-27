# BeautyShot.gd (dev tool)
# Generates a real floor, drops the camera into the most populated combat room, and saves a PNG — so
# the art can be judged IN CONTEXT (mobs, walls, cover, grid) instead of on an isolated sheet.
#   Godot --rendering-driver opengl3 --resolution 1280x720 res://tools/BeautyShot.tscn
extends Node2D

func _ready() -> void:
	var floor_scene: PackedScene = load("res://Floor.tscn")
	add_child.call_deferred(floor_scene.instantiate())   # deferred: the tree is mid-setup during _ready
	for i in range(4):
		await get_tree().process_frame

	# Frame the densest knot of mobs — the most interesting shot on the floor.
	var mobs := get_tree().get_nodes_in_group("enemies")
	var focus := Vector2.ZERO
	var best_n := -1
	for a in mobs:
		var n := 0
		for b in mobs:
			if (a as Node2D).global_position.distance_to((b as Node2D).global_position) < 420.0:
				n += 1
		if n > best_n:
			best_n = n
			focus = (a as Node2D).global_position

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and best_n > 0:
		player.global_position = focus   # camera rides the player
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.zoom = Vector2(0.72, 0.72)   # pull back to frame the room
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/beauty.png")
	print("SAVED /tmp/beauty.png  (room mobs: %d)" % best_n)
	get_tree().quit()
