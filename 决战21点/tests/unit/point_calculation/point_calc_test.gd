extends GdUnitTestSuite

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CardDataModel := preload("res://scripts/card_data_model/card_data_model.gd")
const _PointResult := preload("res://scripts/point_calculation/point_result.gd")
const _PointCalc := preload("res://scripts/point_calculation/point_calc.gd")

var _model: CardDataModel


func before() -> void:
	_model = auto_free(CardDataModel.new())
	_model.initialize()


func after() -> void:
	_model = null


func _make_hand(ranks: Array, suit: int = CardEnums.Suit.HEARTS, owner: int = CardEnums.Owner.PLAYER) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for r in ranks:
		var proto := _model.get_prototype(suit, r)
		cards.append(CardInstance.new(proto, owner))
	return cards


func _make_result(total: int, bust: bool, aces: int, soft: int, count: int) -> Dictionary:
	return {
		"point_total": total,
		"is_bust": bust,
		"ace_count": aces,
		"soft_ace_count": soft,
		"card_count": count,
	}


func _assert_result(result: PointResult, expected: Dictionary, label: String) -> void:
	assert_int(result.point_total).is_equal(expected.point_total)
	assert_bool(result.is_bust).is_equal(expected.is_bust)
	assert_int(result.ace_count).is_equal(expected.ace_count)
	assert_int(result.soft_ace_count).is_equal(expected.soft_ace_count)
	assert_int(result.card_count).is_equal(expected.card_count)


# --- AC-01: Standard hand (no Aces) ---

func test_calculate_hand_standard_no_ace() -> void:
	var cards := _make_hand([CardEnums.Rank.SEVEN, CardEnums.Rank.KING, CardEnums.Rank.THREE])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(20, false, 0, 0, 3), "standard_no_ace")


# --- AC-02: Single Ace soft hand ---

func test_calculate_hand_single_ace_soft() -> void:
	var cards := _make_hand([CardEnums.Rank.ACE, CardEnums.Rank.SEVEN])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(18, false, 1, 1, 2), "single_ace_soft")


# --- AC-03: Ace downgrade to hit 21 ---

func test_calculate_hand_ace_downgrade_to_21() -> void:
	var cards := _make_hand([
		CardEnums.Rank.ACE, CardEnums.Rank.ACE, CardEnums.Rank.NINE,
	], CardEnums.Suit.HEARTS, CardEnums.Owner.PLAYER)
	# Use different suits to create distinct CardInstances
	var hand: Array[CardInstance] = []
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.SPADES, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.DIAMONDS, CardEnums.Rank.NINE), CardEnums.Owner.PLAYER))
	var r := PointCalc.calculate_hand(hand)
	_assert_result(r, _make_result(21, false, 2, 1, 3), "ace_downgrade_21")


# --- AC-04: Bust (no Ace) ---

func test_calculate_hand_bust_no_ace() -> void:
	var cards := _make_hand([CardEnums.Rank.KING, CardEnums.Rank.SEVEN, CardEnums.Rank.SIX])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(23, true, 0, 0, 3), "bust_no_ace")


# --- AC-05: Four Aces ---

func test_calculate_hand_four_aces() -> void:
	var hand: Array[CardInstance] = []
	var suits := [CardEnums.Suit.HEARTS, CardEnums.Suit.DIAMONDS, CardEnums.Suit.SPADES, CardEnums.Suit.CLUBS]
	for s in suits:
		hand.append(CardInstance.new(_model.get_prototype(s, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	var r := PointCalc.calculate_hand(hand)
	_assert_result(r, _make_result(14, false, 4, 1, 4), "four_aces")


# --- AC-06: Empty array ---

func test_calculate_hand_empty() -> void:
	var cards: Array[CardInstance] = []
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(0, false, 0, 0, 0), "empty")


# --- AC-07: Exactly 21 (boundary) ---

func test_calculate_hand_exactly_21() -> void:
	var hand: Array[CardInstance] = []
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.KING), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	var r := PointCalc.calculate_hand(hand)
	_assert_result(r, _make_result(21, false, 1, 1, 2), "exactly_21")
	assert_bool(r.is_bust).is_false()


# --- AC-08: Exactly 22 (minimum bust) ---

func test_calculate_hand_exactly_22() -> void:
	var cards := _make_hand([CardEnums.Rank.KING, CardEnums.Rank.FIVE, CardEnums.Rank.SEVEN])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(22, true, 0, 0, 3), "exactly_22")
	assert_bool(r.is_bust).is_true()


# --- AC-09: simulate_hit non-Ace card ---

func test_simulate_hit_non_ace() -> void:
	var current := PointResult.new()
	current.point_total = 12
	current.is_bust = false
	current.ace_count = 0
	current.soft_ace_count = 0
	current.card_count = 2
	var new_card := CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.EIGHT), CardEnums.Owner.PLAYER)
	var r := PointCalc.simulate_hit(current, new_card)
	_assert_result(r, _make_result(20, false, 0, 0, 3), "sim_hit_non_ace")


# --- AC-10: simulate_hit Ace card ---

func test_simulate_hit_ace() -> void:
	var current := PointResult.new()
	current.point_total = 10
	current.is_bust = false
	current.ace_count = 0
	current.soft_ace_count = 0
	current.card_count = 1
	var new_card := CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER)
	var r := PointCalc.simulate_hit(current, new_card)
	_assert_result(r, _make_result(21, false, 1, 1, 2), "sim_hit_ace")


# --- AC-11: simulate_hit cascade downgrade ---

func test_simulate_hit_cascade_downgrade() -> void:
	var current := PointResult.new()
	current.point_total = 18
	current.is_bust = false
	current.ace_count = 1
	current.soft_ace_count = 1
	current.card_count = 2
	var new_card := CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.EIGHT), CardEnums.Owner.PLAYER)
	var r := PointCalc.simulate_hit(current, new_card)
	_assert_result(r, _make_result(16, false, 1, 0, 3), "sim_hit_cascade")


# --- AC-12: simulate_hit on busted hand ---

func test_simulate_hit_on_bust() -> void:
	var current := PointResult.new()
	current.point_total = 23
	current.is_bust = true
	current.ace_count = 0
	current.soft_ace_count = 0
	current.card_count = 3
	var new_card := CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.FIVE), CardEnums.Owner.PLAYER)
	var r := PointCalc.simulate_hit(current, new_card)
	_assert_result(r, _make_result(28, true, 0, 0, 4), "sim_hit_on_bust")


# --- AC-13: PointResult field completeness ---

func test_point_result_has_five_fields() -> void:
	var hand: Array[CardInstance] = []
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.KING), CardEnums.Owner.PLAYER))
	var r := PointCalc.calculate_hand(hand)
	_assert_result(r, _make_result(21, false, 1, 1, 2), "field_completeness")


# --- AC-14: Pure function determinism ---

func test_calculate_hand_deterministic() -> void:
	var cards := _make_hand([CardEnums.Rank.ACE, CardEnums.Rank.SEVEN, CardEnums.Rank.KING])
	var first := PointCalc.calculate_hand(cards)
	for i in range(5):
		var again := PointCalc.calculate_hand(cards)
		assert_int(again.point_total).is_equal(first.point_total)
		assert_bool(again.is_bust).is_equal(first.is_bust)
		assert_int(again.ace_count).is_equal(first.ace_count)
		assert_int(again.soft_ace_count).is_equal(first.soft_ace_count)


# --- AC-15: Single card input ---

func test_calculate_hand_single_king() -> void:
	var cards := _make_hand([CardEnums.Rank.KING])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(10, false, 0, 0, 1), "single_king")


func test_calculate_hand_single_ace() -> void:
	var cards := _make_hand([CardEnums.Rank.ACE])
	var r := PointCalc.calculate_hand(cards)
	_assert_result(r, _make_result(11, false, 1, 1, 1), "single_ace")


# --- AC-16: All rank categories mapped correctly ---

func test_rank_value_mapping() -> void:
	var cases: Dictionary = {
		CardEnums.Rank.TWO: {"total": 2, "soft": 0},
		CardEnums.Rank.FIVE: {"total": 5, "soft": 0},
		CardEnums.Rank.TEN: {"total": 10, "soft": 0},
		CardEnums.Rank.JACK: {"total": 10, "soft": 0},
		CardEnums.Rank.QUEEN: {"total": 10, "soft": 0},
		CardEnums.Rank.KING: {"total": 10, "soft": 0},
		CardEnums.Rank.ACE: {"total": 11, "soft": 1},
	}
	for rank in cases:
		var cards := _make_hand([rank])
		var r := PointCalc.calculate_hand(cards)
		assert_int(r.point_total).is_equal(cases[rank]["total"])
		assert_int(r.soft_ace_count).is_equal(cases[rank]["soft"])


# --- AC-18: Downgrade stops exactly at 21 ---

func test_downgrade_stops_at_21() -> void:
	var hand: Array[CardInstance] = []
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.SPADES, CardEnums.Rank.ACE), CardEnums.Owner.PLAYER))
	hand.append(CardInstance.new(_model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.NINE), CardEnums.Owner.PLAYER))
	var r := PointCalc.calculate_hand(hand)
	assert_int(r.point_total).is_equal(21)
