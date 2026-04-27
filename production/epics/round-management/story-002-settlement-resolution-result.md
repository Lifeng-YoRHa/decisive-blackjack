# Story 002: Settlement First Player, Resolution Integration, and Result

> **Epic**: Round Management
> **Status**: Ready
> **Layer**: Game Flow
> **Type**: Integration
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.2 day

## Context

**GDD**: `design/gdd/round-management.md`
**Requirements**: TR-rm-003 (settlement_first_player), TR-rm-006 (opponent transition simplified)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Chip Economy & Round Management)
**ADR Decision Summary**: settlement_first_player determined by point comparison (lower goes first). Tie breaks by max card blackjack_value, then coin flip with 20-chip compensation. RoundManager calls resolution.run_pipeline(), handles result, triggers opponent transition on PLAYER_WIN. Round result signal emitted with full context.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Enums, signals stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: RoundManager calls ResolutionEngine API — never runs settlement logic itself
- Forbidden: No direct HP/defense/chip mutation from RoundManager

---

## Acceptance Criteria

*From GDD `design/gdd/round-management.md`, scoped to MVP:*

- [ ] AC-05: Settlement first player — player point_total=19, AI=16 → PLAYER settles first (19 > 16, lower goes first)
- [ ] AC-05c: Tie → compare max card blackjack_value; AI max=A(11) > player max=K(10) → AI first
- [ ] AC-05d: Full tie → coin flip, loser gets 20 chips (SETTLEMENT_TIE_COMP)
- [ ] AC-02: PLAYER_WIN result → AI HP=0 after resolution, victory bonus injected, round_result signal emitted
- [ ] AC-03: PLAYER_LOSE result → player HP=0 after resolution, game over state
- [ ] AC-10 (simplified): Opponent transition — on PLAYER_WIN, AI HP resets for next opponent (from scaling table), round_counter resets to 1, new coin flip for first_player
- [ ] round_result signal emitted with (result, opponent_number, round_number, player_hp, ai_hp)
- [ ] Resolution engine called with correct PipelineInput (sorted hands, point results, multipliers, settlement_first_player)

---

## Implementation Notes

*Derived from ADR-0010:*

settlement_first_player logic (from GDD formulas section):
1. Compare point_totals: lower goes first (advantage)
2. If equal: compare max card blackjack_value (A=11, J-K=10, 2-10=face)
3. If still equal: coin flip → loser gets chips.add_chips(20, SETTLEMENT_TIE_COMP)

RESOLUTION phase:
1. Determine settlement_first_player
2. Calculate hand type multipliers (from HandTypeDetection — Sprint 1)
3. Build PipelineInput with all required fields
4. Call resolution.run_pipeline(input)
5. Receive RoundResult

DEATH_CHECK phase:
1. Process result from resolution
2. Emit round_result signal
3. If CONTINUE: increment round_counter, toggle first_player, start next round
4. If PLAYER_WIN: trigger opponent transition (reset AI HP, increment opponent_number)
5. If PLAYER_LOSE: signal game over

MVP opponent transition is simplified: just reset AI HP from scaling table and increment opponent_number. No shop phase, no match progression FSM.

**Performance**: settlement_first_player determination is 2-3 integer comparisons + max 1 RNG call. Resolution delegation runs within the same frame (synchronous pipeline). Opponent transition resets one Combatant + increments one counter — O(1). Signal emission for round_result is lightweight.

---

## Out of Scope

- Phase FSM and deal logic → Story 001
- Shop phase (between opponents) — deferred
- Match progression FSM — deferred
- Split sub-pipeline — deferred

---

## QA Test Cases

- **AC-05 (settlement first player by points)**:
  - Given: Player point_total=19, AI point_total=16
  - When: Determining settlement_first_player
  - Then: AI goes first (16 < 19, lower has advantage)
  - Edge cases: Player 16, AI 19 → player first

- **AC-05c (tie → max card)**:
  - Given: Both point_total=18, player max card=K(10), AI max card=A(11)
  - When: Determining settlement_first_player
  - Then: Player goes first (AI's A=11 is higher, so AI "wins" tiebreak → player is settlement_first_player)
  - Edge cases: Both same max card → coin flip

- **AC-05d (full tie → coin flip + compensation)**:
  - Given: Both point_total=18, both max card=K(10)
  - When: Coin flip determines settlement_first_player
  - Then: Loser gets chips.add_chips(20, SETTLEMENT_TIE_COMP); result is deterministic with seeded RNG
  - Edge cases: Verify chip compensation actually added

- **AC-02 (PLAYER_WIN)**:
  - Given: Resolution completes with AI HP=0
  - When: Processing result
  - Then: round_result=PLAYER_WIN emitted; victory bonus injected via chips.add_chips(75, VICTORY_BONUS) for opponent 1

- **AC-03 (PLAYER_LOSE)**:
  - Given: Resolution completes with player HP=0
  - When: Processing result
  - Then: round_result=PLAYER_LOSE emitted; game over state

- **AC-10 (opponent transition)**:
  - Given: PLAYER_WIN against opponent 1, player HP=45
  - When: Transitioning to opponent 2
  - Then: AI HP resets to 100 (scaling[2]), round_counter=1, new coin flip for first_player, player HP stays 45

- **PipelineInput correctness**:
  - Given: Sorted hands, point results, multipliers
  - When: Building PipelineInput
  - Then: All fields correctly populated: sorted_player, sorted_ai, player_result, ai_result, player_multipliers, ai_multipliers, settlement_first, insurance=false, doubledown=false, skip_defense_reset=false

- **round_result signal**:
  - Given: Round completes with CONTINUE, player HP=80, AI HP=60
  - When: Signal emitted
  - Then: round_result(CONTINUE, 1, 1, 80, 60)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/round_management/round_resolution_result_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (phase FSM and deal), Resolution Engine Stories 001+002, Combat State Stories 001+002, Chip Economy Story 001, Sprint 1 (HandTypeDetection for multipliers)
- Unlocks: Table UI epic (needs phase signals and round results)
