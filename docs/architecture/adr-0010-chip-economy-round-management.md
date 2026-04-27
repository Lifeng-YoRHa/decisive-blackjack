# ADR-0010: Chip Economy & Round Management Integration

## Status

Accepted

## Date

2026-04-26

## Last Verified

2026-04-26

## Decision Makers

user + technical-director

## Summary

The chip economy and round management systems have 13 partial TRs — ADR coverage exists but is incomplete. Key gaps: ChipSource/ChipPurpose enums are undefined (raw strings used instead), RoundPhase enum is informal, settlement-tie compensation lacks a ChipSource entry, and the RoundManager ↔ MatchProgression ownership boundary has conflicting claims between GDDs. This ADR defines typed enums for all chip transaction categories, formalizes the RoundPhase state machine and MatchState FSM, clarifies the RoundManager/MatchProgression boundary, and specifies all cross-system integration flows.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Feature (chip economy), Game Flow (round/match management) |
| **Knowledge Risk** | LOW — enums, signals, Node lifecycle stable since 4.0 |
| **References Consulted** | VERSION.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (ChipEconomy/RoundManager/MatchProgression as scene-tree nodes), ADR-0003 (signal contracts), ADR-0004 (settlement pipeline chip injection), ADR-0009 (SidePool chip transactions) |
| **Enables** | Typed chip transactions, phase-gated round flow, match state machine |
| **Blocks** | Stories involving chip income/spending, round phase transitions, opponent transitions |
| **Ordering Note** | Must be accepted before implementing ChipEconomy, RoundManager, or MatchProgression. Can proceed in parallel with ADR-0011 (Point Calculation). |

## Context

### Problem Statement

The architecture review identified 13 partial TRs across chip-economy (TR-chip-001..007), round-management (TR-rm-001..006), and match-progression (TR-mp-001..005) systems. While existing ADRs cover broad patterns (signal architecture, scene-tree wiring), specific gaps remain:

1. **No typed enums** for ChipSource/ChipPurpose — ADR-0004 uses `"settlement"` and ADR-0009 uses `"SIDE_POOL_BET"` as raw strings, which are typo-prone and not compile-time checked.
2. **Missing SETTLEMENT_TIE_COMP** — The round-management GDD specifies 20 chips when settlement first-player is decided by coin flip, but this source is absent from ChipSource definitions.
3. **RoundPhase enum undefined** — The 8-phase pipeline is described in prose but never formalized as an enum with validated transitions.
4. **MatchState FSM undefined** — MatchProgression's 5-state machine is in the GDD but has no ADR.
5. **RoundManager ↔ MatchProgression boundary unclear** — Both GDDs claim ownership of opponent transition (rules 8-10 in round-management). The architecture needs a clear delineation.

### Constraints

- ChipEconomy balance range [0, 999] with clamping (chip-economy GDD)
- RoundManager coordinates 8 subsystems (ADR-0001)
- MatchProgression owns opponent_number — other systems read-only (match-progression GDD)
- All chip transactions atomic: spend before mutate (chip-economy GDD)
- Settlement pipeline synchronous, single-frame (ADR-0004)
- RoundManagement GDD explicitly notes "Design in Progress" status

### Requirements

- Typed enums for all chip income sources (6) and spending purposes (3)
- Formal RoundPhase enum with validated linear transitions
- Formal MatchState FSM with validated transitions
- Clear ownership boundary between RoundManager and MatchProgression
- Settlement-tie compensation flow through ChipEconomy
- Victory bonus formula through ChipEconomy
- All existing signal contracts preserved (typed source replacing string)

## Decision

### 1. ChipSource and ChipPurpose Enums

```gdscript
# Defined within ChipEconomy class
class_name ChipEconomy extends Node

enum ChipSource {
    RESOLUTION,           # Per-card chip_output during settlement
    SETTLEMENT_TIE_COMP,  # 20 chips when settlement first-player decided by coin flip
    SIDE_POOL_RETURN,     # Side pool payout (SP7 or CW)
    SHOP_SELL,            # Selling items/cards to shop
    VICTORY_BONUS,        # Defeating an opponent: 50 + 25*(n-1)
    INSURANCE_REFUND,     # Insurance side-effect refund (30 chips)
}

enum ChipPurpose {
    SHOP_PURCHASE,        # Buying items/cards/upgrades
    SIDE_POOL_BET,        # Side pool bet (10/20/50)
    INSURANCE,            # Insurance purchase (30)
}
```

### 2. Updated ChipEconomy API

```gdscript
signal chips_changed(new_balance: int, delta: int, source: int)
# source is ChipSource for income, ChipPurpose for spending — distinguished by delta sign

const INITIAL_BALANCE: int = 100
const CHIP_CAP: int = 999

var _balance: int = 0
var _transaction_log: Array[TransactionRecord] = []

func initialize() -> void:
    _balance = INITIAL_BALANCE
    _transaction_log.clear()

func add_chips(amount: int, source: ChipSource) -> int:
    assert(amount > 0, "add_chips: amount must be positive")
    var old := _balance
    _balance = mini(_balance + amount, CHIP_CAP)
    var actual := _balance - old
    if actual > 0:
        _transaction_log.append(TransactionRecord.new(actual, source, true))
        chips_changed.emit(_balance, actual, source)
    return actual

func spend_chips(amount: int, purpose: ChipPurpose) -> bool:
    assert(amount > 0, "spend_chips: amount must be positive")
    if amount > _balance:
        return false
    _balance -= amount
    _transaction_log.append(TransactionRecord.new(-amount, purpose, false))
    chips_changed.emit(_balance, -amount, purpose)
    return true

func can_afford(amount: int) -> bool:
    return amount > 0 and amount <= _balance

func get_balance() -> int:
    return _balance

func get_transaction_log() -> Array[TransactionRecord]:
    return _transaction_log

func reset_for_new_game() -> void:
    _balance = INITIAL_BALANCE
    _transaction_log.clear()
```

TransactionRecord:

```gdscript
class_name TransactionRecord extends RefCounted
var amount: int       # positive for income, negative for spending
var category: int     # ChipSource or ChipPurpose enum value
var is_income: bool

func _init(amt: int, cat: int, income: bool) -> void:
    amount = amt
    category = cat
    is_income = income
```

### 3. RoundPhase Enum and Transitions

```gdscript
# Defined within RoundManager class
class_name RoundManager extends Node

enum RoundPhase {
    DEAL,
    SIDE_POOL,
    INSURANCE,
    SPLIT_CHECK,
    HIT_STAND,
    SORT,
    RESOLUTION,
    DEATH_CHECK,
}

# Strictly linear — no branching, no skipping
const PHASE_ORDER: Array[RoundPhase] = [
    RoundPhase.DEAL,
    RoundPhase.SIDE_POOL,
    RoundPhase.INSURANCE,
    RoundPhase.SPLIT_CHECK,
    RoundPhase.HIT_STAND,
    RoundPhase.SORT,
    RoundPhase.RESOLUTION,
    RoundPhase.DEATH_CHECK,
]

var _phase: RoundPhase = RoundPhase.DEAL
var _round_counter: int = 0
var _first_player: bool = false

func current_phase() -> RoundPhase:
    return _phase

func advance_phase() -> void:
    var idx := PHASE_ORDER.find(_phase)
    assert(idx >= 0 and idx < PHASE_ORDER.size() - 1, "Cannot advance past DEATH_CHECK")
    var old := _phase
    _phase = PHASE_ORDER[idx + 1]
    phase_changed.emit(_phase, old)
```

### 4. MatchState FSM

```gdscript
# Defined within MatchProgression class
class_name MatchProgression extends Node

enum MatchState {
    NEW_GAME,
    OPPONENT_ACTIVE,
    SHOP,
    VICTORY,
    GAME_OVER,
}

const VALID_TRANSITIONS: Dictionary = {
    MatchState.NEW_GAME: [MatchState.OPPONENT_ACTIVE],
    MatchState.OPPONENT_ACTIVE: [MatchState.SHOP, MatchState.VICTORY, MatchState.GAME_OVER],
    MatchState.SHOP: [MatchState.OPPONENT_ACTIVE],
    MatchState.VICTORY: [],      # Terminal
    MatchState.GAME_OVER: [],    # Terminal
}

signal match_state_changed(new_state: MatchState, old_state: MatchState)

var _state: MatchState = MatchState.NEW_GAME
var _opponent_number: int = 1
var _total_opponents: int = 8

func get_opponent_number() -> int:
    return _opponent_number

func get_match_state() -> MatchState:
    return _state

func transition_to(new_state: MatchState) -> void:
    assert(new_state in VALID_TRANSITIONS[_state],
        "Invalid transition: %s -> %s" % [MatchState.keys()[_state], MatchState.keys()[new_state]])
    var old := _state
    _state = new_state
    match_state_changed.emit(new_state, old)
```

### 5. Ownership Boundary: RoundManager vs MatchProgression

```
MatchProgression OWNS:
  - match_state (MatchState FSM)
  - opponent_number [1..total_opponents]
  - total_opponents (tuning knob, clamped [3..8])

RoundManager OWNS:
  - current_phase (RoundPhase)
  - round_counter
  - first_player (dealing order, alternates each round)
  - player_deck, ai_deck

PROTOCOL:
  1. RoundManager runs rounds, emits round_result(result, opponent, round, player_hp, ai_hp)
  2. MatchProgression._on_round_result() decides: continue, shop, victory, or game_over
  3. MatchProgression calls RoundManager.start_round() to begin next round
  4. MatchProgression calls ShopSystem.enter_shop() between opponents
  5. opponent_number increments AFTER shop closes, BEFORE new round starts
  6. RoundManager NEVER directly modifies opponent_number
  7. RoundManager reads opponent_number via MatchProgression.get_opponent_number()

This resolves the rules 8-10 ownership conflict from the round-management GDD.
Opponent transition, game-over conditions, and game initialization belong to MatchProgression.
```

### 6. Settlement-Tie Compensation Flow

When settlement first-player is determined by coin flip (equal point totals AND equal highest-card bj_value):

```gdscript
# In RoundManager, during transition to RESOLUTION phase
func _determine_settlement_first(player_points: int, ai_points: int,
                                  player_high_card: int, ai_high_card: int) -> bool:
    if player_points != ai_points:
        return player_points > ai_points
    if player_high_card != ai_high_card:
        return player_high_card > ai_high_card
    # Tie: coin flip
    var player_first := _rng.randi() % 2 == 0
    if not player_first:
        _chips.add_chips(settlement_tie_compensation, ChipSource.SETTLEMENT_TIE_COMP)
    return player_first
```

Tuning knob: `settlement_tie_compensation: int = 20`

### 7. Victory Bonus Flow

When MatchProgression detects PLAYER_WIN:

```gdscript
# In MatchProgression._on_round_result()
func _apply_victory_bonus(opponent_number: int) -> void:
    var bonus := victory_base + victory_scale * (opponent_number - 1)
    _chips.add_chips(bonus, ChipSource.VICTORY_BONUS)
```

Tuning knobs: `victory_base: int = 50`, `victory_scale: int = 25`

### Implementation Guidelines

1. **Enum values are source of truth** — no raw strings for chip sources or purposes. ADR-0004 and ADR-0009 code examples should be refined to use typed enums at implementation time.
2. **Phase transitions are linear** — no skipping phases. If a phase is optional (e.g., no side pool bet), the phase still fires but the system is a no-op. UI relies on consistent phase cadence.
3. **MatchState transitions are validated** — the assert in `transition_to()` catches invalid state changes during development.
4. **Settlement-tie compensation** uses the same `add_chips()` API — no special paths. AI has no chip economy, so only player receives compensation.
5. **First-player alternation** toggles `_first_player` each round. Initial value determined by coin flip in round 1. Re-flipped when transitioning to a new opponent (per match-progression GDD).

## Alternatives Considered

### Alternative 1: Raw strings for ChipSource/ChipPurpose (status quo)

- **Description**: Keep using string literals like `"settlement"`, `"SIDE_POOL_BET"`.
- **Pros**: Simpler API, no enum maintenance
- **Cons**: Typo-prone, no compile-time checking, harder to discover available sources, string comparisons at runtime
- **Rejection Reason**: Typed enum prevents misspelling bugs and integrates with Godot's match exhaustiveness checking.

### Alternative 2: Separate ADRs for ChipEconomy and RoundManagement

- **Description**: Split into one ADR for chip enums/API and one for phase/FSM management.
- **Pros**: Smaller, more focused ADRs
- **Cons**: Settlement-tie compensation and victory bonus flow through ChipEconomy during RoundManager phases. Splitting would duplicate integration flows.
- **Rejection Reason**: Integration flows are the primary value. Separate ADRs would miss the cross-system coordination.

### Alternative 3: Phase skipping for optional phases

- **Description**: Allow RoundManager to skip SIDE_POOL if no bets placed, skip INSURANCE if conditions not met.
- **Pros**: Fewer phase transitions, slightly faster
- **Cons**: UI relies on phase_changed signals for state transitions. Skipping causes UI desync. Testing harder with non-linear sequences.
- **Rejection Reason**: Linear phase flow with no-op phases is simpler for UI, testing, and debugging. Performance cost is negligible.

## Consequences

### Positive

- Typed enums prevent typo bugs in chip transaction categories
- Formal FSM for MatchProgression catches invalid state transitions during development
- Clear ownership boundary resolves GDD conflict (rules 8-10)
- All chip flows documented in one place: 6 income sources, 3 spending purposes
- Settlement-tie compensation explicitly defined (was missing from ChipSource list)
- Phase linearity simplifies UI state management

### Negative

- `chips_changed` signal signature changes (source: String → typed enum) — refines ADR-0003 contract
- ADR-0004 and ADR-0009 code examples use raw strings — need refinement at implementation time
- RoundManagement GDD rules 8-10 are architecturally "extracted" to MatchProgression — GDD should note this

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Enum values proliferate as new chip sources added | Low | Low | Enums are append-only; new values don't break existing code |
| Linear phase flow wastes cycles on no-op phases | Low | None | Signal emission cost negligible; UI benefits from consistent cadence |
| MatchProgression FSM too rigid for future game modes | Medium | Medium | VALID_TRANSITIONS is a const dictionary — extendable by appending targets |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | 0ms | <0.01ms (enum comparisons) | 16.6ms |
| Memory | 0 bytes | ~1KB (TransactionRecord array, enums) | 256MB |
| Load Time | 0ms | 0ms | N/A |
| Network | N/A | N/A | N/A |

## Migration Plan

First implementation — no migration needed. Implementation-time refinements to existing ADR code examples:

- **ADR-0003**: `chips_changed` signal source parameter: `String` → typed enum
- **ADR-0004**: `"settlement"` → `ChipSource.RESOLUTION`
- **ADR-0009**: `"SIDE_POOL_BET"` → `ChipPurpose.SIDE_POOL_BET`, `"SIDE_POOL_RETURN"` → `ChipSource.SIDE_POOL_RETURN`

These are code-level refinements, not architectural changes.

## Validation Criteria

- [ ] ChipSource enum contains all 6 income sources
- [ ] ChipPurpose enum contains all 3 spending categories from chip-economy GDD
- [ ] ChipEconomy.add_chips() clamps to CHIP_CAP (999) and returns actual added amount
- [ ] ChipEconomy.spend_chips() returns false when balance insufficient
- [ ] ChipEconomy.can_afford() rejects zero and negative amounts
- [ ] RoundPhase enum matches the 8-phase pipeline from round-management GDD
- [ ] RoundPhase transitions are strictly linear (PHASE_ORDER array)
- [ ] MatchState FSM has exactly 5 states with validated transitions
- [ ] MatchState.VICTORY and GAME_OVER are terminal (no outgoing transitions)
- [ ] RoundManager never directly modifies opponent_number
- [ ] MatchProgression is sole authority on opponent_number
- [ ] Settlement-tie compensation (20 chips) uses ChipSource.SETTLEMENT_TIE_COMP
- [ ] Victory bonus formula: 50 + 25*(opponent_number - 1)
- [ ] TransactionRecord stores amount, category, and is_income
- [ ] reset_for_new_game() restores INITIAL_BALANCE and clears log

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| chip-economy.md | Balance range [0, 999] with cap enforcement | INITIAL_BALANCE=100, CHIP_CAP=999, mini() clamp in add_chips() |
| chip-economy.md | Typed API: add_chips, spend_chips, can_afford, get_balance | Full API with typed enum parameters |
| chip-economy.md | Transaction log recording | TransactionRecord appended on every add/spend |
| chip-economy.md | 5 income sources + settlement-tie comp | ChipSource enum with 6 values |
| chip-economy.md | 3 spending categories | ChipPurpose enum with 3 values |
| chip-economy.md | Victory bonus formula: 50 + 25*n | MatchProgression._apply_victory_bonus() |
| chip-economy.md | Atomic spend-before-mutate | spend_chips() returns bool before downstream action |
| chip-economy.md | Sell price: buy_price * 0.50, rounded down | SHOP_SELL source; formula in shop system ADR-0007 |
| chip-economy.md | Insurance refund: 30 chips | INSURANCE_REFUND source |
| round-management.md | 8-phase pipeline | RoundPhase enum + PHASE_ORDER array |
| round-management.md | First-player alternation per round | _first_player bool toggled each round |
| round-management.md | Settlement first-player by points/high-card/coin-flip | _determine_settlement_first() with tie compensation |
| round-management.md | Split sub-pipeline (hand A full, then hand B) | RoundManager calls run_pipeline() twice (ADR-0004 skip_defense_reset) |
| round-management.md | Phase transition signals | phase_changed signal from RoundManager |
| round-management.md | Settlement-tie compensation: 20 chips | ChipSource.SETTLEMENT_TIE_COMP, tuning knob 20 |
| match-progression.md | 5-state FSM | MatchState enum + VALID_TRANSITIONS dictionary |
| match-progression.md | opponent_number ownership | MatchProgression sole owner; RoundManager reads via get_opponent_number() |
| match-progression.md | Shop gating between opponents | OPPONENT_ACTIVE → SHOP → OPPONENT_ACTIVE transition |
| match-progression.md | Initialization: coordinate 8 systems | MatchProgression.transition_to(NEW_GAME) → init sequence |
| match-progression.md | Terminal states: VICTORY, GAME_OVER | Empty VALID_TRANSITIONS arrays = terminal |
| match-progression.md | Victory bonus injection before shop | _apply_victory_bonus() called before shop entry |

## Related

- ADR-0001: Scene/Node Architecture — ChipEconomy, RoundManager, MatchProgression as scene-tree nodes
- ADR-0003: Signal Architecture — chips_changed, phase_changed, round_result signals (refined: String→enum)
- ADR-0004: Resolution Pipeline — chip injection in Phase 5 uses ChipSource.RESOLUTION
- ADR-0007: Shop Weighted Random — SHOP_PURCHASE purpose, SHOP_SELL source
- ADR-0009: Side Pool System — SIDE_POOL_BET purpose, SIDE_POOL_RETURN source
