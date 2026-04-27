extends GdUnitTestSuite

## Unit tests for CombatState -- Combatant Core API.
## Covers: initialization, HP/damage/defense/heal, signal emission, idempotency.
##
## Acceptance Criteria mapping:
##   AC-01: is_alive / is_dead based on HP > 0
##   AC-02: Player initialized with 100 HP, 0 defense
##   AC-03: AI HP scales per opponent number (8 tiers)
##   AC-04: Defense accumulates without cap, resets per turn
##   AC-05: Damage absorbed by defense first; HP floors at 0
##   AC-06: Heal capped at max_hp; overflow returned
##   AC-07: reset_defense idempotent (no crash when already 0)
##   Signal: hp_changed and defense_changed emit on state changes

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CombatState := preload("res://scripts/combat/combat_state.gd")

var _combat: CombatState


func before_test() -> void:
	_combat = auto_free(CombatState.new())
	_combat.initialize()


func after_test() -> void:
	_combat = null


# ============================================================
# AC-01: is_alive / is_dead
# ============================================================

func test_is_alive_at_full_hp() -> void:
	assert_bool(_combat.player.is_alive).is_true()


func test_is_alive_at_one_hp() -> void:
	_combat.player.hp = 1
	assert_bool(_combat.player.is_alive).is_true()


func test_is_dead_at_zero_hp() -> void:
	_combat.player.hp = 0
	assert_bool(_combat.player.is_alive).is_false()


# ============================================================
# AC-02: Player initialization
# ============================================================

func test_player_hp_is_100() -> void:
	assert_int(_combat.player.hp).is_equal(100)


func test_player_max_hp_is_100() -> void:
	assert_int(_combat.player.max_hp).is_equal(100)


func test_player_defense_starts_at_zero() -> void:
	assert_int(_combat.player.defense).is_equal(0)


# ============================================================
# AC-03: AI HP scaling for all 8 opponent tiers
# ============================================================

func test_ai_default_hp_is_80() -> void:
	assert_int(_combat.ai.hp).is_equal(80)
	assert_int(_combat.ai.max_hp).is_equal(80)


func test_ai_hp_scaling_all_tiers() -> void:
	var expected: Dictionary = {1: 80, 2: 100, 3: 120, 4: 150, 5: 180, 6: 220, 7: 260, 8: 300}
	for tier in expected:
		_combat.setup_opponent(tier)
		assert_int(_combat.ai.max_hp).is_equal(expected[tier])
		assert_int(_combat.ai.hp).is_equal(expected[tier])


func test_ai_defense_starts_at_zero() -> void:
	assert_int(_combat.ai.defense).is_equal(0)


# ============================================================
# AC-04: Defense accumulation (no cap) and reset
# ============================================================

func test_add_defense_accumulates() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 5)
	assert_int(_combat.player.defense).is_equal(5)
	_combat.add_defense(CardEnums.Owner.PLAYER, 10)
	assert_int(_combat.player.defense).is_equal(15)


func test_add_defense_no_cap() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 200)
	assert_int(_combat.player.defense).is_equal(200)


func test_add_defense_to_ai() -> void:
	_combat.add_defense(CardEnums.Owner.AI, 7)
	assert_int(_combat.ai.defense).is_equal(7)


func test_reset_defense_clears_both() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 10)
	_combat.add_defense(CardEnums.Owner.AI, 20)
	_combat.reset_defense()
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


# ============================================================
# AC-05: Damage with defense absorption, HP floor at 0
# ============================================================

func test_damage_reduces_hp() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 30)
	assert_int(_combat.player.hp).is_equal(70)


func test_damage_absorbed_by_defense() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 10)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 7)
	assert_int(_combat.player.defense).is_equal(3)
	assert_int(_combat.player.hp).is_equal(100)


func test_damage_exceeds_defense_reduces_hp() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 5)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 15)
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.player.hp).is_equal(90)


func test_damage_exact_defense_full_absorb() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 10)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 10)
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.player.hp).is_equal(100)


func test_damage_hp_floors_at_zero() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 150)
	assert_int(_combat.player.hp).is_equal(0)


func test_damage_hp_floors_at_zero_no_negative() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 999)
	assert_int(_combat.player.hp).is_equal(0)


func test_damage_to_ai() -> void:
	_combat.apply_damage(CardEnums.Owner.AI, 30)
	assert_int(_combat.ai.hp).is_equal(50)


func test_is_alive_false_after_lethal_damage() -> void:
	_combat.apply_damage(CardEnums.Owner.AI, 80)
	assert_bool(_combat.ai.is_alive).is_false()


func test_is_alive_true_after_nonlethal_damage() -> void:
	_combat.apply_damage(CardEnums.Owner.AI, 79)
	assert_bool(_combat.ai.is_alive).is_true()


# ============================================================
# AC-06: Heal capped at max_hp, overflow returned
# ============================================================

func test_heal_restores_hp() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 40)
	var overflow := _combat.apply_heal(CardEnums.Owner.PLAYER, 20)
	assert_int(_combat.player.hp).is_equal(80)
	assert_int(overflow).is_equal(0)


func test_heal_capped_at_max_hp() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 10)
	var overflow := _combat.apply_heal(CardEnums.Owner.PLAYER, 30)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(overflow).is_equal(20)


func test_heal_at_max_hp_returns_full_overflow() -> void:
	var overflow := _combat.apply_heal(CardEnums.Owner.PLAYER, 50)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(overflow).is_equal(50)


func test_heal_exact_to_max_no_overflow() -> void:
	_combat.apply_damage(CardEnums.Owner.PLAYER, 25)
	var overflow := _combat.apply_heal(CardEnums.Owner.PLAYER, 25)
	assert_int(_combat.player.hp).is_equal(100)
	assert_int(overflow).is_equal(0)


func test_heal_on_ai() -> void:
	_combat.apply_damage(CardEnums.Owner.AI, 30)
	var overflow := _combat.apply_heal(CardEnums.Owner.AI, 10)
	assert_int(_combat.ai.hp).is_equal(60)
	assert_int(overflow).is_equal(0)


# ============================================================
# AC-07: reset_defense idempotent
# ============================================================

func test_reset_defense_idempotent_when_already_zero() -> void:
	# Both defenses are 0 from initialize()
	_combat.reset_defense()
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


func test_reset_defense_twice_in_a_row() -> void:
	_combat.add_defense(CardEnums.Owner.PLAYER, 5)
	_combat.add_defense(CardEnums.Owner.AI, 3)
	_combat.reset_defense()
	_combat.reset_defense()
	assert_int(_combat.player.defense).is_equal(0)
	assert_int(_combat.ai.defense).is_equal(0)


# ============================================================
# Signal emission tests
# Note: GDScript lambdas capture basic types (bool, int) by value.
# Use Dictionary (reference type) so mutations propagate back.
# ============================================================

func test_hp_changed_emitted_on_damage() -> void:
	var spy := {"emitted": false, "target": -1, "hp": -1, "max": -1}
	_combat.hp_changed.connect(func(target: int, new_hp: int, max_hp: int) -> void:
		spy["emitted"] = true
		spy["target"] = target
		spy["hp"] = new_hp
		spy["max"] = max_hp
	)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 25)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["target"]).is_equal(CardEnums.Owner.PLAYER)
	assert_int(spy["hp"]).is_equal(75)
	assert_int(spy["max"]).is_equal(100)


func test_hp_changed_not_emitted_when_defense_absorbs_all() -> void:
	var spy := {"emitted": false}
	_combat.hp_changed.connect(func(_target: int, _new_hp: int, _max_hp: int) -> void:
		spy["emitted"] = true
	)
	_combat.add_defense(CardEnums.Owner.PLAYER, 50)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 30)
	assert_bool(spy["emitted"]).is_false()


func test_hp_changed_emitted_on_heal_when_hp_changes() -> void:
	var spy := {"emitted": false, "hp": -1}
	_combat.hp_changed.connect(func(_target: int, new_hp: int, _max_hp: int) -> void:
		spy["emitted"] = true
		spy["hp"] = new_hp
	)
	_combat.apply_damage(CardEnums.Owner.PLAYER, 30)
	_combat.apply_heal(CardEnums.Owner.PLAYER, 10)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["hp"]).is_equal(80)


func test_hp_changed_not_emitted_on_heal_at_max_hp() -> void:
	var spy := {"emitted": false}
	_combat.hp_changed.connect(func(_target: int, _new_hp: int, _max_hp: int) -> void:
		spy["emitted"] = true
	)
	_combat.apply_heal(CardEnums.Owner.PLAYER, 10)
	assert_bool(spy["emitted"]).is_false()


func test_defense_changed_emitted_on_add() -> void:
	var spy := {"emitted": false, "defense": -1}
	_combat.defense_changed.connect(func(_target: int, new_defense: int) -> void:
		spy["emitted"] = true
		spy["defense"] = new_defense
	)
	_combat.add_defense(CardEnums.Owner.PLAYER, 15)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["defense"]).is_equal(15)


func test_defense_changed_emitted_on_damage_absorb() -> void:
	var spy := {"emitted": false, "defense": -1}
	_combat.defense_changed.connect(func(_target: int, new_defense: int) -> void:
		spy["emitted"] = true
		spy["defense"] = new_defense
	)
	_combat.add_defense(CardEnums.Owner.PLAYER, 20)
	# Reset tracking after the add_defense emit
	spy["emitted"] = false
	_combat.apply_damage(CardEnums.Owner.PLAYER, 12)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["defense"]).is_equal(8)


func test_defense_changed_emitted_on_reset() -> void:
	var signals_received: Array[int] = []
	_combat.defense_changed.connect(func(_target: int, _new_defense: int) -> void:
		signals_received.append(_new_defense)
	)
	_combat.add_defense(CardEnums.Owner.PLAYER, 10)
	_combat.add_defense(CardEnums.Owner.AI, 5)
	signals_received.clear()
	_combat.reset_defense()
	assert_int(signals_received.size()).is_equal(2)
	assert_int(signals_received[0]).is_equal(0)
	assert_int(signals_received[1]).is_equal(0)


func test_defense_changed_not_emitted_on_reset_when_already_zero() -> void:
	var signals_received: Array[int] = []
	_combat.defense_changed.connect(func(_target: int, _new_defense: int) -> void:
		signals_received.append(_new_defense)
	)
	_combat.reset_defense()
	assert_int(signals_received.size()).is_equal(0)


func test_signal_target_correct_for_ai() -> void:
	var spy := {"target": -1}
	_combat.hp_changed.connect(func(target: int, _new_hp: int, _max_hp: int) -> void:
		spy["target"] = target
	)
	_combat.apply_damage(CardEnums.Owner.AI, 10)
	assert_int(spy["target"]).is_equal(CardEnums.Owner.AI)
