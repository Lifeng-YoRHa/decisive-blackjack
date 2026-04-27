# Milestone 1: First Playable Round

> **Target Date**: 2026-05-17 (3 weeks from 2026-04-26)
> **Status**: In Progress
> **Scope**: Foundation + minimal Core layer

## Definition

One complete round of blackjack-style gameplay with card resolution, played against a static AI opponent. No shop, no items, no side pools, no match progression.

## Scope

### In Scope (MVP-core only)

| System | GDD | ADR | Deliverable |
|--------|-----|-----|-------------|
| Card Data Model | card-data-model.md | ADR-0002 | CardPrototype, CardInstance, Deck management |
| Point Calculation | point-calculation-engine.md | ADR-0011 | calculate_hand, Ace greedy algorithm, BUST_THRESHOLD |
| Combat State | combat-system.md | ADR-0001, ADR-0004 | Combatant structs, HP, defense, damage/heal API |
| Hand Type Detection | hand-type-detection.md | ADR-0011 | 7 hand types, multipliers, detection rules |
| Signal Architecture | — | ADR-0003 | Typed signal bus, settlement event queue |
| Minimal Table UI | table-ui.md | ADR-0008 | Card rendering, HP bar, chip counter, phase buttons |

### Explicitly Out of Scope

- Shop system, item system, side pool
- AI strategy (static opponent, random sort)
- Save/load (session-only)
- Card quality / stamp effects (basic resolution only)
- Match progression / opponent scaling
- Accessibility features beyond minimum
- Gamepad input (mouse-only for this milestone)

## Success Criteria

1. Player can be dealt 2 cards, see their point total
2. Player can Hit (draw a card) or Stand
3. Bust detection works (points > 21)
4. AI opponent plays with simple rules (hit below 17)
5. Round resolves with damage applied to both sides
6. HP bars update correctly
7. Chip counter updates correctly
8. At least 10 automated unit tests passing

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Dual-focus API issues (Godot 4.6) | Low | Medium | Mouse-only for this milestone; dual-focus prototype in Sprint 2 |
| GdUnit4 setup friction | Medium | Low | Example test already written; CI pipeline verified |
| Resolution pipeline complexity | Medium | High | Start with simplified pipeline (no stamps, no quality); expand in Sprint 2 |

## Sprint Plan (preliminary)

- **Week 1**: CardDataModel + PointCalculation + unit tests
- **Week 2**: CombatState + HandTypeDetection + SignalArchitecture + unit tests
- **Week 3**: Minimal Table UI + integration + smoke test
