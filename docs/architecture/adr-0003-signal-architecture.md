# ADR-0003: Signal Architecture

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (signals, communication) |
| **Knowledge Risk** | LOW — GDScript signals, typed signals stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (composition root — systems are scene-tree nodes, no Autoloads) |
| **Enables** | ADR-0004 (resolution pipeline uses settlement_step_completed signal), ADR-0008 (UI node hierarchy connects to all system signals) |
| **Blocks** | All stories involving cross-system communication — UI, resolution animation, phase transitions |
| **Ordering Note** | Must be Accepted before ADR-0004 (Resolution Pipeline) and ADR-0008 (UI Node Hierarchy) |

## Context

### Problem Statement
17 systems across 5 layers need to communicate. Three distinct communication patterns exist: (1) state change notifications from logic to UI, (2) player action requests from UI to logic, and (3) orchestration commands between Game Flow systems. How are these patterns standardized? How does the resolution pipeline emit step-by-step events for UI animation while remaining logically synchronous?

### Constraints
- ADR-0001 established: no Autoloads, composition root pattern, injected references
- UI must never call game logic methods directly — request signals only
- Resolution pipeline must be deterministic (seeded RNG) — cannot yield mid-pipeline
- UI needs per-card animation delays during settlement (500ms between cards)
- All signal connections must be explicit (no hidden subscriptions)
- Godot 4.6.2 supports typed signals in GDScript

### Requirements
- Must support 3 distinct communication patterns (state change, request, command)
- Must resolve the synchronous-pipeline vs asynchronous-animation tension
- Must standardize signal naming conventions across all 17 systems
- Must keep all signal connections visible (grep-able) in GameManager._ready()
- Must allow UI to subscribe to multiple system signals without creating coupling to those systems' internals

## Decision

### Three Communication Patterns

All cross-system communication uses one of three patterns:

**Pattern 1: State Change Notification (producer → subscribers)**
A system emits a signal when its owned state changes. Subscribers connect to act on the change.

```gdscript
# Emitter (owns the state)
signal hp_changed(target: CombatantTarget, new_hp: int, max_hp: int)
signal chips_changed(new_balance: int, delta: int, source: String)
signal phase_changed(new_phase: RoundPhase, old_phase: RoundPhase)

# Subscriber (UI, other systems)
combat.hp_changed.connect(_on_hp_changed)
chips.chips_changed.connect(_on_chips_changed)
round_mgr.phase_changed.connect(_on_phase_changed)
```

**Pattern 2: Request Signal (UI → logic)**
UI emits a request signal. Logic nodes connect and handle. UI never knows who handles it.

```gdscript
# UI (emitter — pure consumer cannot call logic methods)
signal player_hit_requested()
signal player_stand_requested()
signal player_shop_purchase_requested(item: ShopItem)

# Logic (subscriber — connects to UI request signals)
ui.player_hit_requested.connect(_on_player_hit_requested)
ui.player_shop_purchase_requested.connect(_on_shop_purchase)
```

**Pattern 3: Command Signal (orchestrator → subsystem)**
Game Flow layer emits commands to coordinate subsystems during phase transitions.

```gdscript
# RoundManager (orchestrator)
signal round_result(result: RoundResult, opponent: int, round: int, player_hp: int, ai_hp: int)

# MatchProgression (subscriber)
round_mgr.round_result.connect(_on_round_result)
```

### Resolution Pipeline: Pre-Computed Event Queue

The resolution pipeline runs **synchronously** to completion, computing all combat and chip outcomes. It emits `SettlementEvent` objects into an internal queue during execution. After the pipeline completes, the queue is emitted as a batch for UI playback.

```gdscript
class_name SettlementEvent extends RefCounted

enum StepKind {
    BASE_VALUE,
    STAMP_EFFECT,
    QUALITY_EFFECT,
    MULTIPLIER_APPLIED,
    BUST_DAMAGE,
    GEM_DESTROY,
    CHIP_GAINED,
    DEFENSE_APPLIED,
    HEAL_APPLIED,
}

var step: StepKind
var card: CardInstance
var value: int
var target: String  # "player" or "ai"
var metadata: Dictionary  # step-specific extra data

class_name ResolutionEngine extends Node

signal settlement_step_completed(events: Array[SettlementEvent])
signal settlement_completed(result: RoundResult)

var _event_queue: Array[SettlementEvent] = []

func run_pipeline(...) -> RoundResult:
    _event_queue.clear()

    # Phase 0a: insurance
    # Phase 0b: SPADE_BLACKJACK
    # Phase 0c: HAMMER
    # ... all phases run synchronously ...
    # Each phase pushes events via _emit_step()

    # After all phases complete, emit the full queue
    settlement_step_completed.emit(_event_queue.duplicate())
    var result := combat.get_round_result()
    settlement_completed.emit(result)
    return result

func _emit_step(step: StepKind, card: CardInstance, value: int, target: String, meta: Dictionary = {}) -> void:
    var event := SettlementEvent.new()
    event.step = step
    event.card = card
    event.value = value
    event.target = target
    event.metadata = meta
    _event_queue.append(event)
```

**UI playback**: TableUI receives the event array and plays it back with Tween delays:

```gdscript
func _on_settlement_step_completed(events: Array[SettlementEvent]) -> void:
    var tween := create_tween()
    for event in events:
        tween.tween_callback(_animate_event.bind(event))
        tween.tween_interval(anim_settle_delay_ms / 1000.0)

func _animate_event(event: SettlementEvent) -> void:
    match event.step:
        StepKind.BASE_VALUE:
            _show_card_base_value(event.card, event.value)
        StepKind.STAMP_EFFECT:
            _show_stamp_animation(event.card, event.value)
        # ... etc
```

### Signal Naming Conventions

| Pattern | Convention | Examples |
|---------|-----------|----------|
| State change | `{noun}_changed` | `hp_changed`, `chips_changed`, `defense_changed` |
| State determined | `{noun}_determined` | `round_result_determined` |
| Phase transition | `phase_changed` | `phase_changed(new_phase, old_phase)` |
| Lifecycle event | `{event_name}` | `settlement_completed`, `round_result` |
| Player request | `player_{action}_requested` | `player_hit_requested`, `player_stand_requested` |
| Dealing event | `cards_dealt` | `cards_dealt(player_cards, ai_cards)` |

### Signal Connection Point: GameManager._ready()

All signal connections are wired in `GameManager._ready()` alongside `initialize()` calls. This makes every subscription visible in one file:

```gdscript
func _ready() -> void:
    # Initialize all subsystems (ADR-0001)
    card_data.initialize()
    combat.initialize(card_data)
    # ... etc

    # Wire signal connections
    _wire_signals()

func _wire_signals() -> void:
    # State change → UI
    combat.hp_changed.connect(ui._on_hp_changed)
    combat.defense_changed.connect(ui._on_defense_changed)
    combat.round_result_determined.connect(round_mgr._on_combat_result)
    chips.chips_changed.connect(ui._on_chips_changed)
    round_mgr.phase_changed.connect(ui._on_phase_changed)
    round_mgr.round_result.connect(match_prog._on_round_result)
    round_mgr.cards_dealt.connect(ui._on_cards_dealt)
    resolution.settlement_step_completed.connect(ui._on_settlement_step_completed)
    resolution.settlement_completed.connect(round_mgr._on_settlement_completed)

    # UI requests → logic
    ui.player_hit_requested.connect(round_mgr._on_player_hit_requested)
    ui.player_stand_requested.connect(round_mgr._on_player_stand_requested)
    ui.player_double_down_requested.connect(round_mgr._on_player_doubledown)
    ui.player_split_requested.connect(round_mgr._on_player_split)
    ui.player_insurance_requested.connect(round_mgr._on_player_insurance)
    ui.player_sort_confirmed.connect(round_mgr._on_player_sort_confirmed)
    ui.item_used.connect(items._on_item_used)
    ui.player_shop_purchase_requested.connect(shop._on_purchase_requested)
```

### Complete Signal Registry

| Signal | Emitter | Subscribers | Pattern |
|--------|---------|-------------|---------|
| `attribute_changed(card)` | CardInstance | UI (card visual refresh) | State change |
| `hp_changed(target, new_hp, max_hp)` | CombatState | UI (HP bar) | State change |
| `defense_changed(target, new_defense)` | CombatState | UI (defense display) | State change |
| `round_result_determined(result)` | CombatState | RoundManager | State change |
| `chips_changed(new_balance, delta, source)` | ChipEconomy | UI (chip counter) | State change |
| `settlement_step_completed(events)` | ResolutionEngine | UI (animation queue) | State change |
| `settlement_completed(result)` | ResolutionEngine | RoundManager | Lifecycle |
| `phase_changed(new_phase, old_phase)` | RoundManager | UI (button states) | Phase |
| `round_result(result, opp, round, hp, hp)` | RoundManager | MatchProgression | Command |
| `cards_dealt(player_cards, ai_cards)` | RoundManager | UI (deal animation) | Lifecycle |
| `player_hit_requested()` | TableUI | RoundManager | Request |
| `player_stand_requested()` | TableUI | RoundManager | Request |
| `player_double_down_requested()` | TableUI | RoundManager | Request |
| `player_split_requested()` | TableUI | RoundManager | Request |
| `player_insurance_requested(payment)` | TableUI | RoundManager | Request |
| `player_sort_confirmed(sorted_order)` | TableUI | RoundManager, CardSorting | Request |
| `item_used(item_type, target)` | TableUI | ItemSystem | Request |
| `player_shop_purchase_requested(item)` | TableUI | ShopSystem | Request |

## Alternatives Considered

### Alternative 1: Centralized EventBus Node
- **Description**: A scene-tree EventBus node that all systems register events on. Publishers call `event_bus.emit("signal_name", args)`, subscribers call `event_bus.subscribe("signal_name", callback)`.
- **Pros**: Decouples publishers from subscribers; easy to add logging/debugging; centralized event history
- **Cons**: String-based event names are not type-safe; runtime errors instead of compile-time; hidden subscriptions (can't grep for connections); defeats Godot's native signal system; adds indirection layer with no benefit for 17 systems
- **Rejection Reason**: Godot's built-in signal system already provides typed, connectable signals with editor support. An EventBus adds string-based dispatch on top of a system that already works. With only 17 systems, the centralization benefit is negligible and the type-safety loss is real.

### Alternative 2: Coroutine/Await Pipeline (yield per step)
- **Description**: Resolution pipeline yields between each settlement step, waiting for UI animation to complete before proceeding.
- **Pros**: Pipeline and animation are perfectly synchronized; no event queue needed
- **Cons**: Pipeline becomes non-deterministic (timing-dependent); game state changes mid-pipeline if UI bugs cause missed resumes; save/load must handle mid-pipeline state; testing requires waiting for animations; breaks the deterministic pipeline principle from architecture.md
- **Rejection Reason**: The architecture principle requires deterministic pipelines with seeded RNG. Yielding mid-pipeline makes the pipeline state-dependent on animation timing, which varies by frame rate, platform, and UI complexity. Pre-computed events preserve determinism while giving UI full control over playback speed.

## Consequences

### Positive
- Type-safe: Godot typed signals catch argument mismatches at parse time
- Explicit connections: every subscription is visible in GameManager._ready()
- Deterministic pipeline: resolution computes all results synchronously, UI plays back independently
- Testable: connect to signals in unit tests without scene tree
- Follows Godot idioms: native signal system, no custom dispatch layer
- UI has full animation control: can speed up, skip, or replay settlement events without affecting logic

### Negative
- GameManager._ready() grows with signal wiring (18 connections)
- Adding a new signal requires editing both the emitter and GameManager
- SettlementEvent queue adds a data class that must be maintained

### Risks
- **Risk**: GameManager._ready() becomes unreadable with initialize() + signal wiring
  **Mitigation**: Extract signal wiring into a private `_wire_signals()` method called from _ready()
- **Risk**: SettlementEvent queue memory for long settlements (52 cards × 6 phases)
  **Mitigation**: Queue is transient — cleared at start of each pipeline run. Max ~312 events × ~64 bytes ≈ 20KB
- **Risk**: UI playback speed mismatch — animation takes longer than expected
  **Mitigation**: UI owns playback speed. If animation is skipped, logic state is already correct. No coupling between animation timing and game state.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| table-ui.md | UI never calls game logic directly | Request signal pattern — UI emits `player_*_requested` signals, logic connects and handles |
| table-ui.md | Settlement animation: per-card, per-phase sub-steps | SettlementEvent queue with StepKind enum — UI plays back with Tween delays |
| table-ui.md | Phase transitions drive button enable/disable | `phase_changed` signal from RoundManager to UI |
| table-ui.md | Chip counter: 0.5s rolling animation | `chips_changed` signal with (new_balance, delta, source) for UI tween |
| table-ui.md | HP/defense rendering from CombatState | `hp_changed` / `defense_changed` signals with typed parameters |
| resolution-engine.md | 6-phase deterministic pipeline | Synchronous execution with event queue — deterministic computation, async playback |
| resolution-engine.md | Emit settlement events per card | `_emit_step()` accumulates SettlementEvent objects during pipeline execution |
| combat-system.md | HP/defense change notifications | CombatState emits `hp_changed` and `defense_changed` after every mutation |
| chip-economy.md | Balance change notification with source tracking | `chips_changed(new_balance, delta, source)` — source identifies origin for UI feedback |
| round-management.md | 8-phase sequential pipeline with phase events | `phase_changed` signal for each RoundPhase transition |
| round-management.md | Round result to Match Progression | `round_result` signal carries (result, opponent, round, hp, hp) |
| match-progression.md | 5-state FSM consumes round results | MatchProgression connects to `round_mgr.round_result` for state transitions |
| shop-system.md | Shop close triggers return to game flow | Shop emits close signal; GameManager wires to RoundManager and MatchProgression |
| item-system.md | Sort phase opens/closes item use window | `phase_changed(SORT, ...)` / `player_sort_confirmed` from RoundManager triggers item window |
| card-data-model.md | attribute_changed signal on mutation | CardInstance emits signal on stamp/quality/quality_level changes |

## Performance Implications
- **CPU**: Signal emission is O(1) per signal with O(n_subscribers) dispatch. Max 3 subscribers per signal. Negligible.
- **Memory**: SettlementEvent queue peaks at ~312 events (~20KB). Freed after each settlement.
- **Load Time**: 18 signal connections in _ready() — negligible (<1ms)
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- All signal connections are in GameManager._ready() or a private helper it calls
- No system connects to another system's signal outside of GameManager wiring
- SettlementEvent queue accurately represents all pipeline phases
- UI can play back settlement events with variable speed without affecting game state
- No string-based signal dispatch (all typed signals)
- Request signals from UI carry no game logic — handlers in logic nodes make all decisions
