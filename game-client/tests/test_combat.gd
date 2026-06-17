extends TestCase
# Combat.deal — the single damage chokepoint: routes raw damage through DR into the HealthComponent,
# reports the HP ACTUALLY removed, and refuses dead / invulnerable / componentless / zero targets.
# Plus the i-frame split this refactor introduced: a HELD invuln (dash / boss dormancy) and the TIMED
# post-hit window are independent sources that can no longer cancel each other.
func _init() -> void: test_name = "combat"

func run() -> void:
	var e := TestStubs.body(self, &"enemies", Vector2(50, 0), 20.0)
	approx(Combat.deal(e, 5.0), 5.0, "deal() removes the damage and reports the amount dealt")
	approx(e.get_node("HealthComponent").current_hearts, 15.0, "victim HP dropped by the dealt amount")

	# Held-invulnerable / null / zero are clean no-ops that report 0 dealt.
	e.get_node("HealthComponent").set_invulnerable(true)
	approx(Combat.deal(e, 5.0), 0.0, "no damage to a held-invulnerable target")
	approx(e.get_node("HealthComponent").current_hearts, 15.0, "invulnerable HP unchanged")
	e.get_node("HealthComponent").set_invulnerable(false)
	approx(Combat.deal(null, 5.0), 0.0, "null victim is a no-op")
	approx(Combat.deal(e, 0.0), 0.0, "zero raw damage is a no-op")

	# i-frame independence — the exact bug this refactor fixes.
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.iframe_seconds = 5.0
	add_child(hc)
	hc.initialize_health(10.0)
	hc.is_player = true                  # post-hit i-frames are player-only
	hc.set_invulnerable(true)            # dashing (held)
	hc.take_damage(2.0)
	approx(hc.current_hearts, 10.0, "held invuln blocks the hit — no window opened")
	hc.set_invulnerable(false)           # dash ends
	check(not hc.is_invulnerable(), "releasing the held flag with no active window = vulnerable again")
	hc.take_damage(2.0)                  # lands → opens the timed window
	approx(hc.current_hearts, 8.0, "the hit lands once the held flag is released")
	check(hc.is_invulnerable(), "a landed hit opens the post-hit i-frame window")
	hc.set_invulnerable(true)            # dash again mid-window…
	hc.set_invulnerable(false)           # …and ending that dash must NOT clear the window
	check(hc.is_invulnerable(), "toggling the held flag leaves the active post-hit window intact")
