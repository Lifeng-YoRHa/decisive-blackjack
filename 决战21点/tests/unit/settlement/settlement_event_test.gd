extends GdUnitTestSuite

const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CardDataModel := preload("res://scripts/card_data_model/card_data_model.gd")
const _SettlementEvent := preload("res://scripts/settlement/settlement_event.gd")

var _model: CardDataModel


func before() -> void:
	_model = auto_free(CardDataModel.new())
	_model.initialize()


func after() -> void:
	_model = null


func _make_card(suit: int, rank: int) -> CardInstance:
	var proto := _model.get_prototype(suit, rank)
	return CardInstance.new(proto, CardEnums.Owner.PLAYER)


func _make_event(step: SettlementEvent.StepKind, card: CardInstance, value: int, target: String, meta: Dictionary = {}) -> SettlementEvent:
	var event := SettlementEvent.new()
	event.step = step
	event.card = card
	event.value = value
	event.target = target
	event.metadata = meta
	return event


# --- StepKind enum completeness ---

func test_step_kind_has_nine_values() -> void:
	assert_int(SettlementEvent.StepKind.BASE_VALUE).is_equal(0)
	assert_int(SettlementEvent.StepKind.STAMP_EFFECT).is_equal(1)
	assert_int(SettlementEvent.StepKind.QUALITY_EFFECT).is_equal(2)
	assert_int(SettlementEvent.StepKind.MULTIPLIER_APPLIED).is_equal(3)
	assert_int(SettlementEvent.StepKind.BUST_DAMAGE).is_equal(4)
	assert_int(SettlementEvent.StepKind.GEM_DESTROY).is_equal(5)
	assert_int(SettlementEvent.StepKind.CHIP_GAINED).is_equal(6)
	assert_int(SettlementEvent.StepKind.DEFENSE_APPLIED).is_equal(7)
	assert_int(SettlementEvent.StepKind.HEAL_APPLIED).is_equal(8)


# --- Event construction with all fields ---

func test_event_construction_all_fields() -> void:
	var card := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.KING)
	var event := _make_event(SettlementEvent.StepKind.BASE_VALUE, card, 13, "player", {"multiplier": 2.0})
	assert_int(event.step).is_equal(SettlementEvent.StepKind.BASE_VALUE)
	assert_object(event.card).is_equal(card)
	assert_int(event.value).is_equal(13)
	assert_str(event.target).is_equal("player")
	assert_dict(event.metadata).is_equal({"multiplier": 2.0})


# --- Event default values ---

func test_event_default_values() -> void:
	var event := SettlementEvent.new()
	assert_int(event.value).is_equal(0)
	assert_str(event.target).is_equal("")
	assert_dict(event.metadata).is_equal({})


# --- Event queue accumulation pattern ---

func test_event_queue_accumulation() -> void:
	var card := _make_card(CardEnums.Suit.SPADES, CardEnums.Rank.JACK)
	var queue: Array[SettlementEvent] = []

	queue.append(_make_event(SettlementEvent.StepKind.BASE_VALUE, card, 11, "player"))
	queue.append(_make_event(SettlementEvent.StepKind.STAMP_EFFECT, card, 3, "player"))
	queue.append(_make_event(SettlementEvent.StepKind.MULTIPLIER_APPLIED, card, 28, "player", {"multiplier": 2.0}))

	assert_int(queue.size()).is_equal(3)
	assert_int(queue[0].step).is_equal(SettlementEvent.StepKind.BASE_VALUE)
	assert_int(queue[1].step).is_equal(SettlementEvent.StepKind.STAMP_EFFECT)
	assert_int(queue[2].step).is_equal(SettlementEvent.StepKind.MULTIPLIER_APPLIED)
	assert_int(queue[2].value).is_equal(28)


# --- Event queue clear (pipeline reset) ---

func test_event_queue_clear_between_runs() -> void:
	var card := _make_card(CardEnums.Suit.HEARTS, CardEnums.Rank.SEVEN)
	var queue: Array[SettlementEvent] = []

	queue.append(_make_event(SettlementEvent.StepKind.BASE_VALUE, card, 7, "player"))
	assert_int(queue.size()).is_equal(1)

	queue.clear()
	assert_int(queue.size()).is_equal(0)

	queue.append(_make_event(SettlementEvent.StepKind.BUST_DAMAGE, card, 23, "ai"))
	assert_int(queue.size()).is_equal(1)
	assert_int(queue[0].step).is_equal(SettlementEvent.StepKind.BUST_DAMAGE)


# --- Event queue preserves order ---

func test_event_queue_order_preserved() -> void:
	var card := _make_card(CardEnums.Suit.DIAMONDS, CardEnums.Rank.NINE)
	var queue: Array[SettlementEvent] = []
	var steps := [
		SettlementEvent.StepKind.BASE_VALUE,
		SettlementEvent.StepKind.STAMP_EFFECT,
		SettlementEvent.StepKind.QUALITY_EFFECT,
		SettlementEvent.StepKind.MULTIPLIER_APPLIED,
		SettlementEvent.StepKind.DEFENSE_APPLIED,
	]
	for s in steps:
		queue.append(_make_event(s, card, 0, "player"))

	for i in steps.size():
		assert_int(queue[i].step).is_equal(steps[i])


# --- Duplicate event queue (safe for emission) ---

func test_event_queue_duplicate_safe() -> void:
	var card := _make_card(CardEnums.Suit.CLUBS, CardEnums.Rank.ACE)
	var queue: Array[SettlementEvent] = []
	queue.append(_make_event(SettlementEvent.StepKind.HEAL_APPLIED, card, 15, "player"))

	var snapshot := queue.duplicate()
	queue.clear()
	assert_int(snapshot.size()).is_equal(1)
	assert_int(snapshot[0].step).is_equal(SettlementEvent.StepKind.HEAL_APPLIED)
	assert_int(queue.size()).is_equal(0)


# --- RefCounted lifecycle (no memory leak in queue) ---

func test_event_is_refcounted() -> void:
	var event := SettlementEvent.new()
	assert_bool(event is RefCounted).is_true()
	event = null
