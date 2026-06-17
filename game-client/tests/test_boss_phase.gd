extends TestCase
# BossPhaseComponent: a one-shot ENRAGE the first time HP crosses the threshold (with a DRAMA_SPIKE)
# and a FATALITY + toast on death, by watching a sibling HealthComponent — the lifecycle the three
# bosses used to each hand-roll. Drives a bare HealthComponent so it's independent of any boss scene.
func _init() -> void: test_name = "boss_phase"

func run() -> void:
	var boss := Node2D.new()
	add_child(boss)
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	boss.add_child(hc)
	hc.initialize_health(10.0)
	var phase := BossPhaseComponent.new()
	phase.defeat_toast = "DOWN!"
	boss.add_child(phase)   # _ready wires it to the sibling HealthComponent

	var enrage_count := [0]                              # array so the lambda can mutate it
	var on_enrage := func(): enrage_count[0] += 1
	phase.enraged.connect(on_enrage)
	var spikes: Array = []
	var on_spike := func(t): spikes.append(t)
	SignalBus.ratings_spike.connect(on_spike)

	hc.take_damage(4.0)   # 60% left — above the 50% threshold
	check(enrage_count[0] == 0, "no enrage above the threshold")
	hc.take_damage(2.0)   # 40% — crosses 50%
	check(enrage_count[0] == 1, "enrage fires once when HP crosses the threshold")
	check("DRAMA_SPIKE" in spikes, "enrage pops a DRAMA_SPIKE for the audience")
	hc.take_damage(1.0)   # still below — must NOT re-fire
	check(enrage_count[0] == 1, "enrage is one-shot")

	hc.take_damage(20.0)  # dead
	check("FATALITY" in spikes, "death pops a FATALITY")

	SignalBus.ratings_spike.disconnect(on_spike)   # leave the autoload's signal clean for sibling tests
