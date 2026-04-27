extends GdUnitTestSuite

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CardDataModel := preload("res://scripts/card_data_model/card_data_model.gd")
const _PointResult := preload("res://scripts/point_calculation/point_result.gd")
const _PointCalc := preload("res://scripts/point_calculation/point_calc.gd")
const _HandTypeOption := preload("res://scripts/hand_type_detection/hand_type_option.gd")
const _HandTypeResult := preload("res://scripts/hand_type_detection/hand_type_result.gd")
const _HandTypeDetection := preload("res://scripts/hand_type_detection/hand_type_detection.gd")

var _model: CardDataModel


func before() -> void:
	_model = auto_free(CardDataModel.new())
	_model.initialize()


func after() -> void:
	_model = null


func _card(suit: int, rank: int, owner: int = CardEnums.Owner.PLAYER) -> CardInstance:
	return CardInstance.new(_model.get_prototype(suit, rank), owner)


func _hand(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for c in cards:
		result.append(c)
	return result


func _point_result(total: int, bust: bool, aces: int = 0, soft: int = 0, count: int = -1) -> PointResult:
	var r := PointResult.new()
	r.point_total = total
	r.is_bust = bust
	r.ace_count = aces
	r.soft_ace_count = soft
	r.card_count = count if count >= 0 else 0
	return r


func _find_type(result: HandTypeResult, type: int) -> HandTypeOption:
	for m in result.matches:
		if m.type == type:
			return m
	return null


# --- AC-01: Bust returns empty result ---

func test_bust_returns_empty() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.KING),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SIX),
	])
	var pr := _point_result(23, true, 0, 0, 3)
	var r := HandTypeDetection.detect(cards, pr)
	assert_int(r.matches.size()).is_equal(0)
	assert_float(r.default_multiplier).is_equal(1.0)
	assert_bool(r.has_instant_win).is_false()


# --- AC-02: Non-bust proceeds to detection (no match) ---

func test_non_bust_no_match() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.KING),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(17, false, 0, 0, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_int(r.matches.size()).is_equal(0)


# --- AC-03: PAIR detection ---

func test_pair_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FOUR),
	])
	var pr := _point_result(18, false, 0, 0, 3)
	var r := HandTypeDetection.detect(cards, pr)
	var pair := _find_type(r, HandTypeDetection.HandType.PAIR)
	assert_object(pair).is_not_null()
	assert_int(pair.display_multiplier).is_equal(2)
	assert_float(pair.per_card_multiplier[0]).is_equal(2.0)
	assert_float(pair.per_card_multiplier[1]).is_equal(2.0)
	assert_float(pair.per_card_multiplier[2]).is_equal(1.0)


# --- AC-04: FLUSH detection (multiplier = hand_size) ---

func test_flush_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.FIVE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.TWO),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(18, false, 1, 1, 5)
	var r := HandTypeDetection.detect(cards, pr)
	var flush := _find_type(r, HandTypeDetection.HandType.FLUSH)
	assert_object(flush).is_not_null()
	assert_int(flush.display_multiplier).is_equal(5)
	for i in 5:
		assert_float(flush.per_card_multiplier[i]).is_equal(5.0)


# --- AC-05: THREE_KIND detection ---

func test_three_kind_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.CLUBS, CardEnums.Rank.FIVE),
	])
	var pr := _point_result(14, false, 0, 0, 4)
	var r := HandTypeDetection.detect(cards, pr)
	var three := _find_type(r, HandTypeDetection.HandType.THREE_KIND)
	assert_object(three).is_not_null()
	assert_int(three.display_multiplier).is_equal(5)
	assert_float(three.per_card_multiplier[0]).is_equal(5.0)
	assert_float(three.per_card_multiplier[1]).is_equal(5.0)
	assert_float(three.per_card_multiplier[2]).is_equal(5.0)
	assert_float(three.per_card_multiplier[3]).is_equal(1.0)


# --- AC-06: TRIPLE_SEVEN detection ---

func test_triple_seven_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(21, false, 0, 0, 3)
	var r := HandTypeDetection.detect(cards, pr)
	var ts := _find_type(r, HandTypeDetection.HandType.TRIPLE_SEVEN)
	assert_object(ts).is_not_null()
	assert_int(ts.display_multiplier).is_equal(7)
	for i in 3:
		assert_float(ts.per_card_multiplier[i]).is_equal(7.0)


# --- AC-07: TWENTY_ONE detection ---

func test_twenty_one_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.KING),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.FIVE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SIX),
	])
	var pr := _point_result(21, false, 0, 0, 3)
	var r := HandTypeDetection.detect(cards, pr)
	var t1 := _find_type(r, HandTypeDetection.HandType.TWENTY_ONE)
	assert_object(t1).is_not_null()
	assert_int(t1.display_multiplier).is_equal(2)
	for i in 3:
		assert_float(t1.per_card_multiplier[i]).is_equal(2.0)


# --- AC-08: BLACKJACK_TYPE (A + J, exactly 2 cards) ---

func test_blackjack_type_ace_jack() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.JACK),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	var bj := _find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)
	assert_object(bj).is_not_null()
	assert_int(bj.display_multiplier).is_equal(4)
	assert_bool(bj.is_instant_win).is_false()
	assert_float(bj.per_card_multiplier[0]).is_equal(4.0)
	assert_float(bj.per_card_multiplier[1]).is_equal(4.0)


# --- AC-09: BLACKJACK_TYPE excludes Q, K, 10 ---

func test_blackjack_excludes_queen() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.QUEEN),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)).is_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.TWENTY_ONE)).is_not_null()


func test_blackjack_excludes_king() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.KING),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)).is_null()


func test_blackjack_excludes_ten() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TEN),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)).is_null()


# --- AC-10: SPADE_BLACKJACK detection ---

func test_spade_blackjack_detection() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.JACK),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	var sb := _find_type(r, HandTypeDetection.HandType.SPADE_BLACKJACK)
	assert_object(sb).is_not_null()
	assert_bool(sb.is_instant_win).is_true()
	assert_bool(r.has_instant_win).is_true()


# --- AC-11: SPADE_BLACKJACK requires exact A♠+J♠ ---

func test_spade_blackjack_excludes_spade_queen() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.QUEEN),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.SPADE_BLACKJACK)).is_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.TWENTY_ONE)).is_not_null()


# --- AC-12: Different ranks produce independent PAIRs ---

func test_independent_pairs() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.CLUBS, CardEnums.Rank.THREE),
	])
	var pr := _point_result(20, false, 0, 0, 4)
	var r := HandTypeDetection.detect(cards, pr)
	var pair_count := 0
	for m in r.matches:
		if m.type == HandTypeDetection.HandType.PAIR:
			pair_count += 1
	assert_int(pair_count).is_equal(2)


# --- AC-13: SPADE_BLACKJACK absorbs BLACKJACK_TYPE ---

func test_spade_blackjack_absorbs_blackjack() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.JACK),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.SPADE_BLACKJACK)).is_not_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)).is_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.TWENTY_ONE)).is_not_null()


# --- AC-14: Split suppresses BLACKJACK_TYPE and SPADE_BLACKJACK ---

func test_split_suppression() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.JACK),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr, true)
	assert_object(_find_type(r, HandTypeDetection.HandType.BLACKJACK_TYPE)).is_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.SPADE_BLACKJACK)).is_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.TWENTY_ONE)).is_not_null()


# --- AC-15: TRIPLE_SEVEN and THREE_KIND(7) co-occur ---

func test_triple_seven_and_three_kind_cooccur() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(21, false, 0, 0, 3)
	var r := HandTypeDetection.detect(cards, pr)
	assert_object(_find_type(r, HandTypeDetection.HandType.TRIPLE_SEVEN)).is_not_null()
	assert_object(_find_type(r, HandTypeDetection.HandType.THREE_KIND)).is_not_null()


# --- AC-16: FLUSH at 2-card hand ---

func test_flush_two_cards() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.THREE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(10, false, 0, 0, 2)
	var r := HandTypeDetection.detect(cards, pr)
	var flush := _find_type(r, HandTypeDetection.HandType.FLUSH)
	assert_object(flush).is_not_null()
	assert_int(flush.display_multiplier).is_equal(2)
	assert_float(flush.per_card_multiplier[0]).is_equal(2.0)
	assert_float(flush.per_card_multiplier[1]).is_equal(2.0)


# --- AC-18: Output structure completeness ---

func test_output_structure_completeness() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.ACE),
		_card(CardEnums.Suit.SPADES, CardEnums.Rank.JACK),
	])
	var pr := _point_result(21, false, 1, 1, 2)
	var r := HandTypeDetection.detect(cards, pr)
	assert_float(r.default_multiplier).is_equal(1.0)
	assert_bool(r.has_instant_win).is_true()
	for m in r.matches:
		assert_bool(m.display_name != "").is_true()
		assert_bool(m.display_multiplier >= 0).is_true()
		assert_int(m.per_card_multiplier.size()).is_equal(2)


# --- validate_multipliers ---

func test_validate_multipliers_default_passes() -> void:
	assert_bool(HandTypeDetection.validate_multipliers(HandTypeDetection.DEFAULT_MULTIPLIERS)).is_true()


func test_validate_multipliers_violates_hierarchy() -> void:
	var bad: Dictionary = {
		HandTypeDetection.HandType.PAIR: 6,
		HandTypeDetection.HandType.THREE_KIND: 5,
		HandTypeDetection.HandType.TRIPLE_SEVEN: 7,
		HandTypeDetection.HandType.TWENTY_ONE: 2,
		HandTypeDetection.HandType.BLACKJACK_TYPE: 4,
	}
	assert_bool(HandTypeDetection.validate_multipliers(bad)).is_false()


# --- Custom multipliers parameter ---

func test_custom_multipliers_overrides() -> void:
	var cards := _hand([
		_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN),
		_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN),
	])
	var pr := _point_result(14, false, 0, 0, 2)
	var custom: Dictionary = {
		HandTypeDetection.HandType.PAIR: 3,
		HandTypeDetection.HandType.THREE_KIND: 5,
		HandTypeDetection.HandType.TRIPLE_SEVEN: 7,
		HandTypeDetection.HandType.TWENTY_ONE: 2,
		HandTypeDetection.HandType.BLACKJACK_TYPE: 4,
	}
	var r := HandTypeDetection.detect(cards, pr, false, custom)
	var pair := _find_type(r, HandTypeDetection.HandType.PAIR)
	assert_int(pair.display_multiplier).is_equal(3)
