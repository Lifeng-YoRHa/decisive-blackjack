# Epic: Round Management

> **Layer**: Game Flow
> **GDD**: design/gdd/round-management.md
> **Architecture Module**: RoundManagement — phase controller, round orchestrator, first_player logic
> **Status**: Ready
> **Stories**: 2 stories (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Round Phase FSM, Deal, and Hit/Stand Flow | Integration | Ready | ADR-0003, ADR-0010 |
| 002 | Settlement First Player, Resolution Integration, and Result | Integration | Ready | ADR-0010 |

## Overview

Implements the round management system for 决胜21点: the phase controller that orchestrates a complete round from deal to result. Sprint 2 MVP scope covers the simplified flow DEAL(2 cards each) → HIT_STAND(player+AI) → SORT(auto) → RESOLUTION(call engine) → DEATH_CHECK. No insurance, split, double down, or side pool. First player alternates per round; settlement first player determined by point comparison. RoundManagement coordinates CardDataModel, CombatState, ChipEconomy, AI Opponent, and the Resolution Engine — it is the top-level orchestrator for game flow.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal Architecture | Phase transition signals: phase_entered, phase_exited, round_result | LOW |
| ADR-0010: Chip Economy & Round Management | RoundPhase FSM; first_player alternation; settlement_first_player determination; on_opponent_defeated integration | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-rm-001 | 8-phase round pipeline — MVP: DEAL → HIT_STAND → SORT → RESOLUTION → DEATH_CHECK (5 phases) | ADR-0010 ✅ |
| TR-rm-002 | first_player alternation: toggles each round between PLAYER and AI | ADR-0010 ✅ |
| TR-rm-003 | settlement_first_player: determined by comparing point_totals, lower goes first | ADR-0010 ✅ |
| TR-rm-004 | Split sub-pipeline — MVP: skipped | ADR-0010 ✅ |
| TR-rm-005 | Phase transition signals: phase_entered(phase), phase_exited(phase), round_result(result) | ADR-0003 ✅ |
| TR-rm-006 | Opponent transition: DEATH_CHECK → SHOP → next opponent or VICTORY/GAME_OVER — MVP: simplified | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/round-management.md` (MVP scope) are verified
- Integration tests in `tests/integration/round_management/` pass
- RoundManagement never mutates CombatState or ChipEconomy directly — calls their APIs

## Next Step

Run `/story-readiness production/epics/round-management/story-001-phase-deal-hitstand.md` to validate before implementation.
