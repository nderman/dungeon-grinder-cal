# CombatEffects.gd
# Stateless orchestrator for the on-hit EFFECTS that gear rolls (LootData effect-affixes, summed by
# LootData.combat_effects). One home so the player's melee swing AND ranged shots proc identically:
#   crit  — resolved at damage time so the bigger number flows through DR and shows in the HP bar.
#   leech — heals the attacker for a fraction of the damage dealt.
#   burn  — attaches a fire DoT (StatusEffect).        chill — slows the victim (StatusEffect).
#   chain — arcs a fraction of the hit to the nearest OTHER enemy, with a quick lightning streak.
class_name CombatEffects
extends RefCounted

const CRIT_MULT := 2.0
const BURN_SECONDS := 3.0
const CHILL_SECONDS := 2.5
const CHAIN_RANGE := 240.0

# Roll crit BEFORE the hit lands (melee per-enemy, ranged per-shot). Returns [damage, was_crit].
static func resolve_damage(base: float, effects: Dictionary) -> Array:
	var chance := float(effects.get("crit", 0.0))
	if chance > 0.0 and randf() < chance:
		return [base * CRIT_MULT, true]
	return [base, false]

# Fire the post-hit procs after `dealt` damage (post-DR) lands on `victim`. `attacker_hc` is the
# player's HealthComponent (for leech); null skips leech. Safe to call with an empty effects dict.
static func apply_on_hit(victim: Node, dealt: float, effects: Dictionary, attacker_hc: HealthComponent) -> void:
	if effects.is_empty() or not is_instance_valid(victim) or dealt <= 0.0:
		return
	var leech := float(effects.get("leech", 0.0))
	if leech > 0.0 and attacker_hc != null:
		attacker_hc.heal(dealt * leech)
	var burn := float(effects.get("burn", 0.0))
	if burn > 0.0:
		StatusEffect.apply(victim, StatusEffect.BURN, burn, BURN_SECONDS)
	var chill := float(effects.get("chill", 0.0))
	if chill > 0.0:
		StatusEffect.apply(victim, StatusEffect.CHILL, chill, CHILL_SECONDS)
	var chain := float(effects.get("chain", 0.0))
	if chain > 0.0:
		_chain(victim, dealt * chain)

# Arc damage to the closest OTHER enemy within range (through its DR), and draw a brief zap.
static func _chain(from: Node, dmg: float) -> void:
	if dmg <= 0.0 or not (from is Node2D):
		return
	var origin: Vector2 = (from as Node2D).global_position
	var best: Node = null
	var best_d := CHAIN_RANGE
	for e in from.get_tree().get_nodes_in_group("enemies"):
		if e == from or not (e is Node2D) or e.is_queued_for_deletion():
			continue
		var d := origin.distance_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var hc := best.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null:
		return
	var prot := best.get_node_or_null("ProtectionComponent") as ProtectionComponent
	hc.take_damage(prot.handle_incoming_damage(dmg) if prot else dmg)
	_zap(from.get_tree(), origin, (best as Node2D).global_position)

# A short-lived lightning streak between two points (art-free, frees itself).
static func _zap(tree: SceneTree, a: Vector2, b: Vector2) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.7, 0.9, 1.0, 0.9)
	# A slight mid-point jag so it reads as a bolt, not a ruler line.
	var mid := a.lerp(b, 0.5) + Vector2(b.y - a.y, a.x - b.x).normalized() * 10.0
	line.points = PackedVector2Array([a, mid, b])
	scene.add_child(line)
	tree.create_timer(0.1).timeout.connect(line.queue_free)
