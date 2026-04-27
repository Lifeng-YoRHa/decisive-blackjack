# ADR-0006: AI Strategy Pattern

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Feature (AI decision-making) |
| **Knowledge Risk** | LOW — Array operations, RandomNumberGenerator, enums stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (AIOpponent as scene-tree node), ADR-0002 (CardInstance data model, is_valid_assignment) |
| **Enables** | ADR-0008 (UI shows AI decision animations), all AI opponent stories |
| **Blocks** | Stories involving AI decision-making, AI deck generation |
| **Ordering Note** | Should be Accepted before AI implementation stories. Can proceed in parallel with ADR-0007/0008. |

## Context

### Problem Statement
AI opponents make decisions at 4 points during a round (insurance, split, hit/stand, sort+hand-type selection). Decision quality scales across 8 opponents using 3 tiers (BASIC/SMART/OPTIMAL). AI deck generation creates 52 cards with difficulty-scaled stamps and qualities. How is the AI structured — single class, polymorphic strategies, or data-driven tables?

### Constraints
- 3 decision tiers across 8 opponents (BASIC=1-3, SMART=4-6, OPTIMAL=7-8)
- AI is stateless between rounds — holds no mutable cross-round state
- AI is called by RoundManager at specific phase points — does not drive game flow
- AI has perfect card counting (tracks all dealt cards)
- Deck generation must be deterministic for given RNG seed
- All tuning knobs must be data-driven (const lookup tables)

### Requirements
- Must support 3 hit/stand strategies (threshold, probability, probability+desperation)
- Must support 3 sort strategies (RANDOM, DEFAULT, TACTICAL)
- Must generate 52-card AI deck with stamp/quality constraints
- Must evaluate hand type options and select optimal
- Must always split and always buy insurance (hardcoded rules)

## Decision

### Single AIOpponent class with tier-indexed lookup tables

```gdscript
class_name AIOpponent extends Node

enum DecisionTier { BASIC, SMART, OPTIMAL }
enum SortStrategy { RANDOM, DEFAULT, TACTICAL }

var _card_data: CardDataModel
var _rng: RandomNumberGenerator

# Tier configuration indexed by opponent_number (0-indexed)
const TIER_TABLE: Array[DecisionTier] = [
    DecisionTier.BASIC, DecisionTier.BASIC, DecisionTier.BASIC,
    DecisionTier.SMART, DecisionTier.SMART, DecisionTier.SMART,
    DecisionTier.OPTIMAL, DecisionTier.OPTIMAL
]

const HIT_THRESHOLD: Array[int] = [14, 15, 16]
const BUST_TOLERANCE: Array[float] = [0.50, 0.40, 0.35, 0.30, 0.25]
const DESPERATION_BONUS: Array[float] = [0.15, 0.20]
const SORT_STRATEGY: Array[SortStrategy] = [
    SortStrategy.RANDOM, SortStrategy.RANDOM, SortStrategy.RANDOM,
    SortStrategy.DEFAULT, SortStrategy.DEFAULT, SortStrategy.TACTICAL,
    SortStrategy.TACTICAL, SortStrategy.TACTICAL
]

func initialize(card_data: CardDataModel) -> void:
    _card_data = card_data
    _rng = RandomNumberGenerator.new()
```

### Hit/Stand Decision

```gdscript
func make_decision(
    hand: Array[CardInstance],
    point_result: PointResult,
    remaining_deck: Dictionary,
    opponent_number: int,
    ai_hp: int,
    ai_max_hp: int
) -> AIAction:
    if point_result.is_bust:
        return AIAction.STAND

    var tier := TIER_TABLE[opponent_number - 1]

    match tier:
        DecisionTier.BASIC:
            return _basic_decision(point_result.point_total, opponent_number)
        DecisionTier.SMART:
            return _smart_decision(point_result, remaining_deck, opponent_number)
        DecisionTier.OPTIMAL:
            return _optimal_decision(point_result, remaining_deck, opponent_number, ai_hp, ai_max_hp)
    return AIAction.STAND

func _basic_decision(point_total: int, opponent_number: int) -> AIAction:
    var threshold: int = HIT_THRESHOLD[opponent_number - 1]
    return AIAction.HIT if point_total <= threshold else AIAction.STAND

func _smart_decision(
    point_result: PointResult,
    remaining_deck: Dictionary,
    opponent_number: int
) -> AIAction:
    var bust_prob := _calculate_bust_probability(point_result, remaining_deck)
    var tolerance: float = BUST_TOLERANCE[opponent_number - 4]
    return AIAction.HIT if bust_prob < tolerance else AIAction.STAND

func _optimal_decision(
    point_result: PointResult,
    remaining_deck: Dictionary,
    opponent_number: int,
    ai_hp: int,
    ai_max_hp: int
) -> AIAction:
    var bust_prob := _calculate_bust_probability(point_result, remaining_deck)
    var tolerance: float = BUST_TOLERANCE[opponent_number - 4]
    var desperation := 1.0 - (float(ai_hp) / float(ai_max_hp))
    var effective := minf(tolerance + desperation * DESPERATION_BONUS[opponent_number - 7], 0.90)
    return AIAction.HIT if bust_prob < effective else AIAction.STAND

func _calculate_bust_probability(
    point_result: PointResult,
    remaining_deck: Dictionary
) -> float:
    var bust_count := 0
    var total_count := 0
    for rank in remaining_deck:
        var count: int = remaining_deck[rank]
        if count == 0:
            continue
        var sim := PointCalc.simulate_hit(point_result, rank)
        if sim.is_bust:
            bust_count += count
        total_count += count
    return float(bust_count) / float(total_count) if total_count > 0 else 1.0
```

### Special Play Decisions (Hardcoded)

```gdscript
func should_buy_insurance(player_visible_card: CardInstance) -> bool:
    return player_visible_card.prototype.rank == Rank.ACE

func should_split(hand: Array[CardInstance]) -> bool:
    return hand.size() == 2 and hand[0].prototype.rank == hand[1].prototype.rank

func should_double_down(point_result: PointResult) -> bool:
    return point_result.point_total in [10, 11]
```

### Hand Type Selection

```gdscript
func select_hand_type(
    matches: Array[HandTypeOption],
    hand: Array[CardInstance]
) -> HandTypeOption:
    if matches.is_empty():
        return null

    # SPADE_BLACKJACK: always selected
    for option in matches:
        if option.type == HandType.SPADE_BLACKJACK:
            return option

    # Score-based selection
    var best_score := -1.0
    var best_option: HandTypeOption = matches[0]
    for option in matches:
        var score := _evaluate_hand_type(option, hand)
        if score > best_score or (score == best_score and _tiebreak_priority(option.type) > _tiebreak_priority(best_option.type)):
            best_score = score
            best_option = option
    return best_option

func _evaluate_hand_type(option: HandTypeOption, hand: Array[CardInstance]) -> float:
    var score := 0.0
    for i in hand.size():
        var combat_value := hand[i].prototype.effect_value
        combat_value += StampSystem.get_combat_bonus(hand[i].stamp)
        combat_value += QualitySystem.resolve_bonus(hand[i].quality, hand[i].quality_level).combat_value
        score += option.per_card_multiplier[i] * combat_value
    return score
```

### Card Sort Strategy

```gdscript
func tiebreak(cards: Array[CardInstance], opponent_number: int) -> Array[CardInstance]:
    var strategy := SORT_STRATEGY[opponent_number - 1]
    match strategy:
        SortStrategy.RANDOM:
            return cards  # Keep deal order
        SortStrategy.DEFAULT:
            return _default_tiebreak(cards)
        SortStrategy.TACTICAL:
            return _tactical_tiebreak(cards)
    return cards

func _default_tiebreak(cards: Array[CardInstance]) -> Array[CardInstance]:
    var sorted := cards.duplicate()
    sorted.sort_custom(func(a, b): return _default_compare(a, b))
    return sorted

func _default_compare(a: CardInstance, b: CardInstance) -> bool:
    if a.prototype.effect_value != b.prototype.effect_value:
        return a.prototype.effect_value > b.prototype.effect_value
    if a.prototype.rank != b.prototype.rank:
        return a.prototype.rank > b.prototype.rank
    return a.prototype.suit < b.prototype.suit

func _tactical_tiebreak(cards: Array[CardInstance], ai_hp: int, ai_max_hp: int) -> Array[CardInstance]:
    var sorted := cards.duplicate()
    sorted.sort_custom(func(a, b): return _tactical_compare(a, b, ai_hp, ai_max_hp))
    return sorted

func _tactical_compare(a: CardInstance, b: CardInstance, ai_hp: int, ai_max_hp: int) -> bool:
    var pri_a := _suit_priority(a.prototype.suit, ai_hp, ai_max_hp)
    var pri_b := _suit_priority(b.prototype.suit, ai_hp, ai_max_hp)
    if pri_a != pri_b:
        return pri_a > pri_b
    return _default_compare(a, b)

func _suit_priority(suit: Suit, ai_hp: int, ai_max_hp: int) -> int:
    var low_hp := ai_hp < ai_max_hp * 0.5
    match suit:
        Suit.SPADES: return 4      # Defense first
        Suit.HEARTS: return 3 if low_hp else 1  # Heal if low HP
        Suit.DIAMONDS: return 2    # Damage
        Suit.CLUBS: return 0       # Chips last
    return 0
```

### AI Deck Generation

```gdscript
func generate_deck(opponent_number: int) -> Array[CardInstance]:
    var deck: Array[CardInstance] = []
    var stamp_count := 0
    var hammer_count := 0
    var quality_count := 0
    var stamp_prob := AI_STAMP_PROB[opponent_number - 1]
    var quality_prob := AI_QUALITY_PROB[opponent_number - 1]

    for suit in [Suit.HEARTS, Suit.DIAMONDS, Suit.SPADES, Suit.CLUBS]:
        for rank in Range.RANKS:
            var card := CardInstance.new()
            card.prototype = _card_data.get_prototype(suit, rank)
            card.owner = Owner.AI
            card.quality_level = QualityLevel.III

            # Assign stamp
            if stamp_count < AI_MAX_STAMPS and _rng.randf() < stamp_prob:
                var stamp := _roll_stamp(hammer_count)
                if stamp != Stamp.NONE:
                    card.stamp = stamp
                    stamp_count += 1
                    if stamp == Stamp.HAMMER:
                        hammer_count += 1

            # Assign quality
            if quality_count < AI_MAX_QUALITIES and _rng.randf() < quality_prob:
                var quality := _roll_gem_quality(suit)
                if quality != Quality.NONE:
                    card.quality = quality
                    card.quality_level = _roll_quality_level(opponent_number)
                    quality_count += 1

            deck.append(card)
    return deck

const AI_STAMP_PROB: Array[float] = [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65]
const AI_QUALITY_PROB: Array[float] = [0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55]
const AI_MAX_STAMPS := 30
const AI_MAX_QUALITIES := 30
const AI_MAX_HAMMERS := 3
const STAMP_WEIGHTS: Dictionary = {
    Stamp.SWORD: 0.25, Stamp.SHIELD: 0.20, Stamp.HEART: 0.15,
    Stamp.HAMMER: 0.10, Stamp.COIN: 0.10,
    Stamp.RUNNING_SHOES: 0.10, Stamp.TURTLE: 0.10
}
const GEM_WEIGHTS: Dictionary = {
    Quality.RUBY: 0.30, Quality.SAPPHIRE: 0.25,
    Quality.OBSIDIAN: 0.25, Quality.EMERALD: 0.20
}
const QUALITY_LEVEL_TABLE: Array = [
    [1.0, 0.0], [1.0, 0.0], [1.0, 0.0],
    [0.7, 0.3], [0.5, 0.5], [0.3, 0.7],
    [0.5, 0.5], [0.3, 0.7]
]
```

## Alternatives Considered

### Alternative 1: Strategy Pattern with Polymorphic Subclasses
- **Description**: AIBasicStrategy, AISmartStrategy, AIOptimalStrategy as separate classes implementing an AIDecision interface. AIOpponent holds a reference to the current strategy.
- **Pros**: Each tier is independently testable; new tiers can be added without modifying existing ones; follows Open/Closed principle
- **Cons**: 3 classes for 3 tiers that share 80% of code (only hit/stand differs); deck generation and sort strategy are orthogonal to decision tier; more files for little benefit; Godot's GDScript class_name system creates overhead per class
- **Rejection Reason**: The 3 tiers differ only in one method (hit/stand decision). Splitting into 3 classes creates 3x the boilerplate for a 20-line difference. Lookup tables indexed by opponent_number achieve the same effect with less complexity.

### Alternative 2: Data-Driven Decision Tables
- **Description**: All AI decisions loaded from JSON/Resource config files. Hit/stand decisions use a lookup table from (point_total, opponent_number) → action.
- **Pros**: Designers can tune AI behavior without code changes; configuration hot-reloadable; supports arbitrary number of difficulty tiers
- **Cons**: SMART/OPTIMAL tiers require runtime computation (bust probability, desperation calculation) that cannot be pre-computed in a lookup table; sort strategy logic cannot be table-driven; adds serialization/deserialization overhead; harder to debug
- **Rejection Reason**: Only BASIC tier is table-compatible. SMART and OPTIMAL tiers require algorithmic decisions (enumerate remaining deck, calculate bust probability, factor in HP desperation). Data-driven only works for the trivial case — the interesting cases need code.

## Consequences

### Positive
- Single class: all AI logic in one file, easy to understand
- Tier lookup tables: difficulty scaling is data-driven, easy to tune
- Stateless between rounds: no cross-round state to manage or corrupt
- Deterministic: given same RNG seed and inputs, produces identical decisions
- Deck generation constraints enforced (HAMMER cap, quality cap, gem-suit binding)

### Negative
- Single class grows with all 3 tiers (~200 lines for decisions alone)
- Adding a 4th tier requires editing the const arrays and adding a new match branch
- TACTICAL sort needs AI HP context passed through tiebreak function

### Risks
- **Risk**: calculate_bust_probability performance (52 × simulate_hit per decision)
  **Mitigation**: Profile during prototype. Expected ~260 arithmetic operations ≈ <1ms. Well within 16.6ms budget.
- **Risk**: AI always splits may be too strong/weak for certain opponents
  **Mitigation**: Playtest data. If split win rate > 65%, add HP > 50% threshold. Open question in GDD.
- **Risk**: Deck generation RNG may produce degenerate hands (all stamps on same suit)
  **Mitigation**: Constraints (max 30 stamps, max 3 hammers) limit degeneracy. Quality-level distribution is controlled per opponent.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ai-opponent.md | 3 decision tiers across 8 opponents | TIER_TABLE + const arrays indexed by opponent_number |
| ai-opponent.md | BASIC: fixed hit threshold | _basic_decision with HIT_THRESHOLD lookup |
| ai-opponent.md | SMART: bust probability evaluation | _calculate_bust_probability enumerates remaining deck |
| ai-opponent.md | OPTIMAL: SMART + HP desperation | _optimal_desperation adjusts tolerance by HP ratio |
| ai-opponent.md | AI always buys insurance on player Ace | should_buy_insurance checks visible card rank |
| ai-opponent.md | AI always splits same-rank starting hand | should_split checks card count and rank equality |
| ai-opponent.md | AI double-down at point_total {10, 11} | should_double_down checks point_total set |
| ai-opponent.md | AI deck generation with stamp/quality constraints | generate_deck enforces max_stamps, max_hammers, max_qualities, gem-suit binding |
| ai-opponent.md | Difficulty-scaled stamp/quality probabilities | AI_STAMP_PROB and AI_QUALITY_PROB arrays increment +0.05 per level |
| ai-opponent.md | Quality level distribution scales per opponent | QUALITY_LEVEL_TABLE per-opponent probability arrays |
| ai-opponent.md | Hand type selection via score evaluation | select_hand_type uses argmax of _evaluate_hand_type |
| ai-opponent.md | 3 sort strategies (RANDOM/DEFAULT/TACTICAL) | tiebreak dispatches by SORT_STRATEGY lookup |
| card-sorting-system.md | AI tiebreak_function interface | tiebreak(cards, opponent_number) implements the interface |
| hand-type-detection.md | AI evaluates per-card multiplier × combat value | _evaluate_hand_type multiplies multiplier by stamp+quality+effect_value |

## Performance Implications
- **CPU**: make_decision ≈ <1ms (BASIC: 1 comparison; SMART/OPTIMAL: 52 × simulate_hit). Deck generation ≈ 52 × randf ≈ <0.5ms.
- **Memory**: AI holds no persistent state between rounds. Deck: 52 CardInstance ≈ 25KB, freed when opponent changes.
- **Load Time**: None — AI is initialized once per match.
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- BASIC tier always hits when point_total ≤ threshold, stands otherwise
- SMART tier calculates bust probability correctly (verified against known deck states)
- OPTIMAL tier adjusts tolerance based on HP ratio (desperation formula verified)
- AI always splits same-rank starting hands
- AI always buys insurance when player visible card is Ace
- AI double-down only at point_total 10 or 11
- Deck generation produces exactly 52 cards with unique (suit, rank) pairs
- HAMMER count never exceeds 3 in generated deck
- Total stamps and qualities never exceed 30 each
- Gem qualities respect suit binding (is_valid_assignment)
- Hand type selection produces deterministic output for given inputs
- TACTICAL sort prioritizes SPADES (defense) over other suits
