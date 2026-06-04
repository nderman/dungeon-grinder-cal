# HitboxComponent.gd
# The damaging Area2D carried by a projectile, melee swing, or trap. On contact it
# routes damage through the victim's ProtectionComponent (DR roll) into HealthComponent.
# Set `target_group` to "player" (enemy attacks) or "enemies" (player attacks).
extends Area2D
class_name HitboxComponent

@export var damage_hearts: float = 1.0
@export var target_group: StringName = &"enemies"
@export var one_shot: bool = true   # projectiles despawn after a hit

# Emitted after damage lands, with the victim and the post-DR amount dealt — lets the carrier
# (e.g. a player bolt) fire on-hit gear EFFECTS via CombatEffects without this node knowing them.
signal hit_landed(victim: Node, dealt: float)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area.get_parent())

func _try_hit(victim: Node) -> void:
	if victim == null:
		return
	# Stop on solid level geometry (walls + lock barriers) — no shooting through walls.
	if victim is StaticBody2D:
		_consume()
		return
	if not victim.is_in_group(target_group):
		return
	var health := victim.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return
	var dmg := damage_hearts
	var prot := victim.get_node_or_null("ProtectionComponent") as ProtectionComponent
	if prot:
		dmg = prot.handle_incoming_damage(dmg)
	health.take_damage(dmg)
	hit_landed.emit(victim, dmg)
	_consume()

func _consume() -> void:
	if one_shot and get_parent() is Node2D:
		get_parent().queue_free()
