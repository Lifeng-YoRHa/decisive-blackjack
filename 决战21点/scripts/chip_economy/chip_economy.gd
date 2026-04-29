class_name ChipEconomy
extends Node

enum ChipSource {
	RESOLUTION,
	SETTLEMENT_TIE_COMP,
	SIDE_POOL_RETURN,
	SHOP_SELL,
	VICTORY_BONUS,
	INSURANCE_REFUND,
}

enum ChipPurpose {
	SHOP_PURCHASE,
	SIDE_POOL_BET,
	INSURANCE,
}

signal chips_changed(new_balance: int, delta: int, source: int)

const INITIAL_BALANCE: int = 100
const CHIP_CAP: int = 9999
const VICTORY_BASE: int = 50
const VICTORY_SCALE: int = 25

var _balance: int = 0
var _transaction_log: Array[TransactionRecord] = []


class TransactionRecord extends RefCounted:
	var amount: int
	var category: int
	var is_income: bool

	func _init(amt: int, cat: int, income: bool) -> void:
		amount = amt
		category = cat
		is_income = income


func initialize() -> void:
	_balance = INITIAL_BALANCE
	_transaction_log.clear()


func add_chips(amount: int, source: ChipSource) -> int:
	if amount <= 0:
		return 0
	var old := _balance
	_balance = mini(_balance + amount, CHIP_CAP)
	var actual := _balance - old
	if actual > 0:
		_transaction_log.append(TransactionRecord.new(actual, source, true))
		chips_changed.emit(_balance, actual, source)
	return actual


func spend_chips(amount: int, purpose: ChipPurpose) -> bool:
	if amount <= 0:
		return false
	if amount > _balance:
		return false
	_balance -= amount
	_transaction_log.append(TransactionRecord.new(-amount, purpose, false))
	chips_changed.emit(_balance, -amount, purpose)
	return true


func can_afford(amount: int) -> bool:
	return amount > 0 and amount <= _balance


func get_balance() -> int:
	return _balance


func get_transaction_log() -> Array[TransactionRecord]:
	return _transaction_log


func reset_for_new_game() -> void:
	_balance = INITIAL_BALANCE
	_transaction_log.clear()


static func calculate_victory_bonus(opponent_number: int) -> int:
	return VICTORY_BASE + VICTORY_SCALE * (opponent_number - 1)
