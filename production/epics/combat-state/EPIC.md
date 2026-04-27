# Epic: Combat State

> **Layer**: Core
> **GDD**: design/gdd/combat-system.md
> **Architecture Module**: CombatState — owns Combatant structs (hp, defense, pending_defense), damage/heal API
> **Status**: Ready
> **Stories**: 2 stories (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Combatant Data Model and Core Combat API | Logic | Ready | ADR-0001, ADR-0004 |
| 002 | Bust Damage, Death Check, and Defense Queue | Logic | Ready | ADR-0004 |

## Overview

Implements the combat state tracking system for 决胜21点: Combatant structs with HP, max_hp, and defense for both player and AI; damage application (defense absorbs first, then HP); healing (capped at max_hp); defense accumulation (no cap, resets per round); bust damage (bypasses defense); AI HP scaling by opponent number; and death check logic (CONTINUE / PLAYER_WIN / PLAYER_LOSE). The CombatState module is the sole authority on HP and defense — all other systems interact through its API.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Scene/Node Architecture | GameManager composition root; CombatState as scene-tree node, no Autoloads | LOW |
| ADR-0004: Resolution Pipeline | CombatState API called by resolution pipeline; signals for hp_changed/defense_changed/round_result_determined | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-combat-001 | Combatant structs with hp, max_hp, defense; player max_hp=100, AI max_hp scaled by opponent_number | ADR-0001 ✅ |
| TR-combat-002 | API: apply_damage, apply_heal, add_defense, apply_bust_damage with hp_changed/defense_changed signals | ADR-0001 ✅ ADR-0004 ✅ |
| TR-combat-003 | Defense bypass: apply_bust_damage reduces hp directly, ignoring defense | ADR-0004 ✅ |
| TR-combat-004 | queue_defense for delayed defense (FIFO, triggered between sort-end and settlement-start) | ADR-0004 ✅ |
| TR-combat-005 | reset_defense() at end of each round, defense set to 0 for both sides | ADR-0004 ✅ |
| TR-combat-006 | AI HP scaling: lookup table by opponent_number, range [80-300] | ADR-0001 ✅ |
| TR-combat-007 | Death check: after all cards settled AND defense reset; hp<=0 triggers death result | ADR-0004 ✅ |
| TR-combat-008 | pending_defense FIFO queue executed before first card settlement | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combat-system.md` are verified
- All Logic stories have passing test files in `tests/unit/combat/`
- CombatState is the sole authority on HP/defense — no other module mutates these values directly

## Next Step

Run `/create-stories combat-state` to break this epic into implementable stories.
