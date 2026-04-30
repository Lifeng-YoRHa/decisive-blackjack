class_name RoundManager
extends Node

## Round orchestrator — coordinates all subsystems through the phase FSM.
## MVP: DEAL → HIT_STAND → SORT → RESOLUTION → DEATH_CHECK.

enum RoundPhase {
	DEAL,
	HIT_STAND,
	SORT,
	RESOLUTION,
	DEATH_CHECK,
}

enum RoundResult {
	CONTINUE,
	PLAYER_WIN,
	PLAYER_LOSE,
}

const _PHASE_ORDER: Array = [
	RoundPhase.DEAL,
	RoundPhase.HIT_STAND,
	RoundPhase.SORT,
	RoundPhase.RESOLUTION,
	RoundPhase.DEATH_CHECK,
]

signal phase_changed(old_phase: int, new_phase: int)
signal round_result(result: int, opponent_number: int, round_number: int, player_hp: int, ai_hp: int)

var _card_data: CardDataModel
var _combat: CombatState
var _chips: ChipEconomy
var _resolution: ResolutionEngine
var _ai: AIOpponent
var _rng: RandomNumberGenerator

var current_phase: int = RoundPhase.DEAL
var round_counter: int = 1
var opponent_number: int = 1
var first_player: int = CardEnums.Owner.PLAYER
var player_hand: Array[CardInstance] = []
var ai_hand: Array[CardInstance] = []
var player_result: PointResult
var ai_result: PointResult

var _player_standing: bool = false
var _ai_standing: bool = false


func initialize(
	card_data: CardDataModel,
	combat: CombatState,
	chips: ChipEconomy,
	resolution: ResolutionEngine,
	ai: AIOpponent,
	seed_value: int = -1
) -> void:
	_card_data = card_data
	_combat = combat
	_chips = chips
	_resolution = resolution
	_ai = ai
	_rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		_rng.seed = seed_value


func start_new_game() -> void:
	_card_data.initialize()
	_combat.initialize()
	_chips.initialize()
	_ai.initialize()
	_rng = RandomNumberGenerator.new()
	opponent_number = 1
	round_counter = 1
	first_player = _rng.randi_range(0, 1) as int
	_shuffle_decks()
	current_phase = RoundPhase.DEAL


func start_round() -> void:
	if not _combat.player.is_alive:
		round_result.emit(RoundResult.PLAYER_LOSE, opponent_number, round_counter, _combat.player.hp, _combat.ai.hp)
		return
	if not _combat.ai.is_alive:
		round_result.emit(RoundResult.PLAYER_WIN, opponent_number, round_counter, _combat.player.hp, _combat.ai.hp)
		return
	player_hand.clear()
	ai_hand.clear()
	_player_standing = false
	_ai_standing = false
	player_result = null
	ai_result = null
	current_phase = RoundPhase.DEAL
	_combat.reset_defense()
	_deal_cards()
	_advance_phase()


## Called by UI when player requests a hit.
func player_hit() -> void:
	if current_phase != RoundPhase.HIT_STAND or _player_standing:
		return
	var card: CardInstance = _draw_card(CardEnums.Owner.PLAYER)
	player_hand.append(card)
	player_result = PointCalc.calculate_hand(player_hand)
	if player_result.is_bust:
		_player_standing = true
		if not _ai_standing:
			_run_ai_decision()
	_check_hit_stand_complete()


## Called by UI when player requests stand.
func player_stand() -> void:
	if current_phase != RoundPhase.HIT_STAND or _player_standing:
		return
	_player_standing = true
	if not _ai_standing:
		_run_ai_decision()
	_check_hit_stand_complete()


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Called by UI when player confirms their card sort order.
func confirm_sort(reordered_hand: Array) -> void:
	if current_phase != RoundPhase.SORT:
		return
	player_hand.clear()
	for card in reordered_hand:
		player_hand.append(card)
	_advance_phase()

## === Private ===


func _shuffle_decks() -> void:
	var player_deck: Array = _card_data.get_player_deck()
	_shuffle_array(player_deck)
	var ai_deck: Array = _card_data.get_ai_deck()
	_shuffle_array(ai_deck)


func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


func _draw_card(owner: int) -> CardInstance:
	var deck: Array = _card_data.get_player_deck() if owner == CardEnums.Owner.PLAYER else _card_data.get_ai_deck()
	if deck.is_empty():
		return null
	var card: CardInstance = deck.pop_front() as CardInstance
	card.expired = true
	return card


func _deal_cards() -> void:
	var first: int = first_player
	var second: int = _opposite(first)
	for i in 2:
		var first_card: CardInstance = _draw_card(first)
		if first == CardEnums.Owner.PLAYER:
			player_hand.append(first_card)
		else:
			ai_hand.append(first_card)
		var second_card: CardInstance = _draw_card(second)
		if second == CardEnums.Owner.PLAYER:
			player_hand.append(second_card)
		else:
			ai_hand.append(second_card)
	player_result = PointCalc.calculate_hand(player_hand)
	ai_result = PointCalc.calculate_hand(ai_hand)


func _advance_phase() -> void:
	var old := current_phase
	var idx: int = _PHASE_ORDER.find(current_phase)
	if idx < 0 or idx >= _PHASE_ORDER.size() - 1:
		return
	current_phase = _PHASE_ORDER[idx + 1]
	phase_changed.emit(old, current_phase)
	_on_phase_entered(current_phase)


func _on_phase_entered(phase: int) -> void:
	match phase:
		RoundPhase.HIT_STAND:
			pass
		RoundPhase.SORT:
			_do_auto_sort()
		RoundPhase.RESOLUTION:
			_run_resolution()
			_advance_phase()
		RoundPhase.DEATH_CHECK:
			_do_death_check()


func _check_hit_stand_complete() -> void:
	if _player_standing and _ai_standing and current_phase == RoundPhase.HIT_STAND:
		_advance_phase()


func _run_ai_decision() -> void:
	if ai_result == null:
		ai_result = PointCalc.calculate_hand(ai_hand)
	var decision: int = _ai.make_decision(ai_result)
	if decision == AIOpponent.AIAction.HIT:
		var card: CardInstance = _draw_card(CardEnums.Owner.AI)
		ai_hand.append(card)
		ai_result = PointCalc.calculate_hand(ai_hand)
		if not ai_result.is_bust:
			_run_ai_decision()
		else:
			_ai_standing = true
	else:
		_ai_standing = true
	_check_hit_stand_complete()


func _do_auto_sort() -> void:
	# MVP: cards remain in deal order. AI sorts randomly.
	ai_hand = _ai.sort_hand(ai_hand)


func _run_resolution() -> void:
	# Recalculate after sort/ai hits
	player_result = PointCalc.calculate_hand(player_hand)
	ai_result = PointCalc.calculate_hand(ai_hand)

	var settlement_first: int = _determine_settlement_first_player(
		player_result.point_total,
		ai_result.point_total,
		player_hand,
		ai_hand
	)

	var player_hand_result: HandTypeResult = HandTypeDetection.detect(player_hand, player_result)
	var ai_hand_result: HandTypeResult = HandTypeDetection.detect(ai_hand, ai_result)

	var player_mult: Array[float] = _extract_best_multipliers(player_hand_result, player_hand.size())
	var ai_mult: Array[float] = _extract_best_multipliers(ai_hand_result, ai_hand.size())

	var input := PipelineInput.new()
	input.sorted_player = player_hand
	input.sorted_ai = ai_hand
	input.player_multipliers = player_mult
	input.ai_multipliers = ai_mult
	input.settlement_first_player = settlement_first

	_resolution.run_pipeline(input)


func _determine_settlement_first_player(
	player_pts: int,
	ai_pts: int,
	p_hand: Array[CardInstance],
	a_hand: Array[CardInstance]
) -> int:
	if player_pts > ai_pts:
		return CardEnums.Owner.PLAYER
	if ai_pts > player_pts:
		return CardEnums.Owner.AI
	# Tie: compare max card blackjack_value
	var p_max: int = _max_bj_value(p_hand)
	var a_max: int = _max_bj_value(a_hand)
	if p_max > a_max:
		return CardEnums.Owner.PLAYER
	if a_max > p_max:
		return CardEnums.Owner.AI
	# Full tie: coin flip + 20 chip compensation to loser
	var winner: int = _rng.randi_range(0, 1) as int
	var loser: int = _opposite(winner)
	_chips.add_chips(20, ChipEconomy.ChipSource.SETTLEMENT_TIE_COMP)
	return winner


func _max_bj_value(hand: Array[CardInstance]) -> int:
	var max_val: int = 0
	for card in hand:
		var vals: Array = card.prototype.bj_values
		var high: int = vals[vals.size() - 1] as int
		if high > max_val:
			max_val = high
	return max_val


func _extract_best_multipliers(result: HandTypeResult, hand_size: int) -> Array[float]:
	if result.matches.is_empty():
		var mults: Array[float] = []
		for _i in hand_size:
			mults.append(1.0)
		return mults
	# Use first match's per_card_multiplier (best match by detection order)
	return result.matches[0].per_card_multiplier


func _do_death_check() -> void:
	var result: int
	if not _combat.player.is_alive:
		result = RoundResult.PLAYER_LOSE
	elif not _combat.ai.is_alive:
		result = RoundResult.PLAYER_WIN
	else:
		result = RoundResult.CONTINUE

	round_result.emit(result, opponent_number, round_counter, _combat.player.hp, _combat.ai.hp)

	if result == RoundResult.CONTINUE:
		round_counter += 1
		first_player = _opposite(first_player)


func transition_to_next_opponent() -> void:
	opponent_number += 1
	round_counter = 1
	first_player = _rng.randi_range(0, 1) as int
	_combat.setup_opponent(opponent_number)
	_card_data.regenerate_ai_deck()
	_shuffle_decks()


static func _opposite(owner: int) -> int:
	return CardEnums.Owner.AI if owner == CardEnums.Owner.PLAYER else CardEnums.Owner.PLAYER
