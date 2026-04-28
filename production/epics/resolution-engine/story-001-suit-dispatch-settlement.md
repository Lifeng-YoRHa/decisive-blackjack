# Story 001: Pipeline Core — Suit Dispatch and Alternating Settlement

> **Epic**: Resolution Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.3 day

## Context

**GDD**: `design/gdd/resolution-engine.md`
**Requirements**: TR-res-001 (MVP phases), TR-res-003 (alternating order), TR-res-004 (event queue), TR-res-007 (synchronous)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal Architecture), ADR-0004 (Resolution Pipeline)
**ADR Decision Summary**: ResolutionEngine is a Node with single `run_pipeline()` entry point. Uses PipelineInput bundled typed object. Each phase is a private method. No mutable state between runs. Emits settlement_step_completed signal with pre-computed SettlementEvent queue. Synchronous — runs to completion in one frame.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. GDScript control flow, Array operations stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: ResolutionEngine calls CombatState and ChipEconomy APIs — never mutates state directly
- Forbidden: No Autoload. No cross-module state mutation. Pipeline must be stateless between runs.

---

## Acceptance Criteria

*From GDD `design/gdd/resolution-engine.md`, scoped to MVP:*

- [x] AC-13: Alternating settlement order — settlement_first_player pos1 → other pos1 → first pos2 → other pos2 → ...
- [x] AC-14: First-player defense advantage — spades on pos1 add defense before opponent's diamonds on pos1 can deal damage
- [x] AC-15: Diamonds → apply_damage to opponent with (effect_value × M)
- [x] AC-16: Hearts → apply_heal to owner with (effect_value × M)
- [x] AC-17: Spades → add_defense to owner with (effect_value × M)
- [x] AC-18: Clubs → add_chips to owner with (chip_value × M), no combat effect
- [x] AC-19 (partial): Suit effect dispatch formula: suit_effect = (effect_value + gem_quality_bonus) × M — MVP: gem_quality_bonus = 0
- [x] Hand type multipliers applied correctly per card (M=1.0 for no hand type, M=2.0 for PAIR, M=hand_count for FLUSH, etc.)
- [x] Non-symmetric hands: player 4 cards, AI 2 cards → positions 3-4 AI side skipped
- [x] settlement_step_completed signal emitted after pipeline completes with array of SettlementEvents
- [x] Pipeline runs synchronously in single frame (no yields/awaits)
- [x] PipelineInput struct bundles all inputs: sorted hands, point results, multipliers, settlement_first_player

---

## Implementation Notes

*Derived from ADR-0004:*

PipelineInput is a RefCounted with typed fields. SettlementEvent is a RefCounted recording each card's settlement (card, position, effect type, amount, target). The pipeline clears the event queue at start, appends events during execution, emits signal at end.

The main settlement loop iterates positions 1..N where N = max(len(player_hand), len(ai_hand)). For each position, settle first player's card (if exists), then other player's card (if exists). For MVP, skip phases 0a/0c/1-4/6 — go directly to suit dispatch per card.

Suit dispatch is a match on card.suit:
- DIAMONDS: combat.apply_damage(other, effect_value × M)
- HEARTS: combat.apply_heal(owner, effect_value × M)
- SPADES: combat.add_defense(owner, effect_value × M)
- CLUBS: chips.add_chips(chip_value × M, ChipSource.RESOLUTION)

MVP multiplier is passed in via PipelineInput (computed by hand type detection from Sprint 1). If no hand type detected, M=1.0.

**Initialize**: `func initialize(combat: CombatState, chips: ChipEconomy) -> void`

**Performance**: Synchronous single-frame execution. Main loop iterates max(len(player_hand), len(ai_hand)) positions (max 11) with O(1) suit dispatch per card. Total: O(n) where n ≤ 22 cards. No allocations during pipeline except SettlementEvent array (pre-sized to card count). Must complete within 16.6ms frame budget — at 22 cards with 4 API calls each, budget is ~190μs per card.

---

## Out of Scope

- Bust handling (Phase 0b) → Story 002
- Defense reset (Phase 7a) → Story 002
- Death check (Phase 7b) → Story 002
- Stamps, quality, HAMMER pre-scan, gem destroy — all deferred to Vertical Slice
- Insurance, doubledown, instant win (Phase 0a) — deferred to Vertical Slice

---

## QA Test Cases

- **AC-13 (alternating order)**:
  - Given: settlement_first_player=PLAYER, player hand [A, B, C], AI hand [X, Y]
  - When: Pipeline runs
  - Then: Settlement order: P-pos1(A) → A-pos1(X) → P-pos2(B) → A-pos2(Y) → P-pos3(C); pos 3 AI skipped
  - Edge cases: settlement_first_player=AI reverses order; 1 card each → 2 settlements

- **AC-14 (defense advantage)**:
  - Given: settlement_first_player=PLAYER, player pos1 = spades-9(M=1.0), AI pos1 = diamonds-12(M=1.0)
  - When: Pos 1 settles
  - Then: Player add_defense(9) first, then AI apply_damage(player, 12) → defense absorbs 9, hp loses 3
  - Edge cases: Verify defense applied before damage in same position

- **AC-15 (diamonds = damage)**:
  - Given: Diamonds-7, M=1.0, AI hp=60, AI defense=0
  - When: Card settles
  - Then: combat.apply_damage(AI, 7) called, AI hp=53
  - Edge cases: M=2.0 → damage=14

- **AC-16 (hearts = heal)**:
  - Given: Hearts-J(effect_value=11), M=1.0, player hp=40
  - When: Card settles
  - Then: combat.apply_heal(PLAYER, 11) called, player hp=51
  - Edge cases: heal at max_hp → overflow returned

- **AC-17 (spades = defense)**:
  - Given: Spades-9, M=1.0, player defense=0
  - When: Card settles
  - Then: combat.add_defense(PLAYER, 9) called, defense=9

- **AC-18 (clubs = chips, no combat)**:
  - Given: Clubs-K(effect_value=13, chip_value=65), M=1.0
  - When: Card settles
  - Then: No combat_state call; chips.add_chips(65, RESOLUTION) called
  - Edge cases: M=2.0 → chip_output=130

- **Hand type multipliers**:
  - Given: PAIR detected, M=[2.0, 2.0] for both cards
  - When: Both cards settle
  - Then: Each card's effect multiplied by 2.0

- **Non-symmetric hands**:
  - Given: Player 4 cards, AI 2 cards
  - When: Pipeline runs
  - Then: Positions 1-2 both sides settle; positions 3-4 only player side settles

- **Synchronous execution**:
  - Given: Pipeline called
  - When: run_pipeline() returns
  - Then: All combat/chip state changes already applied. No pending callbacks.

- **Event queue**:
  - Given: Pipeline with 3 player + 2 AI cards
  - When: Pipeline completes
  - Then: settlement_step_completed signal emitted with array of 5 SettlementEvents in settlement order

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/resolution/resolution_suit_settlement_test.gd` — must exist and pass

**Status**: [x] Created and passing (24 test functions)

---

## Dependencies

- Depends on: Combat State Story 001 (Combatant API), Chip Economy Story 001 (add_chips), Sprint 1 (PointCalculation, HandTypeDetection)
- Unlocks: Story 002 (bust and post-processing), Round Management epic

## Completion Notes
**Completed**: 2026-04-28
**Criteria**: 12/12 passing
**Deviations**: ADVISORY — run_pipeline() returns void instead of RoundResult (death check is Story 002 scope); no phase separation (MVP simplification); signal uses Array not Array[SettlementEvent] (GDScript limitation)
**Test Evidence**: Integration — tests/integration/resolution/resolution_suit_settlement_test.gd (24 test functions, all passing)
**Code Review**: APPROVED WITH SUGGESTIONS

---

## Dependencies

- Depends on: Combat State Story 001 (Combatant API), Chip Economy Story 001 (add_chips), Sprint 1 (PointCalculation, HandTypeDetection)
- Unlocks: Story 002 (bust and post-processing), Round Management epic
