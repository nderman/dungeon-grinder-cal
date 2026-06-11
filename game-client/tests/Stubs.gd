# Stubs.gd
# Shared test fixtures — the stand-ins we kept re-deriving in throwaway tests. A `PlayerStub` mimics
# just the Player interface that combat/status code touches (group "player", a HealthComponent,
# speed_mult, elemental_resist), and factory helpers build common nodes parented under a test.
class_name TestStubs

# A minimal "player" for combat/status tests: in the "player" group, has a HealthComponent, exposes
# speed_mult (for Chill) and elemental_resist (for resist gear). Far cheaper than the real Player.tscn.
class PlayerStub extends CharacterBody2D:
	var speed_mult := 1.0
	var resist := {}
	func elemental_resist(kind: String) -> float:
		return float(resist.get(kind, 0.0))

static func player(host: Node, at: Vector2, resist := {}, hp := 100.0) -> PlayerStub:
	var p := PlayerStub.new()
	p.add_to_group("player")
	p.resist = resist
	p.global_position = at
	p.add_child(_health("HealthComponent", hp))
	host.add_child(p)
	return p

# A bare CharacterBody2D in a group, with a HealthComponent — a generic damage target.
static func body(host: Node, group: StringName, at: Vector2, hp := 100.0) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.add_to_group(group)
	e.global_position = at
	e.add_child(_health("HealthComponent", hp))
	host.add_child(e)
	return e

static func _health(node_name: String, hp: float) -> HealthComponent:
	var hc := HealthComponent.new()
	hc.name = node_name
	hc.configured_hearts = hp
	return hc
