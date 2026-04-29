class_name ShopSystem extends Node

## Shop system for the card-battle game.
## Generates random inventory, handles purchases/sells/purify, all atomic (spend before mutate).
## Design reference: ADR-0007 — Shop Weighted Random, Story 3-4.

# Own constants
const HP_COST_PER_POINT: int = 5
const REFRESH_COST: int = 20
const SELL_PRICE_RATIO: float = 0.50
const RANDOM_STAMP_COUNT: int = 2
const RANDOM_CARD_COUNT: int = 2
const RANDOM_STAMP_RATIO: float = 0.40
const RANDOM_DISCOUNT_RATIO: float = 0.50
const MAX_RETRIES: int = 10

var _combat: CombatState = null
var _chips: ChipEconomy = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_inventory: Array[ShopItem] = []
var _sold_cards: Array[CardInstance] = []


func initialize(combat: CombatState, chips: ChipEconomy) -> void:
	_combat = combat
	_chips = chips


func set_rng_seed(seed_value: int) -> void:
	_rng.set_seed(seed_value)


# ---------------------------------------------------------------------------
# Inventory generation
# ---------------------------------------------------------------------------

func generate_inventory(player_deck: Array[CardInstance], opponent_number: int) -> Array[ShopItem]:
	var items: Array[ShopItem] = []

	# 2 random stamps (without replacement)
	var stamps: Array = _weighted_select_without_replacement(
		StampSystem.STAMP_RANDOM_WEIGHTS, RANDOM_STAMP_COUNT, _rng
	)
	for selected_stamp: int in stamps:
		var p: int = StampSystem.get_price(selected_stamp)
		items.append(ShopItem.new_stamp(selected_stamp, p))

	# 2 random enhanced cards from player deck
	for _i: int in RANDOM_CARD_COUNT:
		if player_deck.size() == 0:
			break
		var card: CardInstance = player_deck[_rng.randi_range(0, player_deck.size() - 1)]
		var item: ShopItem = _generate_enhanced_card(card)
		items.append(item)

	_current_inventory = items
	_sold_cards.clear()
	return items


func refresh_inventory(player_deck: Array[CardInstance], opponent_number: int) -> bool:
	if not _chips.spend_chips(REFRESH_COST, ChipEconomy.ChipPurpose.SHOP_PURCHASE):
		return false
	generate_inventory(player_deck, opponent_number)
	return true


func get_current_inventory() -> Array[ShopItem]:
	return _current_inventory


# ---------------------------------------------------------------------------
# Fixed services — all atomic (spend before mutate)
# ---------------------------------------------------------------------------

func buy_hp(hp_amount: int) -> bool:
	if hp_amount <= 0:
		return false
	var price: int = hp_amount * HP_COST_PER_POINT
	if not _chips.spend_chips(price, ChipEconomy.ChipPurpose.SHOP_PURCHASE):
		return false
	_combat.apply_heal(CardEnums.Owner.PLAYER, hp_amount)
	return true


func buy_stamp(card: CardInstance, stamp: int) -> bool:
	var price: int = StampSystem.get_price(stamp)
	if not _chips.spend_chips(price, ChipEconomy.ChipPurpose.SHOP_PURCHASE):
		return false
	card.assign_stamp(stamp)
	return true


func buy_quality(card: CardInstance, quality: int) -> bool:
	if not CardPrototype.is_valid_assignment(card.prototype.suit, quality):
		return false
	var price: int = QualitySystem.get_price(quality)
	if not _chips.spend_chips(price, ChipEconomy.ChipPurpose.SHOP_PURCHASE):
		return false
	card.assign_quality(quality, CardEnums.QualityLevel.III)
	return true


func purify(card: CardInstance) -> bool:
	if card.quality == CardEnums.Quality.NONE or card.quality_level == CardEnums.QualityLevel.I:
		return false
	var price: int = QualitySystem.get_purify_cost(card.quality_level)
	if not _chips.spend_chips(price, ChipEconomy.ChipPurpose.SHOP_PURCHASE):
		return false
	card.purify()
	return true


func sell_card(card: CardInstance) -> int:
	if card in _sold_cards:
		return 0
	var investment: int = _calculate_investment(card)
	var refund: int = int(investment * SELL_PRICE_RATIO)
	card.sell_card()
	_chips.add_chips(refund, ChipEconomy.ChipSource.SHOP_SELL)
	_sold_cards.append(card)
	return refund


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _weighted_select(weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var total: int = 0
	for w: int in weights.values():
		total += w
	var roll: int = rng.randi_range(1, total)
	var cumulative: int = 0
	for key: Variant in weights:
		cumulative += int(weights[key])
		if roll <= cumulative:
			return key
	return weights.keys()[-1]


func _weighted_select_without_replacement(weights: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var remaining: Dictionary = weights.duplicate()
	var result: Array = []
	for _i: int in count:
		if remaining.size() == 0:
			break
		var selected: Variant = _weighted_select(remaining, rng)
		result.append(selected)
		remaining.erase(selected)
	return result


func _generate_enhanced_card(card: CardInstance) -> ShopItem:
	var is_stamp: bool = _rng.randf() < RANDOM_STAMP_RATIO
	var base_price: int = card.prototype.base_buy_price

	if is_stamp:
		var stamp: int = int(_weighted_select(StampSystem.STAMP_RANDOM_WEIGHTS, _rng))
		var price: int = base_price + int(StampSystem.get_price(stamp) * RANDOM_DISCOUNT_RATIO)
		return ShopItem.new_card_stamp(card, stamp, price)
	else:
		var quality: int = _roll_valid_quality(card.prototype.suit)
		var price: int = base_price + int(QualitySystem.get_price(quality) * RANDOM_DISCOUNT_RATIO)
		return ShopItem.new_card_quality(card, quality, CardEnums.QualityLevel.III, price)


func _roll_valid_quality(suit: int) -> int:
	for _attempt: int in MAX_RETRIES:
		var quality: int = int(_weighted_select(QualitySystem.QUALITY_RANDOM_WEIGHTS, _rng))
		if CardPrototype.is_valid_assignment(suit, quality):
			return quality
	return CardEnums.Quality.COPPER


func _calculate_investment(card: CardInstance) -> int:
	return card.prototype.base_buy_price \
		+ StampSystem.get_price(card.stamp) \
		+ QualitySystem.get_price(card.quality)
