class_name CardEnums

enum Suit { HEARTS, DIAMONDS, SPADES, CLUBS }
enum Rank { ACE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING }
enum Stamp { NONE, SWORD, SHIELD, HEART, COIN, HAMMER, RUNNING_SHOES, TURTLE }
enum Quality { NONE, COPPER, SILVER, GOLD, DIAMOND_Q, RUBY, SAPPHIRE, EMERALD, OBSIDIAN }
enum QualityLevel { III, II, I }
enum Owner { PLAYER, AI }

const ALL_SUITS: Array = [Suit.HEARTS, Suit.DIAMONDS, Suit.SPADES, Suit.CLUBS]
const ALL_RANKS: Array = [
	Rank.ACE, Rank.TWO, Rank.THREE, Rank.FOUR, Rank.FIVE, Rank.SIX,
	Rank.SEVEN, Rank.EIGHT, Rank.NINE, Rank.TEN, Rank.JACK, Rank.QUEEN, Rank.KING,
]
