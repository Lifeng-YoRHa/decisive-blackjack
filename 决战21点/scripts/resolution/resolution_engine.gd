class_name ResolutionEngine
extends Node

## Resolution pipeline — alternating settlement with suit dispatch.
## MVP scope: no bust, no instant win, no hammer, no stamps, no quality, no defense reset.
## Synchronous — runs to completion in one frame.

signal settlement_step_completed(events: Array)

var _combat: CombatState
var _chips: ChipEconomy
var _event_queue: Array = []


func initialize(combat: CombatState, chips: ChipEconomy) -> void:
	_combat = combat
	_chips = chips


func run_pipeline(input: PipelineInput) -> void:
	_event_queue.clear()
	_run_alternating_settlement(
		input.sorted_player,
		input.sorted_ai,
		input.player_multipliers,
		input.ai_multipliers,
		input.settlement_first_player
	)
	settlement_step_completed.emit(_event_queue.duplicate())


func _run_alternating_settlement(
	sorted_player: Array[CardInstance],
	sorted_ai: Array[CardInstance],
	player_mult: Array[float],
	ai_mult: Array[float],
	first_player: int
) -> void:
	var max_pos: int = maxi(sorted_player.size(), sorted_ai.size())
	for pos in range(max_pos):
		var first_cards: Array[CardInstance] = sorted_player if first_player == CardEnums.Owner.PLAYER else sorted_ai
		var second_cards: Array[CardInstance] = sorted_ai if first_player == CardEnums.Owner.PLAYER else sorted_player
		var first_mult: Array[float] = player_mult if first_player == CardEnums.Owner.PLAYER else ai_mult
		var second_mult: Array[float] = ai_mult if first_player == CardEnums.Owner.PLAYER else player_mult
		var first_owner: int = first_player
		var second_owner: int = _opposite(first_player)

		if pos < first_cards.size():
			var mult: float = first_mult[pos] if pos < first_mult.size() else 1.0
			_settle_card(first_cards[pos], mult, first_owner)

		if pos < second_cards.size():
			var mult: float = second_mult[pos] if pos < second_mult.size() else 1.0
			_settle_card(second_cards[pos], mult, second_owner)


func _settle_card(card: CardInstance, mult: float, owner: int) -> void:
	var suit_effect: int = int(card.prototype.effect_value * mult)

	match card.prototype.suit:
		CardEnums.Suit.DIAMONDS:
			var opponent: int = _opposite(owner)
			_combat.apply_damage(opponent, suit_effect)
			_emit_event(SettlementEvent.StepKind.BASE_VALUE, card, suit_effect, opponent)
		CardEnums.Suit.HEARTS:
			var overflow: int = _combat.apply_heal(owner, suit_effect)
			_emit_event(SettlementEvent.StepKind.HEAL_APPLIED, card, suit_effect, owner, {"overflow": overflow})
		CardEnums.Suit.SPADES:
			_combat.add_defense(owner, suit_effect)
			_emit_event(SettlementEvent.StepKind.DEFENSE_APPLIED, card, suit_effect, owner)
		CardEnums.Suit.CLUBS:
			var chip_total: int = int(card.prototype.chip_value * mult)
			_chips.add_chips(chip_total, ChipEconomy.ChipSource.RESOLUTION)
			_emit_event(SettlementEvent.StepKind.CHIP_GAINED, card, chip_total, owner)


func _opposite(owner: int) -> int:
	return CardEnums.Owner.AI if owner == CardEnums.Owner.PLAYER else CardEnums.Owner.PLAYER


func _emit_event(step: int, card: CardInstance, value: int, target_owner: int, meta: Dictionary = {}) -> void:
	var event: SettlementEvent = SettlementEvent.new()
	event.step = step
	event.card = card
	event.value = value
	event.target = "player" if target_owner == CardEnums.Owner.PLAYER else "ai"
	event.metadata = meta
	_event_queue.append(event)
