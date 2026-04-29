class_name ShopItem extends RefCounted

## Lightweight data object representing a single item available in the shop.
## Design reference: ADR-0007 — Shop Weighted Random, Story 3-4.

enum Kind { STAMP, CARD_STAMP, CARD_QUALITY, HP_RECOVERY }

var kind: int = Kind.STAMP
var stamp: int = 0
var quality: int = 0
var quality_level: int = 0
var target_card: CardInstance = null
var price: int = 0


static func new_stamp(p_stamp: int, p_price: int) -> ShopItem:
	var item := ShopItem.new()
	item.kind = Kind.STAMP
	item.stamp = p_stamp
	item.price = p_price
	return item


static func new_card_stamp(p_card: CardInstance, p_stamp: int, p_price: int) -> ShopItem:
	var item := ShopItem.new()
	item.kind = Kind.CARD_STAMP
	item.target_card = p_card
	item.stamp = p_stamp
	item.price = p_price
	return item


static func new_card_quality(p_card: CardInstance, p_quality: int, p_level: int, p_price: int) -> ShopItem:
	var item := ShopItem.new()
	item.kind = Kind.CARD_QUALITY
	item.target_card = p_card
	item.quality = p_quality
	item.quality_level = p_level
	item.price = p_price
	return item


static func new_hp_recovery(p_hp_amount: int, p_price: int) -> ShopItem:
	var item := ShopItem.new()
	item.kind = Kind.HP_RECOVERY
	item.quality = p_hp_amount
	item.price = p_price
	return item
