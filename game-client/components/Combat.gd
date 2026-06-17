# Combat.gd
# The single chokepoint for "deal damage to a thing." Every source — player melee/ranged, enemy
# attacks, bomb blasts, chain arcs, ability novas — routes raw damage through the victim's
# ProtectionComponent (DR + dodge) into its HealthComponent. Returns the HP ACTUALLY removed (post-DR;
# 0 if dodged / i-framed / dormant / already dead / no HealthComponent) so callers can leech off the
# real number or detect a kill. This tail was copy-pasted in 6 places — centralised here so a new
# damage source can't accidentally bypass DR or hit a dormant boss through the door.
class_name Combat
extends RefCounted

static func deal(victim: Node, raw: float) -> float:
	if raw <= 0.0 or not is_instance_valid(victim):
		return 0.0
	var hc := victim.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null or hc.current_hearts <= 0.0 or hc.is_invulnerable():
		return 0.0   # nothing to hurt — dead, dormant/i-framed, or no health pool
	var prot := victim.get_node_or_null("ProtectionComponent") as ProtectionComponent
	var before := hc.current_hearts
	hc.take_damage(prot.handle_incoming_damage(raw) if prot else raw)
	return before - hc.current_hearts
