# Story 002: Bust Damage, Death Check, and Defense Queue

> **Epic**: Combat State
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.2 day

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirements**: TR-combat-004, TR-combat-005, TR-combat-007, TR-combat-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Resolution Pipeline)
**ADR Decision Summary**: ResolutionEngine calls apply_bust_damage (Phase 0b), executes pending_defense FIFO (before Phase 5), calls reset_defense (Phase 7a), calls get_round_result (Phase 7b). Pipeline is synchronous — all combat state changes happen in one frame.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Array operations stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: CombatState API methods called by ResolutionEngine — never reverse
- Forbidden: No cross-module state mutation. ResolutionEngine never writes hp/defense directly.

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md`, scoped to this story:*

- [ ] AC-08: Bust damage = point_total, bypasses defense entirely, hp floor at 0; busting side's cards marked invalid
- [ ] AC-09: Settlement does NOT stop when hp reaches 0 mid-settlement; later heal can revive; death check only after defense reset
- [ ] AC-10: Simultaneous death (both hp ≤ 0) → result = PLAYER_LOSE
- [ ] queue_defense(target, amount) adds to FIFO; execute_pending_defense() drains queue, calling add_defense per entry
- [ ] execute_pending_defense() called once before first card settlement, after sort completion
- [ ] Death check returns enum: CONTINUE (both alive), PLAYER_WIN (AI hp=0), PLAYER_LOSE (player hp=0 or both=0)
- [ ] round_result_determined signal emitted with the RoundResult enum value

---

## Implementation Notes

*Derived from ADR-0004:*

Phase 7 execution order: reset_defense() → get_round_result(). The death check happens ONLY after defense reset — not during settlement. This means a player at hp=0 after damage can be healed by a later heart card in the same settlement.

pending_defense is a FIFO queue (Array used as queue: push_back / pop_front). Each entry is a {target, amount} pair. execute_pending_defense() iterates the queue and calls add_defense() for each entry, then clears the queue.

apply_bust_damage bypasses defense entirely — reads current hp, subtracts bust_damage, clamps to 0. No defense absorption. Emits hp_changed signal.

RoundResult enum: CONTINUE, PLAYER_WIN, PLAYER_LOSE, PLAYER_INSTANT_WIN, AI_INSTANT_WIN (last two for Phase 0a — out of MVP scope but enum should exist).

**Performance**: No performance impact expected — FIFO queue bounded by hand size (max 11 entries), bust damage is a single subtraction, death check is two comparisons. All O(1) operations within the synchronous single-frame pipeline.

---

## Out of Scope

- Combatant struct, basic damage/heal/add_defense/reset_defense → Story 001
- AI HP scaling table → Story 001
- Resolution pipeline orchestration → Resolution Engine epic

---

## QA Test Cases

- **AC-08 (bust damage)**:
  - Given: Player hp=40, defense=10, point_total=23
  - When: apply_bust_damage(player, 23)
  - Then: hp=17 (40-23, defense ignored), defense unchanged=10
  - Edge cases: hp=20, bust_damage=25 → hp=0 (clamped); defense=100, bust_damage=10 → hp reduced by 10, defense untouched

- **AC-09 (mid-settlement death does not stop)**:
  - Given: Player hp=10, defense=0, settlement order: diamonds-12(pos2), hearts-8(pos4)
  - When: Settlement executes both positions
  - Then: After pos2: hp=0; after pos4: hp=8; settlement completed both positions
  - Edge cases: verify hp_changed signal fires at each step, not just at end

- **AC-10 (simultaneous death)**:
  - Given: Player hp=20, AI hp=20, both defense=0, settlement kills both
  - When: get_round_result() called after defense reset
  - Then: result = PLAYER_LOSE (player loses on tie)
  - Edge cases: both hp=0 after bust damage only → same rule applies

- **queue_defense FIFO**:
  - Given: Empty pending_defense queue
  - When: queue_defense(player, 5), queue_defense(player, 3), queue_defense(ai, 7)
  - Then: execute_pending_defense() adds 5+3=8 to player defense, 7 to AI defense; queue cleared
  - Edge cases: empty queue → execute is no-op; queue not cleared until execute called

- **Death check return values**:
  - Given: Player hp=30, AI hp=20, defense=0
  - When: get_round_result()
  - Then: CONTINUE
  - Edge cases: AI hp=0 → PLAYER_WIN; Player hp=0 → PLAYER_LOSE; both hp=0 → PLAYER_LOSE

- **round_result_determined signal**:
  - Given: CombatState instance connected to signal
  - When: get_round_result() returns
  - Then: signal emitted with the result enum value exactly once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/bust_death_defense_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Combatant struct and core combat API must be DONE)
- Unlocks: Resolution Engine epic (needs bust damage, death check, defense queue)
