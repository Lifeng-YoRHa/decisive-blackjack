class_name HandTypeDetection

enum HandType {
	PAIR,
	FLUSH,
	THREE_KIND,
	TRIPLE_SEVEN,
	TWENTY_ONE,
	BLACKJACK_TYPE,
	SPADE_BLACKJACK,
}

const DEFAULT_MULTIPLIERS: Dictionary = {
	HandType.PAIR: 2,
	HandType.THREE_KIND: 5,
	HandType.TRIPLE_SEVEN: 7,
	HandType.TWENTY_ONE: 2,
	HandType.BLACKJACK_TYPE: 4,
}


static func detect(cards: Array[CardInstance], point_result: PointResult,
		suppress_blackjack: bool = false,
		multipliers: Dictionary = DEFAULT_MULTIPLIERS) -> HandTypeResult:
	var result := HandTypeResult.new()
	if point_result.is_bust or cards.is_empty():
		return result

	# Step 1: Rank histogram
	var rank_counts: Dictionary = {}
	var rank_cards: Dictionary = {}
	for i in cards.size():
		var r: int = cards[i].prototype.rank
		if not rank_counts.has(r):
			rank_counts[r] = 0
			rank_cards[r] = []
		rank_counts[r] += 1
		rank_cards[r].append(i)

	# Step 2: Suit set
	var suits: Dictionary = {}
	for card in cards:
		suits[card.prototype.suit] = true

	# Step 3: PAIR and THREE_KIND
	for r in rank_counts:
		var count: int = rank_counts[r]
		if count == 2:
			result.matches.append(_make_scoped(HandType.PAIR, multipliers.get(HandType.PAIR, 2), rank_cards[r], cards.size()))
		elif count == 3:
			result.matches.append(_make_scoped(HandType.THREE_KIND, multipliers.get(HandType.THREE_KIND, 5), rank_cards[r], cards.size()))

	# Step 4: FLUSH
	if suits.size() == 1:
		var flush_mult: int = cards.size()
		result.matches.append(_make_all(HandType.FLUSH, flush_mult, cards.size()))

	# Step 5: TRIPLE_SEVEN
	if rank_counts.get(CardEnums.Rank.SEVEN, 0) == 3:
		result.matches.append(_make_all(HandType.TRIPLE_SEVEN, multipliers.get(HandType.TRIPLE_SEVEN, 7), cards.size()))

	# Step 6: TWENTY_ONE
	if point_result.point_total == 21:
		result.matches.append(_make_all(HandType.TWENTY_ONE, multipliers.get(HandType.TWENTY_ONE, 2), cards.size()))

	# Steps 7-8: BLACKJACK_TYPE and SPADE_BLACKJACK
	if not suppress_blackjack and point_result.point_total == 21 and cards.size() == 2:
		var c0_rank: int = cards[0].prototype.rank
		var c1_rank: int = cards[1].prototype.rank
		var c0_suit: int = cards[0].prototype.suit
		var c1_suit: int = cards[1].prototype.suit
		var has_ace: bool = (c0_rank == CardEnums.Rank.ACE or c1_rank == CardEnums.Rank.ACE)
		var has_jack: bool = (c0_rank == CardEnums.Rank.JACK or c1_rank == CardEnums.Rank.JACK)
		if has_ace and has_jack:
			var is_spade_blackjack := false
			if c0_suit == CardEnums.Suit.SPADES and c1_suit == CardEnums.Suit.SPADES:
				if (c0_rank == CardEnums.Rank.ACE and c1_rank == CardEnums.Rank.JACK) or \
				   (c0_rank == CardEnums.Rank.JACK and c1_rank == CardEnums.Rank.ACE):
					is_spade_blackjack = true
			if is_spade_blackjack:
				result.matches.append(_make_instant_win(cards.size()))
				result.has_instant_win = true
			else:
				result.matches.append(_make_all(HandType.BLACKJACK_TYPE, multipliers.get(HandType.BLACKJACK_TYPE, 4), cards.size()))

	return result


static func validate_multipliers(mults: Dictionary) -> bool:
	var pair: int = mults.get(HandType.PAIR, 2)
	var three: int = mults.get(HandType.THREE_KIND, 5)
	var triple: int = mults.get(HandType.TRIPLE_SEVEN, 7)
	var twenty_one: int = mults.get(HandType.TWENTY_ONE, 2)
	var bj: int = mults.get(HandType.BLACKJACK_TYPE, 4)
	return pair <= three and three <= triple and twenty_one < bj and bj < triple


static func _make_scoped(type: int, base_mult: int, affected: Array, hand_size: int) -> HandTypeOption:
	var opt := HandTypeOption.new()
	opt.type = type
	opt.display_name = HandType.keys()[type]
	opt.display_multiplier = base_mult
	var affected_set: Dictionary = {}
	for idx in affected:
		affected_set[idx] = true
	var mults: Array[float] = []
	for i in hand_size:
		mults.append(float(base_mult) if affected_set.has(i) else 1.0)
	opt.per_card_multiplier = mults
	return opt


static func _make_all(type: int, base_mult: int, hand_size: int) -> HandTypeOption:
	var opt := HandTypeOption.new()
	opt.type = type
	opt.display_name = HandType.keys()[type]
	opt.display_multiplier = base_mult
	var mults: Array[float] = []
	for _i in hand_size:
		mults.append(float(base_mult))
	opt.per_card_multiplier = mults
	return opt


static func _make_instant_win(hand_size: int) -> HandTypeOption:
	var opt := HandTypeOption.new()
	opt.type = HandType.SPADE_BLACKJACK
	opt.display_name = "SPADE_BLACKJACK"
	opt.display_multiplier = 0
	opt.is_instant_win = true
	var mults: Array[float] = []
	for _i in hand_size:
		mults.append(0.0)
	opt.per_card_multiplier = mults
	return opt
