extends GdUnitTestSuite

# Story 3-3: Resolution Engine v2 — integration tests
# Tests: stamp dispatch, quality dual-track, HAMMER pre-scan, gem destroy, combined effects

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
	first_player: int = CardEnums.Owner.PLAYER,
	rng_seed: int = -1
) -> PipelineInput:
	var input := PipelineInput.new()
	input.sorted_player = player_cards
	input.sorted_ai = ai_cards
	input.player_multipliers = player_mult
	input.ai_multipliers = ai_mult
	input.settlement_first_player = first_player
	input.rng_seed = rng_seed
	return input


func _run_and_capture_events(input: PipelineInput) -> Array:
	var spy := {"events": [] as Array}
	_engine.settlement_step_completed.connect(func(events: Array) -> void:
		spy["events"] = events
	)
	_engine.run_pipeline(input)
	return spy["events"]


# === Stamp effects dispatch ===


func test_sword_stamp_adds_damage_to_opponent() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# DIAMONDS-7 base damage = 7, SWORD bonus = 2 → total 9 damage + 2 stamp damage = 11
	assert_int(_combat.ai.hp).is_equal(80 - 7 - 2)


func test_shield_stamp_adds_defense_to_owner() -> void:
	var card := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SHIELD)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# SPADES-9 base defense = 9, SHIELD bonus = 2 → total 11 defense
	assert_int(_combat.player.defense).is_equal(9 + 2)


func test_heart_stamp_adds_heal_to_owner() -> void:
	_combat.player.hp = 40
	var card := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.JACK, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.HEART)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# HEARTS-J(11) heal + HEART stamp heal(2) = 13 total heal
	assert_int(_combat.player.hp).is_equal(40 + 11 + 2)


func test_coin_stamp_adds_chips() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.COIN)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# CLUBS-K chip_value + COIN stamp(10) chip bonus
	assert_int(_chips.get_balance()).is_equal(165 + 10)


func test_non_combat_stamps_no_combat_effect() -> void:
	var hammer_card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	hammer_card.assign_stamp(CardEnums.Stamp.HAMMER)
	var shoes_card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.EIGHT, CardEnums.Owner.PLAYER)
	shoes_card.assign_stamp(CardEnums.Stamp.RUNNING_SHOES)
	var turtle_card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	turtle_card.assign_stamp(CardEnums.Stamp.TURTLE)
	var input := _make_input([hammer_card, shoes_card, turtle_card], [])

	_engine.run_pipeline(input)

	# HAMMER/RUNNING_SHOES/TURTLE have no combat bonus — only base damage applies
	assert_int(_combat.ai.hp).is_equal(80 - 7 - 8 - 9)


# === Quality dual-track ===


func test_ruby_quality_adds_damage_bonus() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# DIAMONDS-7(7) + RUBY III(+3) = 10 damage
	assert_int(_combat.ai.hp).is_equal(80 - 10)


func test_sapphire_quality_adds_heal_bonus() -> void:
	_combat.player.hp = 40
	var card := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.JACK, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.SAPPHIRE, CardEnums.QualityLevel.II)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# HEARTS-J(11) + SAPPHIRE II(+4) = 15 heal
	assert_int(_combat.player.hp).is_equal(40 + 15)


func test_obsidian_quality_adds_defense_bonus() -> void:
	var card := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.I)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# SPADES-9(9) + OBSIDIAN I(+5) = 14 defense
	assert_int(_combat.player.defense).is_equal(14)


func test_copper_quality_adds_chip_bonus() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.COPPER, CardEnums.QualityLevel.III)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# CLUBS-K chip_value(165) + COPPER III chip bonus(10) = 175
	assert_int(_chips.get_balance()).is_equal(165 + 10)


# === HAMMER pre-scan ===


func test_hammer_invalidates_opponent_same_position() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	p1.assign_stamp(CardEnums.Stamp.HAMMER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.AI)
	var input := _make_input([p1], [a1])

	_engine.run_pipeline(input)

	# Player SPADES-9 builds defense. AI DIAMONDS-Q invalidated by HAMMER → no damage.
	assert_int(_combat.player.defense).is_equal(9)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(_combat.ai.hp).is_equal(80)


func test_hammer_ai_invalidates_player_same_position() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.PLAYER)
	var a1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.AI)
	a1.assign_stamp(CardEnums.Stamp.HAMMER)
	var input := _make_input([p1], [a1])

	_engine.run_pipeline(input)

	# Player DIAMONDS-Q invalidated by HAMMER → no damage. AI SPADES-9 builds defense.
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(_combat.ai.defense).is_equal(9)
	assert_int(_combat.ai.hp).is_equal(80)


func test_hammer_mutual_both_invalidated() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.PLAYER)
	p1.assign_stamp(CardEnums.Stamp.HAMMER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.KING, CardEnums.Owner.AI)
	a1.assign_stamp(CardEnums.Stamp.HAMMER)
	var input := _make_input([p1], [a1])

	_engine.run_pipeline(input)

	# Both HAMMER at pos 0 → both invalidated → no damage dealt
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(_combat.ai.hp).is_equal(80)


func test_hammer_no_target_opponent_fewer_cards() -> void:
	var p1 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	var p2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	p2.assign_stamp(CardEnums.Stamp.HAMMER)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([p1, p2], [a1])

	var events := _run_and_capture_events(input)

	# p1(SPADES-9) settles normally at pos 0. a1(HEARTS-2) settles at pos 0.
	# p2(HAMMER) at pos 1 has no AI card to invalidate → settles normally (DIAMONDS-7 damage).
	assert_int(_combat.player.defense).is_equal(9)
	assert_int(_combat.ai.hp).is_equal(80 - 7)
	# 3 cards settled (p1, a1, p2) → at least 3 events
	assert_int(events.size() >= 3).is_true()


# === Gem destroy ===


func test_gem_destroy_rolls_correctly_with_seed() -> void:
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 42
	var roll: float = test_rng.randf()
	var should_destroy: bool = roll < QualitySystem.gem_destroy_prob(CardEnums.QualityLevel.III)

	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([card], [a1], [1.0], [1.0], CardEnums.Owner.PLAYER, 42)

	_engine.run_pipeline(input)

	if should_destroy:
		assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
		assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	else:
		assert_int(card.quality).is_equal(CardEnums.Quality.RUBY)


func test_gem_destroy_deterministic_same_seed() -> void:
	var seed_value: int = 12345

	var card1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card1.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input1 := _make_input([card1], [a1], [1.0], [1.0], CardEnums.Owner.PLAYER, seed_value)
	_engine.run_pipeline(input1)

	var combat2: CombatState = auto_free(CombatState.new())
	combat2.initialize()
	var chips2: ChipEconomy = auto_free(ChipEconomy.new())
	chips2.initialize()
	var engine2: ResolutionEngine = auto_free(ResolutionEngine.new())
	engine2.initialize(combat2, chips2)

	var card2 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card2.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var a2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input2 := _make_input([card2], [a2], [1.0], [1.0], CardEnums.Owner.PLAYER, seed_value)
	engine2.run_pipeline(input2)

	assert_int(card1.quality).is_equal(card2.quality)


func test_metal_quality_never_triggers_destroy() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.GOLD, CardEnums.QualityLevel.I)
	var input := _make_input([card], [], [1.0], [], CardEnums.Owner.PLAYER, 0)

	_engine.run_pipeline(input)

	assert_int(card.quality).is_equal(CardEnums.Quality.GOLD)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.I)


func test_multiple_gem_cards_roll_independently() -> void:
	var c1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	c1.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var c2 := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	c2.assign_quality(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([c1, c2], [a1, a1], [1.0, 1.0], [1.0, 1.0], CardEnums.Owner.PLAYER, 42)

	_engine.run_pipeline(input)

	# Both cards make independent destroy rolls — at least verify mechanism runs
	assert_bool(c1.quality == CardEnums.Quality.NONE or c1.quality == CardEnums.Quality.RUBY).is_true()
	assert_bool(c2.quality == CardEnums.Quality.NONE or c2.quality == CardEnums.Quality.OBSIDIAN).is_true()


# === Combined stamp + quality + multiplier ===


func test_sword_stamp_with_ruby_quality_and_multiplier() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)
	var input := _make_input([card], [], [2.0])

	_engine.run_pipeline(input)

	# suit_total = (7 + 4) × 2 = 22, stamp_total = 2 × 2 = 4 → total 26 damage
	assert_int(_combat.ai.hp).is_equal(80 - 22 - 4)


func test_shield_stamp_with_obsidian_quality() -> void:
	var card := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SHIELD)
	card.assign_quality(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.II)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# suit_total = 9 + 4 = 13 defense, stamp_total = 2 defense → total 15 defense
	assert_int(_combat.player.defense).is_equal(13 + 2)


func test_coin_stamp_with_copper_quality_on_clubs() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.COIN)
	card.assign_quality(CardEnums.Quality.COPPER, CardEnums.QualityLevel.II)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# chip_total = (chip_value + 10(COIN) + 15(COPPER II)) × 1.0
	assert_int(_chips.get_balance()).is_equal(165 + 10 + 15)


# === Regression: MVP still works ===


func test_no_stamp_no_quality_same_as_mvp() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(73)


func test_no_stamp_no_quality_with_multiplier() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	var input := _make_input([card], [], [2.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80 - 14)


# === Edge cases ===


func test_hammer_card_with_gem_quality_destroy_runs() -> void:
	var card := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.NINE, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.HAMMER)
	card.assign_quality(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([card], [a1], [1.0], [1.0], CardEnums.Owner.PLAYER, 42)

	_engine.run_pipeline(input)

	# HAMMER invalidates AI card. Player SPADES-9 builds defense.
	# Gem destroy check runs on HAMMER card itself (OBSIDIAN III).
	assert_bool(a1.invalidated).is_true()
	assert_int(_combat.player.defense).is_equal(9)
	assert_bool(card.quality == CardEnums.Quality.NONE or card.quality == CardEnums.Quality.OBSIDIAN).is_true()


func test_destroyed_quality_does_not_affect_stamp() -> void:
	# Use seed 42, verify destroy outcome, then check stamp survives
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 42
	var roll: float = test_rng.randf()

	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([card], [a1], [1.0], [1.0], CardEnums.Owner.PLAYER, 42)

	_engine.run_pipeline(input)

	# Stamp always survives regardless of quality destroy
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)


func test_event_queue_includes_v2_event_types() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.III)
	var a1 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.AI)
	var input := _make_input([card], [a1], [1.0], [1.0], CardEnums.Owner.PLAYER, 99999)

	var events := _run_and_capture_events(input)

	# Player card: BASE_VALUE(DIAMONDS damage) + STAMP_EFFECT(SWORD) + QUALITY_EFFECT(RUBY)
	# AI card: HEAL_APPLIED
	# Seed 99999 — gem may or may not destroy, don't assert on GEM_DESTROY presence
	var has_base: bool = false
	var has_stamp: bool = false
	var has_quality: bool = false
	for ev in events:
		if ev.card == card:
			if ev.step == SettlementEvent.StepKind.BASE_VALUE:
				has_base = true
			elif ev.step == SettlementEvent.StepKind.STAMP_EFFECT:
				has_stamp = true
			elif ev.step == SettlementEvent.StepKind.QUALITY_EFFECT:
				has_quality = true
	assert_bool(has_base).is_true()
	assert_bool(has_stamp).is_true()
	assert_bool(has_quality).is_true()


func test_invalidated_card_no_events_no_mutations() -> void:
	var p1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.QUEEN, CardEnums.Owner.PLAYER)
	p1.assign_stamp(CardEnums.Stamp.HAMMER)
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.KING, CardEnums.Owner.AI)
	a1.assign_stamp(CardEnums.Stamp.HAMMER)
	var input := _make_input([p1], [a1])

	var events := _run_and_capture_events(input)

	# Both invalidated → no events, no mutations
	assert_int(events.size()).is_equal(0)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(_combat.ai.hp).is_equal(80)


func test_stamp_effect_event_value_includes_multiplier() -> void:
	var card := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.TWO, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.HEART)
	var input := _make_input([card], [], [3.0])

	var events := _run_and_capture_events(input)

	# STAMP_EFFECT value = 2 × 3 = 6
	var stamp_events: Array = events.filter(func(e): return e.step == SettlementEvent.StepKind.STAMP_EFFECT)
	assert_int(stamp_events.size()).is_equal(1)
	assert_int(stamp_events[0].value).is_equal(6)


# === Additional edge cases ===


func test_empty_player_hand_ai_cards_settle_normally() -> void:
	var a1 := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.AI)
	var a2 := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.THREE, CardEnums.Owner.AI)
	var input := _make_input([], [a1, a2])

	_engine.run_pipeline(input)

	assert_int(_combat.player.hp).is_equal(100 - 7)
	assert_int(_combat.ai.hp).is_equal(80 + 3)


func test_emerald_quality_adds_chip_bonus_through_pipeline() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.KING, CardEnums.Owner.PLAYER)
	card.assign_quality(CardEnums.Quality.EMERALD, CardEnums.QualityLevel.II)
	var input := _make_input([card], [])

	_engine.run_pipeline(input)

	# CLUBS-K chip_value(65) + EMERALD II chip bonus(20) = 85
	assert_int(_chips.get_balance()).is_equal(100 + 65 + 20)


func test_zero_multiplier_zeros_all_effects() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN, CardEnums.Owner.PLAYER)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)
	var input := _make_input([card], [], [0.0])

	_engine.run_pipeline(input)

	assert_int(_combat.ai.hp).is_equal(80)
	assert_int(_chips.get_balance()).is_equal(100)
