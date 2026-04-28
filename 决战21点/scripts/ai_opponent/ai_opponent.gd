class_name AIOpponent
extends Node

## AI opponent decision engine. MVP: BASIC tier with fixed threshold.
## Stateless between rounds — same inputs always produce same decision.

enum AIAction {
	HIT,
	STAND,
}

const HIT_THRESHOLD: int = 16

var _rng: RandomNumberGenerator


func initialize() -> void:
	_rng = RandomNumberGenerator.new()


func make_decision(point_result: PointResult) -> int:
	if point_result.is_bust:
		return AIAction.STAND
	return AIAction.HIT if point_result.point_total <= HIT_THRESHOLD else AIAction.STAND


func sort_hand(hand: Array[CardInstance]) -> Array[CardInstance]:
	if hand.size() <= 1:
		return hand.duplicate()
	if _rng == null:
		push_error("AIOpponent.sort_hand: initialize() must be called first")
		return hand.duplicate()
	var sorted := hand.duplicate()
	for i in range(sorted.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp: CardInstance = sorted[i]
		sorted[i] = sorted[j]
		sorted[j] = temp
	return sorted


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
