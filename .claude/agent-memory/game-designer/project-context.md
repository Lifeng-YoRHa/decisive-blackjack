---
name: Project Context
description: Blackjack Showdown game concept, tech stack, and current design state
type: project
---

**Game**: 决胜21点 (Blackjack Showdown) - Strategy card game / Roguelike deck builder
**Engine**: Godot 4.6.2, GDScript
**Platform**: PC (Steam/Epic)
**Target**: Single player vs 8 AI opponents
**Session length**: 20-40 minutes
**Reference**: Balatro

**Key mechanics**: 4-suit combat (Hearts=heal, Diamonds=damage, Spades=defense, Clubs=chips), hand type multipliers (PAIR x2 through BLACKJACK x6/SPADE_BLACKJACK instant win), 7 stamp types, 8 quality types (4 metal chip-only + 4 gem combat + destroy risk), shop between opponents

**Player**: max_hp=100 fixed. AI HP scales [80,100,120,150,180,220,260,300]. Player chips persist across all 8 opponents (start 100, cap 999).

**AI constraints**: No chips. Insurance costs 6 HP. Always splits. Doubles at {10,11}. Always buys insurance vs player Ace. AI deck: 52 cards, random stamp/quality, max 3 hammers, max 30 stamps, max 30 qualities.

**Design state (2026-04-24)**: 10 of 16 systems designed. AI Opponent system is next (skeleton only). Combat, Resolution, Special Plays, Chip Economy, Hand Detection, Card Data Model, Stamps, Qualities, Sorting all designed.

**Why**: This context informs all balance and design decisions for the AI opponent system.

**How to apply**: When designing AI difficulty scaling, consider the full combat pipeline (6-phase resolution), the split mechanic (2 sub-pipelines sharing HP pool), and the economy constraints (AI has no chips so metal qualities are wasted).
