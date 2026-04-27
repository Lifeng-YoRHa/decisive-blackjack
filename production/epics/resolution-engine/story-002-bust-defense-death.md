# Story 002: Bust Handling, Defense Reset, and Death Check

> **Epic**: Resolution Engine
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.2 day

## Context

**GDD**: `design/gdd/resolution-engine.md`
**Requirements**: TR-res-002 (track separation structure), TR-res-008 (bust handling)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Resolution Pipeline)
**ADR Decision Summary**: Phase 0b detects bust — busting side takes self-damage (bypasses defense), cards marked invalid. Single-side bust: non-busting side settles normally. Both bust: both self-damage, no card effects. Phase 7a resets defense. Phase 7b checks death (after defense reset). Pipeline is synchronous.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. GDScript control flow stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: Pipeline calls CombatState.apply_bust_damage, reset_defense, get_round_result
- Forbidden: Pipeline never mutates hp/defense directly

---

## Acceptance Criteria

*From GDD `design/gdd/resolution-engine.md`, scoped to MVP:*

- [ ] AC-05: Both sides bust → both self-damage via apply_bust_damage, all cards invalid, skip settlement, defense reset, death check
- [ ] AC-06: Only player busts → player self-damage, player cards invalid, AI cards settle normally (alternating, player side skipped)
- [ ] AC-07: Only AI busts → AI self-damage, AI cards invalid, player cards settle normally (alternating, AI side skipped)
- [ ] AC-08: Both sides not bust → enter normal settlement (Story 001 logic)
- [ ] AC-22: Defense reset after all cards settled — combat.reset_defense() called
- [ ] AC-23: Death check returns CONTINUE when both alive (hp > 0)
- [ ] AC-24: Death check returns PLAYER_WIN when AI hp = 0
- [ ] AC-25: Death check returns PLAYER_LOSE on simultaneous death (both hp = 0)
- [ ] AC-26: Mid-settlement hp=0 does NOT stop settlement — later heal can revive
- [ ] SettlementEvent queue includes bust events and post-processing events

---

## Implementation Notes

*Derived from ADR-0004:*

Phase 0b logic:
1. Check both sides' is_bust from PointResult
2. If both bust: apply_bust_damage to both, skip all card settlement, go to Phase 7
3. If only one busts: apply_bust_damage to that side, mark their cards as invalid, run single-side settlement for the other
4. If neither busts: proceed to normal alternating settlement (Story 001)

Single-side settlement: iterate only the non-busting side's cards. The busting side's positions are all skipped. The non-busting side's cards dispatch suit effects normally against the busting side.

Phase 7a: `combat.reset_defense()` — called unconditionally after all settlement.

Phase 7b: `combat.get_round_result()` — returns RoundResult enum. This is the pipeline's return value.

The track separation structure (TR-res-002) should be set up so that stamp dispatch can be added later without restructuring suit dispatch. MVP: stamp_effect = 0 for all cards, but the code path exists as a comment/placeholder.

**Performance**: No additional performance impact beyond Story 001 — bust check is two boolean comparisons, single-side settlement iterates one hand (max 11 cards), defense reset is one API call, death check is two integer comparisons. Total added overhead: O(1) for bust check + O(n) for single-side settlement where n ≤ 11.

---

## Out of Scope

- Suit effect dispatch and alternating settlement loop → Story 001
- Stamps, quality, HAMMER pre-scan, gem destroy
- Insurance, doubledown, instant win (Phase 0a)

---

## QA Test Cases

- **AC-05 (both bust)**:
  - Given: Player hp=50, point_total=24; AI hp=80, point_total=26; both is_bust=true
  - When: Pipeline runs
  - Then: Player hp=26 (50-24), AI hp=54 (80-26); no card effects; defense reset; death check: CONTINUE
  - Edge cases: Both die from bust → PLAYER_LOSE

- **AC-06 (only player busts)**:
  - Given: Player hp=40, point_total=22; AI not bust with [spades-9, diamonds-5]
  - When: Pipeline runs
  - Then: Player hp=18 (40-22); AI spades-9: add_defense(AI, 9); AI diamonds-5: apply_damage(player, 5) → hp=13; player cards skipped
  - Edge cases: Player survives bust but dies from AI settlement → PLAYER_LOSE

- **AC-07 (only AI busts)**:
  - Given: AI hp=60, point_total=25; player not bust with [diamonds-K, hearts-J]
  - Then: AI hp=35 (60-25); player diamonds-K: apply_damage(AI, 13) → hp=22; player hearts-J: apply_heal(player, 11); AI cards skipped

- **AC-08 (neither busts)**:
  - Given: Both is_bust=false
  - When: Pipeline evaluates Phase 0b
  - Then: No bust damage applied, proceeds to normal settlement

- **AC-22 (defense reset)**:
  - Given: Player defense=18, AI defense=10 after all cards settle
  - When: Phase 7a runs
  - Then: combat.reset_defense() called, both defense=0

- **AC-23 (CONTINUE)**:
  - Given: Player hp=30, AI hp=20, defense=0
  - When: Phase 7b runs
  - Then: Returns CONTINUE

- **AC-24 (PLAYER_WIN)**:
  - Given: Player hp=30, AI hp=0
  - When: Phase 7b runs
  - Then: Returns PLAYER_WIN

- **AC-25 (simultaneous death → PLAYER_LOSE)**:
  - Given: Player hp=0, AI hp=0
  - When: Phase 7b runs
  - Then: Returns PLAYER_LOSE

- **AC-26 (mid-settlement hp=0 doesn't stop)**:
  - Given: Player hp=10, defense=0, settlement: diamonds-12(pos2), hearts-8(pos4)
  - When: Pipeline runs both positions
  - Then: After pos2: hp=0; after pos4: hp=8; settlement completes both; Phase 7b: CONTINUE

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/resolution/resolution_bust_post_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (suit dispatch settlement loop), Combat State Story 002 (bust damage, death check, defense reset)
- Unlocks: Round Management epic (needs complete pipeline)
