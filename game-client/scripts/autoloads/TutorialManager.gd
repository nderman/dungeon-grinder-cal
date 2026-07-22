# TutorialManager.gd (Autoload)
# As-you-go onboarding: the first time a new player meets each core system (loot, levels, abilities,
# the Safe Room, stairs, potion sickness), fire ONE contextual hint that teaches it in place — the
# antidote to "too complex from the start". Each hint shows ONCE EVER (MetaManager.tutorial_seen,
# persisted), so veterans are never nagged. Hints ride SignalBus.toast.
# Glyphs are limited to the bundled font's coverage (★ → ⚠ · — no SMP emoji, which render as tofu).
extends Node

const HINTS := {
	"first_box": "★ Loot earned! Find a Phase-Door and duck into the Safe Room to open it.",
	"first_level": "★ Level up! Spend points at the Safe-Room terminal — STR melee · DEX speed/dodge · INT spells · CON health · CHA crowd.",
	"first_ability": "New ability! Press Q to cast it — bind more in the Abilities panel (K).",
	"first_stairs": "The stairs are open → reach them to descend, or keep fighting for loot before the floor collapses.",
	"first_safe_room": "Safe Room: crack your loot boxes and spend skill points here. No enemies — breathe.",
	"potion_sickness": "⚠ Potion sickness! Chugging too fast poisons you — wait for the cooldown, or carry an Antidote.",
}

func _ready() -> void:
	GameManager.loot_boxes_changed.connect(_on_boxes)
	GameManager.abilities_changed.connect(_on_abilities)
	GameManager.stairs_opened.connect(func(): _fire("first_stairs"))
	SignalBus.leveled_up.connect(func(_lvl, _pts): _fire("first_level"))
	SignalBus.phasedoor_discovered.connect(func(_loc): _fire("first_safe_room"))
	SignalBus.potion_sickness.connect(func(): _fire("potion_sickness"))

func _on_boxes(count: int) -> void:
	if count > 0:
		_fire("first_box")

func _on_abilities() -> void:
	if not GameManager.known_abilities.is_empty():
		_fire("first_ability")

# Show a hint the first time only; mark it seen (persisted on the next save).
func _fire(key: String) -> void:
	if not HINTS.has(key) or MetaManager.has_seen_hint(key):
		return
	MetaManager.mark_hint_seen(key)
	SignalBus.toast.emit(String(HINTS[key]), _player_pos())

func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player")
	return (p as Node2D).global_position if p is Node2D else Vector2.ZERO
