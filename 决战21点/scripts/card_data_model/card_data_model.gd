class_name CardDataModel extends Node

var _prototypes: Dictionary = {}
var _instances: Array = []
var _instance_index: Dictionary = {}

const GEM_DESTROY_PROB: Dictionary = {
	CardEnums.QualityLevel.III: 0.15,
	CardEnums.QualityLevel.II: 0.10,
	CardEnums.QualityLevel.I: 0.05,
}

const METAL_CHIP_BONUS: Dictionary = {
	CardEnums.Quality.COPPER: {CardEnums.QualityLevel.III: 10, CardEnums.QualityLevel.II: 15, CardEnums.QualityLevel.I: 20},
	CardEnums.Quality.SILVER: {CardEnums.QualityLevel.III: 20, CardEnums.QualityLevel.II: 28, CardEnums.QualityLevel.I: 36},
	CardEnums.Quality.GOLD: {CardEnums.QualityLevel.III: 30, CardEnums.QualityLevel.II: 40, CardEnums.QualityLevel.I: 50},
	CardEnums.Quality.DIAMOND_Q: {CardEnums.QualityLevel.III: 50, CardEnums.QualityLevel.II: 66, CardEnums.QualityLevel.I: 82},
}

const GEM_COMBAT_BONUS: Dictionary = {
	CardEnums.Quality.RUBY: {CardEnums.QualityLevel.III: 3, CardEnums.QualityLevel.II: 4, CardEnums.QualityLevel.I: 5},
	CardEnums.Quality.SAPPHIRE: {CardEnums.QualityLevel.III: 3, CardEnums.QualityLevel.II: 4, CardEnums.QualityLevel.I: 5},
	CardEnums.Quality.EMERALD: {CardEnums.QualityLevel.III: 15, CardEnums.QualityLevel.II: 20, CardEnums.QualityLevel.I: 25},
	CardEnums.Quality.OBSIDIAN: {CardEnums.QualityLevel.III: 3, CardEnums.QualityLevel.II: 4, CardEnums.QualityLevel.I: 5},
}


func initialize() -> void:
	_prototypes.clear()
	_instances.clear()
	_instance_index.clear()
	_build_prototypes()
	_build_instances()


func get_prototype(suit: int, rank: int) -> CardPrototype:
	return _prototypes["%d_%d" % [suit, rank]]


func get_instance(owner: int, suit: int, rank: int) -> CardInstance:
	return _instance_index.get("%d_%d_%d" % [owner, suit, rank])


func get_player_deck() -> Array:
	var result: Array = []
	for c in _instances:
		if c.owner == CardEnums.Owner.PLAYER and not c.expired:
			result.append(c)
	return result


func get_all_player_cards() -> Array:
	var result: Array = []
	for c in _instances:
		if c.owner == CardEnums.Owner.PLAYER:
			result.append(c)
	return result


func get_ai_deck() -> Array:
	var result: Array = []
	for c in _instances:
		if c.owner == CardEnums.Owner.AI and not c.expired:
			result.append(c)
	return result


func regenerate_ai_deck() -> void:
	for c in _instances:
		if c.owner == CardEnums.Owner.AI:
			c.expired = true
	var kept: Dictionary = {}
	for key in _instance_index:
		if _instance_index[key].owner == CardEnums.Owner.PLAYER:
			kept[key] = _instance_index[key]
	_instance_index = kept
	_instances = _instances.filter(func(c): return c.owner == CardEnums.Owner.PLAYER)
	_build_owner_deck(CardEnums.Owner.AI)


func _build_prototypes() -> void:
	for suit in CardEnums.ALL_SUITS:
		for rank in CardEnums.ALL_RANKS:
			var proto := CardPrototype.new(suit, rank)
			_prototypes[proto.key] = proto


func _build_instances() -> void:
	_build_owner_deck(CardEnums.Owner.PLAYER)
	_build_owner_deck(CardEnums.Owner.AI)


func _build_owner_deck(owner: int) -> void:
	for suit in CardEnums.ALL_SUITS:
		for rank in CardEnums.ALL_RANKS:
			var proto := get_prototype(suit, rank)
			var card := CardInstance.new(proto, owner)
			_instances.append(card)
			_instance_index["%d_%d_%d" % [owner, suit, rank]] = card
