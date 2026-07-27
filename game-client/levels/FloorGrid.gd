# FloorGrid.gd
# A faint grid drawn inside a floor slab. Two jobs: it sells the "computer-simulated dungeon" fiction,
# and — more practically — it gives a top-down game MOTION REFERENCE. On a flat untextured floor your
# own movement reads as floaty because nothing slides past you; a grid fixes that for free.
# Child of the floor Polygon2D, so it inherits its z (-10) and is drawn once (no per-frame cost).
class_name FloorGrid
extends Node2D

const CELL := 64.0

var rect: Rect2 = Rect2()
var line_color: Color = Color(1, 1, 1, 0.04)

func _draw() -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# Snap to a WORLD-aligned grid so lines line up across adjoining rooms and corridors instead of
	# restarting at each slab's own edge (which would read as a patchwork).
	var x := ceilf(rect.position.x / CELL) * CELL
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, 1.0)
		x += CELL
	var y := ceilf(rect.position.y / CELL) * CELL
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 1.0)
		y += CELL
