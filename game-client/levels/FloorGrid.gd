# FloorGrid.gd
# A faint grid drawn inside a floor slab. Two jobs: it sells the "computer-simulated dungeon" fiction,
# and — more practically — it gives a top-down game MOTION REFERENCE. On a flat untextured floor your
# own movement reads as floaty because nothing slides past you; a grid fixes that for free.
# Child of the floor Polygon2D, so it inherits its z (-10) and is drawn once (no per-frame cost).
class_name FloorGrid
extends Node2D

const CELL := 64.0

var rect: Rect2 = Rect2()               # slab bounds, in THIS node's local space
var line_color: Color = Color(1, 1, 1, 0.05)

func _draw() -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# Snap against WORLD position so lines continue across adjoining rooms and corridors instead of
	# restarting per slab. Rooms hand us LOCAL corners centred on zero and sit at an arbitrary BSP
	# centre, so without folding that offset back in, every room's grid started on its own phase —
	# producing exactly the patchwork this is meant to avoid.
	var origin := global_position
	var x := ceilf((rect.position.x + origin.x) / CELL) * CELL - origin.x
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, 1.0)
		x += CELL
	var y := ceilf((rect.position.y + origin.y) / CELL) * CELL - origin.y
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 1.0)
		y += CELL
