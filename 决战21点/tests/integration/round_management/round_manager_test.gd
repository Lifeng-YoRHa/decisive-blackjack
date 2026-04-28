extends GdUnitTestSuite

## Integration tests for RoundManager (Story 2-5: Round Management MVP).
## Tests the full round lifecycle: deal → hit/stand → sort → resolution → death_check.

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CardDataModel := preload("res://scripts/card_data_model/card_data_model.gd")
const _CombatState := preload("res://scripts/combat/combat_state.gd")
const _ChipEconomy := preload("res://scripts/chip_economy/chip_economy.gd")
const _AIOpponent := preload("res://scripts/ai_opponent/ai_opponent.gd")
const _ResolutionEngine := preload("res://scripts/resolution/resolution_engine.gd")
const _RoundManager := preload("res://scripts/round_management/round_manager.gd")

var _card_data: CardDataModel
var _combat: CombatState
var _chips: ChipEconomy
var _ai: AIOpponent
var _resolution: ResolutionEngine
var _manager: RoundManager


func before_test() -> void:
	_card_data = auto_free(CardDataModel.new())
	_combat = auto_free(CombatState.new())
	_chips = auto_free(ChipEconomy.new())
	_ai = auto_free(AIOpponent.new())
	_resolution = auto_free(ResolutionEngine.new())
	_resolution.initialize(_combat, _chips)
	_manager = auto_free(RoundManager.new())
	_manager.initialize(_card_data, _combat, _chips, _resolution, _ai, 42)
	_manager.start_new_game()


func after_test() -> void:
	_manager = null
	_resolution = null
	_ai = null
	_chips = null
	_combat = null
	_card_data = null


# Helper: force both sides to stand quickly (AI threshold is 16).
# Player stands immediately; AI stands if points >= 17, else hits.
func _complete_hit_stand() -> void:
	_manager.player_stand()


# Helper: run a full round from start to death_check.
func _run_full_round() -> void:
	_manager.start_round()
	_complete_hit_stand()
	_manager.confirm_sort(_manager.player_hand.duplicate())


# === AC-15: Game initialization ===


func test_game_init_player_hp_100() -> void:
	assert_int(_combat.player.hp).is_equal(100)


func test_game_init_ai_hp_80_opponent1() -> void:
	assert_int(_combat.ai.hp).is_equal(80)


func test_game_init_chips_100() -> void:
	assert_int(_chips.get_balance()).is_equal(100)


func test_game_init_round_counter_1() -> void:
	assert_int(_manager.round_counter).is_equal(1)


func test_game_init_opponent_number_1() -> void:
	assert_int(_manager.opponent_number).is_equal(1)


func test_game_init_first_player_is_valid() -> void:
	assert_bool(
		_manager.first_player == CardEnums.Owner.PLAYER or
		_manager.first_player == CardEnums.Owner.AI
	).is_true()


# === AC-16: Deal order ===


func test_deal_2_cards_each() -> void:
	_manager.start_round()
	assert_int(_manager.player_hand.size()).is_equal(2)
	assert_int(_manager.ai_hand.size()).is_equal(2)


func test_deal_phase_after_start_round() -> void:
	_manager.start_round()
	# After deal + advance, should be in HIT_STAND
	assert_int(_manager.current_phase).is_equal(RoundManager.RoundPhase.HIT_STAND)


func test_deal_sets_point_results() -> void:
	_manager.start_round()
	assert_object(_manager.player_result).is_not_null()
	assert_object(_manager.ai_result).is_not_null()
	assert_bool(_manager.player_result.point_total > 0).is_true()
	assert_bool(_manager.ai_result.point_total > 0).is_true()


# === AC-01: Complete round flow → CONTINUE ===


func test_complete_round_result_continue() -> void:
	# Listen for round_result
	var spy := {"result": -1}
	_manager.round_result.connect(func(r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		spy["result"] = r
	)
	_run_full_round()
	# With default combat and no damage cards, result should be CONTINUE
	# (unless cards happen to deal enough damage to kill AI, unlikely with 2 cards)
	assert_int(spy["result"]).is_equal(RoundManager.RoundResult.CONTINUE)


func test_complete_round_counter_increments() -> void:
	_run_full_round()
	assert_int(_manager.round_counter).is_equal(2)


# === AC-04: First player alternation ===


func test_first_player_alternates_after_round() -> void:
	var initial := _manager.first_player
	_run_full_round()
	var after_r1 := _manager.first_player
	assert_int(after_r1).is_not_equal(initial)
	_run_full_round()
	var after_r2 := _manager.first_player
	assert_int(after_r2).is_equal(initial)


# === AC-18: Defense reset at round start ===


func test_defense_reset_at_round_start() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 12)
	_combat.add_defense(CardEnums.Owner.AI, 5)
	assert_int(_combat.player.defense).is_equal(12)
	assert_int(_combat.ai.defense).is_equal(5)
	_manager.start_round()
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


# === Phase transitions ===


func test_phase_changed_signal_emitted() -> void:
	var transitions: Array = []
	_manager.phase_changed.connect(func(old: int, new_p: int) -> void:
		transitions.append([old, new_p])
	)
	_manager.start_round()
	# DEAL→HIT_STAND should have been emitted
	assert_bool(transitions.size() > 0).is_true()
	assert_int(transitions[0][0]).is_equal(RoundManager.RoundPhase.DEAL)
	assert_int(transitions[0][1]).is_equal(RoundManager.RoundPhase.HIT_STAND)


func test_full_phase_sequence() -> void:
	var phases: Array = []
	_manager.round_result.connect(func(_r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		pass
	)
	_manager.phase_changed.connect(func(_old: int, new_p: int) -> void:
		phases.append(new_p)
	)
	_run_full_round()
	# Expected: HIT_STAND, SORT, RESOLUTION, DEATH_CHECK
	assert_int(phases.size()).is_equal(4)
	assert_int(phases[0]).is_equal(RoundManager.RoundPhase.HIT_STAND)
	assert_int(phases[1]).is_equal(RoundManager.RoundPhase.SORT)
	assert_int(phases[2]).is_equal(RoundManager.RoundPhase.RESOLUTION)
	assert_int(phases[3]).is_equal(RoundManager.RoundPhase.DEATH_CHECK)


# === Sort phase waits for confirm ===


func test_sort_waits_for_confirm() -> void:
	_manager.start_round()
	_manager.player_stand()
	# After stand, should be stuck at SORT (not auto-advance)
	assert_int(_manager.current_phase).is_equal(RoundManager.RoundPhase.SORT)
	_manager.confirm_sort(_manager.player_hand.duplicate())
	# After confirm, should reach DEATH_CHECK
	assert_int(_manager.current_phase).is_equal(RoundManager.RoundPhase.DEATH_CHECK)


func test_confirm_sort_rejected_outside_sort_phase() -> void:
	var phase_before := _manager.current_phase
	_manager.confirm_sort([])
	assert_int(_manager.current_phase).is_equal(phase_before)


func test_confirm_sort_reorders_player_hand() -> void:
	_manager.start_round()
	_manager.player_stand()
	var original := _manager.player_hand.duplicate()
	if original.size() >= 2:
		var reversed := original.duplicate()
		reversed.reverse()
		_manager.confirm_sort(reversed)
		assert_int(_manager.player_hand.size()).is_equal(original.size())
		assert_object(_manager.player_hand[0]).is_equal(original[original.size() - 1])


# === AC-05: Settlement first player — by points ===


func test_settlement_first_player_higher_points_goes_first() -> void:
	# Player 19, AI 16 → player goes first (19 > 16)
	var result := _manager._determine_settlement_first_player(19, 16, [], [])
	assert_int(result).is_equal(CardEnums.Owner.PLAYER)


func test_settlement_first_player_ai_higher_points() -> void:
	# Player 16, AI 19 → AI goes first
	var result := _manager._determine_settlement_first_player(16, 19, [], [])
	assert_int(result).is_equal(CardEnums.Owner.AI)


# === AC-05c: Settlement tie → max card ===


func test_settlement_tie_max_card_breaks() -> void:
	var p_king := CardInstance.new(CardPrototype.new(CardEnums.Suit.HEARTS, CardEnums.Rank.KING), CardEnums.Owner.PLAYER)
	var p_five := CardInstance.new(CardPrototype.new(CardEnums.Suit.DIAMONDS, CardEnums.Rank.FIVE), CardEnums.Owner.PLAYER)
	var a_ace := CardInstance.new(CardPrototype.new(CardEnums.Suit.SPADES, CardEnums.Rank.ACE), CardEnums.Owner.AI)
	var a_five := CardInstance.new(CardPrototype.new(CardEnums.Suit.CLUBS, CardEnums.Rank.FIVE), CardEnums.Owner.AI)

	# Player max=K(10), AI max=A(11) → AI goes first
	var result := _manager._determine_settlement_first_player(15, 16, [p_king, p_five], [a_ace, a_five])
	assert_int(result).is_equal(CardEnums.Owner.AI)


# === AC-05d: Full tie → coin flip + 20 chip compensation ===


func test_settlement_full_tie_coin_flip_and_chip_compensation() -> void:
	var p_king := CardInstance.new(CardPrototype.new(CardEnums.Suit.HEARTS, CardEnums.Rank.KING), CardEnums.Owner.PLAYER)
	var a_king := CardInstance.new(CardPrototype.new(CardEnums.Suit.SPADES, CardEnums.Rank.KING), CardEnums.Owner.AI)
	var balance_before := _chips.get_balance()

	var result := _manager._determine_settlement_first_player(20, 20, [p_king], [a_king])

	assert_bool(
		result == CardEnums.Owner.PLAYER or result == CardEnums.Owner.AI
	).is_true()
	assert_int(_chips.get_balance()).is_equal(balance_before + 20)


# === Player hit during HIT_STAND ===


func test_player_hit_adds_card() -> void:
	_manager.start_round()
	var size_before := _manager.player_hand.size()
	_manager.player_hit()
	assert_int(_manager.player_hand.size()).is_equal(size_before + 1)


func test_player_hit_updates_point_result() -> void:
	_manager.start_round()
	_manager.player_hit()
	assert_object(_manager.player_result).is_not_null()
	assert_int(_manager.player_result.card_count).is_equal(3)


# === AC-02: PLAYER_WIN ===


func test_player_win_when_ai_hp_zero() -> void:
	_combat.ai.hp = 0
	var spy := {"result": -1}
	_manager.round_result.connect(func(r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		spy["result"] = r
	)
	_run_full_round()
	assert_int(spy["result"]).is_equal(RoundManager.RoundResult.PLAYER_WIN)


# === AC-03: PLAYER_LOSE ===


func test_player_lose_when_player_hp_zero() -> void:
	_combat.player.hp = 0
	var spy := {"result": -1}
	_manager.round_result.connect(func(r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		spy["result"] = r
	)
	_run_full_round()
	assert_int(spy["result"]).is_equal(RoundManager.RoundResult.PLAYER_LOSE)


# === AC-10: Opponent transition ===


func test_opponent_transition_resets_ai_hp() -> void:
	_manager.transition_to_next_opponent()
	assert_int(_combat.ai.hp).is_equal(100)  # Opponent 2 = 100
	assert_int(_manager.opponent_number).is_equal(2)
	assert_int(_manager.round_counter).is_equal(1)


func test_opponent_transition_preserves_player_hp() -> void:
	_combat.player.hp = 45
	_manager.transition_to_next_opponent()
	assert_int(_combat.player.hp).is_equal(45)


func test_opponent_transition_injects_victory_bonus() -> void:
	var balance_before := _chips.get_balance()
	_manager.transition_to_next_opponent()
	var bonus: int = ChipEconomy.calculate_victory_bonus(1)  # opponent 1 defeated
	assert_int(_chips.get_balance()).is_equal(balance_before + bonus)


func test_opponent_transition_new_first_player() -> void:
	var old_first := _manager.first_player
	_manager.transition_to_next_opponent()
	# With seed 42, may or may not change — just verify it's a valid value
	assert_bool(
		_manager.first_player == CardEnums.Owner.PLAYER or
		_manager.first_player == CardEnums.Owner.AI
	).is_true()


# === round_result signal ===


func test_round_result_signal_emitted_with_context() -> void:
	var spy := {"result": -1, "opp": -1, "round": -1, "php": -1, "ahp": -1}
	_manager.round_result.connect(func(r: int, on: int, rn: int, ph: int, ah: int) -> void:
		spy["result"] = r
		spy["opp"] = on
		spy["round"] = rn
		spy["php"] = ph
		spy["ahp"] = ah
	)
	_run_full_round()
	assert_int(spy["opp"]).is_equal(1)
	assert_int(spy["round"]).is_equal(1)
	assert_int(spy["php"]).is_equal(_combat.player.hp)
	assert_int(spy["ahp"]).is_equal(_combat.ai.hp)


# === Multiple rounds ===


func test_three_rounds_counter_and_first_player() -> void:
	var initial := _manager.first_player
	_run_full_round()
	assert_int(_manager.round_counter).is_equal(2)
	assert_int(_manager.first_player).is_equal(_opposite(initial))

	_run_full_round()
	assert_int(_manager.round_counter).is_equal(3)
	assert_int(_manager.first_player).is_equal(initial)

	_run_full_round()
	assert_int(_manager.round_counter).is_equal(4)
	assert_int(_manager.first_player).is_equal(_opposite(initial))


static func _opposite(owner: int) -> int:
	return CardEnums.Owner.AI if owner == CardEnums.Owner.PLAYER else CardEnums.Owner.PLAYER
