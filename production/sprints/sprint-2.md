# Sprint 2 — 2026-05-04 to 2026-05-10

## Sprint Goal
Build the Core + Presentation layer for a **first playable round**: Combat State, Resolution Engine (simplified), AI Opponent, Round Management, Chip Economy, and Minimal Table UI — completing Milestone 1's remaining scope.

## Capacity
- Total days: 5 (Mon–Fri)
- Buffer (20%): 1 day
- Available: 4 days
- **Recalibrated estimates**: Sprint 1 retrospective recommended 60-70% reduction. Foundation/Core systems estimated at ~0.3-0.5 day each; UI at ~1.0 day.

## Tasks

### Must Have (Critical Path)
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 2-1 | Combat State: Combatant struct, HP/defense, damage/heal, bust damage, defense reset, death check, AI HP scaling table | 0.5 | Sprint 1 (none) | All core AC from combat-system.md: is_alive derived from hp, damage absorbed by defense then HP, heal capped at max_hp, bust bypasses defense, defense resets to 0, death check unified after resolution, AI HP lookup [80,100,120,150,180,220,260,300] |
| 2-2 | Chip Economy: balance tracking, add_chips (cap 999), spend_chips (reject if insufficient), can_afford, victory_bonus formula, reset_for_new_game | 0.3 | Sprint 1 (none) | Core AC: initial=100, cap=999, spend rejects if < amount, add returns actual gained, victory_bonus=50+25n, AI ops are no-ops, zero-value ops are no-ops |
| 2-3 | Resolution Engine MVP: simplified pipeline — bust detection, suit effect dispatch (diamonds=damage, hearts=heal, spades=defense, clubs=chips), hand type multipliers, alternating settlement, defense reset, death check. No stamps, no quality, no HAMMER pre-scan, no gem destroy. | 0.5 | 2-1, Sprint 1 | Bust: self-damage bypasses defense, bust side cards无效. Alternating: P1->A1->P2->A2. Suit effects correct. Multipliers applied. Defense reset after all cards. Death check returns CONTINUE/PLAYER_WIN/PLAYER_LOSE. |
| 2-4 | AI Opponent MVP: static strategy — hit below 17, stand at 17+. Random sort order. No strategy pattern for MVP (hardcoded decisions). | 0.3 | Sprint 1 | AI hits when point_total < 17, stands at 17+. Sort order is random. Returns HIT/STAND decisions for round management to consume. |
| 2-5 | Round Management MVP: simplified flow — DEAL(2 cards each) -> HIT_STAND(player+AI) -> SORT(auto) -> RESOLUTION(call engine) -> DEATH_CHECK. No insurance, no split, no double down, no side pool. First player alternates per round. Settlement first player by point comparison. | 0.5 | 2-1, 2-2, 2-3, 2-4 | Complete round from deal to result: cards dealt from deck, player hits/stands via signal, AI decides, auto-sort, resolution runs, result determined. First player toggles between rounds. Settlement first player by point_total. |
| 2-6 | Minimal Table UI: card rendering (face up/down), HP bars (player+AI), chip counter, point total display, hit/stand buttons, phase indicator. 1920x1080 layout per table-ui.md. | 1.0 | 2-5 | Player sees their cards face-up, AI visible card + face-down cards. HP bars fill proportionally. Chip counter shows balance. Point total updates on hit. Hit/Stand buttons enabled in HIT_STAND phase, disabled otherwise. Phase indicator shows current phase. |

### Should Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 2-7 | Integration test: end-to-end round flow (deal -> hit/stand -> resolve -> result) | 0.3 | 2-5 | Automated test completes one full round with deterministic outcome |
| 2-8 | Smoke test: all 8 milestone success criteria validated | 0.3 | 2-6 | All 8 criteria from m1-first-playable-round.md pass |

### Nice to Have
| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-------------------|
| 2-9 | Card sorting UI: drag-to-reorder with settlement position numbers | 0.5 | 2-6 | Player can drag cards to reorder in SORT phase, position numbers update |

## Carryover from Previous Sprint
None — Sprint 1 complete with zero carryover.

> **Pre-Sprint Action Item**: Commit all Sprint 1 deliverables to git and verify CI passes before starting Sprint 2 implementation. (From Sprint 1 retrospective action item #1.)

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Resolution Engine MVP scope creep (stamps/quality creep in) | Medium | High | Strictly enforce "no stamps, no quality" — MVP pipeline has 4 phases, not 6 |
| Table UI takes longer than estimated (first UI work) | Medium | Medium | Start with bare-minimum controls; polish deferred to Sprint 3 / Polish stage |
| Round Management integration complexity (5+ system coordinator) | Medium | High | Implement in strict dependency order; test each subsystem independently before wiring |
| Sprint 1 code not committed before Sprint 2 starts | Medium | Medium | Commit Sprint 1 first (action item from retrospective) |

## Dependencies on External Factors
- Godot 4.6.2 editor available for UI work (story 2-6)
- GdUnit4 plugin for automated tests
- No external APIs or services

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (6/6)
- [ ] All tasks pass acceptance criteria
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (8/8 milestone criteria)
- [ ] QA plan exists for Sprint 2
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code committed to git (incremental, per-story)
- [ ] Design documents updated for any deviations from GDD MVP scope

## Milestone
- **Target**: Milestone 1 — First Playable Round (2026-05-17)
- **Sprint contribution**: Core layer + Presentation layer (Weeks 2-3 of 3). Sprint 2 completes Milestone 1 if all Must Have + Should Have stories are delivered.
