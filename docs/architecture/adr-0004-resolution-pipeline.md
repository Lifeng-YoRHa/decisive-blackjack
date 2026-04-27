# ADR-0004: Resolution Pipeline Design

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (game logic pipeline) |
| **Knowledge Risk** | LOW — GDScript control flow, Array operations stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (composition root — ResolutionEngine receives injected refs), ADR-0002 (CardInstance data model — pipeline reads card fields), ADR-0003 (signal architecture — settlement_step_completed event queue pattern) |
| **Enables** | ADR-0008 (UI node hierarchy — UI plays back settlement events), all combat/resolution stories |
| **Blocks** | All stories involving settlement, combat resolution, chip flow, gem destroy |
| **Ordering Note** | Must be Accepted before ADR-0008 (UI Node Hierarchy) and any resolution-related stories |

## Context

### Problem Statement
The settlement pipeline is the most complex single-system in the game. It processes 2 hands of up to 11 cards each through 7 phases across 3 layers, consuming inputs from 7 upstream systems and producing side effects to 4 downstream systems. How is it structured as code?

### Constraints
- 7 phases: 0a (instant win), 0b (bust), 0c (HAMMER scan), 1-6 (per-card), 7a-7b (post-processing)
- Phases 1-4 must be pure arithmetic (no side effects) for testability
- Phase 5 is the only phase with side effects (CombatState + ChipEconomy API calls)
- Phase 6 is the only phase that mutates CardInstance (gem destroy)
- Pipeline must be deterministic (seeded RNG for gem destroy)
- Pipeline must be synchronous (runs to completion in one frame)
- Must support split hands (sequential sub-pipelines, shared HP, defense carryover)
- Track separation: suit effects and stamp effects dispatch independently despite being added in the same formula

### Requirements
- Must process all edge cases (bust, instant win, HAMMER, doubledown, insurance, split)
- Must emit SettlementEvent queue for UI animation (ADR-0003)
- Must be unit-testable without scene tree or other systems (pure computation phases)
- Must handle asymmetric hands (one side has more cards than the other)
- Must use seeded RNG for gem destroy (deterministic replay)

## Decision

### Architecture: Single class with private phase helpers

ResolutionEngine is a Node with a single public `run_pipeline()` entry point. Each phase is a private method. The pipeline has no mutable state between runs — all state is local to `run_pipeline()`.

```gdscript
class_name PipelineInput extends RefCounted
## Bundles all pipeline inputs into a single typed object.
## Eliminates the 14-parameter signature and provides named access.

var sorted_player: Array[CardInstance]
var sorted_ai: Array[CardInstance]
var player_result: PointResult
var ai_result: PointResult
var player_multipliers: Array[float]
var ai_multipliers: Array[float]
var player_hand_type: HandTypeResult
var ai_hand_type: HandTypeResult
var settlement_first: Owner
var insurance_player: bool
var insurance_ai: bool
var doubledown_player: bool
var doubledown_ai: bool
var skip_defense_reset: bool
```

```gdscript
class_name ResolutionEngine extends Node

signal settlement_step_completed(events: Array[SettlementEvent])
signal settlement_completed(result: RoundResult)

var _combat: CombatState
var _chips: ChipEconomy
var _event_queue: Array[SettlementEvent] = []
var _rng: RandomNumberGenerator

func initialize(combat: CombatState, chips: ChipEconomy) -> void:
    _combat = combat
    _chips = chips
    _rng = RandomNumberGenerator.new()

func run_pipeline(input: PipelineInput) -> RoundResult:
    _event_queue.clear()

    # Layer 1: Pre-processing
    var skip_to_post := _phase_0a_instant_win(
        input.player_hand_type, input.ai_hand_type,
        input.insurance_player, input.insurance_ai)
    if skip_to_post:
        return _phase_7_post(input.skip_defense_reset)

    var single_side := _phase_0b_bust(
        input.sorted_player, input.sorted_ai,
        input.player_result, input.ai_result,
        input.doubledown_player, input.doubledown_ai)
    if single_side != null:
        _run_single_side_settlement(single_side, ...)
        return _phase_7_post(input.skip_defense_reset)

    _phase_0c_hammer_scan(input.sorted_player, input.sorted_ai)

    # Layer 2: Per-card settlement loop
    _run_alternating_settlement(
        input.sorted_player, input.sorted_ai,
        input.player_multipliers, input.ai_multipliers,
        input.settlement_first,
        input.doubledown_player, input.doubledown_ai)

    # Layer 3: Post-processing
    return _phase_7_post(input.skip_defense_reset)
```

### Layer 2: Alternating Settlement Loop

```gdscript
func _run_alternating_settlement(
    sorted_player: Array[CardInstance],
    sorted_ai: Array[CardInstance],
    player_mult: Array[float],
    ai_mult: Array[float],
    first: Owner,
    dd_player: bool,
    dd_ai: bool
) -> void:
    var max_pos := maxi(sorted_player.size(), sorted_ai.size())
    for pos in range(max_pos):
        var first_cards := sorted_player if first == Owner.PLAYER else sorted_ai
        var second_cards := sorted_ai if first == Owner.PLAYER else sorted_player
        var first_mult := player_mult if first == Owner.PLAYER else ai_mult
        var second_mult := ai_mult if first == Owner.PLAYER else player_mult
        var first_dd := dd_player if first == Owner.PLAYER else dd_ai
        var second_dd := dd_ai if first == Owner.PLAYER else dd_player

        # First player's card at this position
        if pos < first_cards.size() and not first_cards[pos].invalidated:
            _settle_card(first_cards[pos], first_mult[pos], first_dd, first)

        # Second player's card at this position
        if pos < second_cards.size() and not second_cards[pos].invalidated:
            _settle_card(second_cards[pos], second_mult[pos], second_dd, _opposite(first))
```

### Per-Card Settlement: Compute → Dispatch → Destroy

```gdscript
func _settle_card(card: CardInstance, mult: float, doubledown: bool, side: Owner) -> void:
    # Phases 1-4: Pure arithmetic (no side effects)
    var base := card.prototype.effect_value
    if doubledown:
        base *= 2
    var stamp_bonus := StampSystem.get_combat_bonus(card.stamp)
    var stamp_coin := StampSystem.get_coin_bonus(card.stamp)
    var quality_result := QualitySystem.resolve_bonus(card.quality, card.quality_level)
    var chip_base := card.prototype.chip_value if card.prototype.suit == Suit.CLUBS else 0
    if doubledown:
        chip_base *= 2

    var combat_total := (base + stamp_bonus + quality_result.combat_value) * mult
    var chip_total := (chip_base + stamp_coin + quality_result.chip_value) * mult

    # Phase 4: Emit computation events (pure)
    _emit(StepKind.BASE_VALUE, card, base * mult, side)
    _emit(StepKind.STAMP_EFFECT, card, stamp_bonus * mult, side)
    _emit(StepKind.QUALITY_EFFECT, card, quality_result.combat_value * mult, side)
    _emit(StepKind.MULTIPLIER_APPLIED, card, combat_total, side, {"multiplier": mult})

    # Phase 5: Dispatch effects (side effects via API calls)
    _dispatch_effects(card, combat_total, stamp_bonus * mult, mult, side)

    if chip_total > 0:
        _chips.add_chips(int(chip_total), "settlement")
        _emit(StepKind.CHIP_GAINED, card, int(chip_total), side)

    # Phase 6: Gem destroy check
    _phase_6_gem_destroy(card)

func _dispatch_effects(card: CardInstance, suit_total: int, stamp_total: int, mult: float, side: Owner) -> void:
    var opponent := _opposite(side)

    # Track separation: suit effect dispatch
    var suit_effect := (card.prototype.effect_value + QualitySystem.resolve_bonus(card.quality, card.quality_level).combat_value) * mult
    match card.prototype.suit:
        Suit.DIAMONDS:
            _combat.apply_damage(opponent, suit_effect)
            _emit(StepKind.BASE_VALUE, card, suit_effect, side, {"type": "damage"})
        Suit.HEARTS:
            var overflow := _combat.apply_heal(side, suit_effect)
            _emit(StepKind.HEAL_APPLIED, card, suit_effect, side, {"overflow": overflow})
        Suit.SPADES:
            _combat.add_defense(side, suit_effect)
            _emit(StepKind.DEFENSE_APPLIED, card, suit_effect, side)
        Suit.CLUBS:
            pass  # No combat effect

    # Track separation: stamp effect dispatch
    if stamp_total > 0:
        match card.stamp:
            Stamp.SWORD:
                _combat.apply_damage(opponent, stamp_total)
            Stamp.SHIELD:
                _combat.add_defense(side, stamp_total)
            Stamp.HEART:
                _combat.apply_heal(side, stamp_total)
```

### Phase 6: Gem Destroy

```gdscript
func _phase_6_gem_destroy(card: CardInstance) -> void:
    if card.quality == Quality.NONE:
        return
    if card.quality not in [Quality.RUBY, Quality.SAPPHIRE, Quality.EMERALD, Quality.OBSIDIAN]:
        return  # Metal qualities never trigger destroy
    var prob := QualitySystem.gem_destroy_prob(card.quality_level)
    if _rng.randf() < prob:
        card.destroy_quality()
        _emit(StepKind.GEM_DESTROY, card, 0, card.owner, {"quality": card.quality})
```

### Phase 7: Post-Processing

```gdscript
func _phase_7_post(skip_defense_reset: bool) -> RoundResult:
    if not skip_defense_reset:
        _combat.reset_defense()
    var result := _combat.get_round_result()
    settlement_step_completed.emit(_event_queue.duplicate())
    settlement_completed.emit(result)
    return result
```

### Split Support

Split runs two sequential sub-pipeline invocations with shared state:

```gdscript
# In RoundManager, not ResolutionEngine:
func _execute_split_round(...) -> void:
    # Hand A
    var input_a := PipelineInput.new()
    input_a.sorted_player = hand_a_player
    input_a.sorted_ai = hand_a_ai
    input_a.skip_defense_reset = true  # Defer defense reset
    # ... set remaining fields ...
    var result_a := resolution.run_pipeline(input_a)
    if result_a == RoundResult.PLAYER_LOSE:
        return  # Hand B does not resolve

    # Hand B (defense from Hand A persists)
    var input_b := PipelineInput.new()
    input_b.sorted_player = hand_b_player
    input_b.sorted_ai = hand_b_ai
    input_b.skip_defense_reset = false  # Reset defense after Hand B
    # ... set remaining fields ...
    var result_b := resolution.run_pipeline(input_b)
```

ResolutionEngine is stateless between runs — it does not know about split. RoundManager orchestrates the two calls.

### Determinism

Gem destroy uses a `RandomNumberGenerator` instance owned by ResolutionEngine. The RNG is seeded at initialization:

```gdscript
func initialize(combat: CombatState, chips: ChipEconomy) -> void:
    _combat = combat
    _chips = chips
    _rng = RandomNumberGenerator.new()
    _rng.seed = 0  # Set by RoundManager before each match for replay
    _rng.state = 0
```

For replay: `RoundManager` sets `_rng.seed` to a known value at match start. For production: seed with `randi()`.

## Alternatives Considered

### Alternative 1: Phase Objects with Strategy Pattern
- **Description**: Each phase is a separate class implementing a `Phase` interface. ResolutionEngine iterates over a phase array.
- **Pros**: Phases are independently testable; easy to add/remove/reorder phases; each phase has single responsibility
- **Cons**: 7+ classes for a fixed pipeline that never changes order; phase dependencies create complex constructor wiring; cross-phase state (invalidation flags, doubledown flags) must be passed between phase objects or stored in shared state; overhead with no extensibility benefit
- **Rejection Reason**: The pipeline phases have a fixed order defined by game rules. They will never be reordered, added, or removed. Strategy pattern adds indirection for a problem that doesn't require it. Private methods in a single class provide the same testability through direct unit test calls.

### Alternative 2: Data-Driven Pipeline with Phase Registry
- **Description**: Phases are registered by name in a Dictionary. Pipeline configuration loaded from JSON/Resource. Phases can be enabled/disabled via data.
- **Pros**: Designers can tune phase order; phases can be toggled for testing; fully extensible
- **Cons**: Type safety lost (Dictionary-based dispatch); performance overhead (string lookup per phase); over-engineering for a card game with fixed rules; debug difficulty (phase order determined at runtime)
- **Rejection Reason**: The 7 phases are defined by game rules, not design tuning. No designer will ever reorder them. String-based dispatch in a performance-sensitive pipeline is unjustified. Fixed code > configurable code when the configuration never changes.

## Consequences

### Positive
- Single class: all pipeline logic in one file, easy to trace
- Pure computation phases (1-4) are unit-testable without any dependencies
- Side effects isolated to Phase 5 (API calls) and Phase 6 (card mutation)
- Deterministic: seeded RNG produces identical results for replay
- Synchronous: runs to completion in one frame, no timing bugs
- Track separation: suit and stamp effects dispatch independently but add to the same formula
- Split support: ResolutionEngine is stateless, RoundManager orchestrates sequential calls

### Negative
- `_settle_card()` is a long method (~40 lines)
- Adding a new phase requires editing the private method chain

### Risks
- **Risk**: `_dispatch_effects` duplicates the quality lookup (computed in _settle_card and again in _dispatch_effects)
  **Mitigation**: Pass the quality_result as a parameter instead of re-computing; this is a refactor target
- **Risk**: Split edge cases (Hand A kills player, defense carryover) are complex
  **Mitigation**: Dedicated integration tests for split scenarios; RoundManager owns split orchestration, not ResolutionEngine

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| resolution-engine.md | 6-phase deterministic settlement pipeline | 7 phases in fixed order; seeded RNG; synchronous execution |
| resolution-engine.md | Track separation: suit + stamp effects dispatched independently | `_dispatch_effects` separates suit_base and stamp_base into independent dispatch paths |
| resolution-engine.md | Phases 1-4 pure computation, Phase 5 dispatch, Phase 6 mutation | `_settle_card` structure: compute (1-4) → dispatch (5) → destroy (6) |
| resolution-engine.md | Pre-computed event queue for UI animation | `_emit()` accumulates SettlementEvent objects; batch emitted after pipeline (ADR-0003) |
| resolution-engine.md | HAMMER pre-scan before alternating loop | `_phase_0c_hammer_scan` marks invalidated cards before per-card loop |
| resolution-engine.md | Bust self-damage bypasses defense | `apply_bust_damage()` called in Phase 0b |
| resolution-engine.md | Doubledown: only effect_value and chip_value_base doubled | `base *= 2` and `chip_base *= 2` only in Phase 1; stamp/quality unaffected |
| resolution-engine.md | Gem destroy probability by quality_level | `_phase_6_gem_destroy` uses quality_level-dependent probability |
| resolution-engine.md | Split: sequential sub-pipelines, shared HP, defense carryover | RoundManager calls `run_pipeline()` twice with `skip_defense_reset=true` for Hand A |
| combat-system.md | Damage absorbed by defense before HP | `apply_damage()` in CombatState handles defense absorption |
| combat-system.md | Bust damage bypasses defense | `apply_bust_damage()` bypasses defense entirely |
| stamp-system.md | Stamp bonus lookup for combat and chip | `StampSystem.get_combat_bonus()` and `get_coin_bonus()` in Phase 2 |
| card-quality-system.md | Quality bonus resolve: dual-track (combat + chip) | `QualitySystem.resolve_bonus()` returns (combat_value, chip_value) |
| card-quality-system.md | Gem destroy probabilities: III=15%, II=10%, I=5% | `QualitySystem.gem_destroy_prob()` returns probability by quality_level |
| hand-type-detection.md | Per-card multiplier array | `player_multipliers[pos]` and `ai_multipliers[pos]` applied in Phase 4 |
| special-plays-system.md | Insurance negates SPADE_BLACKJACK | Phase 0a checks `insurance_active` flags |
| special-plays-system.md | Split suppresses BLACKJACK_TYPE/SPADE_BLACKJACK | Hand type detection handles suppression before pipeline input |
| card-data-model.md | destroy_quality() for gem destroy | CardInstance.destroy_quality() called in Phase 6 |

## Performance Implications
- **CPU**: Pipeline runs once per round. Max 22 cards × 6 phases = 132 iterations. Each iteration: property reads + arithmetic + 1-2 API calls. Estimated <2ms total.
- **Memory**: SettlementEvent queue peaks at ~312 events (~20KB). Transient, cleared per run.
- **Load Time**: None — pipeline runs during gameplay, not at load time.
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- Pipeline produces deterministic results given identical inputs and RNG seed
- Phases 1-4 produce zero side effects (pure computation)
- Phase 5 is the only phase that calls CombatState/ChipEconomy APIs
- Phase 6 is the only phase that mutates CardInstance
- Track separation identity holds: suit_effect + stamp_effect = combat_effect for every card
- Split produces correct results (defense carryover, Hand A death stops Hand B)
- Bust self-damage bypasses defense
- HAMMER invalidation is symmetric (no first-player advantage)
- Instant win skips all per-card phases
- Doubledown doubles only effect_value and chip_value_base, not stamp/quality/multiplier
