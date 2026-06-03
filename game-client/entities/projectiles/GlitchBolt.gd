# GlitchBolt.gd
# A travelling Nano-Magic projectile. Movement lives here; DAMAGE is delegated to the
# child HitboxComponent (composition) — it routes through the victim's DR -> Health and
# frees this projectile on a successful hit (one_shot).
extends Node2D

@export var speed: float = 700.0
@export var lifetime: float = 1.0   # range = speed × lifetime ≈ 700px ≈ one room (CELL 768)
var direction: Vector2 = Vector2.RIGHT

# Called by the caster right after instancing. scale_mult/color let a spell (Fireball) be a big,
# distinct projectile instead of looking like a plain weapon shot.
func setup(dir: Vector2, damage: float, group: StringName = &"enemies", scale_mult: float = 1.0, color: Color = Color.TRANSPARENT) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	if scale_mult != 1.0:
		scale = Vector2.ONE * scale_mult   # scales the Visual AND the Hitbox → a fat fireball hits bigger
	if color.a > 0.0:                       # TRANSPARENT sentinel = keep the scene's default colour
		($Visual as Polygon2D).color = color
	var hb := $Hitbox as HitboxComponent
	if hb:
		hb.damage_hearts = damage
		hb.target_group = group

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
