# ADR-0007: Shop Weighted Random

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Feature (shop system, weighted random) |
| **Knowledge Risk** | LOW — RandomNumberGenerator, Array, Dictionary stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (ShopSystem as scene-tree node), ADR-0002 (CardInstance mutation API, is_valid_assignment) |
| **Enables** | Shop UI stories, economy balancing stories |
| **Blocks** | Stories involving shop purchases, inventory generation, sell/refine |
| **Ordering Note** | Should be Accepted before shop implementation stories. Can proceed in parallel with ADR-0006/0008. |

## Context

### Problem Statement
The shop generates 4 random items per visit (2 stamps, 2 enhanced cards) using weighted random selection without replacement. It executes 7 purchase operations atomically (spend before mutate). How is weighted selection implemented? How are inventory and transactions structured?

### Constraints
- 7 stamp types with unequal weights (HAMMER rare at weight 1, others 12-25)
- 8 quality types with unequal weights (DIAMOND rare at weight 5)
- Drawing without replacement for the 2 random stamps
- Enhanced card generation: 40% stamp / 60% quality split
- Gem qualities must respect suit binding (is_valid_assignment)
- All transactions atomic: ChipEconomy.spend_chips() before card mutation
- Shop visits after opponents 1-7 only (7 total)

### Requirements
- Must support weighted random without replacement for stamps
- Must validate gem-suit binding during random quality generation
- Must enforce atomic transactions (no partial state on failure)
- Must price random enhanced cards using base_buy_price + discounted enhancement
- Must support sell card refund at 50% of current investment
- Must enforce max 5 item inventory

## Decision

### Weighted Random Selection: Inline cumulative scan

```gdscript
class_name ShopSystem extends Node

const STAMP_WEIGHTS: Dictionary = {
    Stamp.SWORD: 25, Stamp.SHIELD: 25, Stamp.HEART: 25, Stamp.COIN: 25,
    Stamp.RUNNING_SHOES: 12, Stamp.TURTLE: 12, Stamp.HAMMER: 1,
}

const QUALITY_WEIGHTS: Dictionary = {
    Quality.COPPER: 25, Quality.SILVER: 25, Quality.GOLD: 20,
    Quality.RUBY: 6, Quality.SAPPHIRE: 6, Quality.EMERALD: 7,
    Quality.OBSIDIAN: 6, Quality.DIAMOND: 5,
}

func _weighted_select(weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
    var total := 0
    for w in weights.values():
        total += w
    var roll := rng.randi_range(1, total)
    var cumulative := 0
    for key in weights:
        cumulative += weights[key]
        if roll <= cumulative:
            return key
    return weights.keys()[-1]

func _weighted_select_without_replacement(
    weights: Dictionary, count: int, rng: RandomNumberGenerator
) -> Array:
    var remaining := weights.duplicate()
    var result: Array = []
    for i in count:
        var selected := _weighted_select(remaining, rng)
        result.append(selected)
        remaining.erase(selected)
    return result
```

### Inventory Generation

```gdscript
const RANDOM_STAMP_COUNT := 2
const RANDOM_CARD_COUNT := 2
const RANDOM_STAMP_RATIO := 0.40
const RANDOM_DISCOUNT_RATIO := 0.50
const MAX_RETRIES := 10
const SELL_PRICE_RATIO := 0.50

func generate_inventory(player_deck: Array[CardInstance], opponent_number: int) -> Array[ShopItem]:
    var items: Array[ShopItem] = []

    # 2 random stamps (without replacement)
    var stamps := _weighted_select_without_replacement(STAMP_WEIGHTS, RANDOM_STAMP_COUNT, _rng)
    for stamp in stamps:
        items.append(ShopItem.new_stamp(stamp, _stamp_price(stamp)))

    # 2 random enhanced cards
    for i in RANDOM_CARD_COUNT:
        var card := player_deck[_rng.randi_range(0, player_deck.size() - 1)]
        var item := _generate_enhanced_card(card)
        if item != null:
            items.append(item)

    return items

func _generate_enhanced_card(card: CardInstance) -> ShopItem:
    var is_stamp := _rng.randf() < RANDOM_STAMP_RATIO

    if is_stamp:
        var stamp := _weighted_select(STAMP_WEIGHTS, _rng)
        var price := _base_buy_price(card) + int(_stamp_price(stamp) * RANDOM_DISCOUNT_RATIO)
        return ShopItem.new_card_stamp(card, stamp, price)
    else:
        var quality := _roll_valid_quality(card.prototype.suit)
        var price := _base_buy_price(card) + int(_quality_price(quality) * RANDOM_DISCOUNT_RATIO)
        return ShopItem.new_card_quality(card, quality, QualityLevel.III, price)

func _roll_valid_quality(suit: Suit) -> Quality:
    for attempt in MAX_RETRIES:
        var quality := _weighted_select(QUALITY_WEIGHTS, _rng) as Quality
        if CardDataModel.is_valid_assignment(suit, quality):
            return quality
    return Quality.COPPER  # Fallback: always valid

func _base_buy_price(card: CardInstance) -> int:
    var base := card.prototype.chip_value
    if card.prototype.suit == Suit.SPADES and card.prototype.rank in [Rank.JACK, Rank.QUEEN, Rank.KING, Rank.ACE]:
        base += 10
    return base
```

### ShopItem: Lightweight Data Object

```gdscript
class_name ShopItem extends RefCounted

enum Kind { STAMP, CARD_STAMP, CARD_QUALITY, HP_RECOVERY, ITEM }

var kind: Kind
var stamp: Stamp
var quality: Quality
var quality_level: QualityLevel
var target_card: CardInstance
var item_type: ItemType
var price: int

static func new_stamp(stamp: Stamp, price: int) -> ShopItem:
    var item := ShopItem.new()
    item.kind = Kind.STAMP
    item.stamp = stamp
    item.price = price
    return item

static func new_card_stamp(card: CardInstance, stamp: Stamp, price: int) -> ShopItem:
    var item := ShopItem.new()
    item.kind = Kind.CARD_STAMP
    item.target_card = card
    item.stamp = stamp
    item.price = price
    return item

static func new_card_quality(card: CardInstance, quality: Quality, level: QualityLevel, price: int) -> ShopItem:
    var item := ShopItem.new()
    item.kind = Kind.CARD_QUALITY
    item.target_card = card
    item.quality = quality
    item.quality_level = level
    item.price = price
    return item
```

### Atomic Transaction Pattern

```gdscript
func buy_stamp(card: CardInstance, stamp: Stamp, price: int) -> bool:
    if not _chips.can_afford(price):
        return false
    if not _chips.spend_chips(price, "SHOP_PURCHASE"):
        return false
    card.assign_stamp(stamp)
    return true

func buy_quality(card: CardInstance, quality: Quality, price: int) -> bool:
    if not CardDataModel.is_valid_assignment(card.prototype.suit, quality):
        return false
    if not _chips.can_afford(price):
        return false
    if not _chips.spend_chips(price, "SHOP_PURCHASE"):
        return false
    card.assign_quality(quality, QualityLevel.III)
    return true

func purify(card: CardInstance) -> bool:
    if card.quality == Quality.NONE or card.quality_level == QualityLevel.I:
        return false
    var price := 100 if card.quality_level == QualityLevel.III else 200
    if not _chips.spend_chips(price, "SHOP_PURCHASE"):
        return false
    card.purify()
    return true

func sell_card(card: CardInstance) -> int:
    var investment := _calculate_investment(card)
    var refund := int(investment * SELL_PRICE_RATIO)
    card.assign_stamp(Stamp.NONE)
    card.destroy_quality()
    _chips.add_chips(refund, "SHOP_SELL")
    return refund

func buy_hp(hp_amount: int) -> bool:
    var price := hp_amount * HP_COST_PER_POINT
    if not _chips.spend_chips(price, "SHOP_PURCHASE"):
        return false
    _combat.apply_heal(Owner.PLAYER, hp_amount)
    return true

func buy_item(item_type: ItemType, price: int) -> bool:
    if _items.get_inventory().size() >= MAX_ITEM_INVENTORY:
        return false
    if not _chips.spend_chips(price, "SHOP_PURCHASE"):
        return false
    _items.purchase_item(item_type, price)
    return true

func refresh_inventory() -> bool:
    if not _chips.spend_chips(REFRESH_COST, "SHOP_PURCHASE"):
        return false
    _current_inventory = generate_inventory(_card_data.get_player_deck(), _opponent_number)
    return true
```

### Pricing Tables

```gdscript
const STAMP_PRICES: Dictionary = {
    Stamp.SWORD: 100, Stamp.SHIELD: 100, Stamp.HEART: 100, Stamp.COIN: 100,
    Stamp.RUNNING_SHOES: 150, Stamp.TURTLE: 150, Stamp.HAMMER: 300,
}

const QUALITY_PRICES: Dictionary = {
    Quality.COPPER: 40, Quality.SILVER: 80, Quality.GOLD: 120,
    Quality.DIAMOND: 200, Quality.RUBY: 120, Quality.SAPPHIRE: 120,
    Quality.EMERALD: 120, Quality.OBSIDIAN: 120,
}

const PURIFY_COST_III_TO_II := 100
const PURIFY_COST_II_TO_I := 200
const HP_COST_PER_POINT := 5
const REFRESH_COST := 20
const MAX_ITEM_INVENTORY := 5
```

## Alternatives Considered

### Alternative 1: Utility System with Weight Normalization
- **Description**: A WeightedSelector class that accepts weighted items, normalizes weights, and supports various draw modes (with/without replacement, weighted shuffle).
- **Pros**: Reusable across systems; supports arbitrary item types; well-tested utility
- **Cons**: Only used twice in the entire game (shop stamps + shop qualities); adds a class for 2 call sites; over-engineering for this scope
- **Rejection Reason**: The shop is the only system that needs weighted random selection. A 15-line inline function serves the same purpose as a 100-line utility class with zero reuse potential elsewhere.

### Alternative 2: Pre-Built Pool Pattern
- **Description**: Pre-generate all possible items into a weighted pool, then draw without replacement by removing selected items.
- **Pros**: Guarantees no duplicates naturally; pool can be inspected/debugged
- **Cons**: Pool must be rebuilt per shop visit (card targets change); pool size = 7 stamps + 52 cards × 8 qualities = 423 items; memory waste for items that will never be drawn
- **Rejection Reason**: The pool is 423 items when only 4 are drawn. Inline selection on demand is O(7) or O(8) per draw — negligible cost. Pre-building the pool is premature optimization with no benefit.

## Consequences

### Positive
- Simple: weighted selection is a single function, easily unit-tested
- Without-replacement: stamps are guaranteed distinct per visit
- Atomic transactions: ChipEconomy.spend_chips() always precedes card mutation
- ShopItem as RefCounted: lightweight data object for UI display
- Const pricing tables: all prices data-driven, easy to tune
- Gem-suit validation: retry loop with COPPER fallback prevents dead-end generation

### Negative
- Inline weighted selection is not reusable (acceptable — only 2 call sites in the game)
- _roll_valid_quality retry loop is bounded at 10 attempts (worst case: COPPER fallback)
- ShopItem does not carry UI state (selected, grayed out) — UI manages that separately

### Risks
- **Risk**: Weighted selection produces same stamp distribution every visit
  **Mitigation**: RNG seeded per visit ensures variety across 7 shop visits
- **Risk**: COPPER fallback on gem-suit conflict reduces gem frequency
  **Mitigation**: Most suits have exactly one valid gem (1/4 chance of conflict). 10 retries makes fallback rare.
- **Risk**: Sell refund formula may not match player expectations (50% of current investment only)
  **Mitigation**: UI shows refund amount before confirmation. GDD explicitly defines this behavior.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| shop-system.md | Weighted random stamp selection (2 without replacement) | _weighted_select_without_replacement with STAMP_WEIGHTS |
| shop-system.md | Weighted random enhanced cards (2, stamp 40%/quality 60%) | _generate_enhanced_card with RANDOM_STAMP_RATIO |
| shop-system.md | Gem-suit binding validation during generation | _roll_valid_quality with is_valid_assignment + COPPER fallback |
| shop-system.md | Random card pricing: base_buy_price + discounted enhancement | _base_buy_price + RANDOM_DISCOUNT_RATIO formula |
| shop-system.md | Atomic transactions: spend before mutate | All buy_* functions call spend_chips() before card mutation |
| shop-system.md | Sell card: 50% of current investment | SELL_PRICE_RATIO = 0.50 on _calculate_investment |
| shop-system.md | Fixed pricing tables for stamps, qualities, items, HP | STAMP_PRICES, QUALITY_PRICES, HP_COST_PER_POINT const dictionaries |
| shop-system.md | Purification: III→II=100, II→I=200 | PURIFY_COST constants checked against current quality_level |
| shop-system.md | Refresh: 20 chips, once per visit, regenerates 4 random items | refresh_inventory generates new inventory via generate_inventory |
| chip-economy.md | spend_chips() before any card mutation | Architecture principle enforced in every buy_* method |
| card-data-model.md | Card mutation only via assign_stamp/assign_quality/destroy_quality | Shop uses these exact methods, never direct property writes |
| item-system.md | Max 5 items in inventory | buy_item checks inventory.size() >= MAX_ITEM_INVENTORY |

## Performance Implications
- **CPU**: Weighted selection O(7) for stamps, O(8) for qualities. Inventory generation: 4 draws ≈ negligible.
- **Memory**: ShopItem array: 4 items × ~64 bytes ≈ 256 bytes per visit. Freed on shop exit.
- **Load Time**: None — shop state generated per visit.
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- Weighted selection produces distribution matching STAMP_WEIGHTS within statistical tolerance
- Two random stamps are always distinct (no duplicates)
- Gem-suit validation prevents invalid quality assignments during generation
- COPPER fallback triggered when all retries fail suit restriction
- All buy operations spend chips before mutating card state
- sell_card returns floor(current_investment * 0.50)
- Purification correctly prices III→II at 100 and II→I at 200
- Refresh costs 20 chips and regenerates all 4 random items
- No arbitrage possible (sell refund always less than purchase price)
