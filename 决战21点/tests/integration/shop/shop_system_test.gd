extends GdUnitTestSuite

# Story 3-4: Shop System — integration tests
# Tests: HP heal, stamp/quality purchase, purify, sell, inventory generation,
#        refresh, weighted random, edge cases

var _shop: ShopSystem
var _combat: CombatState
var _chips: ChipEconomy


func before_test() -> void:
	_combat = auto_free(CombatState.new())
	_combat.initialize()
	_chips = auto_free(ChipEconomy.new())
	_chips.initialize()
	_shop = auto_free(ShopSystem.new())
	_shop.initialize(_combat, _chips)


func _make_card(suit: int, rank: int, owner: int) -> CardInstance:
	return auto_free(CardInstance.new(CardPrototype.new(suit, rank), owner))


func _make_deck(count: int) -> Array[CardInstance]:
	var deck: Array[CardInstance] = []
	for _i: int in range(count):
		deck.append(auto_free(CardInstance.new(
			CardPrototype.new(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO),
			CardEnums.Owner.PLAYER
		)))
	return deck


# ---------------------------------------------------------------------------
# 1. HP heal: spend_chips + HP increases
# ---------------------------------------------------------------------------

func test_buy_hp_spend_chips_and_heals_player() -> void:
	_combat.player.hp = 50
	var hp_before: int = _combat.player.hp
	var chips_before: int = _chips.get_balance()

	var result: bool = _shop.buy_hp(10)
	assert_bool(result).is_true()
	assert_int(_combat.player.hp).is_equal(hp_before + 10)
	assert_int(_chips.get_balance()).is_equal(chips_before - 10 * ShopSystem.HP_COST_PER_POINT)


# ---------------------------------------------------------------------------
# 2. HP heal: cap at max_hp
# ---------------------------------------------------------------------------

func test_buy_hp_capped_at_max_hp() -> void:
	_combat.player.hp = 50
	_chips.add_chips(900, ChipEconomy.ChipSource.VICTORY_BONUS)
	var chips_before: int = _chips.get_balance()

	# 150 HP would overshoot max_hp(100), caps at 100. Cost = 150 * 5 = 750, affordable at 999.
	var result: bool = _shop.buy_hp(150)
	assert_bool(result).is_true()
	assert_int(_combat.player.hp).is_equal(_combat.player.max_hp)
	assert_int(_chips.get_balance()).is_equal(chips_before - 150 * ShopSystem.HP_COST_PER_POINT)


# ---------------------------------------------------------------------------
# 3. Stamp assign: card.stamp set after spend_chips
# ---------------------------------------------------------------------------

func test_buy_stamp_assigns_stamp_and_spends_chips() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var chips_before: int = _chips.get_balance()
	var expected_cost: int = StampSystem.get_price(CardEnums.Stamp.SWORD)

	var result: bool = _shop.buy_stamp(card, CardEnums.Stamp.SWORD)
	assert_bool(result).is_true()
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)
	assert_int(_chips.get_balance()).is_equal(chips_before - expected_cost)


# ---------------------------------------------------------------------------
# 4. Quality assign: card.quality/quality_level set after spend_chips
# ---------------------------------------------------------------------------

func test_buy_quality_assigns_quality_and_spends_chips() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var chips_before: int = _chips.get_balance()
	var expected_cost: int = QualitySystem.get_price(CardEnums.Quality.COPPER)

	var result: bool = _shop.buy_quality(card, CardEnums.Quality.COPPER)
	assert_bool(result).is_true()
	assert_int(card.quality).is_equal(CardEnums.Quality.COPPER)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	assert_int(_chips.get_balance()).is_equal(chips_before - expected_cost)


# ---------------------------------------------------------------------------
# 5. Quality assign: gem-suit validation — RUBY on DIAMONDS ok
# ---------------------------------------------------------------------------

func test_buy_quality_ruby_on_diamonds_accepted() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	_chips.add_chips(50, ChipEconomy.ChipSource.VICTORY_BONUS)
	var result: bool = _shop.buy_quality(card, CardEnums.Quality.RUBY)
	assert_bool(result).is_true()
	assert_int(card.quality).is_equal(CardEnums.Quality.RUBY)


# ---------------------------------------------------------------------------
# 6. Quality assign: gem-suit validation — RUBY on HEARTS rejected
# ---------------------------------------------------------------------------

func test_buy_quality_ruby_on_hearts_rejected() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var result: bool = _shop.buy_quality(card, CardEnums.Quality.RUBY)
	assert_bool(result).is_false()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)


# ---------------------------------------------------------------------------
# 7. Purify III -> II costs 100
# ---------------------------------------------------------------------------

func test_purify_iii_to_ii_costs_100() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.COPPER, CardEnums.QualityLevel.III)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)

	# Give enough chips (default is 100, purify costs 100)
	_chips.add_chips(50, ChipEconomy.ChipSource.VICTORY_BONUS)
	var chips_before: int = _chips.get_balance()

	var result: bool = _shop.purify(card)
	assert_bool(result).is_true()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.II)
	assert_int(_chips.get_balance()).is_equal(chips_before - 100)


# ---------------------------------------------------------------------------
# 8. Purify II -> I costs 200
# ---------------------------------------------------------------------------

func test_purify_ii_to_i_costs_200() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.COPPER, CardEnums.QualityLevel.II)

	# Need at least 200 chips; default is 100
	_chips.add_chips(200, ChipEconomy.ChipSource.VICTORY_BONUS)
	var chips_before: int = _chips.get_balance()

	var result: bool = _shop.purify(card)
	assert_bool(result).is_true()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.I)
	assert_int(_chips.get_balance()).is_equal(chips_before - 200)


# ---------------------------------------------------------------------------
# 9. Purify rejected if quality = NONE
# ---------------------------------------------------------------------------

func test_purify_rejected_when_no_quality() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)

	var result: bool = _shop.purify(card)
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# 10. Purify rejected if quality_level = I
# ---------------------------------------------------------------------------

func test_purify_rejected_when_quality_level_i() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.COPPER, CardEnums.QualityLevel.I)

	var result: bool = _shop.purify(card)
	assert_bool(result).is_false()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.I)


# ---------------------------------------------------------------------------
# 11. Sell: refund = int(investment * 0.50), stamp/quality cleared
# ---------------------------------------------------------------------------

func test_sell_refund_is_half_investment_and_clears_enhancements() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.COPPER)

	var investment: int = card.prototype.base_buy_price \
		+ StampSystem.get_price(card.stamp) \
		+ QualitySystem.get_price(card.quality)
	var expected_refund: int = int(investment * 0.50)
	var chips_before: int = _chips.get_balance()

	var refund: int = _shop.sell_card(card)
	assert_int(refund).is_equal(expected_refund)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(_chips.get_balance()).is_equal(chips_before + refund)


# ---------------------------------------------------------------------------
# 12. Sell card with no enhancements: refund = int(base_buy_price * 0.50)
# ---------------------------------------------------------------------------

func test_sell_no_enhancements_refund_is_half_base_price() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var expected_refund: int = int(card.prototype.base_buy_price * 0.50)

	var refund: int = _shop.sell_card(card)
	assert_int(refund).is_equal(expected_refund)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)


# ---------------------------------------------------------------------------
# 13. Weighted random: seeded RNG produces deterministic inventory
# ---------------------------------------------------------------------------

func test_seeded_rng_produces_deterministic_inventory() -> void:
	var deck: Array[CardInstance] = _make_deck(5)

	_shop.set_rng_seed(42)
	var inv1: Array[ShopItem] = _shop.generate_inventory(deck, 1)

	_shop.set_rng_seed(42)
	var inv2: Array[ShopItem] = _shop.generate_inventory(deck, 1)

	assert_int(inv1.size()).is_equal(inv2.size())
	for i: int in inv1.size():
		assert_int(inv1[i].kind).is_equal(inv2[i].kind)
		assert_int(inv1[i].price).is_equal(inv2[i].price)


# ---------------------------------------------------------------------------
# 14. Weighted random without replacement: 2 stamps are distinct
# ---------------------------------------------------------------------------

func test_two_random_stamps_are_distinct() -> void:
	# Run many seeds to verify no duplicates in stamp pair
	for seed_val: int in range(1, 50):
		_shop.set_rng_seed(seed_val)
		var deck: Array[CardInstance] = _make_deck(5)
		var inv: Array[ShopItem] = _shop.generate_inventory(deck, 1)

		# First two items are stamps
		assert_int(inv[0].kind).is_equal(ShopItem.Kind.STAMP)
		assert_int(inv[1].kind).is_equal(ShopItem.Kind.STAMP)
		assert_int(inv[0].stamp).is_not_equal(inv[1].stamp)


# ---------------------------------------------------------------------------
# 15. Refresh: re-rolls inventory at 20 chip cost
# ---------------------------------------------------------------------------

func test_refresh_rerolls_inventory_at_cost() -> void:
	var deck: Array[CardInstance] = _make_deck(5)
	_shop.set_rng_seed(1)
	var inv_before: Array[ShopItem] = _shop.generate_inventory(deck, 1)

	_shop.set_rng_seed(2)
	var chips_before: int = _chips.get_balance()
	var result: bool = _shop.refresh_inventory(deck, 1)

	assert_bool(result).is_true()
	assert_int(_chips.get_balance()).is_equal(chips_before - 20)
	var inv_after: Array[ShopItem] = _shop.get_current_inventory()
	assert_int(inv_after.size()).is_equal(4)


# ---------------------------------------------------------------------------
# 16. Refresh fails if insufficient chips
# ---------------------------------------------------------------------------

func test_refresh_fails_if_insufficient_chips() -> void:
	var deck: Array[CardInstance] = _make_deck(5)
	_shop.generate_inventory(deck, 1)

	# Drain chips to below refresh cost
	while _chips.get_balance() > 0:
		_chips.spend_chips(1, ChipEconomy.ChipPurpose.SHOP_PURCHASE)

	var result: bool = _shop.refresh_inventory(deck, 1)
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# 17. Insufficient chips: all purchases rejected without mutation
# ---------------------------------------------------------------------------

func test_buy_stamp_rejected_when_insufficient_chips() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)

	# Drain all chips
	while _chips.get_balance() > 0:
		_chips.spend_chips(1, ChipEconomy.ChipPurpose.SHOP_PURCHASE)

	var result: bool = _shop.buy_stamp(card, CardEnums.Stamp.SWORD)
	assert_bool(result).is_false()
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)


func test_buy_quality_rejected_when_insufficient_chips() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)

	while _chips.get_balance() > 0:
		_chips.spend_chips(1, ChipEconomy.ChipPurpose.SHOP_PURCHASE)

	var result: bool = _shop.buy_quality(card, CardEnums.Quality.COPPER)
	assert_bool(result).is_false()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)


func test_buy_hp_rejected_when_insufficient_chips() -> void:
	while _chips.get_balance() > 0:
		_chips.spend_chips(1, ChipEconomy.ChipPurpose.SHOP_PURCHASE)

	_combat.player.hp = 10
	var result: bool = _shop.buy_hp(10)
	assert_bool(result).is_false()
	assert_int(_combat.player.hp).is_equal(10)


# ---------------------------------------------------------------------------
# 18. Buy stamp overwrites existing stamp
# ---------------------------------------------------------------------------

func test_buy_stamp_overwrites_existing_stamp() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	_shop.buy_stamp(card, CardEnums.Stamp.SWORD)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)

	_chips.add_chips(200, ChipEconomy.ChipSource.VICTORY_BONUS)
	_shop.buy_stamp(card, CardEnums.Stamp.COIN)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.COIN)


# ---------------------------------------------------------------------------
# 19. Buy quality overwrites existing quality
# ---------------------------------------------------------------------------

func test_buy_quality_overwrites_existing_quality() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	_shop.buy_quality(card, CardEnums.Quality.COPPER)
	assert_int(card.quality).is_equal(CardEnums.Quality.COPPER)

	_chips.add_chips(200, ChipEconomy.ChipSource.VICTORY_BONUS)
	_shop.buy_quality(card, CardEnums.Quality.SILVER)
	assert_int(card.quality).is_equal(CardEnums.Quality.SILVER)


# ---------------------------------------------------------------------------
# 20. Chip cap not exceeded by sell refund
# ---------------------------------------------------------------------------

func test_sell_refund_respects_chip_cap() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE, CardEnums.Owner.PLAYER)
	# Ace of Hearts base_buy_price = 75 (chip_value)
	card.assign_stamp(CardEnums.Stamp.HAMMER)
	card.assign_quality(CardEnums.Quality.DIAMOND_Q)

	# Set balance near cap
	_chips.add_chips(9900, ChipEconomy.ChipSource.VICTORY_BONUS)
	assert_int(_chips.get_balance()).is_equal(ChipEconomy.CHIP_CAP)

	_shop.sell_card(card)
	assert_int(_chips.get_balance()).is_equal(ChipEconomy.CHIP_CAP)


# ---------------------------------------------------------------------------
# 21. generate_inventory with empty deck
# ---------------------------------------------------------------------------

func test_generate_inventory_empty_deck_returns_only_stamps() -> void:
	var empty_deck: Array[CardInstance] = []
	_shop.set_rng_seed(1)
	var inv: Array[ShopItem] = _shop.generate_inventory(empty_deck, 1)

	# Only the 2 stamps, no enhanced cards
	assert_int(inv.size()).is_equal(2)
	assert_int(inv[0].kind).is_equal(ShopItem.Kind.STAMP)
	assert_int(inv[1].kind).is_equal(ShopItem.Kind.STAMP)


# ---------------------------------------------------------------------------
# 22. Enhanced card generation: stamp vs quality split (deterministic)
# ---------------------------------------------------------------------------

func test_enhanced_card_items_have_valid_kind() -> void:
	var deck: Array[CardInstance] = _make_deck(5)
	_shop.set_rng_seed(123)
	var inv: Array[ShopItem] = _shop.generate_inventory(deck, 1)

	# Items 2 and 3 (index) are enhanced cards
	for i: int in range(2, inv.size()):
		assert_bool(inv[i].kind == ShopItem.Kind.CARD_STAMP or inv[i].kind == ShopItem.Kind.CARD_QUALITY).is_true()
		assert_object(inv[i].target_card).is_not_null()


# ---------------------------------------------------------------------------
# 23. HP heal returns false with 0 or negative amount
# ---------------------------------------------------------------------------

func test_buy_hp_rejected_zero_amount() -> void:
	var result: bool = _shop.buy_hp(0)
	assert_bool(result).is_false()


func test_buy_hp_rejected_negative_amount() -> void:
	var result: bool = _shop.buy_hp(-5)
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# 24. Double-sell guard: second sell returns 0 and no chip gain
# ---------------------------------------------------------------------------

func test_sell_card_twice_returns_zero_on_second_call() -> void:
	var card: CardInstance = _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)

	var first_refund: int = _shop.sell_card(card)
	assert_int(first_refund).is_greater(0)
	var chips_after_first: int = _chips.get_balance()

	var second_refund: int = _shop.sell_card(card)
	assert_int(second_refund).is_equal(0)
	assert_int(_chips.get_balance()).is_equal(chips_after_first)
