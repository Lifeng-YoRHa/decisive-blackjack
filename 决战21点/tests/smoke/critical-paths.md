# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
<!-- Example: "Player can deal cards, hit/stand, and resolution runs correctly" -->
4. [Primary mechanic — update when first core system is implemented]

## Card Game Specific

5. 52-card deck deals correctly (no duplicates, correct suits/ranks)
6. Point calculation produces correct results for all hand sizes (1-11 cards)
7. Resolution engine runs full pipeline without crash on typical hands
8. Chip balance updates correctly after resolution

## Data Integrity

9. Save game completes without error (once save system is implemented)
10. Load game restores correct state (once load system is implemented)

## Performance

11. No visible frame rate drops on target hardware (60fps target)
12. No memory growth over 5 minutes of play (once core loop is implemented)
