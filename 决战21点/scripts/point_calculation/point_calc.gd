class_name PointCalc

const BUST_THRESHOLD: int = 21


static func calculate_hand(cards: Array[CardInstance]) -> PointResult:
	var result := PointResult.new()
	result.card_count = cards.size()
	if cards.is_empty():
		return result
	var non_ace_sum := 0
	var ace_count := 0
	for card in cards:
		var vals: Array = card.prototype.bj_values
		if vals.size() == 2:  # Ace: [1, 11]
			ace_count += 1
		else:
			non_ace_sum += vals[0]
	var soft_ace := ace_count
	var total := non_ace_sum + ace_count * 11
	while total > BUST_THRESHOLD and soft_ace > 0:
		total -= 10
		soft_ace -= 1
	result.point_total = total
	result.is_bust = total > BUST_THRESHOLD
	result.ace_count = ace_count
	result.soft_ace_count = soft_ace
	return result


static func simulate_hit(current: PointResult, new_card: CardInstance) -> PointResult:
	var result := PointResult.new()
	var vals: Array = new_card.prototype.bj_values
	var is_ace := vals.size() == 2
	var new_total := current.point_total
	var new_soft := current.soft_ace_count
	if is_ace:
		new_total += 11
		new_soft += 1
	else:
		new_total += vals[0]
	while new_total > BUST_THRESHOLD and new_soft > 0:
		new_total -= 10
		new_soft -= 1
	result.point_total = new_total
	result.is_bust = new_total > BUST_THRESHOLD
	result.ace_count = current.ace_count + (1 if is_ace else 0)
	result.soft_ace_count = new_soft
	result.card_count = current.card_count + 1
	return result
