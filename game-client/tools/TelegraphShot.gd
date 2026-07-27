# TelegraphShot.gd (dev tool)
# End-to-end proof that attack telegraphs actually reach the screen: loads a real floor, drops the
# player into a mob cluster so they aggro, then waits for ANY enemy to enter the TELEGRAPH state and
# screenshots that exact frame.
#   Godot --rendering-driver opengl3 --resolution 1280x720 res://tools/TelegraphShot.tscn
extends Node2D

func _ready() -> void:
	add_child.call_deferred((load("res://Floor.tscn") as PackedScene).instantiate())
	for i in range(4):
		await get_tree().process_frame

	var mobs := get_tree().get_nodes_in_group("enemies")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if mobs.is_empty() or player == null:
		print("NO MOBS"); get_tree().quit(); return

	# Pick an ACTIVE mob (boss-room adds start dormant and never attack) and stand INSIDE its attack
	# range — parking just outside it means it chases forever and never winds up.
	var victim: Node2D = null
	for e in mobs:
		var ai: Node = e.get_node_or_null("AIComponent")
		if ai and ai.start_active:
			victim = e as Node2D
			break
	if victim == null:
		victim = mobs[0] as Node2D
	player.global_position = victim.global_position + Vector2(30, 0)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2(1.4, 1.4)

	# Poll for a live telegraph, then grab that frame.
	for frame in range(1200):
		await get_tree().process_frame
		for e in get_tree().get_nodes_in_group("enemies"):
			var ai: Node = e.get_node_or_null("AIComponent")
			if ai == null:
				continue
			if ai.current_state == ai.State.TELEGRAPH:
				var fx: Node = e.get_node_or_null("TelegraphFx")
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/tmp/telegraph.png")
				print("SAVED /tmp/telegraph.png  frame=%d  fx_visible=%s" % [frame, str(fx.visible) if fx else "NO FX NODE"])
				get_tree().quit()
				return
		if is_instance_valid(victim):   # stay in its face so aggro + attack range hold
			player.global_position = victim.global_position + Vector2(30, 0)
	var states := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		var ai: Node = e.get_node_or_null("AIComponent")
		if ai:
			var k := "state%d_active%s" % [ai.current_state, str(ai._active)]
			states[k] = int(states.get(k, 0)) + 1
	print("NO TELEGRAPH SEEN in 1200 frames — enemy states: %s" % str(states))
	get_tree().quit()
