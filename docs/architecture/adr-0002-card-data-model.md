# ADR-0002: Card Data Model Implementation

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data structures) |
| **Knowledge Risk** | LOW — RefCounted, Resource, signals stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (scene/node architecture — CardDataModel is a scene-tree node) |
| **Enables** | ADR-0004 (resolution pipeline reads CardInstance data), ADR-0005 (save/load serializes CardInstance) |
| **Blocks** | All stories touching card data — combat, resolution, shop, AI, UI |
| **Ordering Note** | Must be Accepted before ADR-0004 (Resolution Pipeline) and ADR-0005 (Save/Load) |

## Context

### Problem Statement
The game has 52 immutable card templates (CardPrototype) and 104 mutable card instances (CardInstance). How are these data objects implemented in Godot — as Resource, RefCounted, or Node? How are lookup tables structured? How is the 104-instance lifecycle managed?

### Constraints
- 104 CardInstance objects exist at all times (52 player + 52 AI) — never created or destroyed
- CardInstance is mutated frequently: stamp, quality, quality_level changes via shop/destroy
- CardPrototype is immutable: suit, rank, bj_values, effect_value, chip_value never change
- Save/load must persist 52 player CardInstance states
- Resolution engine reads CardInstance fields per-card during settlement (performance-sensitive)
- CardInstance must emit signals on mutation (attribute_changed for UI cache invalidation)

### Requirements
- Must support 17 lookup tables (effect_value, chip_value, stamp_bonus, quality_bonus, etc.)
- Must enforce gem-suit binding (is_valid_assignment)
- Must maintain 52-card deck invariant after every mutation
- Must support revision counter for cache invalidation
- Must be serializable for save/load

## Decision

### CardPrototype: RefCounted

```gdscript
class_name CardPrototype extends RefCounted

var suit: Suit            # enum {HEARTS, DIAMONDS, SPADES, CLUBS}
var rank: Rank            # enum {ACE through KING}
var bj_values: Array[int] # A=[1,11], 2-10=[face], J-K=[10]
var effect_value: int     # A=15, 2=10..10=50, J=55..K=65
var chip_value: int       # A=75, 2=10..10=50, J=55..K=65
var key: String           # "{suit}_{rank}" for fast lookup
```

Immutable after construction. 52 instances created once by CardDataModel during `_ready()`. No signals — never changes.

### CardInstance: RefCounted

```gdscript
class_name CardInstance extends RefCounted

signal attribute_changed(card: CardInstance)

var prototype: CardPrototype  # immutable reference
var owner: Owner              # enum {PLAYER, AI}
var stamp: Stamp = Stamp.NONE
var quality: Quality = Quality.NONE
var quality_level: QualityLevel = QualityLevel.III
var revision: int = 0
var expired: bool = false     # AI deck lifecycle

func assign_stamp(new_stamp: Stamp) -> void:
    stamp = new_stamp
    revision += 1
    attribute_changed.emit(self)

func assign_quality(new_quality: Quality, level: QualityLevel = QualityLevel.III) -> void:
    assert(CardPrototype.is_valid_assignment(prototype.suit, new_quality))
    quality = new_quality
    quality_level = level
    revision += 1
    attribute_changed.emit(self)

func destroy_quality() -> void:
    quality = Quality.NONE
    quality_level = QualityLevel.III
    revision += 1
    attribute_changed.emit(self)

func purify() -> bool:
    if quality == Quality.NONE or quality_level == QualityLevel.I:
        return false
    quality_level = QualityLevel.values()[quality_level - 1]
    revision += 1
    attribute_changed.emit(self)
    return true

func to_dict() -> Dictionary:
    return {
        "suit": prototype.suit,
        "rank": prototype.rank,
        "owner": owner,
        "stamp": stamp,
        "quality": quality,
        "quality_level": quality_level,
        "revision": revision
    }

static func from_dict(data: Dictionary, prototypes: Dictionary) -> CardInstance:
    var card := CardInstance.new()
    card.prototype = prototypes["%s_%s" % [data.suit, data.rank]]
    card.owner = data.owner
    card.stamp = data.stamp
    card.quality = data.quality
    card.quality_level = data.quality_level
    card.revision = data.revision
    return card
```

### CardDataModel: Node (composition root for card data)

```gdscript
class_name CardDataModel extends Node

var _prototypes: Dictionary = {}  # "{suit}_{rank}" -> CardPrototype
var _instances: Array[CardInstance] = []

func initialize() -> void:
    _build_prototypes()
    _build_instances()

func get_prototype(suit: Suit, rank: Rank) -> CardPrototype:
    return _prototypes["%s_%s" % [suit, rank]]

func get_player_deck() -> Array[CardInstance]:
    return _instances.filter(func(c): return c.owner == Owner.PLAYER)

func get_ai_deck() -> Array[CardInstance]:
    return _instances.filter(func(c): return c.owner == Owner.AI)

func get_instance(owner: Owner, suit: Suit, rank: Rank) -> CardInstance:
    return _instances.find_custom(
        func(c): return c.owner == owner and c.prototype.suit == suit and c.prototype.rank == rank
    )

static func is_valid_assignment(suit: Suit, quality: Quality) -> bool:
    if quality == Quality.NONE: return true
    match quality:
        Quality.RUBY: return suit == Suit.DIAMONDS
        Quality.SAPPHIRE: return suit == Suit.HEARTS
        Quality.EMERALD: return suit == Suit.CLUBS
        Quality.OBSIDIAN: return suit == Suit.SPADES
        _: return true  # metals unrestricted
```

### Lookup Tables: const dictionaries

All lookup tables are const static members of CardDataModel or the relevant system node. Examples:

```gdscript
# In CardDataModel
const EFFECT_VALUE: Dictionary = {
    Rank.ACE: 15, Rank.TWO: 2, Rank.THREE: 3, ..., Rank.JACK: 11, Rank.QUEEN: 12, Rank.KING: 13
}
const CHIP_VALUE: Dictionary = {
    Rank.ACE: 75, Rank.TWO: 10, Rank.THREE: 15, ..., Rank.JACK: 55, Rank.QUEEN: 60, Rank.KING: 65
}

# In StampSystem
const STAMP_BONUS: Dictionary = {
    Stamp.SWORD: {value=2, type="DAMAGE"},
    Stamp.SHIELD: {value=2, type="DEFENSE"},
    ...
}

# In CombatSystem
const AI_HP_TABLE: Array[int] = [80, 100, 120, 150, 180, 220, 260, 300]
```

### 104-Instance Lifecycle

1. **NEW_GAME**: CardDataModel creates 104 CardInstance objects (52 per owner)
2. **Per round**: Cards drawn from deck (owner's draw pile), returned to discard pile after round
3. **Shop**: CardInstance attributes mutated (assign_stamp, assign_quality, purify)
4. **Destroy**: destroy_quality() sets quality=null but card remains in deck (52 invariant)
5. **Sell**: Card clears stamp+quality but stays in deck (52 invariant)
6. **Opponent transition**: AI deck regenerated (new instances), player deck shuffled (same instances)
7. **Save**: 52 player CardInstance.to_dict() serialized; AI deck NOT saved
8. **Load**: Recreate 52 player instances from dict; regenerate 52 AI instances

## Alternatives Considered

### Alternative 1: Resource for both CardPrototype and CardInstance
- **Description**: Use Godot Resource (.tres) for card data
- **Pros**: Built-in serialization (ResourceSaver/Loader), Inspector editing, type-safe exports
- **Cons**: 104 Resource instances are heavier than RefCounted; serialization of 104 .tres files is overkill; no designer editing needed (data from GDDs); Resource signals work but pattern is non-idiomatic for mutable game state
- **Rejection Reason**: Over-engineering. Card data is defined in GDDs, not edited in Inspector. 104 Resources for internal game state is wasteful. Custom to_dict/from_dict gives full control.

### Alternative 2: Node for CardInstance
- **Description**: Each CardInstance is a Node in the scene tree
- **Pros**: Built-in signal system, can use _process(), visible in Remote tree
- **Cons**: 104 nodes is excessive for data objects; scene tree overhead per node; nodes must be added/removed from tree; unnecessary _process() calls
- **Rejection Reason**: CardInstance is pure data — it has no per-frame logic and no visual representation. Nodes are for scene-tree participants, not data containers.

## Consequences

### Positive
- Lightweight: RefCounted has minimal overhead compared to Resource or Node
- Fast access: direct property reads during resolution (no file I/O, no scene-tree traversal)
- Explicit serialization: to_dict/from_dict gives full control over what's saved
- Type-safe: enums for all categorical fields, assertions on gem-suit binding
- Testable: create CardInstance in unit tests without scene tree or file system

### Negative
- Custom serialization: must maintain to_dict/from_dict manually as fields change
- No Inspector editing: card data not visible in Godot editor (acceptable — data from GDDs)
- No Resource export: can't export CardInstance as @export (only Resource subclasses support this)

### Risks
- **Risk**: to_dict/from_dict drift as fields are added
  **Mitigation**: Add field-count assertion in from_dict; unit test round-trip serialization
- **Risk**: 104-instance find_custom() is O(n) per lookup
  **Mitigation**: CardDataModel maintains a Dictionary index keyed by (owner, suit, rank) for O(1) lookup
- **Risk**: signal attribute_changed emitted on every mutation could be frequent during shop
  **Mitigation**: UI batches updates per frame using deferred signals if needed

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| card-data-model.md | Immutable CardPrototype registry keyed by (suit, rank) | CardPrototype as RefCounted, stored in Dictionary keyed by "{suit}_{rank}" |
| card-data-model.md | CardInstance with unique key (owner, suit, rank) | CardInstance.owner + prototype.suit + prototype.rank; Dictionary index for O(1) lookup |
| card-data-model.md | Enum types: Suit(4), Rank(13), Stamp(7+null), Quality(8+null), QualityLevel(3), Owner(2) | GDScript enums on CardDataModel or global |
| card-data-model.md | Monotonically increasing revision counter | CardInstance.revision incremented on every mutation |
| card-data-model.md | 52-instance deck invariant | Cards never created/destroyed; destroy_quality() keeps card in deck |
| card-data-model.md | is_valid_assignment(suit, quality) | Static method with gem-suit binding logic |
| card-data-model.md | Destroy op atomic: quality=null AND quality_level=III | destroy_quality() is single function, both fields set in one call |
| card-data-model.md | Save/load must validate 104 instances | to_dict/from_dict with field-count assertion; validate on load |
| card-quality-system.md | Dual-track: combat_effect and chip_output | CardInstance stores quality/level; ResolutionEngine computes dual-track at settlement time |
| shop-system.md | Sell clears stamp/quality; card stays in deck | Shop calls assign_stamp(NONE) + destroy_quality() on CardInstance |
| resolution-engine.md | HAMMER invalidation marks opponent same-position cards | ResolutionEngine reads CardInstance.stamp during Phase 0c |

## Performance Implications
- **CPU**: Property read on RefCounted is ~same as Dictionary lookup. No overhead vs Resource.
- **Memory**: 104 RefCounted instances + 52 RefCounted prototypes ≈ ~50KB total. Negligible.
- **Load Time**: 104 instance creation + 52 prototype construction < 5ms
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- 104 CardInstance objects created at initialize(); count assertion passes
- No duplicate (owner, suit, rank) keys in instance index
- to_dict() → from_dict() round-trip preserves all fields
- is_valid_assignment rejects Ruby on non-Diamonds, allows metals on any suit
- destroy_quality() sets quality=null, quality_level=III, increments revision
- 52-card invariant holds after shop operations and quality destruction
