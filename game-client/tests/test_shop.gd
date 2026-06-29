extends TestCase
# Town-vendor economy: Gold pricing (tier/rarity scaling), the Scavenger's Extreme Coupons discount,
# build-aware stock roll, and the buy flow (spend Gold, grant item, leave the shelf).
func _init() -> void: test_name = "shop"

func run() -> void:
	var s_gold := GameManager.gold
	var s_stock := GameManager.shop_stock.duplicate(true)
	var s_floor := GameManager.current_floor
	var s_race := GameManager.current_race
	var s_class := GameManager.current_class
	var s_hotbar := GameManager.hotbar.duplicate(true)

	# --- Pricing -------------------------------------------------------------------------------
	var hp0 := {"kind": "consumable", "base": "health_potion", "tier": 0}
	var hp2 := {"kind": "consumable", "base": "health_potion", "tier": 2}
	eq(LootData.price(hp0), LootData.SHOP_CONSUMABLE_PRICE, "a tier-0 consumable costs the base consumable price")
	check(LootData.price(hp2) > LootData.price(hp0), "a higher-tier consumable costs more")

	# Same gear base, different rarity → the Rare costs more (and gear is always priced > 0).
	var geared := LootData.roll(2, {}, "gear")
	check(not geared.is_empty(), "rolled a gear instance to price")
	var b := String(geared["base"])
	var r0 := {"kind": "gear", "base": b, "slot": geared.get("slot", ""), "rarity": 0, "affixes": []}
	var r2 := {"kind": "gear", "base": b, "slot": geared.get("slot", ""), "rarity": 2, "affixes": []}
	check(LootData.price(r0) > 0, "gear has a positive price")
	check(LootData.price(r2) > LootData.price(r0), "a rarer roll of the same base costs more")

	# A tome is an investment (> a potion); a granted-ability affix adds a premium over a plain piece.
	var tome := {"kind": "consumable", "base": "tome_blink", "tier": 0}
	check(LootData.price(tome) > LootData.price(hp0), "a tome costs more than a potion")
	var grantw := {"kind": "gear", "base": b, "slot": "Weapon", "rarity": 2, "affixes": [{"grant": "blink"}]}
	var plainw := {"kind": "gear", "base": b, "slot": "Weapon", "rarity": 2, "affixes": []}
	check(LootData.price(grantw) > LootData.price(plainw), "a granted-ability affix adds a price premium")

	# --- Scavenger discount (Extreme Coupons) --------------------------------------------------
	GameManager.current_race = "Human"
	GameManager.current_class = "Scavenger"
	approx(GameManager.shop_price_mult(), 0.8, "Extreme Coupons = -20% vendor prices")
	eq(GameManager.shop_price(r2), maxi(1, int(round(LootData.price(r2) * 0.8))), "shop_price folds in the discount")
	GameManager.current_class = "Brawler"
	approx(GameManager.shop_price_mult(), 1.0, "no discount without Scavenger")

	# --- Stock roll ----------------------------------------------------------------------------
	GameManager.current_floor = 4
	GameManager.roll_shop_stock()
	check(GameManager.shop_stock.size() > 0, "the vendor stocks wares")
	check(GameManager.shop_stock.size() <= GameManager.SHOP_GEAR_COUNT + GameManager.SHOP_SUPPLY_COUNT,
		"stock stays within the configured counts")

	# --- Buy flow (controlled stock so it's RNG-free) ------------------------------------------
	GameManager.shop_stock = [{"kind": "consumable", "base": "health_potion", "tier": 0}]
	GameManager.gold = 1000
	var price0 := GameManager.shop_price(GameManager.shop_stock[0])
	check(GameManager.buy_shop_item(0), "an affordable buy succeeds")
	eq(GameManager.gold, 1000 - price0, "Gold drops by exactly the listed price")
	eq(GameManager.shop_stock.size(), 0, "the bought item leaves the shelf")

	# Broke → no-op; bad index → no-op.
	GameManager.shop_stock = [{"kind": "consumable", "base": "health_potion", "tier": 0}]
	GameManager.gold = 0
	check(not GameManager.buy_shop_item(0), "can't buy when broke")
	eq(GameManager.shop_stock.size(), 1, "a failed buy leaves the shelf untouched")
	check(not GameManager.buy_shop_item(7), "an out-of-range index is a no-op")

	# Dead purchase: a tome for an ability you already hold at MAX_LEVEL is refused before charging.
	var aid := String(LootData.consumable_effect("tome_blink", 0).get("ability", ""))
	var had := aid in GameManager.known_abilities
	var prev_uses: Variant = GameManager.ability_uses.get(aid, null)
	if not had:
		GameManager.known_abilities.append(aid)
	GameManager.ability_uses[aid] = 100000   # force MAX_LEVEL
	GameManager.shop_stock = [{"kind": "consumable", "base": "tome_blink", "tier": 0}]
	GameManager.gold = 1000
	check(GameManager.shop_item_is_dead(GameManager.shop_stock[0]), "a maxed-ability tome reads as a dead purchase")
	check(not GameManager.buy_shop_item(0), "the vendor refuses a dead purchase")
	eq(GameManager.gold, 1000, "a refused purchase charges no Gold")
	if not had:
		GameManager.known_abilities.erase(aid)
	if prev_uses == null:
		GameManager.ability_uses.erase(aid)
	else:
		GameManager.ability_uses[aid] = prev_uses

	GameManager.gold = s_gold
	GameManager.shop_stock = s_stock
	GameManager.current_floor = s_floor
	GameManager.current_race = s_race
	GameManager.current_class = s_class
	GameManager.hotbar = s_hotbar
