# Epic: Resolution Engine

> **Layer**: Core
> **GDD**: design/gdd/resolution-engine.md
> **Architecture Module**: ResolutionEngine — stateless settlement pipeline, synchronous single-frame execution
> **Status**: Ready
> **Stories**: 2 stories (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Pipeline Core — Suit Dispatch and Alternating Settlement | Integration | Ready | ADR-0003, ADR-0004 |
| 002 | Bust Handling, Defense Reset, and Death Check | Integration | Ready | ADR-0004 |

## Overview

Implements the settlement pipeline for 决胜21点: a deterministic, synchronous pipeline that processes both sides' cards in alternating order. Sprint 2 MVP scope covers bust detection, suit effect dispatch (diamonds=damage, hearts=heal, spades=defense, clubs=chips), hand type multipliers, alternating settlement, defense reset, and death check. Stamps, quality, HAMMER pre-scan, and gem destroy are excluded from MVP — the pipeline runs 4 phases instead of the full 7.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal Architecture | settlement_step_completed signal pattern; pre-computed SettlementEvent queue for UI playback | LOW |
| ADR-0004: Resolution Pipeline | Single synchronous run_pipeline() function; phased execution; combat_effect = suit_effect + stamp_effect | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-res-001 | 7-phase settlement pipeline (0a-7b) — MVP: phases 0b, 5, 7a, 7b only | ADR-0004 ✅ |
| TR-res-002 | Track separation: suit effect and stamp effect dispatch independently per card | ADR-0004 ✅ |
| TR-res-003 | Alternating settlement: settlement_first_player pos1 → other pos1 → first pos2 → ... | ADR-0004 ✅ |
| TR-res-004 | Pre-computed SettlementEvent queue: Array of RefCounted events emitted via signal | ADR-0003 ✅ |
| TR-res-005 | Seeded RandomNumberGenerator for deterministic gem destroy rolls — MVP: skipped | ADR-0004 ✅ |
| TR-res-006 | Split support: sequential sub-pipeline calls — MVP: skipped | ADR-0004 ✅ |
| TR-res-007 | Synchronous execution: entire pipeline runs in single frame, no yields/awaits | ADR-0004 ✅ |
| TR-res-008 | Bust handling: busting side skips phases 2-6, self-damage bypasses defense | ADR-0004 ✅ |
| TR-res-009 | HAMMER pre-scan — MVP: skipped | ADR-0004 ✅ |
| TR-res-010 | Doubledown — MVP: skipped | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/resolution-engine.md` (MVP scope) are verified
- Integration tests in `tests/integration/resolution/` pass
- Pipeline runs synchronously in a single frame
- ResolutionEngine calls CombatState and ChipEconomy APIs — never mutates state directly

## Next Step

Run `/create-stories resolution-engine` to break this epic into implementable stories.
