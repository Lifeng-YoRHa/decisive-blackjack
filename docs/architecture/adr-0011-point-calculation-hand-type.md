# ADR-0011: Point Calculation & Hand Type Detection

## Status

Accepted

## Date

2026-04-26

## Last Verified

2026-04-26

## Decision Makers

user + technical-director

## Summary

Point calculation and hand type detection are the two Core-layer pure-function systems that feed into the resolution pipeline. Both have GDDs with complete formulas and edge cases, but no ADR specifying implementation: data structure types (RefCounted vs Dictionary), code organization (static class vs Node), enum definitions, tuning knob delivery, and integration contracts with PipelineInput. This ADR defines both as static utility classes with RefCounted output structs, typed enums, const tuning knobs, and zero scene-tree dependency.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (pure computation, no side effects) |
| **Knowledge Risk** | LOW — static functions, RefCounted, typed arrays, enums stable since 4.0 |
| **References Consulted** | VERSION.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (CardPrototype.bj_values, CardInstance.prototype indirection), ADR-0004 (PipelineInput expects PointResult + HandTypeResult) |
| **Enables** | Resolution pipeline pre-computation, AI decision support (simulate_hit), AI deck scoring |
| **Blocks** | Stories involving point calculation, hand type detection, settlement pipeline execution, AI strategy |
| **Ordering Note** | Must be accepted before implementing resolution pipeline or AI opponent. Can proceed in parallel with ADR-0010. |

## Context

### Problem Statement

The architecture review identified 8 partial TRs across point-calculation (TR-pce-001..004) and hand-type-detection (TR-htd-001..004). ADR-0004 defines PipelineInput with `PointResult` and `HandTypeResult` fields, but never specifies:
- What type these structs are (RefCounted, Dictionary, inner class)
- Where the code lives (Node, static class, autoload)
- How HandType enum and Scope convention are defined
- How tuning knobs are delivered to the detection system
- How RoundManager calls these to populate PipelineInput

### Constraints

- Both systems are stateless pure functions (GDD: "zero side effects")
- Point calculation reads ONLY `card.prototype.bj_values` (AC-17 boundary)
- Hand type detection reads `card.prototype.suit` and `card.prototype.rank`
- Output structures must match ADR-0004 PipelineInput fields exactly
- `simulate_hit` must be O(1) — incremental, no full re-traversal
- Hand type detection must be O(n) linear in hand size
- BUST_THRESHOLD = 21 is a constant, not a tuning knob
- All point values are int; multipliers are float

### Requirements

- RefCounted output structs matching PipelineInput contract
- Static utility classes with no scene-tree dependency
- 7-value HandType enum with PAIR..SPADE_BLACKJACK
- Tuning knob delivery for hand type multipliers
- Integration contract: RoundManager calls these to populate PipelineInput
- SPADE_BLACKJACK absorption of BLACKJACK_TYPE
- Split suppression via suppress_blackjack flag
- Bust short-circuit in hand type detection

## Decision

### 1. PointResult Data Structure

```gdscript
class_name PointResult extends RefCounted

var point_total: int = 0
var is_bust: bool = false
var ace_count: int = 0
var soft_ace_count: int = 0
var card_count: int = 0
```

Five fields, matching ADR-0004 PipelineInput.player_result / ai_result.

### 2. PointCalc Static Class

```gdscript
class_name PointCalc

const BUST_THRESHOLD: int = 21

static func calculate_hand(cards: Array[CardInstance]) -> PointResult:
	var result := PointResult.new()
	result.card_count = cards.size()
	if cards.is_empty():
		return result
	var non_ace_sum := 0
	var ace_count := 0
	for card in cards:
		var vals: Array[int] = card.prototype.bj_values
		if vals.size() == 2:  # Ace: [1, 11]
			ace_count += 1
		else:
			non_ace_sum += vals[0]
	var soft_ace := ace_count
	var total := non_ace_sum + ace_count * 11
	while total > BUST_THRESHOLD and soft_ace > 0:
		total -= 10
		soft_ace -= 1
	result.point_total = total
	result.is_bust = total > BUST_THRESHOLD
	result.ace_count = ace_count
	result.soft_ace_count = soft_ace
	return result

static func simulate_hit(current: PointResult, new_card: CardInstance) -> PointResult:
	var result := PointResult.new()
	var vals: Array[int] = new_card.prototype.bj_values
	var is_ace := vals.size() == 2
	var new_total := current.point_total
	var new_soft := current.soft_ace_count
	if is_ace:
		new_total += 11
		new_soft += 1
	else:
		new_total += vals[0]
	while new_total > BUST_THRESHOLD and new_soft > 0:
		new_total -= 10
		new_soft -= 1
	result.point_total = new_total
	result.is_bust = new_total > BUST_THRESHOLD
	result.ace_count = current.ace_count + (1 if is_ace else 0)
	result.soft_ace_count = new_soft
	result.card_count = current.card_count + 1
	return result
```

### 3. HandType Enum and Scope Convention

```gdscript
enum HandType {
	PAIR,
	FLUSH,
	THREE_KIND,
	TRIPLE_SEVEN,
	TWENTY_ONE,
	BLACKJACK_TYPE,
	SPADE_BLACKJACK,
}
```

Scope is determined by a const lookup:

```gdscript
const SCOPED_TYPES: Array[HandType] = [HandType.PAIR, HandType.THREE_KIND]
# All others are ALL scope
```

### 4. HandTypeOption and HandTypeResult Data Structures

```gdscript
class_name HandTypeOption extends RefCounted

var type: HandType = HandType.PAIR
var display_name: String = ""
var display_multiplier: int = 1
var is_instant_win: bool = false
var per_card_multiplier: Array[float] = []
```

```gdscript
class_name HandTypeResult extends RefCounted

var matches: Array[HandTypeOption] = []
var default_multiplier: float = 1.0
var has_instant_win: bool = false
```

Three fields, matching ADR-0004 PipelineInput.player_hand_type / ai_hand_type.

### 5. HandTypeDetection Static Class

```gdscript
class_name HandTypeDetection

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
	var rank_counts: Dictionary = {}  # Rank -> int
	var rank_cards: Dictionary = {}   # Rank -> Array[int] (indices)
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
			result.matches.append(_make_scoped(HandType.PAIR, multipliers[HandType.PAIR], rank_cards[r], cards.size()))
		elif count == 3:
			result.matches.append(_make_scoped(HandType.THREE_KIND, multipliers[HandType.THREE_KIND], rank_cards[r], cards.size()))

	# Step 4: FLUSH
	if suits.size() == 1:
		var flush_mult: float = float(cards.size())
		result.matches.append(_make_all(HandType.FLUSH, int(flush_mult), cards.size()))

	# Step 5: TRIPLE_SEVEN
	if rank_counts.get(Rank.SEVEN, 0) == 3:
		result.matches.append(_make_all(HandType.TRIPLE_SEVEN, multipliers[HandType.TRIPLE_SEVEN], cards.size()))

	# Step 6: TWENTY_ONE
	if point_result.point_total == 21:
		result.matches.append(_make_all(HandType.TWENTY_ONE, multipliers[HandType.TWENTY_ONE], cards.size()))

	# Steps 7-8: BLACKJACK_TYPE and SPADE_BLACKJACK (suppressed during split)
	if not suppress_blackjack and point_result.point_total == 21 and cards.size() == 2:
		var c0_rank: int = cards[0].prototype.rank
		var c1_rank: int = cards[1].prototype.rank
		var c0_suit: int = cards[0].prototype.suit
		var c1_suit: int = cards[1].prototype.suit
		var has_ace: bool = (c0_rank == Rank.ACE or c1_rank == Rank.ACE)
		var has_jack: bool = (c0_rank == Rank.JACK or c1_rank == Rank.JACK)
		if has_ace and has_jack:
			# Check SPADE_BLACKJACK: A of Spades + J of Spades
			var is_spade_blackjack := false
			if c0_suit == Suit.SPADES and c1_suit == Suit.SPADES:
				if (c0_rank == Rank.ACE and c1_rank == Rank.JACK) or \
				   (c0_rank == Rank.JACK and c1_rank == Rank.ACE):
					is_spade_blackjack = true
			if is_spade_blackjack:
				result.matches.append(_make_instant_win(cards.size()))
				result.has_instant_win = true
			else:
				result.matches.append(_make_all(HandType.BLACKJACK_TYPE, multipliers[HandType.BLACKJACK_TYPE], cards.size()))

	return result

static func _make_scoped(type: HandType, base_mult: int, affected: Array, hand_size: int) -> HandTypeOption:
	var opt := HandTypeOption.new()
	opt.type = type
	opt.display_name = HandType.keys()[type]
	opt.display_multiplier = base_mult
	var mults: Array[float] = []
	for i in hand_size:
		mults.append(base_mult if i in affected else 1.0)
	opt.per_card_multiplier = mults
	return opt

static func _make_all(type: HandType, base_mult: int, hand_size: int) -> HandTypeOption:
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
```

### 6. Tuning Knob Delivery

Multipliers passed as a `Dictionary` parameter with `DEFAULT_MULTIPLIERS` as default. This allows:
- Tests to pass custom multipliers for isolated testing
- Future config resource to override without changing code
- Constraint enforcement in a validation function:

```gdscript
static func validate_multipliers(mults: Dictionary) -> bool:
	var pair: int = mults.get(HandType.PAIR, 2)
	var three: int = mults.get(HandType.THREE_KIND, 5)
	var triple: int = mults.get(HandType.TRIPLE_SEVEN, 7)
	var twenty_one: int = mults.get(HandType.TWENTY_ONE, 2)
	var bj: int = mults.get(HandType.BLACKJACK_TYPE, 4)
	return pair <= three and three <= triple and twenty_one < bj and bj < triple
```

### 7. Integration with RoundManager and PipelineInput

```gdscript
# In RoundManager, during RESOLUTION phase preparation
func _prepare_pipeline_input() -> PipelineInput:
	var input := PipelineInput.new()
	input.player_result = PointCalc.calculate_hand(_player_hand)
	input.ai_result = PointCalc.calculate_hand(_ai_hand)
	var suppress := _is_split_round  # suppress_blackjack during split
	input.player_hand_type = HandTypeDetection.detect(_player_hand, input.player_result, suppress)
	input.ai_hand_type = HandTypeDetection.detect(_ai_hand, input.ai_result, false)
	# Player selects hand type -> populate player_multipliers from selected option
	# AI selects hand type -> populate ai_multipliers from AI strategy
	return input
```

### Implementation Guidelines

1. **Static functions, no Node** — Both classes are pure utility. No scene-tree, no signals, no lifecycle. Unit tests call directly without scene setup.
2. **RefCounted for all output structs** — Follows ADR-0002 pattern. Lightweight, typed, no .tres overhead.
3. **BUST_THRESHOLD is constant** — Not a tuning knob. Future variant modes use config override, not in-game tuning.
4. **SPADE_BLACKJACK absorbs BLACKJACK_TYPE** — When both match, only SPADE_BLACKJACK is emitted. TWENTY_ONE from Step 6 still fires independently.
5. **Insurance negation is external** — Detection always emits SPADE_BLACKJACK. The calling system (RoundManager via SpecialPlays) removes it if opponent has insurance.
6. **HAMMER-invalidated cards remain** — Hand type detection does not filter. Invalidated cards participate in detection but skip execution in the resolution pipeline.
7. **Ace detection via bj_values.size == 2** — The only reliable way to identify Aces: non-Ace cards have `bj_values = [value]`, Aces have `bj_values = [1, 11]`.
8. **Max hand size 11** — Per-card_multiplier arrays can be up to 11 elements. Practical cap is 7 cards.

## Alternatives Considered

### Alternative 1: Node-based singletons for PointCalc and HandTypeDetection

- **Description**: Both as `extends Node` singletons in the scene tree, with instance methods.
- **Pros**: Consistent with other systems (ChipEconomy, RoundManager are Nodes)
- **Cons**: Stateful nodes for stateless computation violates the architecture principle "pure functions for computation". Unnecessary scene-tree overhead. Harder to unit test (need scene setup).
- **Rejection Reason**: GDD explicitly states both are stateless pure functions. Static classes are the correct pattern for stateless computation in GDScript.

### Alternative 2: Dictionary return types instead of RefCounted

- **Description**: Return untyped dictionaries from calculate_hand and detect.
- **Pros**: No class definitions needed, simpler code
- **Cons**: No type safety, no autocomplete, no field validation, PipelineInput expects typed objects
- **Rejection Reason**: ADR-0004 PipelineInput uses typed fields (`player_result: PointResult`, `player_hand_type: HandTypeResult`). Dictionaries would require conversion at the pipeline boundary.

### Alternative 3: Combined PointCalc + HandTypeDetection class

- **Description**: Single class handling both point calculation and hand type detection.
- **Pros**: Fewer files, single import
- **Cons**: Violates single responsibility — point calculation has zero tuning knobs while hand type detection has 7. Different input/output types. AI only needs point calculation for simulate_hit, not the full detection machinery.
- **Rejection Reason**: Separate concerns, different dependencies (point calc reads bj_values only; hand type reads suit+rank), different testing profiles.

## Consequences

### Positive

- Pure static functions — no scene-tree dependency, trivially testable
- RefCounted structs — typed, lightweight, match PipelineInput contract
- Tuning knobs as Dictionary parameter — testable with custom values, future-proof for config resources
- BUST_THRESHOLD as constant — prevents accidental tuning of core game rule
- Separate classes — point calculation reusable by AI without pulling in hand type detection

### Negative

- Two more class_name definitions in the global namespace (PointCalc, HandTypeDetection)
- HandTypeDetection.detect() has 4 parameters — slightly verbose but clear
- FLUSH multiplier dynamic by hand size means per_card_multiplier array varies — UI must handle variable multiplier display

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| FLUSH at 7+ cards exceeds TRIPLE_SEVEN (x7) | Low | Low | Intentional per GDD — flush+multi-card is rarer |
| Ace detection relies on bj_values.size == 2 | Low | Low | Stable convention from ADR-0002 CardPrototype |
| Multiplier constraint violated by tuning | Medium | Medium | validate_multipliers() guard function |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (point calc) | 0ms | <0.01ms (O(n), n=max 11) | 16.6ms |
| CPU (hand type) | 0ms | <0.01ms (O(n), n=max 11) | 16.6ms |
| Memory | 0 bytes | ~200 bytes per PointResult + HandTypeResult | 256MB |
| Load Time | 0ms | 0ms (no scene tree) | N/A |

## Migration Plan

First implementation — no migration needed.

## Validation Criteria

- [ ] PointResult has exactly 5 fields: point_total, is_bust, ace_count, soft_ace_count, card_count
- [ ] calculate_hand([]) returns PointResult{0, false, 0, 0, 0}
- [ ] calculate_hand([K]) returns {10, false, 0, 0, 1}
- [ ] calculate_hand([A]) returns {11, false, 1, 1, 1}
- [ ] calculate_hand([A,A,A,A]) returns {14, false, 4, 1, 4} (greedy: 11+1+1+1)
- [ ] calculate_hand([K,5,6]) returns {21, false, 0, 0, 3}
- [ ] calculate_hand([K,5,7]) returns {22, true, 0, 0, 3}
- [ ] simulate_hit is O(1) — uses current PointResult + 1 new card only
- [ ] PointCalc reads ONLY card.prototype.bj_values, no other fields
- [ ] HandType enum has exactly 7 values
- [ ] detect() on busted hand returns empty HandTypeResult (bust short-circuit)
- [ ] detect() finds PAIR when a rank appears exactly 2 times
- [ ] detect() finds FLUSH when all cards same suit, multiplier = hand_size
- [ ] detect() finds THREE_KIND when a rank appears exactly 3 times
- [ ] detect() finds TRIPLE_SEVEN when rank==7 appears exactly 3 times
- [ ] detect() finds TWENTY_ONE when point_total == 21
- [ ] detect() finds BLACKJACK_TYPE when 21 + 2 cards + one A + one J
- [ ] detect() excludes Q/K/10 from BLACKJACK_TYPE
- [ ] detect() finds SPADE_BLACKJACK when A-spades + J-spades
- [ ] SPADE_BLACKJACK absorbs BLACKJACK_TYPE (only SPADE emitted)
- [ ] TWENTY_ONE still emitted alongside SPADE_BLACKJACK
- [ ] suppress_blackjack=true skips Steps 7-8 (split suppression)
- [ ] Different ranks produce independent PAIRs
- [ ] 3-of-a-kind reports THREE_KIND only, not PAIR
- [ ] per_card_multiplier: SCOPED types apply mult to affected indices only, 1.0 to rest
- [ ] per_card_multiplier: ALL types apply mult to all indices
- [ ] validate_multipliers() enforces PAIR <= THREE_KIND <= TRIPLE_SEVEN
- [ ] HandTypeResult.default_multiplier = 1.0 when no matches

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| point-calculation-engine.md | Stateless pure function calculate_hand(cards) | PointCalc static class, returns RefCounted PointResult |
| point-calculation-engine.md | PointResult: point_total, is_bust, ace_count, soft_ace_count, card_count | 5-field RefCounted struct |
| point-calculation-engine.md | A resolution: greedy algorithm, ACE_HIGH=11, downgrade by 10 | While-loop in calculate_hand(), BUST_THRESHOLD=21 |
| point-calculation-engine.md | simulate_hit O(1) incremental for AI | Static function using current PointResult + 1 card |
| point-calculation-engine.md | BUST_THRESHOLD=21 constant, is_bust = total > 21 | BUST_THRESHOLD const, boolean in PointResult |
| point-calculation-engine.md | Empty array returns zeroed PointResult | Early return in calculate_hand() |
| point-calculation-engine.md | Reads ONLY bj_values (AC-17 boundary) | Only accesses card.prototype.bj_values |
| hand-type-detection.md | 7 hand types with detection rules | HandType enum + 9-step detection algorithm |
| hand-type-detection.md | per_card_multiplier: SCOPED vs ALL | _make_scoped() and _make_all() helpers |
| hand-type-detection.md | FLUSH multiplier = hand_size | float(cards.size()) in Step 4 |
| hand-type-detection.md | SPADE_BLACKJACK absorbs BLACKJACK_TYPE | is_spade_blackjack branch skips BLACKJACK_TYPE emission |
| hand-type-detection.md | Split suppression: suppress_blackjack flag | Parameter in detect(), skips Steps 7-8 |
| hand-type-detection.md | Bust short-circuit: empty result | Early return on is_bust |
| hand-type-detection.md | 7 tuning knobs with constraint hierarchy | DEFAULT_MULTIPLIERS + validate_multipliers() |
| hand-type-detection.md | AI hand type score formula | per_card_multiplier array enables AI scoring |
| hand-type-detection.md | Detection after point calc, before settlement | RoundManager calls PointCalc then HandTypeDetection before pipeline |
| resolution-engine.md | PipelineInput pre-computed results | PointResult and HandTypeResult match PipelineInput fields |

## Related

- ADR-0002: Card Data Model — CardPrototype.bj_values, CardInstance.prototype
- ADR-0004: Resolution Pipeline — PipelineInput consumes PointResult + HandTypeResult
- ADR-0006: AI Strategy Pattern — AI uses simulate_hit for decision support, hand type score for deck scoring
- ADR-0010: Chip Economy & Round Management — RoundManager orchestrates point calc → hand type → pipeline sequence
