# Cross-GDD Review Report

Date: 2026-04-26
GDDs Reviewed: 16 system GDDs + game-concept + systems-index + entities registry
Systems Covered: Card Data Model, Point Calculation, Hand Type Detection, Stamp System, Card Quality, Resolution Engine, Card Sorting, Combat State, Special Plays, Side Pool, Chip Economy, Shop System, AI Opponent, Round Management, Match Progression, Table UI, Item System

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

None.

### Warnings (should resolve, but won't block)

**W1: `chip_value_base` not registered in entities.yaml as derived formula**
card-quality-system.md defines `chip_value_base` as "Clubs=chip_value, non-Clubs=0" in the `chip_output` formula. Used consistently across 6 GDDs (card-quality, resolution-engine, stamp-system, special-plays, chip-economy, item-system references). However, entities.yaml has no entry for `chip_value_base` as a standalone formula — it only appears as a variable within `chip_output`. This creates a traceability gap: if the "Clubs=chip_value, else=0" rule changes, there is no registry entry to flag affected GDDs.
Recommendation: Register `chip_value_base` as a derived formula in entities.yaml with source: card-quality-system.md.

**W2: `stamp_combat_bonus` vs `stamp_bonus_lookup` naming gap**
The stamp system's registered formula is `stamp_bonus_lookup` (returns bonus_value + effect_type). The resolution engine and card-quality system consume this as `stamp_combat_bonus`. Same value, different names at different abstraction layers. If stamp bonuses change, a grep for `stamp_bonus_lookup` would not find the consuming references under `stamp_combat_bonus`.
Recommendation: Add a note to `stamp_bonus_lookup` registry entry listing alias names used in consuming GDDs.

**W3: `insurance_hp_cost` (value 6) not registered in entities.yaml**
special-plays-system.md marks this as "pending registration". The chip-based `insurance_chip_cost` (value 30) is registered. Both cross system boundaries (special-plays -> combat-system, round-management).
Recommendation: Register `insurance_hp_cost` in entities.yaml.

**W4: `bust_damage_multiplier` not registered in entities.yaml**
combat-system.md owns this tuning knob (default 1.0). special-plays-system.md consumes it for doubledown bust calculation. Crosses two GDDs but absent from registry.
Recommendation: Register in entities.yaml with source: combat-system.md.

**W5: `second_player_chip_comp` (combat-system) vs `second_player_bonus` (chip-economy) naming alias**
Same constant (value 50), two different names across two GDDs. The registered name is `second_player_bonus`. Combat-system uses `second_player_chip_comp`.
Recommendation: Combat-system should reference the registered name, or registry should document the alias.

**W6: `total_opponents` has duplicate registry entries**
One deprecated (source: round-management), one active (source: match-progression). Same name, different status. Grep for `total_opponents` returns both, potentially confusing automated checks.
Recommendation: Rename deprecated entry to `total_opponents_deprecated` or add clear disambiguation note.

**W7: gem_destroy_prob example text stale at card-quality-system.md line 256**
Line 256 states "quality_level=I -> P_d=0.10 -> 10%" but the lookup table and registered formula define quality_level=I as 0.05 (5%). Line 242 correctly states II=0.10. The example on line 256 has a copy-paste error.
Recommendation: Fix line 256 to read "quality_level=I -> P_d=0.05 -> 5%".

**W8: `settlement_tie_compensation` (20 chips) unregistered**
round-management.md Formula 1b defines a 20-chip compensation for settlement-first-player coin flip ties. Not registered in entities.yaml. Crosses to chip-economy (add_chips call).
Recommendation: Register as constant in entities.yaml.

**W9: `sell_price` formula range mismatch between chip-economy and registry**
chip-economy.md AC-14 shows `buy_price` max = 800 (HAMMER 300 + DIAMOND I 200 + purify 300). Registry's `sell_refund` entry lists `total_investment` range as [0, 400]. Since `buy_price = total_investment`, the registry range should be [0, 800], not [0, 400].
Recommendation: Correct `sell_refund` variable range in registry to [0, 800].

**W10: match-progression GDD flags round-management Rules 8-10 as stale**
match-progression.md Dependencies section notes that round-management Rules 8 (opponent transitions), 9 (game end conditions), and 10 (game initialization) still contain old ownership language that should be updated to reflect match-progression's ownership of `opponent_number` and game-end determination. This is documented but unresolved.
Recommendation: Update round-management Rules 8-10 to use "match-progression owns X" language.

### Info

**I1: game-concept.md pending design questions now resolved**
Initial chips (100), initial HP (100), and opponent count (8) are now defined in their respective GDDs. Consider updating game-concept.md to note these are resolved.

**I2: Deprecated AI probability knobs still listed in card-data-model tuning table**
`ai_stamp_probability` and `ai_quality_probability` are marked deprecated but remain in the tuning knobs table. Should be moved to a deprecated section or removed.

**I3: Systems-index dependency map numbering inconsistencies**
System 6a appears as a sub-number. Items 13 and 14 are assigned differently across the enumeration table vs dependency map. Non-blocking formatting issue.

---

## Game Design Issues

### Blocking

None. The dominant strategy concern (W11 below) is significant but acknowledged in the GDDs and is a playtest-tuning issue, not a documentation defect.

### Warnings

**W11: Metal quality + FLUSH economic snowball (dominant strategy risk)**
The `chip_output` formula applies hand_type_multiplier to ALL chip contributions, including metal_chip_bonus. A DIAMOND I card (metal_chip_bonus=82) on any suit under FLUSH x5 produces 82 x 5 = 410 chips from the metal bonus alone -- regardless of suit. Combined with Clubs base value and COIN stamp, a single card can produce 835+ chips/round. The entire DIAMOND I investment (200 + 100 + 200 = 500 chips) is repaid in ~2 rounds of FLUSH resolution.

Key problem: metal quality has zero destruction risk, applies to any suit, and its bonus is multiplied by hand type. This creates a dominant "metal quality + FLUSH" strategy that trivializes the chip economy by mid-game. Shop prices are fixed (max single purchase: 300 for HAMMER), so inflation has no balancing force.

card-quality-system.md Open Questions already flags this: "metal chip bonus under FLUSH amplification may be too strong."

Recommendation: Playtest first. If confirmed, options include: (a) exempt metal_chip_bonus from hand_type_multiplier, (b) scale shop prices with opponent_number, or (c) cap metal chip contribution per card.

**W12: Sort phase cognitive overload -- 6 systems simultaneously active**
During the sort phase, players manage: card sorting (drag), stamp awareness (running shoes/turtle), item usage (up to 5), hand type display (locked multipliers), HP/defense monitoring, and a 30-second countdown timer. This is the highest cognitive load moment in the game.
Recommendation: Consider extending sort timer to 45s for early rounds (tutorial pacing), or gating item usage behind a later tutorial phase.

**W13: HP attrition spiral with no catch-up mechanism**
Player HP does not reset between opponents. Shop healing costs 5 chips/HP -- competing with deck building for the same budget. A player entering opponent 5 at 30 HP needs 350 chips just to heal to full, roughly equal to one HAMMER stamp + one DIAMOND quality assignment. There is no "mercy" mechanic for low-HP players.
Recommendation: Monitor in playtest. Consider a small HP floor after shop (e.g., minimum 10 HP if below) or a discounted "emergency heal" service.

**W14: Side pool system is a new-player trap**
7-Side Pool has 52% house edge. Casino War has 10.3% house edge. Both are negative-EV. The optimal strategy is to never use them. New players may treat them as valid income and drain their economy.
Recommendation: Add prominent UI warning about house edge, or gate side pools behind a tutorial that explains the odds.

**W15: Timer expiry during item selection -- undefined behavior**
Item system GDD specifies items are used during sort phase with ~3-5s per interaction. But no rule covers what happens if the timer expires while a player has selected an item but not confirmed the target. Is the item consumed? Is the selection cancelled?
Recommendation: Add explicit rule: "Timer expiry cancels any in-progress item selection without consuming the item."

### Info

**I4: Side pool pillar misalignment**
Optimal play ignores side pools entirely. They serve casino atmosphere, not strategic depth. This is intentional design tension, not a flaw.

**I5: Bust + gem quality perverse incentive**
Bust skips resolution Phases 1-6, including Phase 6 (gem destroy check). Therefore, gem quality cards are safest when the player busts. The bust penalty (self-damage + zero card effects) far outweighs this benefit, so it's not exploitable, but it's a non-obvious interaction.

**I6: AI insurance exploit**
AI always buys insurance at HP=7 (dropping to HP=1). Players can deliberately reveal an Ace to trigger this, creating a reliable "cheese" strategy. Noted in AI-opponent GDD Open Questions.

---

## Cross-System Scenario Issues

Scenarios walked: 3

### Blockers
None.

### Warnings

**W16: Sort phase timer + item usage race condition** -- Sort System + Item System + Round Management
Timer expires mid-item-selection (item chosen, target not confirmed). Item system has no rule for this state. Could result in item being consumed without effect (if target is None) or item being lost (if selection auto-confirms with wrong target).
Recommendation: Add explicit rule as described in W15.

**W17: FLUSH economy flywheel creates unbounded positive feedback** -- Card Quality + Chip Economy + Shop
Once a FLUSH + metal quality deck is established (typically opponent 3-4), chip income exceeds all possible expenditures. With chip_cap=999, overflow is wasted but the player has already purchased everything needed. The economic tension that drives interesting shop decisions evaporates.
Recommendation: Playtest to validate. Consider scaling shop prices or adding premium items.

### Info

**I7: Bust protects gem quality cards** -- Resolution Engine + Card Quality
Bust detection -> all Phases 1-6 skipped -> Phase 6 gem destroy check never fires -> gem cards are safe. Non-exploitable but non-obvious.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| card-quality-system.md | Line 256 gem_destroy_prob example says I=10% (should be 5%) | Consistency | Warning |
| combat-system.md | Uses `second_player_chip_comp` instead of registered `second_player_bonus` | Consistency | Warning |
| round-management.md | Rules 8-10 stale ownership language (match-progression owns opponent_number) | Consistency | Warning |

---

## Verdict: CONCERNS

No blocking issues found. All findings are warnings that should be addressed but do not prevent architecture work from beginning.

**Key concerns to track for playtest:**
1. Metal quality + FLUSH economic snowball (W11) -- most significant balance risk
2. Sort phase cognitive load (W12) -- UX pacing concern
3. Timer expiry during item use (W15/W16) -- undefined behavior that needs a rule

**Simple documentation fixes (can be done now):**
- Fix card-quality-system.md line 256 (W7)
- Register missing constants in entities.yaml (W3, W4, W8)
- Fix sell_refund range in registry (W9)
