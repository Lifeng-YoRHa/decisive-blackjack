extends GdUnitTestSuite

# Story 3-1: Stamp System — unit tests
# Tests: stamp_bonus_lookup, stamp_sort_key, combat/coin bonus helpers, CardInstance.stamp integration


func test_sword_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.SWORD)
	assert_int(bonus.value).is_equal(2)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.DAMAGE)


func test_shield_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.SHIELD)
	assert_int(bonus.value).is_equal(2)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.DEFENSE)


func test_heart_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.HEART)
	assert_int(bonus.value).is_equal(2)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.HEAL)


func test_coin_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.COIN)
	assert_int(bonus.value).is_equal(10)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.CHIPS)


func test_hammer_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.HAMMER)
	assert_int(bonus.value).is_equal(0)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.NULLIFY_TARGET)


func test_running_shoes_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.RUNNING_SHOES)
	assert_int(bonus.value).is_equal(0)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.SORT_FIRST)


func test_turtle_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.TURTLE)
	assert_int(bonus.value).is_equal(0)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.SORT_LAST)


func test_none_bonus() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(CardEnums.Stamp.NONE)
	assert_int(bonus.value).is_equal(0)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.NONE)


func test_invalid_stamp_returns_none() -> void:
	var bonus: Dictionary = StampSystem.get_bonus(999)
	assert_int(bonus.value).is_equal(0)
	assert_int(bonus.type).is_equal(StampSystem.StampEffectType.NONE)


func test_sort_key_running_shoes_is_0() -> void:
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.RUNNING_SHOES)).is_equal(0)


func test_sort_key_turtle_is_2() -> void:
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.TURTLE)).is_equal(2)


func test_sort_key_default_stamps_are_1() -> void:
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.NONE)).is_equal(1)
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.SWORD)).is_equal(1)
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.SHIELD)).is_equal(1)
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.HEART)).is_equal(1)
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.COIN)).is_equal(1)
	assert_int(StampSystem.get_sort_key(CardEnums.Stamp.HAMMER)).is_equal(1)


func test_sort_key_invalid_is_1() -> void:
	assert_int(StampSystem.get_sort_key(999)).is_equal(1)


func test_combat_bonus_returns_value_for_combat_types() -> void:
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.SWORD)).is_equal(2)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.SHIELD)).is_equal(2)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.HEART)).is_equal(2)


func test_combat_bonus_returns_0_for_non_combat_types() -> void:
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.COIN)).is_equal(0)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.HAMMER)).is_equal(0)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.RUNNING_SHOES)).is_equal(0)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.TURTLE)).is_equal(0)
	assert_int(StampSystem.get_combat_bonus(CardEnums.Stamp.NONE)).is_equal(0)


func test_coin_bonus_returns_10_for_coin() -> void:
	assert_int(StampSystem.get_coin_bonus(CardEnums.Stamp.COIN)).is_equal(10)


func test_coin_bonus_returns_0_for_non_coin() -> void:
	assert_int(StampSystem.get_coin_bonus(CardEnums.Stamp.SWORD)).is_equal(0)
	assert_int(StampSystem.get_coin_bonus(CardEnums.Stamp.NONE)).is_equal(0)
	assert_int(StampSystem.get_coin_bonus(CardEnums.Stamp.HAMMER)).is_equal(0)


func test_is_sort_stamp() -> void:
	assert_bool(StampSystem.is_sort_stamp(CardEnums.Stamp.RUNNING_SHOES)).is_true()
	assert_bool(StampSystem.is_sort_stamp(CardEnums.Stamp.TURTLE)).is_true()
	assert_bool(StampSystem.is_sort_stamp(CardEnums.Stamp.SWORD)).is_false()
	assert_bool(StampSystem.is_sort_stamp(CardEnums.Stamp.NONE)).is_false()


func test_is_hammer() -> void:
	assert_bool(StampSystem.is_hammer(CardEnums.Stamp.HAMMER)).is_true()
	assert_bool(StampSystem.is_hammer(CardEnums.Stamp.SWORD)).is_false()
	assert_bool(StampSystem.is_hammer(CardEnums.Stamp.NONE)).is_false()


func test_stamp_prices() -> void:
	assert_int(StampSystem.get_price(CardEnums.Stamp.SWORD)).is_equal(100)
	assert_int(StampSystem.get_price(CardEnums.Stamp.SHIELD)).is_equal(100)
	assert_int(StampSystem.get_price(CardEnums.Stamp.HEART)).is_equal(100)
	assert_int(StampSystem.get_price(CardEnums.Stamp.COIN)).is_equal(100)
	assert_int(StampSystem.get_price(CardEnums.Stamp.RUNNING_SHOES)).is_equal(150)
	assert_int(StampSystem.get_price(CardEnums.Stamp.TURTLE)).is_equal(150)
	assert_int(StampSystem.get_price(CardEnums.Stamp.HAMMER)).is_equal(300)


func test_stamp_price_none_is_0() -> void:
	assert_int(StampSystem.get_price(CardEnums.Stamp.NONE)).is_equal(0)


func test_card_instance_assign_stamp() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)
	assert_int(card.revision).is_equal(0)

	card.assign_stamp(CardEnums.Stamp.SWORD)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)
	assert_int(card.revision).is_equal(1)


func test_card_instance_stamp_overwrite() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)

	card.assign_stamp(CardEnums.Stamp.SWORD)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)

	card.assign_stamp(CardEnums.Stamp.COIN)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.COIN)
	assert_int(card.revision).is_equal(2)


func test_card_instance_sell_clears_stamp() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.HAMMER)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.HAMMER)

	card.sell_card()
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)


func test_stable_sort_order() -> void:
	# Simulate hand: [Turtle(2), RunningShoes(0), Default(1), RunningShoes(0), Default(1)]
	# Expected after stable sort by sort_key: [RS, RS, Default, Default, Turtle]
	var sort_keys: Array[int] = [
		StampSystem.get_sort_key(CardEnums.Stamp.TURTLE),
		StampSystem.get_sort_key(CardEnums.Stamp.RUNNING_SHOES),
		StampSystem.get_sort_key(CardEnums.Stamp.NONE),
		StampSystem.get_sort_key(CardEnums.Stamp.RUNNING_SHOES),
		StampSystem.get_sort_key(CardEnums.Stamp.SWORD),
	]
	assert_int(sort_keys[0]).is_equal(2)
	assert_int(sort_keys[1]).is_equal(0)
	assert_int(sort_keys[2]).is_equal(1)
	assert_int(sort_keys[3]).is_equal(0)
	assert_int(sort_keys[4]).is_equal(1)
