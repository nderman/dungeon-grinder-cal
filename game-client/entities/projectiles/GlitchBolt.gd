# GlitchBolt.gd
# A travelling Nano-Magic projectile. Movement lives here; DAMAGE is delegated to the
# child HitboxComponent (composition) — it routes through the victim's DR -> Health and
# frees this projectile on a successful hit (one_shot).
extends Node2D

@export var speed: float = 700.0
@export var lifetime: float = 1.0   # range = speed × lifetime ≈ 700px ≈ one room (CELL 768)
var direction: Vector2 = Vector2.RIGHT

# On-hit gear EFFECTS this bolt carries (empty for spells / enemy fire). Applied via CombatEffects
# when the Hitbox lands. _attacker is the player's HealthComponent so leech can heal the shooter.
var _effects: Dictionary = {}
var _attacker: HealthComponent = null

# Called by the caster right after instancing. scale_mult/color let a spell (Fireball) be a big,
# distinct projectile instead of looking like a plain weapon shot.
func setup(dir: Vector2, damage: float, group: StringName = &"enemies", scale_mult: float = 1.0, color: Color = Color.TRANSPARENT) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	if scale_mult != 1.0:
		scale = Vector2.ONE * scale_mult   # scales the Visual AND the Hitbox -> a fat fireball hits bigger
	if color.a > 0.0:                       # TRANSPARENT sentinel = keep the scene's default colour
		($Visual as Polygon2D).color = color
	var hb := $Hitbox as HitboxComponent
	if hb:
		hb.damage_hearts = damage
		hb.target_group = group

# Optional: attach the shooter's gear effects (leech/burn/chill/chain) so a ranged weapon procs
# them just like a melee swing. Called by the Player after setup() for weapon fire only.
func arm_effects(effects: Dictionary, attacker: HealthComponent) -> void:
	_effects = effects
	_attacker = attacker
	if not effects.is_empty():
		var hb := $Hitbox as HitboxComponent
		if hb:
			hb.hit_landed.connect(_on_hit_landed)

func _on_hit_landed(victim: Node, dealt: float) -> void:
	CombatEffects.apply_on_hit(victim, dealt, _effects, _attacker)

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
