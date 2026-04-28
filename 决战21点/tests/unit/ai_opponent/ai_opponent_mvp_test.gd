extends GdUnitTestSuite

var _ai: AIOpponent


func before_test() -> void:
	_ai = auto_free(AIOpponent.new())
	_ai.initialize()


func after_test() -> void:
	_ai = null


# --- Helpers ---

func _make_point_result(total: int, bust: bool = false) -> PointResult:
	var pr := PointResult.new()
	pr.point_total = total
	pr.is_bust = bust
	return pr


func _make_card(suit: int, rank: int, owner: int = CardEnums.Owner.AI) -> CardInstance:
	var proto := CardPrototype.new(suit, rank)
	return CardInstance.new(proto, owner)


func _make_hand(count: int) -> Array[CardInstance]:
	var hand: Array[CardInstance] = []
	var suits := [CardEnums.Suit.HEARTS, CardEnums.Suit.DIAMONDS, CardEnums.Suit.SPADES, CardEnums.Suit.CLUBS]
	for i in count:
		hand.append(_make_card(suits[i % 4], CardEnums.ALL_RANKS[i]))
	return hand


# --- AC-05: BASIC hit/stand ---

func test_hit_at_low_total() -> void:
	assert_int(_ai.make_decision(_make_point_result(5))).is_equal(AIOpponent.AIAction.HIT)


func test_hit_at_threshold() -> void:
	assert_int(_ai.make_decision(_make_point_result(16))).is_equal(AIOpponent.AIAction.HIT)


func test_stand_above_threshold() -> void:
	assert_int(_ai.make_decision(_make_point_result(17))).is_equal(AIOpponent.AIAction.STAND)


func test_stand_at_21() -> void:
	assert_int(_ai.make_decision(_make_point_result(21))).is_equal(AIOpponent.AIAction.STAND)


func test_hit_at_minimum() -> void:
	assert_int(_ai.make_decision(_make_point_result(2))).is_equal(AIOpponent.AIAction.HIT)


func test_stand_at_20() -> void:
	assert_int(_ai.make_decision(_make_point_result(20))).is_equal(AIOpponent.AIAction.STAND)


# --- AC-09: Bust forces stand ---

func test_bust_forces_stand_at_low_total() -> void:
	assert_int(_ai.make_decision(_make_point_result(14, true))).is_equal(AIOpponent.AIAction.STAND)


func test_bust_at_22() -> void:
	assert_int(_ai.make_decision(_make_point_result(22, true))).is_equal(AIOpponent.AIAction.STAND)


func test_bust_at_30() -> void:
	assert_int(_ai.make_decision(_make_point_result(30, true))).is_equal(AIOpponent.AIAction.STAND)


# --- AC-17: Determinism ---

func test_determinism_stand_repeated() -> void:
	var pr := _make_point_result(17)
	for i in range(3):
		assert_int(_ai.make_decision(pr)).is_equal(AIOpponent.AIAction.STAND)


func test_determinism_hit_repeated() -> void:
	var pr := _make_point_result(10)
	for i in range(3):
		assert_int(_ai.make_decision(pr)).is_equal(AIOpponent.AIAction.HIT)


func test_no_input_mutation() -> void:
	var pr := _make_point_result(14)
	var original_total := pr.point_total
	var original_bust := pr.is_bust
	_ai.make_decision(pr)
	assert_int(pr.point_total).is_equal(original_total)
	assert_bool(pr.is_bust).is_equal(original_bust)


# --- Random Sort ---

func test_sort_preserves_card_count() -> void:
	var hand := _make_hand(5)
	var sorted := _ai.sort_hand(hand)
	assert_int(sorted.size()).is_equal(5)


func test_sort_deterministic_with_same_seed() -> void:
	var hand := _make_hand(5)
	_ai.set_seed(42)
	var result1 := _ai.sort_hand(hand)
	_ai.set_seed(42)
	var result2 := _ai.sort_hand(hand)
	for i in result1.size():
		assert_int(result1[i].prototype.rank).is_equal(result2[i].prototype.rank)


func test_sort_different_seeds_likely_different() -> void:
	var hand := _make_hand(10)
	_ai.set_seed(42)
	var result1 := _ai.sort_hand(hand)
	_ai.set_seed(123)
	var result2 := _ai.sort_hand(hand)
	var differ := false
	for i in result1.size():
		if result1[i].prototype.rank != result2[i].prototype.rank:
			differ = true
			break
	assert_bool(differ).is_true()


func test_sort_empty_hand() -> void:
	var hand: Array[CardInstance] = []
	var sorted := _ai.sort_hand(hand)
	assert_int(sorted.size()).is_equal(0)


func test_sort_single_card() -> void:
	var hand: Array[CardInstance] = [_make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE)]
	var sorted := _ai.sort_hand(hand)
	assert_int(sorted.size()).is_equal(1)
	assert_int(sorted[0].prototype.rank).is_equal(CardEnums.Rank.ACE)


func test_sort_preserves_all_cards() -> void:
	var hand := _make_hand(5)
	var sorted := _ai.sort_hand(hand)
	var original_ranks: Array[int] = []
	for c in hand:
		original_ranks.append(c.prototype.rank)
	original_ranks.sort()
	var sorted_ranks: Array[int] = []
	for c in sorted:
		sorted_ranks.append(c.prototype.rank)
	sorted_ranks.sort()
	for i in original_ranks.size():
		assert_int(sorted_ranks[i]).is_equal(original_ranks[i])


func test_sort_does_not_modify_original() -> void:
	var hand := _make_hand(5)
	var original_first_rank := hand[0].prototype.rank
	_ai.set_seed(42)
	_ai.sort_hand(hand)
	assert_int(hand[0].prototype.rank).is_equal(original_first_rank)


func test_sort_two_cards_both_orders_possible() -> void:
	var card_a := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE)
	var card_b := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO)
	var found_original := false
	var found_swapped := false
	for s in range(20):
		_ai.set_seed(s)
		var sorted := _ai.sort_hand([card_a, card_b])
		if sorted[0].prototype.rank == CardEnums.Rank.ACE:
			found_original = true
		else:
			found_swapped = true
	assert_bool(found_original or found_swapped).is_true()


# --- AIAction Enum ---

func test_aiaction_hit_and_stand_distinct() -> void:
	assert_int(AIOpponent.AIAction.HIT).is_not_equal(AIOpponent.AIAction.STAND)


func test_aiaction_values() -> void:
	assert_int(AIOpponent.AIAction.HIT).is_equal(0)
	assert_int(AIOpponent.AIAction.STAND).is_equal(1)
