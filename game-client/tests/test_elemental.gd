extends TestCase
# Enemy elemental attacks hit the player; resist gear mitigates; IGNITE only for enemy victims;
# surviving a burn emits DOUSED.
func _init() -> void: test_name = "elemental"

const BRUTE := preload("res://entities/enemies/Brute.tscn")

func run() -> void:
	var spikes: Array = []
	var cb := func(t): spikes.append(t)
	SignalBus.ratings_spike.connect(cb)

	# A Brute (chill on hit) slows the player it strikes.
	var brute := BRUTE.instantiate()
	add_child(brute)
	brute.global_position = Vector2.ZERO
	var victim := TestStubs.player(self, Vector2(40, 0))
	brute.get_node("AIComponent").target = victim
	brute.get_node("AIComponent")._hit_target()
	approx(victim.speed_mult, 1.0 - 0.35, "Brute chill drops player speed_mult")

	# Resistance scales an incoming status's power AND duration.
	var r := TestStubs.player(self, Vector2(0, 200), {"burn": 0.5})
	StatusEffect.apply(r, StatusEffect.BURN, 1.0, 3.0)
	var burn := r.get_node_or_null("Status_burn")
	truthy(burn, "burn attaches to the player")
	if burn:
		approx(burn._power, 0.5, "50% fire resist halves burn power")
		approx(burn._remaining, 1.5, "50% fire resist halves burn duration")

	# Resist is CAPPED — even 80% on gear can't make you near-immune (clamps to RESIST_CAP).
	var rr := TestStubs.player(self, Vector2(0, 600), {"burn": 0.8})
	StatusEffect.apply(rr, StatusEffect.BURN, 1.0, 3.0)
	var capped := rr.get_node_or_null("Status_burn")
	if capped:
		approx(capped._power, 1.0 * (1.0 - StatusEffect.RESIST_CAP), "fire resist caps at RESIST_CAP, not 80%")

	# IGNITE (Pyromaniac) must NOT fire when the PLAYER is the one burned.
	var pre := spikes.count("IGNITE")
	StatusEffect.apply(TestStubs.player(self, Vector2(0, 400)), StatusEffect.BURN, 1.0, 2.0)
	eq(spikes.count("IGNITE"), pre, "burning the player does not award Pyromaniac")

	# DOUSED: a burn that expires while the player lives.
	var survivor := TestStubs.player(self, Vector2(200, 400))
	StatusEffect.apply(survivor, StatusEffect.BURN, 0.5, 0.1)
	await get_tree().create_timer(0.3).timeout
	truthy("DOUSED" in spikes, "surviving a burn emits DOUSED")

	SignalBus.ratings_spike.disconnect(cb)
