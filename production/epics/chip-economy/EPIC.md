# Epic: Chip Economy

> **Layer**: Feature
> **GDD**: design/gdd/chip-economy.md
> **Architecture Module**: ChipEconomy — owns balance [0,999], transaction log, all chip operations
> **Status**: Ready
> **Stories**: 1 story (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Chip Balance, Transactions, and Victory Bonus | Logic | Ready | ADR-0010 |

## Overview

Implements the chip economy system for 决胜21点: balance tracking with a hard cap of 999, atomic add/spend operations (spend before mutate), 6 income sources and 3 spend categories, victory bonus formula (50 + 25 × opponent_number), AI chip operations as no-ops, zero-value and negative-amount rejection, and a transaction log for UI queries. ChipEconomy is the sole authority on chip balance — no other module may mutate it directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Chip Economy & Round Management | Typed ChipSource/ChipPurpose enums; RoundPhase FSM; settlement-tie compensation; RoundManager/MatchProgression boundary | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-chip-001 | Balance range [0, 999] with CHIP_CAP enforcement on add_chips() | ADR-0010 ✅ |
| TR-chip-002 | API: add_chips(amount, source), spend_chips(amount, purpose)→bool, can_afford(amount)→bool, get_balance()→int | ADR-0010 ✅ |
| TR-chip-003 | Transaction logging with source categories for each add/spend | ADR-0010 ✅ |
| TR-chip-004 | 6 income sources and 3 spend categories | ADR-0010 ✅ |
| TR-chip-005 | DEPRECATED — second_player_bonus replaced by SETTLEMENT_TIE_COMP=20 | ADR-0010 ✅ |
| TR-chip-006 | victory_bonus formula: base + opponent scaling | ADR-0010 ✅ |
| TR-chip-007 | Atomic spend-before-mutate: spend_chips() must succeed before any card mutation | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/chip-economy.md` are verified
- Unit tests in `tests/unit/chip_economy/` pass
- ChipEconomy is the sole authority on chip balance — no other module mutates it directly

## Next Step

Run `/create-stories chip-economy` to break this epic into implementable stories.
