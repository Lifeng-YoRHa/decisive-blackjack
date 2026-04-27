extends GdUnitTestSuite

# Force-load source scripts so class_name resolution doesn't depend on editor state
const _CardEnums := preload("res://scripts/card_data_model/enums.gd")
const _CardPrototype := preload("res://scripts/card_data_model/card_prototype.gd")
const _CardInstance := preload("res://scripts/card_data_model/card_instance.gd")
const _CardDataModel := preload("res://scripts/card_data_model/card_data_model.gd")

var _model: CardDataModel


func before() -> void:
	_model = auto_free(CardDataModel.new())
	assert_bool(_model != null).is_true()
	_model.initialize()


func after() -> void:
	_model = null


# --- AC-01: Prototype lookup completeness ---

func test_prototype_lookup_52_unique() -> void:
	var keys: Dictionary = {}
	for suit in CardEnums.ALL_SUITS:
		for rank in CardEnums.ALL_RANKS:
			var proto := _model.get_prototype(suit, rank)
			assert_bool(proto != null).is_true()
			assert_bool(not keys.has(proto.key)).is_true()
			keys[proto.key] = true
	assert_int(keys.size()).is_equal(52)


# --- AC-02: Prototype field correctness ---

func test_prototype_ace_fields() -> void:
	var ace := _model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.ACE)
	assert_array(ace.bj_values).is_equal([1, 11])
	assert_int(ace.effect_value).is_equal(15)
	assert_int(ace.chip_value).is_equal(75)

func test_prototype_spade_king_buy_price() -> void:
	var spade_k := _model.get_prototype(CardEnums.Suit.SPADES, CardEnums.Rank.KING)
	assert_int(spade_k.base_buy_price).is_equal(75)

func test_prototype_heart_king_buy_price() -> void:
	var heart_k := _model.get_prototype(CardEnums.Suit.HEARTS, CardEnums.Rank.KING)
	assert_int(heart_k.base_buy_price).is_equal(65)


# --- AC-03: Instance creation uniqueness ---

func test_instance_creation_104_unique() -> void:
	assert_int(_model._instances.size()).is_equal(104)
	var keys: Dictionary = {}
	for c in _model._instances:
		var key := "%d_%d_%d" % [c.owner, c.prototype.suit, c.prototype.rank]
		assert_bool(not keys.has(key)).is_true()
		keys[key] = true
	assert_int(keys.size()).is_equal(104)


# --- AC-04: Player deck default state ---

func test_player_deck_defaults() -> void:
	var player_deck := _model.get_player_deck()
	assert_int(player_deck.size()).is_equal(52)
	for c in player_deck:
		assert_int(c.stamp).is_equal(CardEnums.Stamp.NONE)
		assert_int(c.quality).is_equal(CardEnums.Quality.NONE)
		assert_int(c.quality_level).is_equal(CardEnums.QualityLevel.III)


# --- AC-05: Deck invariant after mutation ---

func test_deck_invariant_after_mutation() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.HEARTS, CardEnums.Rank.ACE)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.COPPER)
	assert_int(_model.get_player_deck().size()).is_equal(52)


# --- AC-06: Enhancement overwrite ---

func test_enhancement_overwrite() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.SPADES, CardEnums.Rank.ACE)
	card.assign_stamp(CardEnums.Stamp.SHIELD)
	card.assign_quality(CardEnums.Quality.GOLD, CardEnums.QualityLevel.II)
	card.assign_stamp(CardEnums.Stamp.COIN)
	card.assign_quality(CardEnums.Quality.SILVER, CardEnums.QualityLevel.III)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.COIN)
	assert_int(card.quality).is_equal(CardEnums.Quality.SILVER)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)


# --- AC-07: Revision counter increment ---

func test_revision_increments() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.HEARTS, CardEnums.Rank.KING)
	assert_int(card.revision).is_equal(0)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	assert_int(card.revision).is_equal(1)
	card.destroy_quality()
	assert_int(card.revision).is_equal(2)


# --- AC-08: Gem quality destroy ---

func test_destroy_quality_clears_gem_keeps_stamp() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.DIAMONDS, CardEnums.Rank.SEVEN)
	card.assign_stamp(CardEnums.Stamp.SWORD)
	card.assign_quality(CardEnums.Quality.RUBY, CardEnums.QualityLevel.II)
	card.destroy_quality()
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	assert_int(card.stamp).is_equal(CardEnums.Stamp.SWORD)


# --- AC-14: is_valid_assignment gem-suit binding ---

func test_gem_suit_binding() -> void:
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.RUBY)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.SAPPHIRE)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.EMERALD)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.OBSIDIAN)).is_true()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.HEARTS, CardEnums.Quality.RUBY)).is_false()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.SPADES, CardEnums.Quality.SAPPHIRE)).is_false()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.DIAMONDS, CardEnums.Quality.EMERALD)).is_false()
	assert_bool(CardPrototype.is_valid_assignment(CardEnums.Suit.CLUBS, CardEnums.Quality.OBSIDIAN)).is_false()


# --- AC-15: Metal quality no suit restriction ---

func test_metal_no_suit_restriction() -> void:
	var metals := [CardEnums.Quality.COPPER, CardEnums.Quality.SILVER, CardEnums.Quality.GOLD, CardEnums.Quality.DIAMOND_Q]
	for suit in CardEnums.ALL_SUITS:
		for metal in metals:
			assert_bool(CardPrototype.is_valid_assignment(suit, metal)).is_true()


# --- AC-10: Sell card mechanism ---

func test_sell_card_clears_enhancements() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.HEARTS, CardEnums.Rank.KING)
	card.assign_stamp(CardEnums.Stamp.HAMMER)
	card.assign_quality(CardEnums.Quality.DIAMOND_Q, CardEnums.QualityLevel.I)
	card.sell_card()
	assert_int(card.stamp).is_equal(CardEnums.Stamp.NONE)
	assert_int(card.quality).is_equal(CardEnums.Quality.NONE)
	assert_int(card.quality_level).is_equal(CardEnums.QualityLevel.III)
	assert_int(_model.get_player_deck().size()).is_equal(52)


# --- Serialization round-trip ---

func test_to_dict_from_dict_roundtrip() -> void:
	var card := _model.get_instance(CardEnums.Owner.PLAYER, CardEnums.Suit.SPADES, CardEnums.Rank.JACK)
	card.assign_stamp(CardEnums.Stamp.COIN)
	card.assign_quality(CardEnums.Quality.OBSIDIAN, CardEnums.QualityLevel.I)
	var data := card.to_dict()
	var restored := CardInstance.from_dict(data, _model._prototypes)
	assert_int(restored.prototype.suit).is_equal(CardEnums.Suit.SPADES)
	assert_int(restored.prototype.rank).is_equal(CardEnums.Rank.JACK)
	assert_int(restored.owner).is_equal(CardEnums.Owner.PLAYER)
	assert_int(restored.stamp).is_equal(CardEnums.Stamp.COIN)
	assert_int(restored.quality).is_equal(CardEnums.Quality.OBSIDIAN)
	assert_int(restored.quality_level).is_equal(CardEnums.QualityLevel.I)
	assert_int(restored.revision).is_equal(card.revision)


# --- O(1) instance lookup ---

func test_get_instance_returns_correct_card() -> void:
	var card := _model.get_instance(CardEnums.Owner.AI, CardEnums.Suit.DIAMONDS, CardEnums.Rank.THREE)
	assert_bool(card != null).is_true()
	assert_int(card.owner).is_equal(CardEnums.Owner.AI)
	assert_int(card.prototype.suit).is_equal(CardEnums.Suit.DIAMONDS)
	assert_int(card.prototype.rank).is_equal(CardEnums.Rank.THREE)


# --- Regenerate AI deck ---

func test_regenerate_ai_deck() -> void:
	var old_ai := _model.get_ai_deck()
	assert_int(old_ai.size()).is_equal(52)
	_model.regenerate_ai_deck()
	var new_ai := _model.get_ai_deck()
	assert_int(new_ai.size()).is_equal(52)
	assert_int(_model.get_player_deck().size()).is_equal(52)
	assert_int(_model._instances.size()).is_equal(104)
