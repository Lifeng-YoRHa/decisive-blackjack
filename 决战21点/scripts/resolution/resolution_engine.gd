class_name ResolutionEngine
extends Node

## Resolution pipeline — v2: suit dispatch + stamp effects + quality dual-track + HAMMER pre-scan + gem destroy.
## Synchronous — runs to completion in one frame.

signal settlement_step_completed(events: Array[SettlementEvent])

var _combat: CombatState
var _chips: ChipEconomy
var _event_queue: Array[SettlementEvent] = []
var _rng: RandomNumberGenerator


func initialize(combat: CombatState, chips: ChipEconomy) -> void:
	_combat = combat
	_chips = chips
	_rng = RandomNumberGenerator.new()


func run_pipeline(input: PipelineInput) -> void:
	_event_queue.clear()

	for card in input.sorted_player:
		card.invalidated = false
	for card in input.sorted_ai:
		card.invalidated = false

	if input.rng_seed >= 0:
		_rng.seed = input.rng_seed

	# Bust handling: busting side takes self-damage (bypasses defense) and skips settlement
	if input.player_bust:
		var bust_dmg: int = _calculate_bust_damage(input.sorted_player)
		_combat.apply_bust_damage(CardEnums.Owner.PLAYER, bust_dmg)
		_emit_event(SettlementEvent.StepKind.BASE_VALUE, null, bust_dmg, CardEnums.Owner.PLAYER, {"bust": true})
	if input.ai_bust:
		var bust_dmg: int = _calculate_bust_damage(input.sorted_ai)
		_combat.apply_bust_damage(CardEnums.Owner.AI, bust_dmg)
		_emit_event(SettlementEvent.StepKind.BASE_VALUE, null, bust_dmg, CardEnums.Owner.AI, {"bust": true})

	# Both bust — no settlement needed
	if input.player_bust and input.ai_bust:
		settlement_step_completed.emit(_event_queue.duplicate())
		return

	_phase_0c_hammer_scan(input.sorted_player, input.sorted_ai)

	_run_alternating_settlement(
		input.sorted_player,
		input.sorted_ai,
		input.player_multipliers,
		input.ai_multipliers,
		input.settlement_first_player,
		input.player_bust,
		input.ai_bust
	)

	settlement_step_completed.emit(_event_queue.duplicate())


func _calculate_bust_damage(hand: Array[CardInstance]) -> int:
	var result: PointResult = PointCalc.calculate_hand(hand)
	if not result.is_bust:
		return 0
	return result.point_total


func _phase_0c_hammer_scan(sorted_player: Array[CardInstance], sorted_ai: Array[CardInstance]) -> void:
	var max_pos: int = maxi(sorted_player.size(), sorted_ai.size())
	for pos in range(max_pos):
		var player_card: CardInstance = sorted_player[pos] if pos < sorted_player.size() else null
		var ai_card: CardInstance = sorted_ai[pos] if pos < sorted_ai.size() else null

		var player_has_hammer: bool = player_card != null and StampSystem.is_hammer(player_card.stamp)
		var ai_has_hammer: bool = ai_card != null and StampSystem.is_hammer(ai_card.stamp)

		if player_has_hammer and ai_card != null:
			ai_card.invalidated = true
		if ai_has_hammer and player_card != null:
			player_card.invalidated = true


func _run_alternating_settlement(
	sorted_player: Array[CardInstance],
	sorted_ai: Array[CardInstance],
	player_mult: Array[float],
	ai_mult: Array[float],
	first_player: CardEnums.Owner,
	player_bust: bool,
	ai_bust: bool
) -> void:
	var first_cards: Array[CardInstance] = sorted_player if first_player == CardEnums.Owner.PLAYER else sorted_ai
	var second_cards: Array[CardInstance] = sorted_ai if first_player == CardEnums.Owner.PLAYER else sorted_player
	var first_mult: Array[float] = player_mult if first_player == CardEnums.Owner.PLAYER else ai_mult
	var second_mult: Array[float] = ai_mult if first_player == CardEnums.Owner.PLAYER else player_mult
	var first_owner: CardEnums.Owner = first_player
	var second_owner: CardEnums.Owner = _opposite(first_player)
	var first_bust: bool = player_bust if first_player == CardEnums.Owner.PLAYER else ai_bust
	var second_bust: bool = ai_bust if first_player == CardEnums.Owner.PLAYER else player_bust

	var max_pos: int = maxi(sorted_player.size(), sorted_ai.size())
	for pos in range(max_pos):
		if pos < first_cards.size() and not first_bust:
			var mult: float = first_mult[pos] if pos < first_mult.size() else 1.0
			_settle_card(first_cards[pos], mult, first_owner)

		if pos < second_cards.size() and not second_bust:
			var mult: float = second_mult[pos] if pos < second_mult.size() else 1.0
			_settle_card(second_cards[pos], mult, second_owner)


func _settle_card(card: CardInstance, mult: float, owner: CardEnums.Owner) -> void:
	if card.invalidated:
		return

	# Phase 1: Base values
	var base_combat: int = card.prototype.effect_value
	var chip_base: int = card.prototype.chip_value if card.prototype.suit == CardEnums.Suit.CLUBS else 0

	# Phase 2: Stamp bonuses
	var stamp_combat: int = StampSystem.get_combat_bonus(card.stamp)
	var stamp_coin: int = StampSystem.get_coin_bonus(card.stamp)

	# Phase 3: Quality dual-track
	var quality_result: Dictionary = QualitySystem.resolve_bonus(card.quality, card.quality_level)
	var quality_combat: int = quality_result.combat_value
	var quality_chip: int = quality_result.chip_value

	# Phase 4: Apply multiplier
	var suit_total: int = int((base_combat + quality_combat) * mult)
	var stamp_total: int = int(stamp_combat * mult)
	var chip_total: int = int((chip_base + stamp_coin + quality_chip) * mult)

	# Phase 5: Dispatch effects — track separation
	var opponent: CardEnums.Owner = _opposite(owner)

	# Suit dispatch (quality combat bonus folded into suit_total)
	match card.prototype.suit:
		CardEnums.Suit.DIAMONDS:
			_combat.apply_damage(opponent, suit_total)
			_emit_event(SettlementEvent.StepKind.BASE_VALUE, card, suit_total, opponent)
		CardEnums.Suit.HEARTS:
			var overflow: int = _combat.apply_heal(owner, suit_total)
			_emit_event(SettlementEvent.StepKind.HEAL_APPLIED, card, suit_total, owner, {"overflow": overflow})
		CardEnums.Suit.SPADES:
			_combat.add_defense(owner, suit_total)
			_emit_event(SettlementEvent.StepKind.DEFENSE_APPLIED, card, suit_total, owner)
		CardEnums.Suit.CLUBS:
			pass

	# Stamp dispatch (independent of suit)
	_dispatch_stamp_effects(card, stamp_total, owner, opponent)

	# Quality effect event (informational)
	if quality_combat > 0:
		_emit_event(SettlementEvent.StepKind.QUALITY_EFFECT, card, int(quality_combat * mult), owner)

	# Chip dispatch (single flow)
	if chip_total > 0:
		_chips.add_chips(chip_total, ChipEconomy.ChipSource.RESOLUTION)
		_emit_event(SettlementEvent.StepKind.CHIP_GAINED, card, chip_total, owner)

	# Phase 6: Gem destroy check
	_phase_6_gem_destroy(card)


func _dispatch_stamp_effects(card: CardInstance, stamp_total: int, owner: CardEnums.Owner, opponent: CardEnums.Owner) -> void:
	if stamp_total <= 0:
		return
	match card.stamp:
		CardEnums.Stamp.SWORD:
			_combat.apply_damage(opponent, stamp_total)
		CardEnums.Stamp.SHIELD:
			_combat.add_defense(owner, stamp_total)
		CardEnums.Stamp.HEART:
			_combat.apply_heal(owner, stamp_total)
	_emit_event(SettlementEvent.StepKind.STAMP_EFFECT, card, stamp_total, owner)


func _phase_6_gem_destroy(card: CardInstance) -> void:
	if not QualitySystem.is_gem(card.quality):
		return
	var prob: float = QualitySystem.gem_destroy_prob(card.quality_level)
	if _rng.randf() < prob:
		card.destroy_quality()
		_emit_event(SettlementEvent.StepKind.GEM_DESTROY, card, 0, card.owner, {"destroyed": true})


func _opposite(owner: CardEnums.Owner) -> CardEnums.Owner:
	return CardEnums.Owner.AI if owner == CardEnums.Owner.PLAYER else CardEnums.Owner.PLAYER


func _emit_event(step: int, card: CardInstance, value: int, target_owner: int, meta: Dictionary = {}) -> void:
	var event: SettlementEvent = SettlementEvent.new()
	event.step = step
	event.card = card
	event.value = value
	event.target = "player" if target_owner == CardEnums.Owner.PLAYER else "ai"
	event.metadata = meta
	_event_queue.append(event)
