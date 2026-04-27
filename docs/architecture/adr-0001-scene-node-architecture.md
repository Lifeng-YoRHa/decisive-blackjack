# ADR-0001: Scene/Node Architecture

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (scene management, node lifecycle) |
| **Knowledge Risk** | LOW — SceneTree, Node, _ready(), @onready stable since 4.0 |
| **References Consulted** | docs/engine-reference/godot/VERSION.md, breaking-changes.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR) |
| **Enables** | ADR-0002 (Card Data Model), ADR-0003 (Signal Architecture), ADR-0004 (Resolution Pipeline), all subsequent ADRs |
| **Blocks** | All Foundation/Core layer stories — cannot start coding without this |
| **Ordering Note** | Must be Accepted before any other ADR. All other ADRs assume this pattern. |

## Context

### Problem Statement
The game has 17 systems across 5 architecture layers that must be instantiated, connected, and lifecycle-managed. How are they created, how do they find each other, and who controls their lifecycle?

### Constraints
- Single-scene game: the table view is the only gameplay scene. No scene transitions during a match.
- Godot 4.6.2 with GDScript
- Systems must be testable in isolation
- Dependency direction must be enforced (Core never accesses Feature)
- All 17 systems are active simultaneously during gameplay

### Requirements
- Must support dependency injection for testability
- Must enforce architecture layer boundaries (no upward dependencies)
- Must handle game initialization (104 CardInstances, player/AI HP, chips)
- Must support save/load (serialize state, reconstruct on load)
- Must allow future addition of a main menu scene without rewriting access patterns

## Decision

All game systems are scene-tree nodes managed by a **GameManager composition root** pattern.

The main scene (`Table.tscn`) contains a `GameManager` node as root. All 17 subsystems are child nodes. GameManager holds `@onready` references and injects dependencies via `initialize()` methods during `_ready()`.

### Architecture Diagram

```
Table.tscn (main scene — autoloaded or set as main)
└── GameManager (Node — composition root)
    ├── CardDataModel (Node)       [Foundation]
    ├── CombatState (Node)         [Core]
    ├── ChipEconomy (Node)         [Feature]
    ├── ResolutionEngine (Node)    [Core]
    ├── SpecialPlays (Node)        [Feature]
    ├── SidePool (Node)            [Feature]
    ├── ShopSystem (Node)          [Feature]
    ├── AIOpponent (Node)          [Feature]
    ├── ItemSystem (Node)          [Feature]
    ├── RoundManager (Node)        [Game Flow]
    ├── MatchProgression (Node)    [Game Flow]
    └── TableUI (Control)          [Presentation]
```

### Key Interfaces

```gdscript
class_name GameManager extends Node

@onready var card_data: CardDataModel = $CardDataModel
@onready var combat: CombatState = $CombatState
@onready var chips: ChipEconomy = $ChipEconomy
@onready var resolution: ResolutionEngine = $ResolutionEngine
@onready var special_plays: SpecialPlays = $SpecialPlays
@onready var side_pool: SidePool = $SidePool
@onready var shop: ShopSystem = $ShopSystem
@onready var ai: AIOpponent = $AIOpponent
@onready var items: ItemSystem = $ItemSystem
@onready var round_mgr: RoundManager = $RoundManager
@onready var match_prog: MatchProgression = $MatchProgression
@onready var ui: TableUI = $TableUI

func _ready() -> void:
    # Foundation layer
    card_data.initialize()

    # Core layer
    combat.initialize(card_data)
    resolution.initialize(combat, chips)

    # Feature layer
    chips.initialize()
    special_plays.initialize(combat, chips, card_data)
    side_pool.initialize(chips)
    shop.initialize(chips, card_data, combat, items)
    ai.initialize(card_data)
    items.initialize(combat, chips, card_data)

    # Game Flow layer
    round_mgr.initialize(
        card_data, combat, chips, resolution,
        special_plays, side_pool, ai, items
    )
    match_prog.initialize(round_mgr, chips, shop, card_data, combat)

    # Presentation layer
    ui.initialize(combat, chips, card_data, round_mgr, match_prog)
```

**Subsystem initialize() pattern:**

```gdscript
class_name CombatState extends Node

var _card_data: CardDataModel

func initialize(card_data: CardDataModel) -> void:
    _card_data = card_data
    # Reset state for new game
    player = Combatant.new(100)
    ai = Combatant.new(80)
```

**Access rules:**
- Subsystems store injected refs as private (`_var_name`)
- Subsystems expose their own API as public methods/signals
- Subsystems never call `get_node()` or `get_parent()` to find other systems
- GameManager is the ONLY node that knows about ALL subsystems
- RoundManager receives refs to its dependencies but does NOT hold a ref to GameManager

## Alternatives Considered

### Alternative 1: All Autoloads
- **Description**: Register every system as an Autoload singleton in Project Settings
- **Pros**: Simple global access; survives scene changes; no reference passing
- **Cons**: Hidden coupling (any node can access any system); untestable in isolation; no lifecycle control; global mutable state; load order fragility
- **Rejection Reason**: Hidden coupling violates layer boundaries. A Feature node could directly call a Core API without going through the proper orchestration layer. No compile-time or load-time enforcement of dependency direction.

### Alternative 2: Hybrid (Autoloads for Foundation, scene-tree for rest)
- **Description**: CardDataModel and ChipEconomy as Autoloads (global state); Feature and Game Flow as scene-tree nodes
- **Cons**: Two access patterns confuse developers; the boundary between "global" and "scene" is arbitrary for a single-scene game; migrating a system from scene-tree to Autoload is easy but the reverse is not
- **Rejection Reason**: Over-engineering for a single-scene game. If scene transitions are added later, specific systems can be migrated to Autoloads at that point without architectural changes.

## Consequences

### Positive
- Explicit dependencies — every subsystem's requirements are visible in its `initialize()` signature
- Testable — create a test scene with only the subsystems needed, inject mocks
- Layer boundaries enforced — a Core system physically cannot call a Feature system because it doesn't have a reference to one
- Lifecycle control — `_enter_tree()`/`_exit_tree()` for per-match setup/teardown
- Simple mental model — one scene, one tree, one initialization sequence

### Negative
- GameManager `_ready()` is a large initialization function (11 `initialize()` calls)
- Adding a new subsystem requires editing GameManager and potentially RoundManager
- No cross-scene persistence (acceptable for single-scene game)

### Risks
- **Risk**: GameManager becomes a "god node" that knows too much
  **Mitigation**: GameManager only does wiring. It contains zero game logic. It reads no game state and makes no game decisions.
- **Risk**: Future main menu scene requires restructuring
  **Mitigation**: Save/load persists minimal state (match_progress JSON). Table scene reconstructs from save data. If needed, migrate CardDataModel and ChipEconomy to Autoloads in a future ADR.
- **Risk**: Circular dependency if a subsystem needs GameManager
  **Mitigation**: Subsystems never receive a GameManager ref. They only receive refs to specific subsystems they depend on.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| card-data-model.md | 104 CardInstances created at NEW_GAME; immutable prototypes | GameManager initializes CardDataModel first (Foundation layer). Prototypes loaded once. |
| combat-system.md | Combatant structs with HP/defense; API-driven access | CombatState initialized with card_data ref for AI HP scaling lookup |
| chip-economy.md | Singleton balance tracker [0,999] | ChipEconomy as scene-tree node with initialize(); no global singleton |
| resolution-engine.md | 12 typed inputs from 7 upstream systems | ResolutionEngine receives all dependencies via initialize() |
| round-management.md | 8-phase sequential pipeline; coordinates all subsystems | RoundManager receives refs to all subsystems it orchestrates |
| match-progression.md | 5-state FSM; owns opponent_number | MatchProgression receives round_mgr and other dependencies |
| table-ui.md | Signal architecture; UI never calls logic directly | TableUI receives read-only refs to state providers; emits request signals |
| item-system.md | Inventory persists across rounds/opponents | ItemSystem as scene-tree node; state survives within the single scene |

## Performance Implications
- **CPU**: Negligible — initialization runs once per game session
- **Memory**: All 17 subsystem nodes in memory simultaneously (acceptable — card game, minimal per-system overhead)
- **Load Time**: Single scene load + 11 initialize() calls < 100ms
- **Network**: N/A

## Migration Plan
First ADR — no existing code to migrate.

If a main menu scene is added in the future:
1. Move Table.tscn from main scene to a scene loaded on "New Game"
2. Create MainMenu.tscn as new main scene
3. Optionally migrate ChipEconomy and CardDataModel to Autoloads if cross-scene persistence is needed
4. Or: persist match state to disk, reconstruct on Table scene load

## Validation Criteria
- All 17 subsystems can be created and initialized without errors
- No subsystem accesses another subsystem without an injected reference
- GameManager contains zero game logic (no state reads, no decisions)
- A test scene can create a subset of subsystems with mock dependencies
- No `get_node()` calls outside of GameManager and UI scene setup
