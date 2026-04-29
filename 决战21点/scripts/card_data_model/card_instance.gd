class_name CardInstance extends RefCounted

signal attribute_changed(card: CardInstance)

var prototype: CardPrototype
var owner: int
var stamp: int = CardEnums.Stamp.NONE
var quality: int = CardEnums.Quality.NONE
var quality_level: int = CardEnums.QualityLevel.III
var revision: int = 0
var expired: bool = false
var invalidated: bool = false


func _init(p_prototype: CardPrototype, p_owner: int) -> void:
	prototype = p_prototype
	owner = p_owner


func assign_stamp(new_stamp: int) -> void:
	stamp = new_stamp
	revision += 1
	attribute_changed.emit(self)


func assign_quality(new_quality: int, level: int = CardEnums.QualityLevel.III) -> void:
	assert(CardPrototype.is_valid_assignment(prototype.suit, new_quality),
		"Invalid quality-suit assignment: quality=%d suit=%d" % [new_quality, prototype.suit])
	quality = new_quality
	quality_level = level
	revision += 1
	attribute_changed.emit(self)


func destroy_quality() -> void:
	quality = CardEnums.Quality.NONE
	quality_level = CardEnums.QualityLevel.III
	revision += 1
	attribute_changed.emit(self)


func purify() -> bool:
	if quality == CardEnums.Quality.NONE or quality_level == CardEnums.QualityLevel.I:
		return false
	quality_level += 1
	revision += 1
	attribute_changed.emit(self)
	return true


func sell_card() -> void:
	stamp = CardEnums.Stamp.NONE
	quality = CardEnums.Quality.NONE
	quality_level = CardEnums.QualityLevel.III
	invalidated = false
	revision += 1
	attribute_changed.emit(self)


func to_dict() -> Dictionary:
	return {
		"suit": prototype.suit,
		"rank": prototype.rank,
		"owner": owner,
		"stamp": stamp,
		"quality": quality,
		"quality_level": quality_level,
		"revision": revision,
		"invalidated": invalidated,
	}


static func from_dict(data: Dictionary, prototypes: Dictionary) -> CardInstance:
	var key: String = "%d_%d" % [data.suit, data.rank]
	var card := CardInstance.new(prototypes[key], data.owner)
	card.stamp = data.stamp
	card.quality = data.quality
	card.quality_level = data.quality_level
	card.revision = data.revision
	card.invalidated = data.get("invalidated", false)
	return card
