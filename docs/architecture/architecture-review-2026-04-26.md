# Architecture Review Report #2

**Date**: 2026-04-26
**Engine**: Godot 4.6.2
**GDDs Reviewed**: 16
**ADRs Reviewed**: 11 (of 12 planned)
**Mode**: full
**Previous Verdict**: CONCERNS (Review #1)
**Current Verdict**: PASS

---

## Changes Since Previous Review

| Change | Previous | Current |
|--------|----------|---------|
| ADRs Accepted | 8 | 11 (+3 new) |
| ADR-0009: Side Pool | Did not exist | Accepted |
| ADR-0010: Chip Economy & Round Management | Did not exist | Accepted |
| ADR-0011: Point Calc & Hand Type | Did not exist | Accepted |
| Side pool gap TRs | 5 GAPS | 0 (all covered) |
| Overall coverage | 67% | 92% |

---

## Traceability Summary

| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Total TRs | 114 | 114 | -- |
| Covered | 76 (67%) | 105 (92%) | +29 |
| Partial | 33 (29%) | 9 (8%) | -24 |
| Gaps | 5 (4%) | 0 (0%) | -5 |

Note: TR-chip-005 (second_player_bonus) marked deprecated this review. Active TRs: 113.

## Coverage by System

| System | TRs | Covered | Partial | Gap | Primary ADR(s) |
|--------|-----|---------|---------|-----|----------------|
| card-data-model (#1) | 10 | 10 | 0 | 0 | ADR-0002 |
| point-calculation (#2) | 4 | 4 | 0 | 0 | ADR-0011 |
| hand-type-detection (#3) | 4 | 4 | 0 | 0 | ADR-0011 |
| stamp-system (#4) | 4 | 4 | 0 | 0 | ADR-0002, ADR-0004 |
| card-quality-system (#5) | 5 | 5 | 0 | 0 | ADR-0002, ADR-0004 |
| card-sorting (#6a) | 5 | 2 | 3 | 0 | ADR-0006, ADR-0008 |
| combat-system (#7) | 8 | 8 | 0 | 0 | ADR-0001, ADR-0003, ADR-0004 |
| resolution-engine (#6) | 10 | 10 | 0 | 0 | ADR-0004 |
| special-plays (#8) | 6 | 6 | 0 | 0 | ADR-0004, ADR-0010 |
| chip-economy (#10) | 7 | 6 | 1 | 0 | ADR-0010 |
| side-pool (#9) | 4 | 4 | 0 | 0 | ADR-0009 |
| shop-system (#11) | 8 | 8 | 0 | 0 | ADR-0007 |
| ai-opponent (#12) | 6 | 6 | 0 | 0 | ADR-0006 |
| round-management (#13) | 6 | 6 | 0 | 0 | ADR-0010 |
| match-progression (#14) | 5 | 5 | 0 | 0 | ADR-0001, ADR-0010 |
| item-system (#16) | 5 | 2 | 3 | 0 | (no dedicated ADR) |
| table-ui (#15) | 17 | 15 | 2 | 0 | ADR-0008, ADR-0009 |

## Remaining Partial Coverage (9 TRs)

| TR-ID | System | Requirement | Why Partial |
|-------|--------|-------------|-------------|
| TR-sort-001 | card-sorting | Two-pass sorting algorithm | No dedicated ADR; split between ADR-0008 (UI) and ADR-0004 (pipeline input) |
| TR-sort-002 | card-sorting | 1-based position assignment | Implementation detail in ADR-0004; no sorting-specific ADR |
| TR-sort-005 | card-sorting | Padlock card locking | ADR-0008 covers UI; game logic not ADR-specified |
| TR-chip-005 | chip-economy | ~~second_player_bonus=50~~ | **Deprecated**: design override replaced with SETTLEMENT_TIE_COMP=20; GDD not yet revised |
| TR-item-001 | item-system | 7 item types, 3 timing categories | No ItemInstance ADR; spread across ADR-0007/ADR-0004 |
| TR-item-003 | item-system | Sort-phase-only usage restriction | ADR-0010 defines SORT phase but no ADR restricts item timing |
| TR-item-005 | item-system | Padlock card locking game logic | ADR-0008 covers UI side only |
| TR-ui-015 | table-ui | Item bar rendering in SORT phase | ADR-0008 general UI; no item-specific UI spec |
| TR-ui-017 | table-ui | Accessibility implementation | ADR-0008 covers dual-focus; no accessibility ADR |

---

## Cross-ADR Conflicts

**No conflicts detected.** All 11 ADRs are internally consistent:
- Signal naming consistent across ADR-0003, ADR-0004, ADR-0008, ADR-0009, ADR-0010
- Data ownership unambiguous
- Pipeline ordering consistent
- No dependency cycles

### Noted Refinements (not conflicts)

- ADR-0010 refines `chips_changed` signal: String source -> typed ChipSource enum (documented in ADR-0010, code examples in ADR-0004/ADR-0009 should use typed enums at implementation time)
- ADR-0009 adds `pool_result`/`bet_placed` signals not in ADR-0003's original 18-signal registry (additive, not contradictory)

## ADR Dependency Order (topologically sorted)

```
Foundation (no dependencies):
  1. ADR-0001: Scene/Node Architecture

Depends on Foundation:
  2. ADR-0002: Card Data Model (-> ADR-0001)
  3. ADR-0003: Signal Architecture (-> ADR-0001)

Depends on Core:
  4. ADR-0005: Save/Load Strategy (-> ADR-0002)
  5. ADR-0004: Resolution Pipeline (-> ADR-0001, ADR-0002, ADR-0003)
  6. ADR-0006: AI Strategy Pattern (-> ADR-0001, ADR-0002)
  7. ADR-0007: Shop Weighted Random (-> ADR-0001, ADR-0002)
  8. ADR-0008: UI Node Hierarchy (-> ADR-0001, ADR-0003)
  9. ADR-0009: Side Pool System (-> ADR-0001, ADR-0002)

Integration layer:
  10. ADR-0010: Chip Economy & Round Management (-> ADR-0001, ADR-0003, ADR-0004, ADR-0009)
  11. ADR-0011: Point Calculation & Hand Type (-> ADR-0002, ADR-0004)

Unresolved Dependencies: None. All 11 Accepted.
Dependency Cycles: None.
```

---

## GDD Revision Flags

| GDD | Assumption | Reality (from ADR) | Action |
|-----|-----------|---------------------|--------|
| chip-economy.md | `second_player_bonus=50` for going second | ADR-0010 uses `SETTLEMENT_TIE_COMP=20`; design override deleted 50-chip bonus | Revise GDD: remove second_player_bonus, add settlement_tie_comp |
| round-management.md | References `second_player_bonus` | Same as above | Revise GDD |

## Engine Compatibility Issues

| Field | Value |
|-------|-------|
| Engine | Godot 4.6.2 |
| ADRs with Engine Compatibility section | 11/11 |
| Deprecated API references | None |
| Stale version references | None |
| Post-cutoff API conflicts | None |

### Carried Forward (Advisory, non-blocking)

| # | Severity | ADR | Finding |
|---|----------|-----|---------|
| 1 | MEDIUM | ADR-0005 | FileAccess.store_*() returns bool since 4.4; must check return value |
| 2 | HIGH | ADR-0008 | Dual-focus system (4.6): mouse and gamepad focus independent; prototype validation needed |
| 3 | LOW | Project | Forward+ renderer for 2D-only game; suitability advisory |

All 3 new ADRs (0009, 0010, 0011) have LOW engine risk, no post-cutoff API usage.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` references 11/12 ADRs. All 17 systems from `systems-index.md` appear in the architecture layer map. No orphaned architecture. Deferred: ADR-0012 (Performance Budget Validation).

---

## Verdict: PASS

All requirements have at least partial ADR coverage (0 gaps). No cross-ADR conflicts. Engine consistent. All 11 ADRs Accepted. Previous 5 blocking gaps fully resolved by ADR-0009, ADR-0010, ADR-0011.

### Remaining Advisory Items (non-blocking)

1. **GDD Revision**: Update `chip-economy.md` and `round-management.md` to remove `second_player_bonus`, add `settlement_tie_comp=20`
2. **TR Registry**: TR-chip-005 marked deprecated this review
3. **Optional ADR-0012**: Item System -- would resolve 3 partial TRs
4. **Optional ADR-0013**: Performance Budget Validation -- deferred per architecture.md
5. **Optional ADR-0014**: Accessibility Implementation -- would resolve TR-ui-017 partial

### Advisory Items can be deferred to implementation phase
