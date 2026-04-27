# Story 001: Combatant Data Model and Core Combat API

> **Epic**: Combat State
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.3 day

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirements**: TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-006
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Scene/Node Architecture), ADR-0004 (Resolution Pipeline)
**ADR Decision Summary**: CombatState is a Node child of GameManager composition root. It exposes typed signals (hp_changed, defense_changed) and API methods (apply_damage, apply_heal, add_defense). ResolutionEngine calls CombatState API — never mutates HP/defense directly.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Node lifecycle stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: CombatState initialized via `initialize()` with dependency injection
- Forbidden: No Autoload singletons. No cross-module state mutation.

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md`, scoped to this story:*

- [ ] AC-01: `is_alive` derived from `hp > 0` (hp=0 → false, hp=1 → true regardless of defense)
- [ ] AC-02: Player hp=100, max_hp=100 on init; heal capped at max_hp with overflow tracking
- [ ] AC-03: AI HP scales by opponent_number: lookup `[80, 100, 120, 150, 180, 220, 260, 300]`; resets per opponent (not inherited)
- [ ] AC-04: Defense resets to 0 per round for both sides; add_defense has no cap
- [ ] AC-05: Damage absorbed by defense first, remainder reduces hp; hp floor at 0; defense only consumed by damage
- [ ] AC-06: Heal capped at max_hp; overflow returned but has no game effect
- [ ] AC-07: reset_defense() sets both sides' defense to 0 (idempotent)
- [ ] hp_changed signal emitted on any hp change with (target, new_hp, max_hp)
- [ ] defense_changed signal emitted on any defense change with (target, new_defense)

---

## Implementation Notes

*Derived from ADR-0001:*

CombatState extends Node, placed as child of GameManager in Table.tscn. Initialized via `initialize()` called by GameManager._ready(). Stores Combatant data internally — no other module reads hp/defense directly; they consume signals.

*Derived from ADR-0004:*

CombatState API is called by ResolutionEngine during Phase 5 (suit/stamp dispatch) and Phase 7 (defense reset, death check). All methods are void (apply_damage, apply_heal, add_defense) except apply_heal which returns overflow.

**Combatant struct** — use inner class or Dictionary. Fields: hp, max_hp, defense, pending_defense (int, default 0). Player and AI each have one Combatant instance.

**ai_hp_scaling** — const Dictionary mapping opponent_number (1-8) to max_hp values.

**Performance**: No performance impact expected — pure state management with integer arithmetic, no per-frame processing. All methods are O(1) dictionary lookups or simple arithmetic. Signals emit only on actual state changes.

---

## Out of Scope

- Bust damage (apply_bust_damage) → Story 002
- Death check (get_round_result) → Story 002
- pending_defense FIFO queue → Story 002
- AI HP healing (AI can be healed by resolution engine)

---

## QA Test Cases

- **AC-01 (is_alive)**:
  - Given: Combatant hp=0, max_hp=100, defense=5
  - When: check is_alive
  - Then: is_alive = false
  - Edge cases: hp=1 → true; hp=-1 (should never happen, but floor ensures hp >= 0)

- **AC-02 (player init)**:
  - Given: New game, opponent_number=1
  - When: Player Combatant initialized
  - Then: hp=100, max_hp=100
  - Edge cases: heal at max_hp returns overflow equal to heal amount

- **AC-03 (AI HP scaling)**:
  - Given: opponent_number=1 through 8
  - When: AI Combatant initialized for each
  - Then: max_hp matches lookup [80, 100, 120, 150, 180, 220, 260, 300]
  - Edge cases: opponent_number=4 → hp=150; opponent resets → hp restored to max_hp, not inherited

- **AC-04 (defense accumulation and reset)**:
  - Given: Player defense=0
  - When: add_defense called 3 times with amount 10
  - Then: defense=30 (no cap)
  - Edge cases: reset_defense when already 0 → no change

- **AC-05 (damage application)**:
  - Given: target hp=40, defense=8
  - When: apply_damage(target, 15)
  - Then: defense=0, hp=33 (absorbed=8, damage_to_hp=7)
  - Edge cases: defense > amount → hp unchanged, defense reduced; hp+damage would go negative → hp=0

- **AC-06 (heal application)**:
  - Given: target hp=95, max_hp=100
  - When: apply_heal(target, 12)
  - Then: hp=100, overflow=7
  - Edge cases: hp=0, heal 20 → hp=20, overflow=0

- **AC-07 (defense reset)**:
  - Given: player defense=18, AI defense=10
  - When: reset_defense()
  - Then: both defense=0
  - Edge cases: both already 0 → no change, no error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/combatant_core_api_test.gd` — must exist and pass

**Status**: [x] 38 tests passing — all ACs covered

---

## Dependencies

- Depends on: None (first story in epic)
- Unlocks: Story 002 (bust damage and death check need Combatant struct and damage API)

## Completion Notes
**Completed**: 2026-04-27
**Criteria**: 9/9 passing (all auto-verified via unit tests)
**Deviations**: ADVISORY — initialize() takes no params (ADR-0001 specifies card_data, not yet needed); PLAYER_MAX_HP/AI_HP_SCALING hardcoded constants (acceptable for story scope).
**Test Evidence**: Logic — `tests/unit/combat/combatant_core_api_test.gd` (38 tests, all passing)
**Code Review**: Complete — approved with fixes applied (typed dictionary, doc comment, enum signals, bounds checks)
