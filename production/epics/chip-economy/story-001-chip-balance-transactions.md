# Story 001: Chip Balance, Transactions, and Victory Bonus

> **Epic**: Chip Economy
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.3 day

## Context

**GDD**: `design/gdd/chip-economy.md`
**Requirements**: TR-chip-001, TR-chip-002, TR-chip-003, TR-chip-004, TR-chip-006, TR-chip-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Chip Economy & Round Management Integration)
**ADR Decision Summary**: Typed ChipSource (6 sources) and ChipPurpose (3 categories) enums. ChipEconomy extends Node, child of GameManager. Sole authority on chip balance — no other module mutates it. Transaction log with typed records. Atomic spend-before-mutate pattern.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. Enums, signals, mini() stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: ChipEconomy initialized via `initialize()` with no dependencies
- Forbidden: No direct balance mutation from outside ChipEconomy. No Autoload.

---

## Acceptance Criteria

*From GDD `design/gdd/chip-economy.md`, scoped to this story:*

- [ ] AC-01: Initial balance = 100 on `reset_for_new_game()`, transaction log cleared
- [ ] AC-02: AI chip operations (add_chips with AI target) are no-ops — balance unchanged, no log entry
- [ ] AC-03: Balance capped at 999; add_chips returns actual amount gained (overflow discarded)
- [ ] AC-04: 6 income sources work independently: RESOLUTION, SETTLEMENT_TIE_COMP, SIDE_POOL_RETURN, SHOP_SELL, VICTORY_BONUS, INSURANCE_REFUND
- [ ] AC-05: Balance persists across opponents (no reset between opponents)
- [ ] AC-06: Zero chip income possible (no forced minimum)
- [ ] AC-07: victory_bonus = 50 + 25 × opponent_number (range 75-250 for opponents 1-8)
- [ ] AC-15: spend_chips returns false if balance < amount; balance unchanged, no log entry
- [ ] AC-16: Zero-value add_chips is a no-op — balance unchanged, no log entry
- [ ] AC-17: Negative amounts rejected (assert or return 0)
- [ ] AC-18: add_chips returns actual amount gained (not requested amount)
- [ ] AC-26: can_afford(amount) returns true iff amount > 0 and amount <= balance
- [ ] AC-28: reset_for_new_game() resets balance to 100 and clears log
- [ ] chips_changed signal emitted with (new_balance, delta, source/purpose)
- [ ] Transaction log entries contain amount, source enum, and direction (income/spend)

---

## Implementation Notes

*Derived from ADR-0010:*

Use typed enums `ChipSource` and `ChipPurpose` (defined in ADR-0010, Section 1). `add_chips` takes `ChipSource`; `spend_chips` takes `ChipPurpose`. Distinguish by sign in signal delta (positive = income, negative = spend).

TransactionRecord is a RefCounted with fields: amount (int, always positive), source (int — ChipSource or ChipPurpose value), is_income (bool).

Constants: INITIAL_BALANCE = 100, CHIP_CAP = 999.

victory_bonus is NOT a ChipEconomy method — it's a formula consumed by the caller (RoundManager or MatchProgression) which then calls `add_chips(result, VICTORY_BONUS)`. But for MVP, provide a helper `static func calculate_victory_bonus(opponent_number: int) -> int`.

AI no-ops: for MVP, ChipEconomy only tracks the player's balance. Any call with an AI target context is silently ignored. This can be handled by simply not calling ChipEconomy for AI — the no-op behavior is at the caller level.

**Performance**: No performance impact expected — single integer balance with mini/maxi clamp, transaction log append-only array bounded by rounds played (max ~50 entries per game). add_chips/spend_chips are O(1). Signal emits only on actual balance change.

---

## Out of Scope

- sell_price formula (used by Shop system — deferred to Alpha)
- insurance_cost / insurance_refund constants (used by Special Plays — deferred)
- Cross-system integration with ResolutionEngine (handled in Round Management epic)

---

## QA Test Cases

- **AC-01 (initial balance)**:
  - Given: New ChipEconomy instance
  - When: initialize() then get_balance()
  - Then: returns 100
  - Edge cases: reset_for_new_game() after transactions → back to 100, log cleared

- **AC-02 (AI no-ops)**:
  - Given: Balance = 200
  - When: add_chips(500, RESOLUTION) is called by AI context
  - Then: Balance unchanged at 200, no log entry
  - Edge cases: For MVP, ChipEconomy only tracks player — this is enforced at caller level

- **AC-03 (cap enforcement)**:
  - Given: Balance = 980
  - When: add_chips(50, RESOLUTION)
  - Then: Balance = 999, returns 19 (actual gained)
  - Edge cases: Balance=999, add_chips(1) → returns 0, no change

- **AC-04 (6 income sources)**:
  - Given: Balance = 0
  - When: Sequential adds with each ChipSource (25, 20, 100, 37, 125, 30)
  - Then: Balance = 337, log has 6 entries with correct sources
  - Edge cases: Each source independently produces correct log entry

- **AC-05 (cross-opponent persistence)**:
  - Given: Balance = 250 after defeating opponent 3
  - When: Spend 80 in shop, opponent 4 starts
  - Then: Balance = 170 carried forward, no reset

- **AC-07 (victory bonus formula)**:
  - Given: opponent_number = 1
  - When: calculate_victory_bonus(1)
  - Then: returns 75 (50 + 25×1)
  - Edge cases: opponent 8 → 250; opponent 0 → 50; opponent 9 → 275 (out of range but formula still works)

- **AC-15 (insufficient balance)**:
  - Given: Balance = 50
  - When: spend_chips(75, SHOP_PURCHASE)
  - Then: returns false, balance stays 50, no log entry

- **AC-16 (zero-value no-op)**:
  - Given: Balance = 100
  - When: add_chips(0, RESOLUTION)
  - Then: Balance unchanged, no log entry, returns 0

- **AC-17 (negative rejected)**:
  - Given: Balance = 100
  - When: add_chips(-50, RESOLUTION)
  - Then: Rejected (assert or return 0), balance unchanged

- **AC-18 (return actual gained)**:
  - Given: Balance = 990
  - When: add_chips(50, RESOLUTION)
  - Then: Returns 9 (actual), balance = 999

- **AC-26 (can_afford)**:
  - Given: Balance = 25
  - When: can_afford(30) → false; can_afford(25) → true; can_afford(0) → false
  - Edge cases: can_afford(-5) → false

- **chips_changed signal**:
  - Given: ChipEconomy with signal connected
  - When: add_chips(50, RESOLUTION) on balance 100
  - Then: Signal emitted with (150, 50, RESOLUTION)

- **Transaction log**:
  - Given: add_chips(45, RESOLUTION) then spend_chips(30, INSURANCE)
  - When: get_transaction_log()
  - Then: Array of 2 records: [+45, RESOLUTION, income] and [-30, INSURANCE, spend]

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/chip_economy/chip_economy_test.gd` — must exist and pass

**Status**: [x] Created — 36 tests, all passing

---

## Dependencies

- Depends on: None
- Unlocks: Resolution Engine epic (chip injection during settlement), Round Management epic (victory bonus, spend-before-mutate)

## Completion Notes
**Completed**: 2026-04-27
**Criteria**: 14/14 passing (all auto-verified via unit tests)
**Deviations**:
- ADVISORY: Victory bonus formula unified to ADR-0010 version `50 + 25 × (n-1)` (range 50-225). GDD originally specified `50 + 25 × n` (range 75-250). User-directed change.
- ADVISORY: `assert()` replaced with guard clauses for zero/negative amounts. Story AC-17 permits either approach.
**Test Evidence**: Logic — `tests/unit/chip_economy/chip_economy_test.gd` (36 tests, all passing)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (array typing fixed, formula unified)
