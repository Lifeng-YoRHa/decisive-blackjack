# Story 001: Round Phase FSM, Deal, and Hit/Stand Flow

> **Epic**: Round Management
> **Status**: Ready
> **Layer**: Game Flow
> **Type**: Integration
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.3 day

## Context

**GDD**: `design/gdd/round-management.md`
**Requirements**: TR-rm-001 (MVP phase pipeline), TR-rm-002 (first_player alternation), TR-rm-005 (phase signals)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal Architecture), ADR-0010 (Chip Economy & Round Management)
**ADR Decision Summary**: RoundManager extends Node, child of GameManager. RoundPhase enum with validated linear transitions. phase_changed signal emitted on every transition. first_player alternates each round. Game initialization via initialize() with all subsystem references.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Enums, signals, Node lifecycle stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: RoundManager coordinates subsystems via their APIs — never mutates state directly
- Forbidden: No Autoload. No cross-module state mutation.

---

## Acceptance Criteria

*From GDD `design/gdd/round-management.md`, scoped to MVP:*

- [ ] AC-15: Game initialization — player hp=100, AI hp=80 (opponent 1), chips=100, both decks shuffled, opponent_number=1, round_counter=1, first_player=random
- [ ] AC-16: Deal order follows first_player — first_player's card 1 → other's card 1 → first_player's card 2 → other's card 2
- [ ] AC-01: Normal round completes: deal → hit/stand → sort(auto) → resolution → death_check → result=CONTINUE, round_counter increments, first_player toggles
- [ ] AC-04: First player alternates — round N first_player=PLAYER → round N+1 first_player=AI
- [ ] AC-18: Defense reset at round start — reset_defense() called during DEAL phase
- [ ] RoundPhase enum: DEAL, HIT_STAND, SORT, RESOLUTION, DEATH_CHECK (MVP subset)
- [ ] Phase transitions emit phase_changed(old_phase, new_phase) signal
- [ ] MVP: SORT phase is automatic (no player input) — cards sorted by default order
- [ ] Deal draws 2 cards each from CardDataModel deck management

---

## Implementation Notes

*Derived from ADR-0010 and ADR-0001:*

RoundManager.initialize() receives references to all subsystems: card_data, combat, chips, resolution, ai. Stored as private vars.

RoundPhase FSM: linear progression DEAL → HIT_STAND → SORT → RESOLUTION → DEATH_CHECK. advance_phase() validates the current phase and transitions to next. Emits phase_changed signal.

start_round() is the entry point:
1. combat.reset_defense()
2. Transition to DEAL
3. Deal 2 cards each (alternating by first_player)
4. Transition to HIT_STAND
5. In HIT_STAND: player signals (hit_requested/stand_requested) drive card draws; AI decides via ai.make_decision()
6. When both stand (or AI stands + player stands): transition to SORT
7. SORT: auto-sort (no player input in MVP) — skip immediately to RESOLUTION
8. Transition to RESOLUTION (handled by Story 002)

first_player alternation: stored as var, toggled at end of round (when result=CONTINUE). Initial value is random coin flip on game init.

**Deal**: CardDataModel provides deck management (draw pile + discard pile). RoundManager draws cards and assigns to player/AI hands. Each card drawn reduces draw pile count. MVP: no reshuffle needed (52 cards per side, 4 dealt = 48 remaining).

**Performance**: No per-frame processing — phase transitions are event-driven (signal-based). Deal draws 2 cards each (4 draw operations). HIT_STAND awaits player signal + AI decision (O(1)). Auto-sort is no-op in MVP. All state changes delegate to subsystem APIs (O(1) per call). Signal emission is lightweight.

---

## Out of Scope

- Settlement first player determination → Story 002
- Resolution engine integration → Story 002
- Death check result handling → Story 002
- Insurance, split, double down phases
- Side pool phase
- Player manual sorting (auto-sort only)

---

## QA Test Cases

- **AC-15 (game initialization)**:
  - Given: New RoundManager initialized
  - When: initialize() called with all subsystems
  - Then: Player hp=100, AI hp=80, chips=100, round_counter=1, first_player ∈ {PLAYER, AI}
  - Edge cases: Verify all subsystem refs stored correctly

- **AC-16 (deal order)**:
  - Given: first_player=PLAYER, decks ready
  - When: DEAL phase executes
  - Then: Draw order: player card 1 → AI card 1 → player card 2 → AI card 2. Each side gets 2 cards.
  - Edge cases: first_player=AI → AI draws first

- **AC-01 (complete round flow)**:
  - Given: Initialized game, round 1
  - When: Player stands immediately, AI stands, auto-sort, resolution runs
  - Then: round_result=CONTINUE, round_counter=2
  - Edge cases: Player hits once then stands → 3 player cards

- **AC-04 (first_player alternation)**:
  - Given: Round 1 first_player=PLAYER, result=CONTINUE
  - When: Round 2 starts
  - Then: first_player=AI
  - Edge cases: 3 rounds → PLAYER, AI, PLAYER

- **AC-18 (defense reset at round start)**:
  - Given: Previous round ended with player defense=12
  - When: New round starts (DEAL phase)
  - Then: combat.reset_defense() called, both sides defense=0

- **Phase transitions**:
  - Given: Round in DEAL phase
  - When: advance_phase() called
  - Then: Transitions to HIT_STAND; phase_changed(DEAL, HIT_STAND) signal emitted
  - Edge cases: advance from DEATH_CHECK → wraps or signals round end

- **MVP auto-sort**:
  - Given: HIT_STAND completes, transition to SORT
  - When: SORT phase enters
  - Then: Cards remain in deal order (no reordering); immediately advances to RESOLUTION

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/round_management/round_phase_deal_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Combat State Stories 001+002, Chip Economy Story 001, AI Opponent Story 001, Sprint 1 (CardDataModel, PointCalculation)
- Unlocks: Story 002 (resolution integration and results)
