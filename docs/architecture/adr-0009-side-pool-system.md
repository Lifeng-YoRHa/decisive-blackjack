# ADR-0009: Side Pool System

## Status

Accepted

## Date

2026-04-26

## Last Verified

2026-04-26

## Decision Makers

user + technical-director

## Summary

The side-pool system had zero ADR coverage (5 gap TRs), making it the highest-priority architectural gap. This ADR defines a single `SidePool extends Node` class implementing two independent side bets (7-Side Pool and Casino War) with const lookup tables, pure-function settlement logic, and all money flowing through ChipEconomy API.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Feature (side bets, chip transactions) |
| **Knowledge Risk** | LOW — Node lifecycle, Array, Dictionary, signals stable since 4.0 |
| **References Consulted** | VERSION.md, deprecated-apis.md |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (SidePool as scene-tree node), ADR-0002 (CardInstance.rank access) |
| **Enables** | Side pool UI stories, round management Phase 2a/2b/2c/2d stories |
| **Blocks** | Stories involving side pool betting, settlement, or UI display |
| **Ordering Note** | Can proceed in parallel with ADR-0010/0011. Round management must call place_bet/settle at correct phases. |

## Context

### Problem Statement

The architecture review identified the side-pool system as the only system with zero ADR coverage — 5 gap TRs (TR-spool-001 through TR-spool-004, TR-ui-016). Without an ADR, there is no implementation contract for how side bets are placed, settled, or how they interact with ChipEconomy and RoundManager.

### Constraints

- Two independent side bets: 7-Side Pool (count sevens) and Casino War (rank comparison)
- 3 bet tiers shared by both: 10, 20, 50 chips
- All money must flow through ChipEconomy.spend_chips() / add_chips()
- No cross-round state — each round's bet-settle cycle is independent
- AI does not participate in side pools
- Settlement must occur post-deal but pre-insurance/split

### Requirements

- Must accept optional bets on either or both pool types before dealing
- Must settle SP7 by counting rank==7 in 3 visible cards (player 2 + AI 1 face-up)
- Must settle CW by comparing max rank in 4 cards (player 2 + AI 2), tie = loss
- Must use rank values (A=14) for CW, not bj_value (A=11/1)
- Must emit signals for UI feedback on bet placement and settlement results
- Must handle chip cap (999) overflow from large payouts

## Decision

### Architecture

```
RoundManager
  │
  ├─ Phase 2a: side_pool.place_bet(SidePoolType.SP7, tier)
  │             → ChipEconomy.spend_chips()
  │
  ├─ Phase 2b: side_pool.place_bet(SidePoolType.CW, tier)
  │             → ChipEconomy.spend_chips()
  │
  ├─ Phase 1:  Deal cards
  │
  ├─ Phase 2c: side_pool.settle(player_cards, ai_face_up)
  │             → _settle_sp7() → ChipEconomy.add_chips() if payout > 0
  │             → emit pool_result(SP7, outcome, payout)
  │
  └─ Phase 2d: side_pool.settle_cw(player_cards, ai_cards)
               → _settle_cw() → ChipEconomy.add_chips() if payout > 0
               → emit pool_result(CW, outcome, payout)
```

### Key Interfaces

```gdscript
class_name SidePool extends Node

enum SidePoolType { SP7, CW }
enum CWOutcome { WIN, LOSE, TIE }

signal pool_result(pool_type: SidePoolType, outcome: String, payout: int)
signal bet_placed(pool_type: SidePoolType, amount: int)

const BET_TIERS: Array[int] = [10, 20, 50]
const SP7_MULTIPLIERS: Array[int] = [0, 2, 5, 15]  # indexed by seven_count
const CW_WIN_MULTIPLIER: int = 2
const RANK_VALUES: Dictionary = {
    Rank.TWO: 2, Rank.THREE: 3, Rank.FOUR: 4, Rank.FIVE: 5,
    Rank.SIX: 6, Rank.SEVEN: 7, Rank.EIGHT: 8, Rank.NINE: 9,
    Rank.TEN: 10, Rank.JACK: 11, Rank.QUEEN: 12, Rank.KING: 13,
    Rank.ACE: 14,
}

var _chips: ChipEconomy
var _sp7_bet: int = 0
var _cw_bet: int = 0

func initialize(chips: ChipEconomy) -> void:
    _chips = chips

func place_bet(pool_type: SidePoolType, tier: int) -> bool:
    assert(tier in BET_TIERS, "Invalid bet tier: %d" % tier)
    if not _chips.can_afford(tier):
        return false
    if not _chips.spend_chips(tier, "SIDE_POOL_BET"):
        return false
    match pool_type:
        SidePoolType.SP7:
            _sp7_bet = tier
        SidePoolType.CW:
            _cw_bet = tier
    bet_placed.emit(pool_type, tier)
    return true

func settle_sp7(player_cards: Array[CardInstance], ai_face_up: CardInstance) -> void:
    if _sp7_bet == 0:
        return
    var seven_count := _count_sevens(player_cards, ai_face_up)
    var multiplier := SP7_MULTIPLIERS[seven_count]
    var payout := _sp7_bet * multiplier
    if payout > 0:
        _chips.add_chips(payout, "SIDE_POOL_RETURN")
    pool_result.emit(SidePoolType.SP7, "%d sevens" % seven_count, payout)
    _sp7_bet = 0

func settle_cw(player_cards: Array[CardInstance], ai_cards: Array[CardInstance]) -> void:
    if _cw_bet == 0:
        return
    var max_player := _max_rank(player_cards)
    var max_ai := _max_rank(ai_cards)
    var outcome: CWOutcome
    if max_player > max_ai:
        outcome = CWOutcome.WIN
    elif max_player < max_ai:
        outcome = CWOutcome.LOSE
    else:
        outcome = CWOutcome.TIE  # treated as loss
    var payout := _cw_bet * CW_WIN_MULTIPLIER if outcome == CWOutcome.WIN else 0
    if payout > 0:
        _chips.add_chips(payout, "SIDE_POOL_RETURN")
    pool_result.emit(SidePoolType.CW, CWOutcome.keys()[outcome], payout)
    _cw_bet = 0

func reset() -> void:
    _sp7_bet = 0
    _cw_bet = 0

func _count_sevens(player_cards: Array[CardInstance], ai_face_up: CardInstance) -> int:
    var count := 0
    for card in player_cards:
        if card.prototype.rank == Rank.SEVEN:
            count += 1
    if ai_face_up.prototype.rank == Rank.SEVEN:
        count += 1
    return count

func _max_rank(cards: Array[CardInstance]) -> int:
    var max_val := 0
    for card in cards:
        var val: int = RANK_VALUES[card.prototype.rank]
        if val > max_val:
            max_val = val
    return max_val
```

### Implementation Guidelines

1. **Reset on round start**: RoundManager must call `reset()` at the start of each round to clear previous bets.
2. **Phase ordering**: Bets (place_bet) at Phase 2a/2b before deal. Settlement (settle_sp7/settle_cw) at Phase 2c/2d after deal, before insurance (Phase 3).
3. **Chip cap handling**: ChipEconomy.add_chips() already clamps to 999. No additional clamping needed in SidePool.
4. **No AI interaction**: AI never calls place_bet or settle. AI cards are only read for rank comparison in CW.

## Alternatives Considered

### Alternative 1: Single settle() call for both pools

- **Description**: One `settle(player_cards, ai_cards)` method that settles both SP7 and CW in sequence.
- **Pros**: Fewer method calls from RoundManager
- **Cons**: Forces CW to use only AI's face-up card (1 card) rather than both AI cards. The GDD specifies SP7 checks 3 visible cards (player 2 + AI 1 face-up) while CW checks all 4 cards (player 2 + AI 2). Different input sets make a combined call awkward.
- **Rejection Reason**: SP7 and CW have different input scopes (3 vs 4 cards). Separate methods with explicit inputs are clearer and match the GDD's phased settlement (2c before 2d).

### Alternative 2: SidePool as RefCounted (stateless utility)

- **Description**: SidePool as a RefCounted with no internal state. RoundManager holds bet amounts and calls static settlement functions.
- **Pros**: Truly stateless — no reset needed
- **Cons**: Bet state (which pools are active and at what tier) would move to RoundManager, mixing orchestration with game state. RoundManager already has 8 dependencies; adding bet tracking violates single responsibility.
- **Rejection Reason**: SidePool should own its own bet state for the duration of a round. Node lifecycle provides natural reset points.

## Consequences

### Positive

- Closes all 5 gap TRs — side pool goes from zero to full ADR coverage
- Stateless between rounds — no save/load complexity
- All money through ChipEconomy — consistent with spend-before-mutate principle
- Const lookup tables — multipliers and tiers are data-driven tuning knobs
- Signal-based UI feedback — pool_result and bet_placed signals for TableUI

### Negative

- Two separate settle methods instead of one — slightly more RoundManager wiring
- Rank value mapping (RANK_VALUES dictionary) duplicates knowledge also needed by other systems if they ever compare ranks

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| SP7 52% house edge too aggressive for players | Medium | Low | sp7_multiplier_1 tuning knob (2→3 cuts edge to ~32%) |
| CW tie=loss confuses players | Medium | Low | UI displays tie outcome explicitly; GDD open question tracked |
| RANK_VALUES dictionary drifts from Rank enum | Low | Low | Const dictionary indexed by Rank enum values — compile-time checked |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | 0ms | <0.01ms | 16.6ms |
| Memory | 0 bytes | ~200 bytes (Node + const tables) | 256MB |
| Load Time | 0ms | 0ms | N/A |
| Network | N/A | N/A | N/A |

## Migration Plan

First implementation — no migration needed.

## Validation Criteria

- [ ] place_bet() calls spend_chips() and returns false when can_afford() is false
- [ ] settle_sp7() counts rank==7 in exactly 3 cards (player 2 + AI face-up 1)
- [ ] settle_sp7() applies SP7_MULTIPLIERS correctly (0→0, 1→×2, 2→×5, 3→×15)
- [ ] settle_cw() uses RANK_VALUES (A=14) not bj_value (A=11/1)
- [ ] settle_cw() treats tie as loss (no payout)
- [ ] reset() clears both bet amounts to 0
- [ ] No add_chips() call when payout is 0
- [ ] pool_result signal emitted for every settlement (win, lose, or skip)
- [ ] Chip cap (999) handled by ChipEconomy.add_chips() — no SidePool clamping needed

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| side-pool.md | SP7 count/payout: count rank==7 in 3 visible cards, multiplier table [0,2,5,15] | settle_sp7() with _count_sevens() + SP7_MULTIPLIERS const |
| side-pool.md | Casino War rank comparison: max rank in 4 cards, A=14, tie=loss | settle_cw() with _max_rank() + RANK_VALUES dictionary |
| side-pool.md | 3 bet tiers: 10/20/50 chips | BET_TIERS const array, validated in place_bet() |
| side-pool.md | Settlement timing: bets pre-deal, settle post-deal before insurance/split | place_bet() at Phase 2a/2b, settle_sp7/settle_cw at Phase 2c/2d |
| side-pool.md | All money through ChipEconomy spend/add | place_bet calls spend_chips(), settle calls add_chips() |
| side-pool.md | AI does not participate | No AI-facing API; AI cards read-only for rank comparison |
| side-pool.md | No cross-round state | reset() called by RoundManager at round start |
| side-pool.md | Side pool UI bet selection and result display | pool_result and bet_placed signals for TableUI |
| chip-economy.md | spend_chips() before any game action | place_bet() calls spend_chips() before recording bet |
| round-management.md | Phase 2 side pool integration | Phase 2a/2b for bets, 2c/2d for settlement |

## Related

- ADR-0001: Scene/Node Architecture — SidePool as scene-tree child of GameManager
- ADR-0002: Card Data Model — CardInstance.prototype.rank for seven detection and rank comparison
- ADR-0003: Signal Architecture — pool_result and bet_placed follow typed signal pattern
- ADR-0007: Shop Weighted Random — same ChipEconomy spend/add API pattern
