extends GdUnitTestSuite

## Integration tests for MatchProgression (Story 3-5: Match Progression).
## Tests the 5-state MatchState FSM, opponent progression, shop gating,
## victory/game-over terminals, and signal emission.

var _match: MatchProgression
var _round_manager: RoundManager
var _shop: ShopSystem
var _combat: CombatState
var _chips: ChipEconomy
var _card_data: CardDataModel
var _ai: AIOpponent
var _resolution: ResolutionEngine


func before_test() -> void:
	_card_data = auto_free(CardDataModel.new())
	_combat = auto_free(CombatState.new())
	_chips = auto_free(ChipEconomy.new())
	_ai = auto_free(AIOpponent.new())
	_resolution = auto_free(ResolutionEngine.new())
	_resolution.initialize(_combat, _chips)
	_round_manager = auto_free(RoundManager.new())
	_round_manager.initialize(_card_data, _combat, _chips, _resolution, _ai, 42)
	_shop = auto_free(ShopSystem.new())
	_shop.initialize(_combat, _chips)
	_match = auto_free(MatchProgression.new())
	_match.initialize(_round_manager, _shop, _chips, _combat, _card_data)


func after_test() -> void:
	_match = null
	_round_manager = null
	_shop = null
	_combat = null
	_chips = null
	_card_data = null
	_ai = null
	_resolution = null


# Helper: run a full round (start -> stand -> confirm_sort).
func _run_full_round() -> void:
	_round_manager.start_round()
	_round_manager.player_stand()
	_round_manager.confirm_sort(_round_manager.player_hand.duplicate())


# ---------------------------------------------------------------------------
# 1. NEW_GAME -> OPPONENT_ACTIVE on start_new_game
# ---------------------------------------------------------------------------

func test_start_new_game_transitions_to_opponent_active() -> void:
	_match.start_new_game()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)


# ---------------------------------------------------------------------------
# 2. CONTINUE after non-lethal round stays in OPPONENT_ACTIVE, new round starts
# ---------------------------------------------------------------------------

func test_continue_stays_in_opponent_active() -> void:
	_match.start_new_game()
	# Round 1 will likely result in CONTINUE (default HP, no lethal damage)
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)


# ---------------------------------------------------------------------------
# 3. PLAYER_WIN -> SHOP transition (opponents 1-7)
# ---------------------------------------------------------------------------

func test_player_win_transitions_to_shop_before_opponent_8() -> void:
	_match.start_new_game()
	# Kill AI to force PLAYER_WIN
	_combat.ai.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.SHOP)


# ---------------------------------------------------------------------------
# 4. SHOP -> OPPONENT_ACTIVE on exit_shop
# ---------------------------------------------------------------------------

func test_exit_shop_transitions_to_opponent_active() -> void:
	_match.start_new_game()
	_combat.ai.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.SHOP)

	_match.exit_shop()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)


# ---------------------------------------------------------------------------
# 5. PLAYER_WIN after opponent 8 -> VICTORY (no shop)
# ---------------------------------------------------------------------------

func test_player_win_opponent_8_transitions_to_victory() -> void:
	_match.start_new_game()
	# Advance through opponents 1-7 to reach opponent 8
	for _i: int in range(7):
		_combat.ai.hp = 0
		_run_full_round()
		if _match.get_match_state() == MatchProgression.MatchState.SHOP:
			_match.exit_shop()

	# Now at opponent 8
	assert_int(_match.get_opponent_number()).is_equal(8)
	_combat.ai.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.VICTORY)


# ---------------------------------------------------------------------------
# 6. PLAYER_LOSE -> GAME_OVER
# ---------------------------------------------------------------------------

func test_player_lose_transitions_to_game_over() -> void:
	_match.start_new_game()
	_combat.player.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.GAME_OVER)


# ---------------------------------------------------------------------------
# 7. Victory bonus injected via add_chips on opponent defeat
# ---------------------------------------------------------------------------

func test_victory_bonus_injected_on_opponent_defeat() -> void:
	_match.start_new_game()
	var chips_before: int = _chips.get_balance()

	_combat.ai.hp = 0
	_run_full_round()
	# Victory bonus injected BEFORE shop entry (per ADR-0010)
	var expected_bonus: int = ChipEconomy.calculate_victory_bonus(1)
	assert_int(_chips.get_balance()).is_equal(chips_before + expected_bonus)

	# Exiting shop does NOT inject another bonus
	var chips_at_shop: int = _chips.get_balance()
	_match.exit_shop()
	assert_int(_chips.get_balance()).is_equal(chips_at_shop)


# ---------------------------------------------------------------------------
# 8. AI deck regenerated per opponent
# ---------------------------------------------------------------------------

func test_ai_deck_regenerated_on_opponent_transition() -> void:
	_match.start_new_game()

	# Expire some AI cards to verify regeneration
	var ai_deck_before: Array = _card_data.get_ai_deck()
	var initial_ai_count: int = ai_deck_before.size()

	_combat.ai.hp = 0
	_run_full_round()
	_match.exit_shop()

	var ai_deck_after: Array = _card_data.get_ai_deck()
	# AI deck should be fully regenerated (all cards available, none expired)
	assert_int(ai_deck_after.size()).is_equal(initial_ai_count)


# ---------------------------------------------------------------------------
# 9. AI HP scaled per opponent_number (CombatState.AI_HP_SCALING)
# ---------------------------------------------------------------------------

func test_ai_hp_scaled_per_opponent() -> void:
	_match.start_new_game()
	assert_int(_combat.ai.hp).is_equal(CombatState.AI_HP_SCALING[1])

	# Defeat opponent 1, advance to opponent 2
	_combat.ai.hp = 0
	_run_full_round()
	_match.exit_shop()

	assert_int(_match.get_opponent_number()).is_equal(2)
	assert_int(_combat.ai.hp).is_equal(CombatState.AI_HP_SCALING[2])


# ---------------------------------------------------------------------------
# 10. opponent_number incremented correctly after shop exit
# ---------------------------------------------------------------------------

func test_opponent_number_increments_after_shop_exit() -> void:
	_match.start_new_game()
	assert_int(_match.get_opponent_number()).is_equal(1)

	_combat.ai.hp = 0
	_run_full_round()
	# Still opponent 1 in shop
	assert_int(_match.get_opponent_number()).is_equal(1)

	_match.exit_shop()
	assert_int(_match.get_opponent_number()).is_equal(2)


# ---------------------------------------------------------------------------
# 11. First player alternation preserved across rounds
# ---------------------------------------------------------------------------

func test_first_player_alternation_preserved_across_rounds() -> void:
	_match.start_new_game()
	var initial_first: int = _round_manager.first_player

	_run_full_round()
	assert_int(_round_manager.first_player).is_not_equal(initial_first)

	_run_full_round()
	assert_int(_round_manager.first_player).is_equal(initial_first)


# ---------------------------------------------------------------------------
# 12. Invalid transition rejected
# ---------------------------------------------------------------------------

func test_invalid_transition_rejected() -> void:
	_match.start_new_game()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)

	# GAME_OVER cannot go to SHOP
	var state_before: int = _match.get_match_state()
	_combat.player.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.GAME_OVER)

	# Try invalid transition from terminal state
	_match.transition_to(MatchProgression.MatchState.SHOP)
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.GAME_OVER)


# ---------------------------------------------------------------------------
# 13. Game over at opponent 1 (immediate loss)
# ---------------------------------------------------------------------------

func test_game_over_at_opponent_1() -> void:
	_match.start_new_game()
	assert_int(_match.get_opponent_number()).is_equal(1)

	_combat.player.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.GAME_OVER)
	assert_int(_match.get_opponent_number()).is_equal(1)


# ---------------------------------------------------------------------------
# 14. Multiple CONTINUE rounds before opponent defeat
# ---------------------------------------------------------------------------

func test_multiple_continue_rounds_before_opponent_defeat() -> void:
	_match.start_new_game()
	assert_int(_round_manager.round_counter).is_equal(1)

	# Run several non-lethal rounds
	for i: int in range(3):
		_run_full_round()
		assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)
		assert_int(_round_manager.round_counter).is_equal(i + 2)

	# Now defeat the opponent
	_combat.ai.hp = 0
	_run_full_round()
	assert_int(_match.get_match_state()).is_equal(MatchProgression.MatchState.SHOP)


# ---------------------------------------------------------------------------
# 15. match_state_changed signal emitted on transitions
# ---------------------------------------------------------------------------

func test_match_state_changed_signal_emitted() -> void:
	var signal_log: Array = []
	_match.match_state_changed.connect(func(new_state: int, old_state: int) -> void:
		signal_log.append({"new": new_state, "old": old_state})
	)

	_match.start_new_game()
	# start_new_game emits: NEW_GAME->OPPONENT_ACTIVE
	assert_int(signal_log.size()).is_equal(1)
	assert_int(signal_log[0]["new"]).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)
	assert_int(signal_log[0]["old"]).is_equal(MatchProgression.MatchState.NEW_GAME)

	# Force PLAYER_WIN -> SHOP
	_combat.ai.hp = 0
	_run_full_round()
	assert_int(signal_log.size()).is_equal(2)
	assert_int(signal_log[1]["new"]).is_equal(MatchProgression.MatchState.SHOP)
	assert_int(signal_log[1]["old"]).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)

	_match.exit_shop()
	assert_int(signal_log.size()).is_equal(3)
	assert_int(signal_log[2]["new"]).is_equal(MatchProgression.MatchState.OPPONENT_ACTIVE)
	assert_int(signal_log[2]["old"]).is_equal(MatchProgression.MatchState.SHOP)
