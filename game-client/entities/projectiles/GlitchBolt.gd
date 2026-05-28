# GlitchBolt.gd
# A travelling Nano-Magic projectile. Movement lives here; DAMAGE is delegated to the
# child HitboxComponent (composition) — it routes through the victim's DR -> Health and
# frees this projectile on a successful hit (one_shot).
extends Node2D

@export var speed: float = 700.0
@export var lifetime: float = 2.0
var direction: Vector2 = Vector2.RIGHT

# Called by the caster right after instancing.
func setup(dir: Vector2, damage: float, group: StringName = &"enemies") -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
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
