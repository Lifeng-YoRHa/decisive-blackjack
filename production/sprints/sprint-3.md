# Sprint 3 — 2026-05-06 to 2026-05-12

## Sprint Goal
Build the **Core upgrades + Feature layer** for a full game loop: stamp system, card quality, resolution engine v2 (stamps + quality + HAMMER + gem destroy), shop system, and match progression — transforming one playable round into a complete 8-opponent roguelike run.

## Capacity
- Total days: 5 (Mon–Fri)
- Buffer (20%): 1 day
- Available: 4 days
- **Estimation basis**: Sprint 2 retrospective showed core systems at ~0.3 day, integration at ~0.5 day, UI at ~0.5 day (further reduced 30-40% from Sprint 2 UI estimate).

## Tasks

### Must Have (Critical Path)
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 3-1 | Stamp System: 7 stamp types, stamp_bonus_lookup, stamp_sort_key (RUNNING_SHOES=0, default=1, TURTLE=2), CardInstance.stamp field integration | 0.3 | Sprint 2 (CardDataModel) | All 7 stamps defined, bonus lookup returns correct values, sort_key determines settlement order, stamp stored on CardInstance |
| 3-2 | Card Quality System: 8 quality types (4 metal + 4 gem), 3 purity levels (III→II→I), gem-suit binding (RUBY→DIAMONDS, SAPPHIRE→HEARTS, EMERALD→CLUBS, OBSIDIAN→SPADES), quality_bonus_resolve lookup | 0.3 | Sprint 2 (CardDataModel) | 8 qualities with correct values, purity downgrade works, is_valid_assignment enforces gem-suit, bonus lookup returns combat_type+value+chip |
| 3-3 | Resolution Engine v2: full pipeline — stamps (SWORD +2 dmg, SHIELD +2 def, HEART +2 heal, COIN +10 chips, HAMMER pre-scan destroys opponent same-position card), quality dual-track (combat + chip), gem destroy roll per settlement, full sort integration (stamp_sort_key) | 0.5 | 3-1, 3-2 | HAMMER pre-scan works, stamp effects dispatch correctly, quality dual-track applies, gem destroy rolls with seeded RNG, stamp_sort_key sorts correctly |
| 3-4 | Shop System: fixed services (HP heal at 5 chips/HP, stamp assign, quality assign, purify, sell) + random inventory (2 stamps + 2 enhanced cards via weighted random), refresh at 20 chips, pricing tables from GDD | 0.5 | 3-1, 3-2, Sprint 2 (ChipEconomy) | HP heal works with spend_chips, stamp/quality assign via shop modifies CardInstance, weighted random generates inventory, refresh re-rolls random items, sell returns investment |
| 3-5 | Match Progression: formal 5-state FSM (NEW_GAME→OPPONENT_N→SHOP→VICTORY/GAME_OVER), opponent_number authority, victory_bonus on opponent defeat, shop trigger between opponents, AI deck regeneration per opponent | 0.3 | 3-4, Sprint 2 (RoundManager) | State machine transitions correctly, shop enters after opponent defeat, victory_bonus calculated, AI regenerates deck, VICTORY after opponent 8 |

### Should Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 3-6 | Shop UI: shop overlay with fixed services panel, random inventory, player card selection, buy/sell/heal buttons, chip balance display | 0.5 | 3-4 | Player can buy stamps/quality from shop, heal HP, see inventory, refresh random items |

### Nice to Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 3-7 | Card Sorting v2: two-pass sorting — Pass 1 manual drag (from Sprint 2), Pass 2 stable_sort_by(stamp_sort_key, manual_order), AI tiebreak function interface | 0.3 | 3-1, Sprint 2 (Card Sort UI) | Two-pass sort produces correct order, RUNNING_SHOES cards first, TURTLE cards last, tiebreak interface for AI |

## Carryover from Previous Sprint
None — Sprint 2 complete with zero carryover.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Resolution Engine v2 scope (6-phase pipeline) | Medium | High | Strictly implement phases in order; test each phase independently |
| Shop weighted random edge cases (empty pool, duplicates) | Low | Medium | Test with seeded RNG; handle edge cases explicitly |
| Match Progression refactoring may break existing RoundManager | Medium | High | Existing integration + smoke tests must pass after refactor |
| Shop UI complexity (first multi-panel UI) | Medium | Medium | Start with fixed services only; random inventory as stretch |

## Dependencies on External Factors
- Godot 4.6.2 editor for Shop UI (story 3-6)
- GdUnit4 plugin for automated tests
- No external APIs or services

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (5/5)
- [ ] All tasks pass acceptance criteria
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] QA plan exists for Sprint 3
- [ ] No S1/S2/S3 bugs in delivered features
- [ ] Code committed to git (per-story, not batched)
- [ ] Design documents updated for any deviations from GDD scope
- [ ] Existing smoke test still passes after refactoring

## Milestone
- **Target**: Milestone 2 — Full Game Loop (new)
- **Sprint contribution**: Core upgrades (stamps, quality) + Feature layer (shop, match progression). Sprint 3 completes Milestone 2 if all Must Have stories are delivered.
