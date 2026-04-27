extends GdUnitTestSuite

const _ChipEconomy := preload("res://scripts/chip_economy/chip_economy.gd")

var _chips: ChipEconomy


func before_test() -> void:
	_chips = auto_free(ChipEconomy.new())
	_chips.initialize()


func after_test() -> void:
	_chips = null


# ============================================================
# AC-01: Initial balance = 100, transaction log cleared
# ============================================================

func test_initialize_sets_balance_to_100() -> void:
	assert_int(_chips.get_balance()).is_equal(100)


func test_initialize_clears_transaction_log() -> void:
	_chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	_chips.initialize()
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


# ============================================================
# AC-03: Balance capped at 999; add_chips returns actual gained
# ============================================================

func test_balance_capped_at_999() -> void:
	_chips.add_chips(800, ChipEconomy.ChipSource.RESOLUTION)
	var actual := _chips.add_chips(100, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(_chips.get_balance()).is_equal(999)
	assert_int(actual).is_equal(99)


func test_add_chips_at_cap_returns_zero() -> void:
	_chips.add_chips(898, ChipEconomy.ChipSource.RESOLUTION)
	var actual := _chips.add_chips(1, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(1)
	var overflow := _chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(overflow).is_equal(0)
	assert_int(_chips.get_balance()).is_equal(999)


# ============================================================
# AC-04: All 6 income sources work independently
# ============================================================

func test_all_six_income_sources() -> void:
	var sources: Array[int] = [
		ChipEconomy.ChipSource.RESOLUTION,
		ChipEconomy.ChipSource.SETTLEMENT_TIE_COMP,
		ChipEconomy.ChipSource.SIDE_POOL_RETURN,
		ChipEconomy.ChipSource.SHOP_SELL,
		ChipEconomy.ChipSource.VICTORY_BONUS,
		ChipEconomy.ChipSource.INSURANCE_REFUND,
	]
	var amounts: Array[int] = [25, 20, 100, 37, 125, 30]
	var expected_balance := 0
	for i in range(sources.size()):
		expected_balance += amounts[i]
		_chips.add_chips(amounts[i], sources[i])
	assert_int(_chips.get_balance()).is_equal(100 + expected_balance)
	var log_entries := _chips.get_transaction_log()
	assert_int(log_entries.size()).is_equal(6)
	for i in range(log_entries.size()):
		var record: ChipEconomy.TransactionRecord = log_entries[i]
		assert_int(record.amount).is_equal(amounts[i])
		assert_int(record.category).is_equal(sources[i])
		assert_bool(record.is_income).is_true()


# ============================================================
# AC-05: Balance persists across add/spend cycles
# ============================================================

func test_balance_persists_across_operations() -> void:
	_chips.add_chips(150, ChipEconomy.ChipSource.VICTORY_BONUS)
	assert_int(_chips.get_balance()).is_equal(250)
	_chips.spend_chips(80, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_int(_chips.get_balance()).is_equal(170)


# ============================================================
# AC-06: Zero chip income possible (no forced minimum)
# ============================================================

func test_small_income_works() -> void:
	var actual := _chips.add_chips(1, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(1)
	assert_int(_chips.get_balance()).is_equal(101)


# ============================================================
# AC-07: victory_bonus = 50 + 25 * (opponent_number - 1) (range 50-225)
# ============================================================

func test_victory_bonus_opponent_1() -> void:
	assert_int(ChipEconomy.calculate_victory_bonus(1)).is_equal(50)


func test_victory_bonus_opponent_8() -> void:
	assert_int(ChipEconomy.calculate_victory_bonus(8)).is_equal(225)


func test_victory_bonus_opponent_range() -> void:
	var expected: Dictionary = {
		1: 50, 2: 75, 3: 100, 4: 125,
		5: 150, 6: 175, 7: 200, 8: 225,
	}
	for opponent in expected:
		assert_int(ChipEconomy.calculate_victory_bonus(opponent)).is_equal(expected[opponent])


func test_victory_bonus_opponent_0_returns_25() -> void:
	assert_int(ChipEconomy.calculate_victory_bonus(0)).is_equal(25)


func test_victory_bonus_opponent_9_returns_250() -> void:
	assert_int(ChipEconomy.calculate_victory_bonus(9)).is_equal(250)


# ============================================================
# AC-15: spend_chips returns false if balance insufficient
# ============================================================

func test_spend_chips_insufficient_returns_false() -> void:
	var result := _chips.spend_chips(150, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(result).is_false()
	assert_int(_chips.get_balance()).is_equal(100)
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


# ============================================================
# AC-16: Zero-value add_chips is a no-op
# ============================================================

func test_add_chips_zero_is_noop() -> void:
	var actual := _chips.add_chips(0, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(0)
	assert_int(_chips.get_balance()).is_equal(100)
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


# ============================================================
# AC-17: Negative amounts rejected
# ============================================================

func test_add_chips_negative_rejected() -> void:
	var actual := _chips.add_chips(-50, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(0)
	assert_int(_chips.get_balance()).is_equal(100)
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


func test_add_chips_negative_no_signal() -> void:
	var spy := {"emitted": false}
	_chips.chips_changed.connect(func(_b: int, _d: int, _s: int) -> void:
		spy["emitted"] = true
	)
	_chips.add_chips(-50, ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(spy["emitted"]).is_false()


func test_spend_chips_negative_rejected() -> void:
	var result := _chips.spend_chips(-10, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(result).is_false()
	assert_int(_chips.get_balance()).is_equal(100)


func test_spend_chips_zero_rejected() -> void:
	var result := _chips.spend_chips(0, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(result).is_false()
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


func test_spend_chips_zero_no_signal() -> void:
	var spy := {"emitted": false}
	_chips.chips_changed.connect(func(_b: int, _d: int, _s: int) -> void:
		spy["emitted"] = true
	)
	_chips.spend_chips(0, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(spy["emitted"]).is_false()


# ============================================================
# AC-18: add_chips returns actual amount gained
# ============================================================

func test_add_chips_returns_actual_gained_near_cap() -> void:
	_chips.add_chips(890, ChipEconomy.ChipSource.RESOLUTION)
	var actual := _chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(9)
	assert_int(_chips.get_balance()).is_equal(999)


func test_add_chips_returns_full_amount_when_below_cap() -> void:
	var actual := _chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	assert_int(actual).is_equal(50)


# ============================================================
# AC-26: can_afford(amount) returns true iff amount > 0 and amount <= balance
# ============================================================

func test_can_afford_exact_balance() -> void:
	assert_bool(_chips.can_afford(100)).is_true()


func test_can_afford_less_than_balance() -> void:
	assert_bool(_chips.can_afford(50)).is_true()


func test_can_afford_more_than_balance() -> void:
	assert_bool(_chips.can_afford(101)).is_false()


func test_can_afford_zero() -> void:
	assert_bool(_chips.can_afford(0)).is_false()


func test_can_afford_negative() -> void:
	assert_bool(_chips.can_afford(-5)).is_false()


# ============================================================
# AC-28: reset_for_new_game resets balance and clears log
# ============================================================

func test_reset_for_new_game() -> void:
	_chips.add_chips(200, ChipEconomy.ChipSource.VICTORY_BONUS)
	_chips.spend_chips(50, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	_chips.reset_for_new_game()
	assert_int(_chips.get_balance()).is_equal(100)
	assert_int(_chips.get_transaction_log().size()).is_equal(0)


# ============================================================
# chips_changed signal emission
# ============================================================

func test_signal_emitted_on_add_chips() -> void:
	var spy := {"emitted": false, "balance": -1, "delta": -1, "source": -1}
	_chips.chips_changed.connect(func(b: int, d: int, s: int) -> void:
		spy["emitted"] = true
		spy["balance"] = b
		spy["delta"] = d
		spy["source"] = s
	)
	_chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["balance"]).is_equal(150)
	assert_int(spy["delta"]).is_equal(50)
	assert_int(spy["source"]).is_equal(ChipEconomy.ChipSource.RESOLUTION)


func test_signal_emitted_on_spend_chips() -> void:
	var spy := {"emitted": false, "balance": -1, "delta": -1, "source": -1}
	_chips.chips_changed.connect(func(b: int, d: int, s: int) -> void:
		spy["emitted"] = true
		spy["balance"] = b
		spy["delta"] = d
		spy["source"] = s
	)
	_chips.spend_chips(30, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(spy["emitted"]).is_true()
	assert_int(spy["balance"]).is_equal(70)
	assert_int(spy["delta"]).is_equal(-30)
	assert_int(spy["source"]).is_equal(ChipEconomy.ChipPurpose.SHOP_PURCHASE)


func test_signal_not_emitted_on_zero_add() -> void:
	var spy := {"emitted": false}
	_chips.chips_changed.connect(func(_b: int, _d: int, _s: int) -> void:
		spy["emitted"] = true
	)
	_chips.add_chips(0, ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(spy["emitted"]).is_false()


func test_signal_not_emitted_on_insufficient_spend() -> void:
	var spy := {"emitted": false}
	_chips.chips_changed.connect(func(_b: int, _d: int, _s: int) -> void:
		spy["emitted"] = true
	)
	_chips.spend_chips(500, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(spy["emitted"]).is_false()


func test_signal_not_emitted_at_cap() -> void:
	_chips.add_chips(898, ChipEconomy.ChipSource.RESOLUTION)
	var spy := {"emitted": false}
	_chips.chips_changed.connect(func(_b: int, _d: int, _s: int) -> void:
		spy["emitted"] = true
	)
	_chips.add_chips(1, ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(spy["emitted"]).is_true()
	spy["emitted"] = false
	_chips.add_chips(50, ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(spy["emitted"]).is_false()


# ============================================================
# Transaction log entries
# ============================================================

func test_transaction_log_contains_income_and_spend() -> void:
	_chips.add_chips(45, ChipEconomy.ChipSource.RESOLUTION)
	_chips.spend_chips(30, ChipEconomy.ChipPurpose.INSURANCE)
	var log_entries := _chips.get_transaction_log()
	assert_int(log_entries.size()).is_equal(2)

	var income_record: ChipEconomy.TransactionRecord = log_entries[0]
	assert_int(income_record.amount).is_equal(45)
	assert_int(income_record.category).is_equal(ChipEconomy.ChipSource.RESOLUTION)
	assert_bool(income_record.is_income).is_true()

	var spend_record: ChipEconomy.TransactionRecord = log_entries[1]
	assert_int(spend_record.amount).is_equal(-30)
	assert_int(spend_record.category).is_equal(ChipEconomy.ChipPurpose.INSURANCE)
	assert_bool(spend_record.is_income).is_false()


func test_transaction_log_capped_income_records_actual() -> void:
	_chips.add_chips(850, ChipEconomy.ChipSource.RESOLUTION)
	_chips.add_chips(50, ChipEconomy.ChipSource.VICTORY_BONUS)
	var log_entries := _chips.get_transaction_log()
	assert_int(log_entries.size()).is_equal(2)
	var capped_record: ChipEconomy.TransactionRecord = log_entries[1]
	assert_int(capped_record.amount).is_equal(49)


	# ============================================================
	# Extra coverage: balance-to-zero, SIDE_POOL_BET
	# ============================================================

func test_spend_exact_balance_to_zero() -> void:
	var result := _chips.spend_chips(100, ChipEconomy.ChipPurpose.SHOP_PURCHASE)
	assert_bool(result).is_true()
	assert_int(_chips.get_balance()).is_equal(0)
	assert_bool(_chips.can_afford(1)).is_false()
	var second := _chips.spend_chips(1, ChipEconomy.ChipPurpose.INSURANCE)
	assert_bool(second).is_false()


func test_spend_side_pool_bet_purpose() -> void:
	var result := _chips.spend_chips(20, ChipEconomy.ChipPurpose.SIDE_POOL_BET)
	assert_bool(result).is_true()
	assert_int(_chips.get_balance()).is_equal(80)
	var log_entries := _chips.get_transaction_log()
	assert_int(log_entries.size()).is_equal(1)
	var record: ChipEconomy.TransactionRecord = log_entries[0]
	assert_int(record.category).is_equal(ChipEconomy.ChipPurpose.SIDE_POOL_BET)
	assert_bool(record.is_income).is_false()
