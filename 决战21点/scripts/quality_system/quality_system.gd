class_name QualitySystem extends RefCounted

enum CombatType { NONE, DAMAGE, HEAL, DEFENSE, CHIPS }

const QUALITY_BONUS_RESOLVE: Dictionary = {
	CardEnums.Quality.NONE: { combat_type = CombatType.NONE, combat_value = [0, 0, 0], chip_value = [0, 0, 0] },
	CardEnums.Quality.COPPER: { combat_type = CombatType.NONE, combat_value = [0, 0, 0], chip_value = [10, 15, 20] },
	CardEnums.Quality.SILVER: { combat_type = CombatType.NONE, combat_value = [0, 0, 0], chip_value = [20, 28, 36] },
	CardEnums.Quality.GOLD: { combat_type = CombatType.NONE, combat_value = [0, 0, 0], chip_value = [30, 40, 50] },
	CardEnums.Quality.DIAMOND_Q: { combat_type = CombatType.NONE, combat_value = [0, 0, 0], chip_value = [50, 66, 82] },
	CardEnums.Quality.RUBY: { combat_type = CombatType.DAMAGE, combat_value = [3, 4, 5], chip_value = [0, 0, 0] },
	CardEnums.Quality.SAPPHIRE: { combat_type = CombatType.HEAL, combat_value = [3, 4, 5], chip_value = [0, 0, 0] },
	CardEnums.Quality.EMERALD: { combat_type = CombatType.CHIPS, combat_value = [0, 0, 0], chip_value = [15, 20, 25] },
	CardEnums.Quality.OBSIDIAN: { combat_type = CombatType.DEFENSE, combat_value = [3, 4, 5], chip_value = [0, 0, 0] },
}

const GEM_DESTROY_PROB: Dictionary = {
	CardEnums.QualityLevel.III: 0.15,
	CardEnums.QualityLevel.II: 0.10,
	CardEnums.QualityLevel.I: 0.05,
}

const PURIFY_COST: Dictionary = {
	CardEnums.QualityLevel.III: 100,
	CardEnums.QualityLevel.II: 200,
}

const QUALITY_PRICES: Dictionary = {
	CardEnums.Quality.COPPER: 40,
	CardEnums.Quality.SILVER: 80,
	CardEnums.Quality.GOLD: 120,
	CardEnums.Quality.DIAMOND_Q: 200,
	CardEnums.Quality.RUBY: 120,
	CardEnums.Quality.SAPPHIRE: 120,
	CardEnums.Quality.EMERALD: 120,
	CardEnums.Quality.OBSIDIAN: 120,
}

const QUALITY_RANDOM_WEIGHTS: Dictionary = {
	CardEnums.Quality.COPPER: 25,
	CardEnums.Quality.SILVER: 25,
	CardEnums.Quality.GOLD: 20,
	CardEnums.Quality.DIAMOND_Q: 5,
	CardEnums.Quality.RUBY: 6,
	CardEnums.Quality.SAPPHIRE: 6,
	CardEnums.Quality.EMERALD: 6,
	CardEnums.Quality.OBSIDIAN: 6,
}

const GEM_QUALITIES: Array = [
	CardEnums.Quality.RUBY,
	CardEnums.Quality.SAPPHIRE,
	CardEnums.Quality.EMERALD,
	CardEnums.Quality.OBSIDIAN,
]


static func resolve_bonus(quality: int, quality_level: int) -> Dictionary:
	if not QUALITY_BONUS_RESOLVE.has(quality):
		return { combat_type = CombatType.NONE, combat_value = 0, chip_value = 0 }
	var entry: Dictionary = QUALITY_BONUS_RESOLVE[quality]
	var level_index: int = quality_level
	if level_index < 0 or level_index > 2:
		level_index = 0
	return {
		combat_type = entry.combat_type,
		combat_value = entry.combat_value[level_index],
		chip_value = entry.chip_value[level_index],
	}


static func gem_destroy_prob(quality_level: int) -> float:
	if GEM_DESTROY_PROB.has(quality_level):
		return GEM_DESTROY_PROB[quality_level]
	return 0.0


static func is_gem(quality: int) -> bool:
	return quality in GEM_QUALITIES


static func get_price(quality: int) -> int:
	if QUALITY_PRICES.has(quality):
		return QUALITY_PRICES[quality]
	return 0


static func get_purify_cost(current_level: int) -> int:
	if PURIFY_COST.has(current_level):
		return PURIFY_COST[current_level]
	return 0
