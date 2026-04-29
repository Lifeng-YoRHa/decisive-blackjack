extends GdUnitTestSuite

# Story 3-2: Card Quality System — unit tests
# Tests: quality_bonus_resolve, gem_destroy_prob, is_gem, prices, CardInstance integration


func test_copper_bonus_all_levels() -> void:
	var iii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.COPPER, CardEnums.QualityLevel.III)
	assert_int(iii.combat_value).is_equal(0)
	assert_int(iii.chip_value).is_equal(10)
	assert_int(iii.combat_type).is_equal(QualitySystem.CombatType.NONE)

	var ii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.COPPER, CardEnums.QualityLevel.II)
	assert_int(ii.chip_value).is_equal(15)

	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.COPPER, CardEnums.QualityLevel.I)
	assert_int(i.chip_value).is_equal(20)


func test_silver_bonus() -> void:
	var iii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.SILVER, CardEnums.QualityLevel.III)
	assert_int(iii.chip_value).is_equal(20)
	assert_int(iii.combat_value).is_equal(0)

	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.SILVER, CardEnums.QualityLevel.I)
	assert_int(i.chip_value).is_equal(36)


func test_gold_bonus() -> void:
	var iii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.GOLD, CardEnums.QualityLevel.III)
	assert_int(iii.chip_value).is_equal(30)

	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.GOLD, CardEnums.QualityLevel.I)
	assert_int(i.chip_value).is_equal(50)


func test_diamond_bonus() -> void:
	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.DIAMOND_Q, CardEnums.QualityLevel.I)
	assert_int(i.chip_value).is_equal(82)
	assert_int(i.combat_value).is_equal(0)


func test_ruby_bonus() -> void:
	var ii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)
	assert_int(ii.combat_value).is_equal(4)
	assert_int(ii.combat_type).is_equal(QualitySystem.CombatType.DAMAGE)
	assert_int(ii.chip_value).is_equal(0)


func test_sapphire_bonus() -> void:
	var iii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.SAPPHIRE, CardEnums.QualityLevel.III)
	assert_int(iii.combat_value).is_equal(3)
	assert_int(iii.combat_type).is_equal(QualitySystem.CombatType.HEAL)
	assert_int(iii.chip_value).is_equal(0)

	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.SAPPHIRE, CardEnums.QualityLevel.I)
	assert_int(i.combat_value).is_equal(5)


func test_emerald_bonus() -> void:
	var ii: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.EMERALD, CardEnums.QualityLevel.II)
	assert_int(ii.combat_type).is_equal(QualitySystem.CombatType.CHIPS)
	assert_int(ii.combat_value).is_equal(0)
	assert_int(ii.chip_value).is_equal(20)


func test_obsidian_bonus() -> void:
	var i: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.I)
	assert_int(i.combat_value).is_equal(5)
	assert_int(i.combat_type).is_equal(QualitySystem.CombatType.DEFENSE)
	assert_int(i.chip_value).is_equal(0)


func test_none_bonus() -> void:
	var result: Dictionary = QualitySystem.resolve_bonus(CardEnums.Quality.NONE, CardEnums.QualityLevel.III)
	assert_int(result.combat_value).is_equal(0)
	assert_int(result.chip_value).is_equal(0)
	assert_int(result.combat_type).is_equal(QualitySystem.CombatType.NONE)


func test_invalid_quality_returns_none() -> void:
	var result: Dictionary = QualitySystem.resolve_bonus(999, CardEnums.QualityLevel.III)
	assert_int(result.combat_value).is_equal(0)
	assert_int(result.chip_value).is_equal(0)


func test_gem_destroy_prob() -> void:
	assert_float(QualitySystem.gem_destroy_prob(CardEnums.QualityLevel.III)).is_equal(0.15)
	assert_float(QualitySystem.gem_destroy_prob(CardEnums.QualityLevel.II)).is_equal(0.10)
	assert_float(QualitySystem.gem_destroy_prob(CardEnums.QualityLevel.I)).is_equal(0.05)


func test_gem_destroy_prob_invalid_returns_0() -> void:
	assert_float(QualitySystem.gem_destroy_prob(999)).is_equal(0.0)


func test_is_gem() -> void:
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.RUBY)).is_true()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.SAPPHIRE)).is_true()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.EMERALD)).is_true()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.OBSIDIAN)).is_true()


func test_is_not_gem() -> void:
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.NONE)).is_false()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.COPPER)).is_false()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.SILVER)).is_false()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.GOLD)).is_false()
	assert_bool(QualitySystem.is_gem(CardEnums.Quality.DIAMOND_Q)).is_false()


func test_is_valid_assignment_gem_suit_binding() -> void:
	# Ruby → Diamonds only
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.RUBY)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.RUBY)).is_false()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.RUBY)).is_false()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.RUBY)).is_false()

	# Sapphire → Hearts only
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.SAPPHIRE)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.SAPPHIRE)).is_false()

	# Emerald → Clubs only
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.EMERALD)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.EMERALD)).is_false()

	# Obsidian → Spades only
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.OBSIDIAN)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.OBSIDIAN)).is_false()


func test_is_valid_assignment_metals_unrestricted() -> void:
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.COPPER)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.SILVER)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.GOLD)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.DIAMOND_Q)).is_true()


func test_is_valid_assignment_none_always_true() -> void:
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.NONE)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.NONE)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.NONE)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.NONE)).is_true()


func test_card_instance_assign_quality() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)

	card.assign_quality(CardEnums.Quality.RUBY)
	assert_int(card.quality).is_equal(CardEnums.Quality.RUBY)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	assert_int(card.revision).is_equal(1)


func test_card_instance_assign_quality_custom_level() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)

	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)
	assert_int(card.quality).is_equal(CardEnums.Quality.RUBY)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.II)


func test_card_instance_destroy_quality() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.I)

	card.destroy_quality()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)


func test_card_instance_purify() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.COPPER)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)

	var result: bool = card.purify()
	assert_bool(result).is_true()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.II)

	result = card.purify()
	assert_bool(result).is_true()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.I)

	result = card.purify()
	assert_bool(result).is_false()
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.I)


func test_card_instance_purify_rejected_when_no_quality() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)

	var result: bool = card.purify()
	assert_bool(result).is_false()


func test_quality_prices() -> void:
	assert_int(QualitySystem.get_price(CardEnums.Quality.COPPER)).is_equal(40)
	assert_int(QualitySystem.get_price(CardEnums.Quality.SILVER)).is_equal(80)
	assert_int(QualitySystem.get_price(CardEnums.Quality.GOLD)).is_equal(120)
	assert_int(QualitySystem.get_price(CardEnums.Quality.DIAMOND_Q)).is_equal(200)
	assert_int(QualitySystem.get_price(CardEnums.Quality.RUBY)).is_equal(120)
	assert_int(QualitySystem.get_price(CardEnums.Quality.SAPPHIRE)).is_equal(120)
	assert_int(QualitySystem.get_price(CardEnums.Quality.EMERALD)).is_equal(120)
	assert_int(QualitySystem.get_price(CardEnums.Quality.OBSIDIAN)).is_equal(120)


func test_purify_costs() -> void:
	assert_int(QualitySystem.get_purify_cost(CardEnums.QualityLevel.III)).is_equal(100)
	assert_int(QualitySystem.get_purify_cost(CardEnums.QualityLevel.II)).is_equal(200)
	assert_int(QualitySystem.get_purify_cost(CardEnums.QualityLevel.I)).is_equal(0)


func test_sell_clears_quality() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.I)
	card.assign_stamp(CardEnums.Stamp.SWORD)

	card.sell_card()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)


func test_destroy_does_not_affect_stamp() -> void:
	var proto := CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	var card := CardInstance.new(proto, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)

	card.destroy_quality()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)
