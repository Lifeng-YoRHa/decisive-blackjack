class_name StampSystem extends RefCounted

enum StampEffectType { NONE, DAMAGE, DEFENSE, HEAL, CHIPS, NULLIFY_TARGET, SORT_FIRST, SORT_LAST }

const STAMP_BONUS_LOOKUP: Dictionary = {
	CardEnums.Stamp.NONE: { value = 0, type = StampEffectType.NONE },
	CardEnums.Stamp.SWORD: { value = 2, type = StampEffectType.DAMAGE },
	CardEnums.Stamp.SHIELD: { value = 2, type = StampEffectType.DEFENSE },
	CardEnums.Stamp.HEART: { value = 2, type = StampEffectType.HEAL },
	CardEnums.Stamp.COIN: { value = 10, type = StampEffectType.CHIPS },
	CardEnums.Stamp.HAMMER: { value = 0, type = StampEffectType.NULLIFY_TARGET },
	CardEnums.Stamp.RUNNING_SHOES: { value = 0, type = StampEffectType.SORT_FIRST },
	CardEnums.Stamp.TURTLE: { value = 0, type = StampEffectType.SORT_LAST },
}

const STAMP_SORT_KEY: Dictionary = {
	CardEnums.Stamp.NONE: 1,
	CardEnums.Stamp.SWORD: 1,
	CardEnums.Stamp.SHIELD: 1,
	CardEnums.Stamp.HEART: 1,
	CardEnums.Stamp.COIN: 1,
	CardEnums.Stamp.HAMMER: 1,
	CardEnums.Stamp.RUNNING_SHOES: 0,
	CardEnums.Stamp.TURTLE: 2,
}

const STAMP_PRICES: Dictionary = {
	CardEnums.Stamp.SWORD: 100,
	CardEnums.Stamp.SHIELD: 100,
	CardEnums.Stamp.HEART: 100,
	CardEnums.Stamp.COIN: 100,
	CardEnums.Stamp.RUNNING_SHOES: 150,
	CardEnums.Stamp.TURTLE: 150,
	CardEnums.Stamp.HAMMER: 300,
}

const STAMP_RANDOM_WEIGHTS: Dictionary = {
	CardEnums.Stamp.SWORD: 25,
	CardEnums.Stamp.SHIELD: 25,
	CardEnums.Stamp.HEART: 25,
	CardEnums.Stamp.COIN: 25,
	CardEnums.Stamp.RUNNING_SHOES: 12,
	CardEnums.Stamp.TURTLE: 12,
	CardEnums.Stamp.HAMMER: 1,
}


static func get_bonus(stamp: int) -> Dictionary:
	if STAMP_BONUS_LOOKUP.has(stamp):
		return STAMP_BONUS_LOOKUP[stamp]
	return STAMP_BONUS_LOOKUP[CardEnums.Stamp.NONE]


static func get_combat_bonus(stamp: int) -> int:
	var bonus: Dictionary = get_bonus(stamp)
	if bonus.type == StampEffectType.DAMAGE or bonus.type == StampEffectType.DEFENSE or bonus.type == StampEffectType.HEAL:
		return bonus.value
	return 0


static func get_coin_bonus(stamp: int) -> int:
	var bonus: Dictionary = get_bonus(stamp)
	if bonus.type == StampEffectType.CHIPS:
		return bonus.value
	return 0


static func get_sort_key(stamp: int) -> int:
	if STAMP_SORT_KEY.has(stamp):
		return STAMP_SORT_KEY[stamp]
	return 1


static func get_price(stamp: int) -> int:
	if STAMP_PRICES.has(stamp):
		return STAMP_PRICES[stamp]
	return 0


static func is_sort_stamp(stamp: int) -> bool:
	return stamp == CardEnums.Stamp.RUNNING_SHOES or stamp == CardEnums.Stamp.TURTLE


static func is_hammer(stamp: int) -> bool:
	return stamp == CardEnums.Stamp.HAMMER
