extends GdUnitTestSuite

## E2E integration test — first playable round (Story 2-7).
## Validates all subsystems cooperate: deal → hit/stand → sort → resolution → death_check.
## Maps directly to Milestone 1 success criteria 1–5.

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


# === Helpers ===


# Run one full round, capture settlement events and round result.
func _run_round_capture() -> Dictionary:
	var events_spy := {"data": [] as Array}
	var events_cb := func(e: Array) -> void: events_spy["data"] = e
	_resolution.settlement_step_completed.connect(events_cb)

	var result_spy := {"result": -1, "opp": -1, "round": -1, "php": -1, "ahp": -1}
	var result_cb := func(r: int, on: int, rn: int, ph: int, ah: int) -> void:
		result_spy["result"] = r
		result_spy["opp"] = on
		result_spy["round"] = rn
		result_spy["php"] = ph
		result_spy["ahp"] = ah
	_manager.round_result.connect(result_cb)

	_manager.start_round()
	_manager.player_stand()

	_resolution.settlement_step_completed.disconnect(events_cb)
	_manager.round_result.disconnect(result_cb)

	return {"events": events_spy["data"], "result": result_spy}


# Replay settlement events to compute expected state.
# Defense starts at 0 (reset at round start). HP and chips carry from init values.
func _simulate_events(
	events: Array,
	init_p_hp: int, init_a_hp: int, init_chips: int,
	p_max: int, a_max: int
) -> Dictionary:
	var p_hp := init_p_hp
	var a_hp := init_a_hp
	var p_def := 0
	var a_def := 0
	var chips := init_chips

	for event in events:
		match event.step:
			SettlementEvent.StepKind.BASE_VALUE:  # DIAMONDS → damage to target
				var dmg: int = event.value
				if event.target == "player":
					if dmg <= p_def:
						p_def -= dmg
					else:
						dmg -= p_def
						p_def = 0
						p_hp = maxi(p_hp - dmg, 0)
				else:
					if dmg <= a_def:
						a_def -= dmg
					else:
						dmg -= a_def
						a_def = 0
						a_hp = maxi(a_hp - dmg, 0)
			SettlementEvent.StepKind.HEAL_APPLIED:
				if event.target == "player":
					p_hp = mini(p_hp + event.value, p_max)
				else:
					a_hp = mini(a_hp + event.value, a_max)
			SettlementEvent.StepKind.DEFENSE_APPLIED:
				if event.target == "player":
					p_def += event.value
				else:
					a_def += event.value
			SettlementEvent.StepKind.CHIP_GAINED:
				chips = mini(chips + event.value, ChipEconomy.CHIP_CAP)

	return {
		"player_hp": p_hp,
		"ai_hp": a_hp,
		"player_defense": p_def,
		"ai_defense": a_def,
		"chips_balance": chips,
	}


# === Milestone 1 Criterion 1: Dealt 2 cards, point total visible ===


func test_e2e_dealt_cards_and_point_total() -> void:
	_manager.start_round()
	assert_int(_manager.player_hand.size()).is_equal(2)
	assert_int(_manager.ai_hand.size()).is_equal(2)
	assert_object(_manager.player_result).is_not_null()
	assert_bool(_manager.player_result.point_total >= 2).is_true()
	assert_bool(_manager.player_result.point_total <= 30).is_true()


# === Milestone 1 Criterion 2: Player can Hit or Stand ===


func test_e2e_player_hit_draws_card() -> void:
	_manager.start_round()
	var size_before := _manager.player_hand.size()
	_manager.player_hit()
	assert_int(_manager.player_hand.size()).is_equal(size_before + 1)
	assert_int(_manager.player_result.card_count).is_equal(size_before + 1)


func test_e2e_player_stand_completes_round() -> void:
	_manager.start_round()
	var spy := {"result": -1}
	var cb := func(r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		spy["result"] = r
	_manager.round_result.connect(cb)
	_manager.player_stand()
	_manager.round_result.disconnect(cb)
	assert_int(spy["result"]).is_not_equal(-1)
	assert_int(_manager.current_phase).is_equal(RoundManager.RoundPhase.DEATH_CHECK)


# === Milestone 1 Criterion 3: Bust detection ===


func test_e2e_bust_detection() -> void:
	_manager.start_round()
	var bust_found := false
	for i in range(10):
		if _manager.player_result.is_bust:
			bust_found = true
			break
		_manager.player_hit()

	if bust_found:
		assert_bool(_manager.player_result.point_total > 21).is_true()
		# Player auto-stands on bust — further hits ignored
		var size_before := _manager.player_hand.size()
		_manager.player_hit()
		assert_int(_manager.player_hand.size()).is_equal(size_before)
	else:
		# Extremely rare: 12 cards without bust — just verify valid state
		assert_int(_manager.player_hand.size()).is_equal(12)


# === Milestone 1 Criterion 4: AI hits below 17, stands at 17+ ===


func test_e2e_ai_follows_hit_stand_rules() -> void:
	_manager.start_round()
	_manager.player_stand()

	if _manager.ai_result.is_bust:
		assert_bool(_manager.ai_result.point_total > 21).is_true()
	else:
		assert_bool(_manager.ai_result.point_total >= 17).is_true()


# === Milestone 1 Criterion 5: Damage applied to both sides ===


func test_e2e_settlement_events_match_state() -> void:
	var init_p_hp := _combat.player.hp
	var init_a_hp := _combat.ai.hp
	var init_chips := _chips.get_balance()

	var captured := _run_round_capture()
	var events: Array = captured["events"]

	var expected := _simulate_events(
		events, init_p_hp, init_a_hp, init_chips,
		_combat.player.max_hp, _combat.ai.max_hp
	)

	assert_int(_combat.player.hp).is_equal(expected["player_hp"])
	assert_int(_combat.ai.hp).is_equal(expected["ai_hp"])
	assert_int(_combat.player.defense).is_equal(expected["player_defense"])
	assert_int(_combat.ai.defense).is_equal(expected["ai_defense"])
	assert_int(_chips.get_balance()).is_equal(expected["chips_balance"])


# === Round result validity ===


func test_e2e_round_result_is_valid() -> void:
	var captured := _run_round_capture()
	var result: int = captured["result"]["result"]
	assert_bool(
		result == RoundManager.RoundResult.CONTINUE or
		result == RoundManager.RoundResult.PLAYER_WIN or
		result == RoundManager.RoundResult.PLAYER_LOSE
	).is_true()
	assert_int(captured["result"]["opp"]).is_equal(1)
	assert_int(captured["result"]["round"]).is_equal(1)


# === Multi-round: state accumulates correctly across rounds ===


func test_e2e_three_rounds_accumulation() -> void:
	var events_spy := {"data": [] as Array}
	var events_cb := func(e: Array) -> void: events_spy["data"] = e
	_resolution.settlement_step_completed.connect(events_cb)

	var player_hp := _combat.player.hp
	var ai_hp := _combat.ai.hp
	var chips := _chips.get_balance()

	for round_idx in range(3):
		_manager.start_round()
		_manager.player_stand()

		var expected := _simulate_events(
			events_spy["data"], player_hp, ai_hp, chips,
			_combat.player.max_hp, _combat.ai.max_hp
		)

		player_hp = expected["player_hp"]
		ai_hp = expected["ai_hp"]
		chips = expected["chips_balance"]

		assert_int(_combat.player.hp).is_equal(player_hp)
		assert_int(_combat.ai.hp).is_equal(ai_hp)
		assert_int(_chips.get_balance()).is_equal(chips)
		assert_int(_manager.round_counter).is_equal(round_idx + 2)

	_resolution.settlement_step_completed.disconnect(events_cb)


# === Opponent transition: full E2E ===


func test_e2e_opponent_transition() -> void:
	# Force AI death — start_round detects it via early death check
	_combat.ai.hp = 0
	var spy := {"result": -1}
	var cb := func(r: int, _on: int, _rn: int, _ph: int, _ah: int) -> void:
		spy["result"] = r
	_manager.round_result.connect(cb)
	_manager.start_round()
	_manager.round_result.disconnect(cb)
	assert_int(spy["result"]).is_equal(RoundManager.RoundResult.PLAYER_WIN)

	var pre_chips := _chips.get_balance()
	var pre_player_hp := _combat.player.hp
	_manager.transition_to_next_opponent()

	assert_int(_manager.opponent_number).is_equal(2)
	assert_int(_manager.round_counter).is_equal(1)
	assert_int(_combat.player.hp).is_equal(pre_player_hp)
	assert_int(_combat.ai.hp).is_equal(100)  # Opponent 2 = 100 from scaling table
	assert_bool(_chips.get_balance() > pre_chips).is_true()  # Victory bonus added


# === Events correspond to actual cards in hands ===


func test_e2e_events_reference_dealt_cards() -> void:
	var captured := _run_round_capture()
	var events: Array = captured["events"]

	# Build a set of all card references from both hands
	var all_cards: Dictionary = {}
	for card in _manager.player_hand:
		all_cards[card.get_instance_id()] = true
	for card in _manager.ai_hand:
		all_cards[card.get_instance_id()] = true

	for event in events:
		assert_bool(all_cards.has(event.card.get_instance_id())).is_true()
