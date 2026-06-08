# Corpse.gd
# A lootable drop left where a mob died. Walk over it (Area2D senses the player) to collect its
# COMMON drip — gold, and sometimes a basic potion. Loot Boxes remain the source of better gear.
# Auto-fades after a while so uncollected corpses don't clutter the floor.
extends Area2D

const LIFETIME := 25.0   # seconds before an uncollected corpse fades

var _gold: int = 0
var _potion: String = ""   # "" = none; else a consumable base to grant
var _collected: bool = false

func setup(gold: int, potion: String = "") -> void:
	_gold = gold
	_potion = potion

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Fade + free if left uncollected.
	var tw := create_tween()
	tw.tween_interval(LIFETIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	SignalBus.ratings_spike.emit("GRAVE_ROBBER")   # "Grave Robber" — looted the dead
	if _gold > 0:
		GameManager.add_gold(_gold)
		SignalBus.toast.emit("+%d gold" % _gold, global_position)
	if _potion != "":
		GameManager.add_consumable(_potion, 0)
		SignalBus.toast.emit(LootData.item_name(_potion), global_position + Vector2(0, -16))
	queue_free()
