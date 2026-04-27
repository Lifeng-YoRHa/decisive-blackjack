# Epic: AI Opponent

> **Layer**: Feature
> **GDD**: design/gdd/ai-opponent.md
> **Architecture Module**: AI Opponent — decision engine, deck generator, difficulty scaling
> **Status**: Ready
> **Stories**: 1 story (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Static Hit/Stand Decision and Random Sort | Logic | Ready | ADR-0006 |

## Overview

Implements the AI opponent system for 决胜21点. Sprint 2 MVP scope is a static strategy: hit when point_total < 17, stand at 17+. Random sort order for card sorting. No strategy pattern, no deck generation, no bust probability calculation, no hand type selection — those are deferred to the full implementation. The MVP AI returns HIT/STAND decisions that round management consumes via a simple function call.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: AI Strategy Pattern | Strategy interface for AI decisions; difficulty scaling via lookup tables; AIOpponent as scene-tree node | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ai-001 | 3 decision tiers (BASIC/SMART/OPTIMAL) — MVP: BASIC only | ADR-0006 ✅ |
| TR-ai-002 | generate_deck() — MVP: skipped (use default deck) | ADR-0006 ✅ |
| TR-ai-003 | hand_type_score evaluation — MVP: skipped | ADR-0006 ✅ |
| TR-ai-004 | Sort strategies: RANDOM, DEFAULT, TACTICAL — MVP: RANDOM only | ADR-0006 ✅ |
| TR-ai-005 | calculate_bust_probability — MVP: skipped | ADR-0006 ✅ |
| TR-ai-006 | Const lookup tables indexed by opponent_number — MVP: ai_hit_threshold only | ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ai-opponent.md` (MVP scope) are verified
- Unit tests in `tests/unit/ai_opponent/` pass
- AI decision function is stateless — same input produces same output for given RNG seed

## Next Step

Run `/create-stories ai-opponent` to break this epic into implementable stories.
