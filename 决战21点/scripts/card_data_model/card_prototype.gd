class_name CardPrototype extends RefCounted

var suit: int
var rank: int
var bj_values: Array
var effect_value: int
var chip_value: int
var base_buy_price: int
var key: String

const _BJ_VALUES: Dictionary = {
	CardEnums.Rank.ACE: [1, 11],
	CardEnums.Rank.TWO: [2], CardEnums.Rank.THREE: [3], CardEnums.Rank.FOUR: [4],
	CardEnums.Rank.FIVE: [5], CardEnums.Rank.SIX: [6], CardEnums.Rank.SEVEN: [7],
	CardEnums.Rank.EIGHT: [8], CardEnums.Rank.NINE: [9], CardEnums.Rank.TEN: [10],
	CardEnums.Rank.JACK: [10], CardEnums.Rank.QUEEN: [10], CardEnums.Rank.KING: [10],
}

const EFFECT_VALUE: Dictionary = {
	CardEnums.Rank.ACE: 15, CardEnums.Rank.TWO: 2, CardEnums.Rank.THREE: 3,
	CardEnums.Rank.FOUR: 4, CardEnums.Rank.FIVE: 5, CardEnums.Rank.SIX: 6,
	CardEnums.Rank.SEVEN: 7, CardEnums.Rank.EIGHT: 8, CardEnums.Rank.NINE: 9,
	CardEnums.Rank.TEN: 10, CardEnums.Rank.JACK: 11, CardEnums.Rank.QUEEN: 12,
	CardEnums.Rank.KING: 13,
}

const CHIP_VALUE: Dictionary = {
	CardEnums.Rank.ACE: 75, CardEnums.Rank.TWO: 10, CardEnums.Rank.THREE: 15,
	CardEnums.Rank.FOUR: 20, CardEnums.Rank.FIVE: 25, CardEnums.Rank.SIX: 30,
	CardEnums.Rank.SEVEN: 35, CardEnums.Rank.EIGHT: 40, CardEnums.Rank.NINE: 45,
	CardEnums.Rank.TEN: 50, CardEnums.Rank.JACK: 55, CardEnums.Rank.QUEEN: 60,
	CardEnums.Rank.KING: 65,
}

const SPADE_FACE_BONUS: int = 10


func _init(p_suit: int, p_rank: int) -> void:
	suit = p_suit
	rank = p_rank
	bj_values = _BJ_VALUES[rank]
	effect_value = EFFECT_VALUE[rank]
	chip_value = CHIP_VALUE[rank]
	var bonus: int = 0
	if suit == CardEnums.Suit.SPADES and rank in [CardEnums.Rank.JACK, CardEnums.Rank.QUEEN, CardEnums.Rank.KING, CardEnums.Rank.ACE]:
		bonus = SPADE_FACE_BONUS
	base_buy_price = chip_value + bonus
	key = "%d_%d" % [suit, rank]


static func is_valid_assignment(suit: int, quality: int) -> bool:
	if quality == CardEnums.Quality.NONE:
		return true
	match quality:
		CardEnums.Quality.RUBY: return suit == CardEnums.Suit.DIAMONDS
		CardEnums.Quality.SAPPHIRE: return suit == CardEnums.Suit.HEARTS
		CardEnums.Quality.EMERALD: return suit == CardEnums.Suit.CLUBS
		CardEnums.Quality.OBSIDIAN: return suit == CardEnums.Suit.SPADES
		_: return true
