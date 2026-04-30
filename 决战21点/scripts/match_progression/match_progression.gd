class_name MatchProgression
extends Node

## Match-level coordinator sitting above RoundManager.
## Owns the 5-state MatchState FSM and opponent progression [1..total_opponents].
## Per ADR-0010: MatchProgression is the sole authority on opponent_number
## and match lifecycle. RoundManager handles round-level phase orchestration.
##
## Design reference: ADR-0010 (MatchState FSM, ownership boundary),
## Story 3-5 (Match Progression).

enum MatchState {
	NEW_GAME,
	OPPONENT_ACTIVE,
	SHOP,
	VICTORY,
	GAME_OVER,
}

const VALID_TRANSITIONS: Dictionary = {
	MatchState.NEW_GAME: [MatchState.OPPONENT_ACTIVE],
	MatchState.OPPONENT_ACTIVE: [MatchState.SHOP, MatchState.VICTORY, MatchState.GAME_OVER],
	MatchState.SHOP: [MatchState.OPPONENT_ACTIVE],
	MatchState.VICTORY: [],      # Terminal
	MatchState.GAME_OVER: [],    # Terminal
}

const DEFAULT_TOTAL_OPPONENTS: int = 8

signal match_state_changed(new_state: int, old_state: int)

var _state: int = MatchState.NEW_GAME
var _opponent_number: int = 1
var _total_opponents: int = DEFAULT_TOTAL_OPPONENTS

var _round_manager: RoundManager
var _shop: ShopSystem
var _chips: ChipEconomy
var _combat: CombatState
var _card_data: CardDataModel


func initialize(
	round_manager: RoundManager,
	shop: ShopSystem,
	chips: ChipEconomy,
	combat: CombatState,
	card_data: CardDataModel,
	total_opponents: int = DEFAULT_TOTAL_OPPONENTS
) -> void:
	_round_manager = round_manager
	_shop = shop
	_chips = chips
	_combat = combat
	_card_data = card_data
	_total_opponents = clampi(total_opponents, 3, 8)
	if _round_manager.round_result.is_connected(_on_round_result):
		_round_manager.round_result.disconnect(_on_round_result)
	_round_manager.round_result.connect(_on_round_result)


func start_new_game() -> void:
	_state = MatchState.NEW_GAME
	_opponent_number = 1
	_round_manager.start_new_game()
	transition_to(MatchState.OPPONENT_ACTIVE)
	_round_manager.start_round()


func get_match_state() -> int:
	return _state


func get_opponent_number() -> int:
	return _opponent_number


func get_total_opponents() -> int:
	return _total_opponents


func transition_to(new_state: int) -> void:
	if not _is_valid_transition(new_state):
		push_error("MatchProgression: invalid transition %s -> %s" % [
			MatchState.keys()[_state], MatchState.keys()[new_state]
		])
		return
	var old: int = _state
	_state = new_state
	match_state_changed.emit(new_state, old)


func enter_shop() -> void:
	var bonus: int = ChipEconomy.calculate_victory_bonus(_opponent_number)
	_chips.add_chips(bonus, ChipEconomy.ChipSource.VICTORY_BONUS)
	transition_to(MatchState.SHOP)
	var player_deck: Array = _card_data.get_player_deck()
	var typed_deck: Array[CardInstance] = []
	for card in player_deck:
		typed_deck.append(card)
	_shop.generate_inventory(typed_deck, _opponent_number)


func exit_shop() -> void:
	_opponent_number += 1
	_advance_to_next_opponent()
	transition_to(MatchState.OPPONENT_ACTIVE)


func _on_round_result(
	result: int,
	_opponent_num: int,
	_round_num: int,
	_player_hp: int,
	_ai_hp: int
) -> void:
	match result:
		RoundManager.RoundResult.PLAYER_LOSE:
			transition_to(MatchState.GAME_OVER)

		RoundManager.RoundResult.PLAYER_WIN:
			if _opponent_number >= _total_opponents:
				transition_to(MatchState.VICTORY)
			else:
				enter_shop()

		RoundManager.RoundResult.CONTINUE:
			_round_manager.start_round()


func _advance_to_next_opponent() -> void:
	_round_manager.transition_to_next_opponent()
	_round_manager.start_round()


func _is_valid_transition(new_state: int) -> bool:
	var allowed: Array = VALID_TRANSITIONS[_state] as Array
	return new_state in allowed
