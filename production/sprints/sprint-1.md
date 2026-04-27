# Sprint 1 — 2026-04-27 to 2026-05-03

## Sprint Goal
Implement Foundation-layer data systems (CardDataModel + PointCalculation + Signal Architecture) with full test coverage, establishing the core data structures all other systems depend on.

## Capacity
- Total days: 5 (Mon–Fri)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-1 | CardDataModel: CardPrototype + CardInstance + Deck | 2.0 | None (root system) | 52 CardPrototypes created, 104 CardInstances indexed by (owner, suit, rank), to_dict/from_dict serialization, destroy_quality() works, lookup tables const |
| 1-2 | PointCalculation: calculate_hand + Ace greedy | 0.5 | 1-1 | Pure function returns correct total for 10+ test cases including multi-ace, blackjack, bust, empty hand |
| 1-3 | CardDataModel unit tests | 1.0 | 1-1 | Deck 52-card invariant, serialization round-trip, quality destroy, lookup table correctness, edge cases from GDD |
| 1-4 | PointCalculation unit tests | 0.5 | 1-2 | All 7 existing test cases in point_calculation_test.gd pass + hand type edge cases |

### Should Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-5 | Signal Architecture: typed signal bus + event queue | 1.0 | None (Foundation) | Signal bus implements ADR-0003 naming convention, settlement event queue pre-computes events, type-safe connections |
| 1-6 | Hand Type Detection: 7 types + multipliers | 1.0 | 1-1, 1-2 | Detects all 7 hand types correctly, per_card_multiplier calculated, ai_hand_type_score evaluated per GDD |

### Nice to Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 1-7 | Dual-focus prototype validation | 0.5 | Godot project | 3-5 CardView Controls tested for independent mouse hover + gamepad focus per ADR-0008 |

## Carryover from Previous Sprint
N/A (first sprint)

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| CardDataModel scope larger than estimated | Medium | Medium | CardPrototype can start with 4 suits × 13 ranks as const dicts; full lookup tables in Sprint 2 |
| Godot RefCounted serialization surprises (4.4+ FileAccess) | Low | Low | ADR-0005 flagged MEDIUM risk; to_dict/from_dict avoids direct FileAccess |
| GdUnit4 import paths require adjustment | Low | Low | Example test already validates framework; CI pipeline verified |

## Dependencies on External Factors
- Godot 4.6.2 editor installed and GdUnit4 plugin activated locally
- No external APIs or services

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (4/4)
- [ ] All tasks pass acceptance criteria
- [ ] All unit tests passing in CI
- [ ] Minimum 10 unit tests total (4 existing + 6+ new)
- [ ] No S1 or S2 bugs in delivered systems
- [ ] Code reviewed and merged to main

## Milestone
- **Target**: Milestone 1 — First Playable Round (2026-05-17)
- **Sprint contribution**: Foundation data layer (Week 1 of 3)
