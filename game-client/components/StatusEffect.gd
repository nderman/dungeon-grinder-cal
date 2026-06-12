# StatusEffect.gd
# A timed on-hit status attached to a VICTIM (an enemy via CombatEffects, OR the player via an
# enemy's elemental attack):
#   BURN  — ticks damage-over-time into the victim's HealthComponent (a fire DoT).
#   CHILL — drops the victim's speed_mult so it crawls (AIComponent for mobs, the Player node for the
#           player), restored when the status ends.
# Resistant victims (the player, via fire/frost-resist gear) take a weaker, shorter status — see apply().
# One node per (victim, kind): a fresh hit REFRESHES the timer and keeps the stronger power instead
# of stacking nodes. Art-free _draw paints a small marker above the body so the status reads on
# screen. Self-frees on expiry (chill restores speed first); dies with the victim like any child.
class_name StatusEffect
extends Node2D

const BURN := "burn"
const CHILL := "chill"
const TICK := 0.5             # burn applies damage in half-second ticks
const MAX_SLOW := 0.8         # chill can never freeze a mob solid (always ≥20% speed)
const RESIST_CAP := 0.6      # fire/frost resist can shrug off at most 60% of a status (never ~immune)

var kind := BURN
var _remaining := 0.0
var _power := 0.0             # burn: hearts/sec · chill: slow fraction (0.35 = 35% slower)
var _tick_accum := 0.0
var _marker_y := -26.0        # draw the marker above the body

# Attach-or-refresh. Keeps a single node per (victim, kind); a re-hit refreshes time and takes the
# stronger power so spamming hits doesn't spawn a pile of tickers.
static func apply(victim: Node, k: String, power: float, seconds: float) -> void:
	if not is_instance_valid(victim) or power <= 0.0:
		return
	# Resistance gear (the player) takes a weaker AND shorter status — fully resists if it scales to 0.
	if victim.has_method("elemental_resist"):
		var resist := clampf(victim.elemental_resist(k), 0.0, RESIST_CAP)
		power *= (1.0 - resist)
		seconds *= (1.0 - resist)
		if power <= 0.0 or seconds <= 0.0:
			return
	var existing := victim.get_node_or_null("Status_" + k) as StatusEffect
	if existing != null:
		existing._remaining = maxf(existing._remaining, seconds)
		existing._power = maxf(existing._power, power)
		if k == CHILL:
			existing._apply_chill()
		return
	var s := StatusEffect.new()
	s.kind = k
	s._power = power
	s._remaining = seconds
	s.name = "Status_" + k
	victim.add_child(s)
	if k == BURN and not victim.is_in_group("player"):
		SignalBus.ratings_spike.emit("IGNITE")   # "Pyromaniac" — YOU set an ENEMY ablaze (not yourself)

func _ready() -> void:
	if kind == CHILL:
		_apply_chill()

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_end()
		return
	if kind == BURN:
		_tick_accum += delta
		if _tick_accum >= TICK:
			_tick_accum -= TICK
			var hc := get_parent().get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				hc.apply_dot(_power * TICK)   # DoT bypasses armour/i-frames — already inside you
	queue_redraw()   # flicker the marker

func _apply_chill() -> void:
	_set_speed_mult(1.0 - clampf(_power, 0.0, MAX_SLOW))

# Chill drives speed_mult on the mob's AIComponent, or directly on the Player node (no AIComponent).
func _set_speed_mult(m: float) -> void:
	var ai := get_parent().get_node_or_null("AIComponent")
	if ai != null:
		ai.speed_mult = m
	elif "speed_mult" in get_parent():
		get_parent().speed_mult = m

func _end() -> void:
	if kind == CHILL:
		_set_speed_mult(1.0)
	elif kind == BURN and get_parent().is_in_group("player"):
		var hc := get_parent().get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_hearts > 0.0:
			SignalBus.ratings_spike.emit("DOUSED")   # "Stop, Drop & Roll" — survived being on fire
	queue_free()

# Art-free status marker bobbing above the body: a flickering flame for burn, a frost shard for chill.
func _draw() -> void:
	var flick := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.02)
	if kind == BURN:
		var tip := Vector2(0.0, _marker_y - 8.0 * flick)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-5, _marker_y + 4), tip, Vector2(5, _marker_y + 4)]),
			Color(1.0, 0.45, 0.1, 0.9))
		draw_colored_polygon(
			PackedVector2Array([Vector2(-2.5, _marker_y + 4), Vector2(0, _marker_y - 3.0 * flick), Vector2(2.5, _marker_y + 4)]),
			Color(1.0, 0.85, 0.3, 0.95))
	else:   # CHILL — a pale frost diamond
		var c := Color(0.6, 0.85, 1.0, 0.5 + 0.4 * flick)
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, _marker_y - 6), Vector2(5, _marker_y), Vector2(0, _marker_y + 6), Vector2(-5, _marker_y)]),
			c)
