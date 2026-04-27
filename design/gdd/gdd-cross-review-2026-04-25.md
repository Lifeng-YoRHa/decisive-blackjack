# Cross-GDD Review Report

**Date**: 2026-04-25
**GDDs Reviewed**: 16 system GDDs + game concept + systems index
**Systems Covered**: All 16 systems (MVP 9, Vertical Slice 4, Alpha 3)
**Review Mode**: full (consistency + design theory)

---

## Consistency Issues (Phase 2)

### Warnings (12)

**W-C1: Tuning Knob Ownership — `ai_max_hammers/stamps/qualities`**
card-data-model.md, stamp-system.md, card-quality-system.md
Three GDDs claim ownership of `ai_max_hammers`, `ai_max_stamps`, `ai_max_qualities`. Entity registry correctly assigns to card-data-model (Foundation layer). Stamp-system uses different names (`hammer_max_per_ai`, `stamps_max_per_ai`). Card-quality-system also lists `ai_max_qualities` as its own.
→ card-data-model is correct owner. Others should list as "consumed, owned by card-data-model."

**W-C2: `opponent_number` Authority Split**
round-management.md, match-progression.md
Round-management GDD is stale relative to match-progression. `opponent_number` and opponent transition logic split across two GDDs without clear delegation. Match-progression claims "sole authority" but round-management still defines opponent rules locally (Rules 8-10).
→ Transfer authority to match-progression; round-management Rules 8-10 need updating.

**W-C3: Side-Pool Sub-Phase Alignment**
side-pool.md, round-management.md
Side-pool defines sub-phases 2a/2b (betting) and 2c/2d (resolution). Round-management defines Phase 2 as monolithic "SIDE_POOL." Sub-phase ordering mismatch.
→ Round-management Phase 2 should reference side-pool's sub-phase structure.

**W-C4: game-concept Sell-Price Description Stale**
game-concept.md, shop-system.md, chip-economy.md
Game-concept says "Sell Card = 50% of buy price" where "buy price" is ambiguous. Actual implementation uses `total_investment` (enhancements only), not `base_buy_price`. Shop-system clarifies with `sell_refund` formula.
→ Update game-concept to match shop-system/chip-economy definition.

**W-C5: game-concept Settlement Order Outdated**
game-concept.md, resolution-engine.md
Game-concept describes batch-by-suit settlement (Hearts → Diamonds → Spades → Clubs → Clear defense). Resolution-engine implements alternating-per-card order (player pos1 → AI pos1 → player pos2 → ...).
→ Resolution-engine is authoritative. Update game-concept to reflect alternating model.

**W-C6: game-concept Shop Pricing Description Contradicts Shop-System**
game-concept.md, shop-system.md
Game-concept: "stamp/quality +50% extra" implies surcharge on enhancement. Shop-system: `RANDOM_DISCOUNT_RATIO = 0.50` applies a 50% DISCOUNT on enhancement price. Different results: concept says 65 + 100×1.50 = 215; shop says 65 + floor(100×0.50) = 115.
→ Update game-concept pricing description to match shop-system discount model.

**W-C7: SHIELD Stamp Multiplier Contradiction**
stamp-system.md (AC-04), resolution-engine.md
Stamp-system AC-04: "PAIR multiplier does NOT amplify defense value." Resolution-engine `stamp_effect_dispatch = stamp_combat_bonus × M` multiplies SHIELD stamp bonus by `per_card_multiplier`. If spade card has SHIELD + PAIR (M=2.0): resolution applies 2×2=4 defense from stamp, but stamp-system says multiplier should not amplify.
→ Resolve: either (a) multiplier should apply to shield (update stamp-system AC-04) or (b) shield should not be multiplied (fix resolution-engine formula).

**W-C8: `insurance_hp_cost` Missing from Entity Registry**
special-plays-system.md
Formula section says `insurance_hp_cost` value is 6 with status "to be registered." Entity registry constants section does NOT contain it. Referenced by multiple GDDs (special-plays, round-management, combat-system).
→ Add `insurance_hp_cost` to entity registry constants with value 6, source: special-plays-system.md.

**W-C9: `gem_destroy_prob` Knobs Duplicated**
card-data-model.md, card-quality-system.md
Card-data-model owns `gem_destroy_prob_iii/ii/i` tuning knobs. Card-quality-system lists same knobs with same defaults as its own.
→ Card-quality-system should list as "consumed, owned by card-data-model."

**W-C10: `settlement_animation_delay_ms` Name Collision**
resolution-engine.md, table-ui.md
Same knob name in two GDDs, same default (500ms). Resolution-engine defines logical delay; table-ui defines visual animation timing. Same name would collide in config loading.
→ Disambiguate: `logic_settle_delay_ms` (resolution-engine) vs `anim_settle_delay_ms` (table-ui).

**W-C11: chip-economy AC-12 Wrong Prices**
chip-economy.md
AC-12 uses `buy_price = 75` with breakdown "SHIELD 40 + RUBY III 35." Actual prices: SHIELD stamp = 100, RUBY quality = 120. Example calculation based on outdated pricing.
→ Fix AC-12 with correct prices: buy_price = 100 + 120 = 220, sell_price = floor(220 × 0.50) = 110.

**W-C12: Round-Management ACs Assume Direct `opponent_number` Management**
round-management.md, match-progression.md
AC-10 implies round-management directly manages `opponent_number` transitions. Match-progression claims sole authority. ACs need updating after authority transfer.
→ Update round-management ACs after opponent_number transfer to match-progression is complete.

### Info (10)

- **I-C1**: special-plays INS-6 implies AI has two insurance payment options; chip path is meaningless (AI has no chip economy). AI effectively only pays HP. Minor wording.
- **I-C2**: resolution-engine GDD lacks `skip_defense_reset` input parameter for split scenarios (referenced in round-management AC-06).
- **I-C3**: Deprecated tuning knobs in card-data-model still visible in table. Correct practice, no action needed.
- **I-C4**: `final_card_value` formula correctly deprecated in entity registry.
- **I-C5**: systems-index.md progress tracker shows 0 reviewed/approved (stale but not a design issue).
- **I-C6**: `counter_attack_damage` formula correctly deprecated in entity registry.
- **I-C7**: `shop_visits` constant (7) is derivable from `total_opponents - 1` and is redundant.
- **I-C8**: `chip_output` max (1837) always clamped to CHIP_CAP (999) at top end. Documented behavior.
- **I-C9**: Doubledown bust damage max (186) can exceed player HP (100). Intentional high-risk design.
- **I-C10**: AI insurance: chip payment path is no-op for AI (no chip tracking). Consistent but misleading.

---

## Game Design Issues (Phase 3)

### Blocking (3 — design-level, not architecture-blocking)

**B-D1: Metal Quality + Hand-Type Multiplier Chip Amplification**
card-quality-system.md, stamp-system.md, resolution-engine.md, chip-economy.md
Pure metal-quality Clubs flush with coin stamps produces ~2000+ chips/round with zero risk. `chip_output` formula includes `hand_type_multiplier`, making FLUSH ×5 amplify economy output. Example: Clubs A with Diamond-I + COIN stamp = (75 + 82 + 10) × 5 = 835 chips per card. A 5-card flush produces ~4175 chips (capped at 999). This makes economic builds strictly dominant — no other build path competes.
→ **Recommendation**: Remove `hand_type_multiplier` from `chip_output` formula. Hand-type multipliers should amplify combat effects only, not chip income. Alternative: cap metal chip bonus so it doesn't scale with multiplier.

**B-D2: Gem Quality Destruction Regression Loop**
card-quality-system.md, chip-economy.md, shop-system.md
With 5+ active gem quality cards, probability of at least one destruction per round is 76%+ (III level). Re-assignment costs 120 chips. Players investing in gem builds face progressive quality loss that outpaces their chip income from shop visits. By opponents 6-8, this creates a death spiral where quality destruction rate exceeds rebuilding capacity.
→ **Recommendation**: Add a "quality resilience" mechanism — e.g., temporary immunity after N destructions within same opponent, or reduce destruction rates per opponent progression (5/10/15% instead of 10/20/25%). Or add a cheaper shop service to restore destroyed quality (40 chips without level change).

**B-D3: Gem Quality Mathematically Suboptimal vs Metal**
card-quality-system.md, shop-system.md, chip-economy.md
Ruby-I costs 420 chips total (assign 120 + purify 100 + purify 200), adds +5 damage with 10% destroy risk per round. Diamond-I costs 40 chips, adds +82 chips/round with zero risk. Risk-adjusted return heavily favors metals. Gem combat bonuses (+3/+4/+5) are too small relative to metal chip bonuses (+10 to +82).
→ **Recommendation**: Either (a) increase gem combat bonuses significantly (+8/+12/+16), or (b) reduce gem destruction rates to 5/10/15%, or (c) allow gem qualities to also provide a small chip bonus (e.g., Ruby-I = +5 damage AND +10 chips).

### Warnings (7)

**W-D1: Cognitive Overload — 6 Concurrent Active Systems**
During battle phase: side-pool betting (3 decisions) + insurance (1) + split (1) + hit/stand (repeated) + hand-type selection (1) + card sorting (spatial). Threshold is 4; current design has 6. Side-pool is main culprit — 3 decisions with zero synergy to subsequent systems.
→ Keep side-pool as Alpha tier (correct). Default to skip after first playthrough. Consider moving to pre-battle screen.

**W-D2: RUNNING_SHOES + HAMMER First-Position Combo**
stamp-system.md, card-sorting-system.md, resolution-engine.md
RUNNING_SHOES guarantees position 1 (settles first); HAMMER nullifies opponent's position 1 card. Together: player always gets first strike AND neutralizes AI's strongest card. AI default sort is effect_value DESC, so position 1 is usually strongest.
→ Needs playtesting. Flagged as open question in resolution-engine. Only mitigate if win rate exceeds 65%.

**W-D3: FIVE_UNDER Low Total Point Abuse**
hand-type-detection.md
×5 multiplier triggers at 5+ cards with no `point_total` floor. [2,2,3,3,A] = total 11 gets same ×5 as a carefully-built near-21 hand. Combined with B-D1 (chip amplification), creates double-dominant strategy: pursue FIVE_UNDER for ×5 economic AND combat multiplier.
→ Needs playtesting. If dominant: reduce multiplier to ×4 or add minimum point_total threshold (≥15).

**W-D4: No Catch-Up Mechanism**
match-progression.md, chip-economy.md, combat-system.md
Bad luck in opponents 1-3 (bust streaks, gem destruction chains, side-pool losses) can leave player at low HP/low chips entering opponent 4. Victory bonus provides some catch-up but requires winning. No safety net for consecutive losses.
→ Consider "mercy" mechanism: HP recovery cost halved when HP < 20 entering shop.

**W-D5: AI HP Scaling Outpaces Player Damage**
combat-system.md, match-progression.md, ai-opponent.md
AI HP: [80,100,120,150,180,220,260,300] — accelerates at opponent 4+. Player damage per card: max ~22 (Diamond-A + SWORD + Ruby-I). Defeating opponent 7 (260 HP) requires 5-7 rounds. Player HP (100, never resets) can't sustain this without heavy shop healing investment.
→ Playtest opponents 6-8 win rates. If <40%, reduce late-game AI HP by 10-15% or add slight HP recovery between opponents.

**W-D6: `chip_cap` (999) Punishes Economic Builds**
chip-economy.md
Successful economic builds (500+ chips/round) hit cap in 2 rounds. All excess wasted. Cap exists for UI display but actively punishes the economic build path in late game.
→ Increase to 9999 or remove entirely. Shop prices are fixed; no balance need for cap.

**W-D7: AI Quality Level Distribution Unquantified**
ai-opponent.md
AI quality generation uses vague "mix of III/II/I" for opponents 4-8. Unlike `ai_hp_scaling` which is a precise lookup table, quality levels are not quantified. Makes late-game difficulty impossible to model precisely.
→ Define `ai_quality_level_table` as exact lookup table per opponent number.

### Info (4)

- **I-D1**: Side-pool system serves only "risk/reward" pillar, not "strategic depth" or "buildcraft." Purely optional content. MVP priority correctly sets it to Alpha.
- **I-D2**: Side-pool designed as negative-EV gambling — mathematically always wrong to bet. Positioned as emotional release, not strategic mechanic.
- **I-D3**: Combat-system player fantasy ("strategic commander") less defined than other systems — primarily a data container.
- **I-D4**: AI quality level scaling for opponents 4-8 not precisely specified — affects difficulty modeling.

---

## Cross-System Scenario Issues

### Scenarios Walked: 3

**Scenario 1: Normal Battle Round** (all MVP systems)
Side-pool bet → Insurance → Hit/Stand → Sort → Resolution → Death check → Victory bonus
→ ⚠️ Side-pool adds 3 decisions with zero synergy to subsequent systems. Cognitive load exceeds threshold.

**Scenario 2: Split Aces + Defense Accumulation**
Split → Hand A (hit/stand) → Hand B (hit/stand) → Sort both → Resolution pipeline with skip_defense_reset
→ ℹ️ `skip_defense_reset` parameter referenced in round-management but not documented in resolution-engine GDD.

**Scenario 3: Late-Game Clubs Flush Economy Build**
5-card Clubs flush + Diamond-I quality + COIN stamps → Chip output before cap
→ 🔴 Confirms B-D1: ~4175 chips produced (75% wasted at 999 cap). Build has zero risk, trivializes economy after opponent 4.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| card-quality-system.md | `chip_output` includes `hand_type_multiplier` (B-D1) | Design | Blocking |
| resolution-engine.md | SHIELD multiplier contradiction (W-C7); missing `skip_defense_reset` param (I-C2) | Consistency | Warning |
| stamp-system.md | AC-04 contradicts resolution-engine multiplier (W-C7) | Consistency | Warning |
| chip-economy.md | AC-12 wrong prices (W-C11); `chip_cap` too low (W-D6) | Consistency + Balance | Warning |
| game-concept.md | Stale settlement order (W-C5), sell-price (W-C4), shop pricing (W-C6) | Stale Reference | Warning |
| round-management.md | `opponent_number` authority transfer incomplete (W-C2, W-C12); Phase 2 alignment (W-C3) | Consistency | Warning |
| ai-opponent.md | Quality level distribution not quantified (W-D7) | Balance | Warning |

---

## Verdict: CONCERNS

No architecture-blocking issues. The 3 blocking design issues (B-D1, B-D2, B-D3) are formula/balance problems resolvable without changing data flow architecture. The 12 consistency warnings are documentation-level fixes.

**Design strength**: 16 complete GDDs with clean dependency graph, consistent formula naming, comprehensive acceptance criteria, and a well-defined entity registry (27 formulas, 33 constants). The cross-system issues found are at interaction boundaries — things that only emerge when seeing all systems together.

### If FAIL — required actions before re-running:
N/A (verdict is CONCERNS, not FAIL)
