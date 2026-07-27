extends TestCase
# The art pass: every archetype resolves to a real polygon, and — the one that actually bites — every
# entity SCENE references a shape the component knows. A typo like shape="brut" would silently fall
# through to the generic blob and nobody would notice until it shipped.
func _init() -> void: test_name = "silhouette"

const KNOWN := Silhouette.SHAPES   # single source of truth — don't redeclare it here, it WILL drift

const SCENES := [
	"res://entities/player/Player.tscn", "res://entities/enemies/BaseEnemy.tscn",
	"res://entities/enemies/GlitchGoblin.tscn", "res://entities/enemies/Screamer.tscn",
	"res://entities/enemies/Brute.tscn", "res://entities/enemies/ShieldBotCleric.tscn",
	"res://entities/enemies/Healer.tscn", "res://entities/enemies/SyndicateSniper.tscn",
	"res://entities/enemies/MeatGrinderGolem.tscn", "res://entities/enemies/HexgunTurret.tscn",
	"res://entities/enemies/Showrunner.tscn", "res://entities/NonCombatantNPC.tscn",
]

func run() -> void:
	var s := Silhouette.new()
	add_child(s)
	for kind in KNOWN:
		check(s._points(kind, 16.0).size() >= 3, "'%s' resolves to a drawable polygon" % kind)
	# An unknown name still draws SOMETHING (a blob) rather than vanishing.
	check(s._points("not_a_shape", 16.0).size() >= 3, "an unknown shape falls back to a blob, never nothing")
	s.queue_free()

	# Every entity scene must carry a Silhouette with a known shape and a sane radius.
	for path in SCENES:
		var inst := (load(path) as PackedScene).instantiate()
		var vis := inst.get_node_or_null("Visual")
		check(vis is Silhouette, "%s has a Silhouette visual" % path.get_file())
		if vis is Silhouette:
			check(vis.shape in KNOWN, "%s uses a known shape (got '%s')" % [path.get_file(), vis.shape])
			check(vis.radius > 0.0, "%s has a positive radius" % path.get_file())
		inst.free()
