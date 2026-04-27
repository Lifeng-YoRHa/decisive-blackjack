# Story 001: Static Hit/Stand Decision and Random Sort

> **Epic**: AI Opponent
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.3 day

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirements**: TR-ai-001 (BASIC tier), TR-ai-004 (RANDOM sort), TR-ai-006 (lookup table)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (AI Strategy Pattern)
**ADR Decision Summary**: Single AIOpponent class with tier-indexed lookup tables. MVP uses BASIC tier only: fixed threshold hit/stand. Sort strategy is RANDOM. AIOpponent is a Node child of GameManager, initialized with CardDataModel reference. Stateless between rounds.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. RandomNumberGenerator, Array operations stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: AIOpponent initialized via `initialize()` with dependency injection
- Forbidden: No Autoload. No mutable cross-round state.

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to MVP:*

- [ ] AC-05 (BASIC): AI returns HIT when `point_total < 17`, STAND when `point_total >= 17`
- [ ] AC-09 (Bust forces stand): AI returns STAND when `is_bust = true`, regardless of tier
- [ ] AC-17 (Determinism): Same inputs produce same decision (stateless — no global/static mutation)
- [ ] Random sort: AI card sort order is random (uses seeded RNG), no optimization
- [ ] AIAction enum defined: HIT, STAND (future: DOUBLE_DOWN, SPLIT, BUY_INSURANCE, SKIP_INSURANCE)

---

## Implementation Notes

*Derived from ADR-0006:*

AIOpponent extends Node, child of GameManager. For MVP, the `make_decision()` function implements only the BASIC tier path:

```gdscript
func make_decision(point_result: PointResult) -> AIAction:
    if point_result.is_bust:
        return AIAction.STAND
    return AIAction.HIT if point_result.point_total <= 16 else AIAction.STAND
```

The `sort_hand()` function shuffles cards randomly using `_rng`:

```gdscript
func sort_hand(hand: Array[CardInstance]) -> Array[CardInstance]:
    var sorted := hand.duplicate()
    sorted.shuffle()  # Uses internal RNG — but Godot shuffle is unseeded
    # For determinism: implement Fisher-Yates with _rng
    return sorted
```

For deterministic testing, the RNG should be seedable. Use `RandomNumberGenerator` with a configurable seed. In tests, set a fixed seed and verify output order is consistent.

The full ADR defines tier tables (TIER_TABLE, HIT_THRESHOLD, SORT_STRATEGY) — for MVP, these are not needed. The function is hardcoded with threshold=16. The tier infrastructure can be added later when SMART/OPTIMAL tiers are implemented.

`initialize(card_data: CardDataModel)` stores the reference (needed for future deck generation) and creates the RNG. For MVP, card_data is stored but not used.

**Performance**: No performance impact expected — make_decision is a single integer comparison, sort_hand is Fisher-Yates shuffle on max 11 cards (O(n)). Stateless between calls, no allocation except sorted array duplicate.

---

## Out of Scope

- SMART and OPTIMAL decision tiers (bust probability, desperation bonus)
- Deck generation (generate_deck)
- Hand type selection (ai_hand_type_score)
- Bust probability calculation (calculate_bust_probability)
- Insurance, split, double down decisions
- TACTICAL sort strategy

---

## QA Test Cases

- **AC-05 (BASIC hit/stand)**:
  - Given: AI hand point_total=14, is_bust=false
  - When: make_decision()
  - Then: returns HIT
  - Edge cases: point_total=16 → HIT; point_total=17 → STAND; point_total=21 → STAND

- **AC-09 (bust forces stand)**:
  - Given: AI hand point_total=24, is_bust=true
  - When: make_decision()
  - Then: returns STAND (overrides hit/stand logic)
  - Edge cases: point_total=22 (minimal bust) → STAND

- **AC-17 (determinism)**:
  - Given: Same point_result (total=17, is_bust=false)
  - When: make_decision() called 3 times
  - Then: All 3 calls return STAND. No global state modified between calls.

- **Random sort**:
  - Given: Hand of 5 cards, RNG seed=42
  - When: sort_hand() called twice with same seed
  - Then: Both calls return identical order. Order differs from input order (with high probability).
  - Edge cases: 1 card → returns same single card; 2 cards → one of 2 possible orders

- **AIAction enum**:
  - Given: AIAction.HIT and AIAction.STAND defined
  - When: compared
  - Then: They are distinct enum values, not strings

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai_opponent/ai_opponent_mvp_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Sprint 1 CardDataModel provides card types)
- Unlocks: Round Management epic (needs AI decisions during HIT_STAND phase)
