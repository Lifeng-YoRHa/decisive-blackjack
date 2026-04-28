extends GdUnitTestSuite

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CombatState := preload("res://scripts/combat/combat_state.gd")
const _ChipEconomy := preload("res://scripts/chip_economy/chip_economy.gd")
const _SettlementEvent := preload("res://scripts/settlement/settlement_event.gd")
const _PipelineInput := preload("res://scripts/resolution/pipeline_input.gd")
const _ResolutionEngine := preload("res://scripts/resolution/resolution_engine.gd")

var _combat: CombatState
var _chips: ChipEconomy
var _engine: ResolutionEngine


func before_test() -> void:
	_combat = auto_free(CombatState.new())
	_combat.initialize()
	_chips = auto_free(ChipEconomy.new())
	_chips.initialize()
	_engine = auto_free(ResolutionEngine.new())
	_engine.initialize(_combat, _chips)


func after_test() -> void:
	_engine = null
	_chips = null
	_combat = null


func _make_card(suit: int, rank: int, owner: int) -> CardInstance:
	var proto := CardPrototype.new(suit, rank)
	return CardInstance.new(proto, owner)


func _make_input(
	player_cards: Array[CardInstance],
	ai_cards: Array[CardInstance],
	player_mult: Array[float] = [],
	ai_mult: Array[float] = [],
	first_player: int = CardEnums.Owner.PLAYER
) -> PipelineInput:
	var input := PipelineInput.new()
	input.sorted_player = player_cards
	input.sorted_ai = ai_cards
	input.player_multipliers = player_mult
	input.ai_multipliers = ai_mult
	input.settlement_first_player = first_player
	return input


func _run_and_capture_events(input: PipelineInput) -> Array:
	var spy := {"events": [] as Array}
	_engine.settlement_step_completed.connect(func(events: Array) -> void:
		spy["events"] = events
	)
	_engine.run_pipeline(input)
	return spy["events"]


# === AC-13: Alternating settlement order ===


func test_alternating_settlement_player_first_3v2_cards() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.PLAYER)
	var p3 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.FOUR, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SIX, CardEnums.Owner.AI)
	var input := _make_input([p1, p2, p3], [a1, a2])

	var events := _run_and_capture_events(input)

	assert_int(events.size()).is_equal(5)
	assert_object(events[0].card).is_equal(p1)
	assert_object(events[1].card).is_equal(a1)
	assert_object(events[2].card).is_equal(p2)
	assert_object(events[3].card).is_equal(a2)
	assert_object(events[4].card).is_equal(p3)


func test_alternating_settlement_ai_first_reverses_order() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SIX, CardEnums.Owner.AI)
	var input := _make_input([p1, p2], [a1, a2], [], [], CardEnums.Owner.AI)

	var events := _run_and_capture_events(input)

	assert_int(events.size()).is_equal(4)
	assert_object(events[0].card).is_equal(a1)
	assert_object(events[1].card).is_equal(p1)
	assert_object(events[2].card).is_equal(a2)
	assert_object(events[3].card).is_equal(p2)


func test_alternating_settlement_1v1_two_settlements() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	var events := _run_and_capture_events(input)

	assert_int(events.size()).is_equal(2)


# === AC-14: First-player defense advantage ===


func test_defense_advantage_spades_before_diamonds_same_pos() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	_engine.run_pipeline(input)

	# Spades adds 9 defense first, then Diamonds deals 12 damage to player.
	# Defense absorbs 9, net HP loss = 3. Without spades-first, player would lose 12 HP.
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.player.hp).is_equal(97)
	assert_int(_combat.ai.hp).is_equal(80)


func test_no_defense_advantage_when_ai_first() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1], [], [], CardEnums.Owner.AI)

	_engine.run_pipeline(input)

	# AI settles first: Spades adds 9 defense to AI.
	# Player settles second: Diamonds deals 12 damage to AI, but defense absorbs 9.
	# The AI gets the defense advantage, not the player.
	assert_int(_combat.ai.defense).is_equal(0)
	assert_int(_combat.ai.hp).is_equal(77)
	assert_int(_combat.player.hp).is_equal(100)


# === AC-15: Diamonds → apply_damage to opponent ===


func test_diamonds_deals_damage_to_opponent() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(73)


func test_diamonds_damage_with_multiplier_2() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [], [2.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(66)


# === AC-16: Hearts → apply_heal to owner ===


func test_hearts_heals_owner() -> void:
	_combat.player.hp = 40
	var p1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.JACK, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_combat.player.hp).is_equal(51)


func test_hearts_capped_at_max_hp() -> void:
	_combat.player.hp = 95
	var p1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.JACK, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_combat.player.hp).is_equal(100)


# === AC-17: Spades → add_defense to owner ===


func test_spades_adds_defense_to_owner() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_combat.player.defense).is_equal(9)


func test_spades_defense_with_multiplier() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [], [2.0])

	_engine.run_pipeline(input)

	assert_int(_combat.player.defense).is_equal(18)


# === AC-18: Clubs → add_chips, no combat effect ===


func test_clubs_adds_chips_no_combat() -> void:
	var p1 := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_chips.get_balance()).is_equal(165)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(_combat.ai.hp).is_equal(80)
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


func test_clubs_chip_with_multiplier_2() -> void:
	var p1 := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [], [2.0])

	_engine.run_pipeline(input)

	assert_int(_chips.get_balance()).is_equal(230)


func test_clubs_no_defense_no_heal_no_damage() -> void:
	var p1 := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	var player_hp_before := _combat.player.hp
	var ai_hp_before := _combat.ai.hp
	_engine.run_pipeline(input)

	assert_int(_combat.player.hp).is_equal(player_hp_before)
	assert_int(_combat.ai.hp).is_equal(ai_hp_before)
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


# === AC-19 (partial): Suit effect dispatch formula ===


func test_suit_effect_formula_mvp_no_quality_bonus() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80 - 9)


func test_suit_effect_with_multiplier() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var input := _make_input([p1], [], [2.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80 - 18)


# === Hand type multipliers ===


func test_per_card_multiplier_pair_applied() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SIX, CardEnums.Owner.PLAYER)
	var input := _make_input([p1, p2], [], [2.0, 2.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80 - 10 - 12)


func test_per_card_multiplier_mixed() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SIX, CardEnums.Owner.PLAYER)
	var input := _make_input([p1, p2], [], [2.0, 1.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80 - 10 - 6)


# === Non-symmetric hands ===


func test_asymmetric_4v2_player_skips_ai_pos3_pos4() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE, CardEnums.Owner.PLAYER)
	var p3 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FOUR, CardEnums.Owner.PLAYER)
	var p4 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1, p2, p3, p4], [a1, a2])

	var events := _run_and_capture_events(input)

	assert_int(events.size()).is_equal(6)
	assert_object(events[0].card).is_equal(p1)
	assert_object(events[1].card).is_equal(a1)
	assert_object(events[2].card).is_equal(p2)
	assert_object(events[3].card).is_equal(a2)
	assert_object(events[4].card).is_equal(p3)
	assert_object(events[5].card).is_equal(p4)


func test_asymmetric_2v4_ai_skips_player_pos3_pos4() -> void:
	var p1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var a3 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FOUR, CardEnums.Owner.AI)
	var a4 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE, CardEnums.Owner.AI)
	var input := _make_input([p1, p2], [a1, a2, a3, a4])

	var events := _run_and_capture_events(input)

	assert_int(events.size()).is_equal(6)
	assert_object(events[0].card).is_equal(p1)
	assert_object(events[1].card).is_equal(a1)
	assert_object(events[2].card).is_equal(p2)
	assert_object(events[3].card).is_equal(a2)
	assert_object(events[4].card).is_equal(a3)
	assert_object(events[5].card).is_equal(a4)


# === Settlement signal ===


func test_signal_emitted_with_events_after_pipeline() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.PLAYER)
	var p3 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.FOUR, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE, CardEnums.Owner.AI)

	var spy := {"count": 0, "events": [] as Array}
	_engine.settlement_step_completed.connect(func(events: Array) -> void:
		spy["count"] += 1
		spy["events"] = events
	)

	var input := _make_input([p1, p2, p3], [a1, a2])
	_engine.run_pipeline(input)

	assert_int(spy["count"]).is_equal(1)
	assert_int(spy["events"].size()).is_equal(5)


func test_signal_events_in_settlement_order() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	var events := _run_and_capture_events(input)

	assert_int(events[0].step).is_equal(SettlementEvent.StepKind.BASE_VALUE)
	assert_object(events[0].card).is_equal(p1)
	assert_str(events[0].target).is_equal("ai")
	assert_int(events[1].step).is_equal(SettlementEvent.StepKind.HEAL_APPLIED)
	assert_object(events[1].card).is_equal(a1)
	assert_str(events[1].target).is_equal("ai")


# === Synchronous execution ===


func test_synchronous_all_state_applied_before_return() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(73)
	assert_int(_combat.player.hp).is_equal(97)


# === PipelineInput struct ===


func test_pipeline_input_bundles_all_fields() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1], [2.0], [1.5], CardEnums.Owner.AI)

	assert_int(input.sorted_player.size()).is_equal(1)
	assert_int(input.sorted_ai.size()).is_equal(1)
	assert_int(input.player_multipliers.size()).is_equal(1)
	assert_float(input.player_multipliers[0]).is_equal(2.0)
	assert_float(input.ai_multipliers[0]).is_equal(1.5)
	assert_int(input.settlement_first_player).is_equal(CardEnums.Owner.AI)
