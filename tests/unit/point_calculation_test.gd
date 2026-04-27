# Framework validation + point calculation spec test
# Validates GdUnit4 infrastructure and encodes the core scoring formula
# from GDD point-calculation-engine.md / ADR-0011 for TDD reference.
extends GdUnitTestSuite

const BUST_THRESHOLD := 21

# Calculate hand value using the Ace greedy algorithm from ADR-0011.
# Pure function — no scene tree, no side effects.
static func calculate_hand(card_values: Array[int]) -> int:
	var total := 0
	var aces := 0
	for v in card_values:
		if v == 11:
			aces += 1
		total += v
	while total > BUST_THRESHOLD and aces > 0:
		total -= 10
		aces -= 1
	return total

func test_single_ten_value_card_returns_face_value() -> void:
	# Arrange
	var values: Array[int] = [10]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 10)

func test_ace_eleven_when_under_bust() -> void:
	# Arrange
	var values: Array[int] = [11, 8]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 19)

func test_ace_demoted_to_one_when_bust() -> void:
	# Arrange
	var values: Array[int] = [11, 10, 5]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 16)

func test_blackjack_returns_21() -> void:
	# Arrange
	var values: Array[int] = [11, 10]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 21)

func test_bust_over_21() -> void:
	# Arrange
	var values: Array[int] = [10, 10, 5]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 25)
	assert_true(result > BUST_THRESHOLD)

func test_multiple_aces_demoted_greedily() -> void:
	# Arrange — three aces + 9 = 12 (11+1+1+9 would bust, so 1+1+1+9)
	var values: Array[int] = [11, 11, 11, 9]
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 12)

func test_empty_hand_returns_zero() -> void:
	# Arrange
	var values: Array[int] = []
	# Act
	var result := calculate_hand(values)
	# Assert
	assert_eq(result, 0)
