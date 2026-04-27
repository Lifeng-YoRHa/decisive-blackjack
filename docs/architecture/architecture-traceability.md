# Architecture Traceability Index
Last Updated: 2026-04-26
Engine: Godot 4.6.2

## Coverage Summary
- Total active requirements: 113
- Covered: 105 (92%)
- Partial: 9 (8%)
- Gaps: 0 (0%)
- Deprecated: 1 (TR-chip-005 — second_player_bonus deleted)

## Full Matrix

| TR-ID | System | Requirement | ADR Coverage | Status |
|-------|--------|-------------|--------------|--------|
| TR-cdm-001 | card-data-model | CardPrototype RefCounted with suit, rank, bj_values | ADR-0002 | Covered |
| TR-cdm-002 | card-data-model | CardInstance RefCounted with prototype, owner, stamp, quality | ADR-0002 | Covered |
| TR-cdm-003 | card-data-model | attribute_changed signal | ADR-0002, ADR-0003 | Covered |
| TR-cdm-004 | card-data-model | is_valid_assignment gem-suit binding | ADR-0002 | Covered |
| TR-cdm-005 | card-data-model | to_dict/from_dict serialization | ADR-0002, ADR-0005 | Covered |
| TR-cdm-006 | card-data-model | 52-card invariant per owner | ADR-0002 | Covered |
| TR-cdm-007 | card-data-model | destroy_quality() method | ADR-0002 | Covered |
| TR-cdm-008 | card-data-model | Lookup tables as const dictionaries | ADR-0002 | Covered |
| TR-cdm-009 | card-data-model | Deck management with reshuffle | ADR-0002 | Covered |
| TR-cdm-010 | card-data-model | 104 instances indexed by (owner, suit, rank) | ADR-0002 | Covered |
| TR-pce-001 | point-calculation | calculate_hand pure function → PointResult | ADR-0011 | Covered |
| TR-pce-002 | point-calculation | simulate_hit O(1) incremental | ADR-0011 | Covered |
| TR-pce-003 | point-calculation | Ace greedy algorithm | ADR-0011 | Covered |
| TR-pce-004 | point-calculation | BUST_THRESHOLD=21 | ADR-0011 | Covered |
| TR-htd-001 | hand-type-detection | 7 hand types with detection rules | ADR-0011 | Covered |
| TR-htd-002 | hand-type-detection | per_card_multiplier calculation | ADR-0011 | Covered |
| TR-htd-003 | hand-type-detection | ai_hand_type_score evaluation | ADR-0011 | Covered |
| TR-htd-004 | hand-type-detection | Detection timing (after point calc, before settlement) | ADR-0011, ADR-0004 | Covered |
| TR-stamp-001 | stamp-system | 7 stamp types with stamp_bonus_lookup | ADR-0002, ADR-0004 | Covered |
| TR-stamp-002 | stamp-system | stamp_sort_key ordering | ADR-0004, ADR-0008 | Covered |
| TR-stamp-003 | stamp-system | HAMMER pre-scan mechanism | ADR-0004 | Covered |
| TR-stamp-004 | stamp-system | Stamps on CardInstance, persistent across rounds | ADR-0002 | Covered |
| TR-cqs-001 | card-quality | 8 quality types, 3 purity levels, gem-suit binding | ADR-0002 | Covered |
| TR-cqs-002 | card-quality | Dual-track settlement formula | ADR-0004 | Covered |
| TR-cqs-003 | card-quality | Gem destroy check per settlement | ADR-0004 | Covered |
| TR-cqs-004 | card-quality | quality_bonus_resolve lookup table | ADR-0002 | Covered |
| TR-cqs-005 | card-quality | Suit restriction enforcement | ADR-0002 | Covered |
| TR-sort-001 | card-sorting | Two-pass sorting algorithm | ADR-0008 (UI), ADR-0004 (pipeline) | Partial |
| TR-sort-002 | card-sorting | 1-based position assignment | ADR-0004 | Partial |
| TR-sort-003 | card-sorting | AI tiebreak_function interface | ADR-0006 | Covered |
| TR-sort-004 | card-sorting | Sort timer 30s with auto-confirm | ADR-0008 | Covered |
| TR-sort-005 | card-sorting | Card locking for padlock item | ADR-0008 (UI only) | Partial |
| TR-combat-001 | combat-system | Combatant structs with hp, max_hp, defense | ADR-0001, ADR-0004 | Covered |
| TR-combat-002 | combat-system | API: apply_damage, apply_heal, add_defense, etc. | ADR-0003, ADR-0004 | Covered |
| TR-combat-003 | combat-system | Defense bypass for bust damage | ADR-0004 | Covered |
| TR-combat-004 | combat-system | queue_defense FIFO | ADR-0004 | Covered |
| TR-combat-005 | combat-system | reset_defense at Phase 7a | ADR-0004 | Covered |
| TR-combat-006 | combat-system | AI HP scaling by opponent_number | ADR-0001, ADR-0010 | Covered |
| TR-combat-007 | combat-system | Death check after defense reset | ADR-0004 | Covered |
| TR-combat-008 | combat-system | pending_defense FIFO before first card | ADR-0004 | Covered |
| TR-res-001 | resolution-engine | 7-phase settlement pipeline | ADR-0004 | Covered |
| TR-res-002 | resolution-engine | Track separation (suit + stamp independent) | ADR-0004 | Covered |
| TR-res-003 | resolution-engine | Alternating settlement order | ADR-0004 | Covered |
| TR-res-004 | resolution-engine | Pre-computed SettlementEvent queue | ADR-0003, ADR-0004 | Covered |
| TR-res-005 | resolution-engine | Seeded RNG for gem destroy | ADR-0004 | Covered |
| TR-res-006 | resolution-engine | Split support with shared HP | ADR-0004 | Covered |
| TR-res-007 | resolution-engine | Synchronous single-frame execution | ADR-0004 | Covered |
| TR-res-008 | resolution-engine | Bust handling (skip phases 2-6) | ADR-0004 | Covered |
| TR-res-009 | resolution-engine | HAMMER pre-scan before main loop | ADR-0004 | Covered |
| TR-res-010 | resolution-engine | Doubledown ×2 on base values only | ADR-0004 | Covered |
| TR-sp-001 | special-plays | Double down mechanics | ADR-0004, ADR-0010 | Covered |
| TR-sp-002 | special-plays | Split mechanics with shared HP | ADR-0004, ADR-0010 | Covered |
| TR-sp-003 | special-plays | Insurance chip/HP payment | ADR-0004, ADR-0010 | Covered |
| TR-sp-004 | special-plays | Condition checks (split, DD, insurance) | ADR-0004, ADR-0010 | Covered |
| TR-sp-005 | special-plays | Insurance dual payment paths | ADR-0004 | Covered |
| TR-sp-006 | special-plays | Split sub-hands with independent HIT_STAND | ADR-0004 | Covered |
| TR-chip-001 | chip-economy | Balance range [0, 999] with CHIP_CAP | ADR-0010 | Covered |
| TR-chip-002 | chip-economy | API: add/spend/can_afford/get_balance | ADR-0010 | Covered |
| TR-chip-003 | chip-economy | Transaction logging with categories | ADR-0010 | Covered |
| TR-chip-004 | chip-economy | 6 income sources, 3 spend categories | ADR-0010 | Covered |
| ~~TR-chip-005~~ | ~~chip-economy~~ | ~~second_player_bonus=50~~ (DELETED) | N/A | Deprecated |
| TR-chip-006 | chip-economy | victory_bonus formula | ADR-0010 | Covered |
| TR-chip-007 | chip-economy | Atomic spend-before-mutate | ADR-0007, ADR-0010 | Covered |
| TR-spool-001 | side-pool | 7-Side Pool count/payout | ADR-0009 | Covered |
| TR-spool-002 | side-pool | Casino War rank comparison | ADR-0009 | Covered |
| TR-spool-003 | side-pool | Bet tiers 10/20/50 | ADR-0009 | Covered |
| TR-spool-004 | side-pool | Settlement timing in round pipeline | ADR-0009, ADR-0010 | Covered |
| TR-shop-001 | shop-system | Fixed services + random inventory | ADR-0007 | Covered |
| TR-shop-002 | shop-system | Weighted random selection algorithm | ADR-0007 | Covered |
| TR-shop-003 | shop-system | Sell/refund formula | ADR-0007 | Covered |
| TR-shop-004 | shop-system | Refresh mechanism | ADR-0007 | Covered |
| TR-shop-005 | shop-system | Atomic spend-before-mutate | ADR-0007 | Covered |
| TR-shop-006 | shop-system | Pricing tables | ADR-0007 | Covered |
| TR-shop-007 | shop-system | Quality assignment and purification | ADR-0007 | Covered |
| TR-shop-008 | shop-system | Item purchases with inventory cap | ADR-0007 | Covered |
| TR-ai-001 | ai-opponent | 3 decision tiers with lookup tables | ADR-0006 | Covered |
| TR-ai-002 | ai-opponent | generate_deck with constraints | ADR-0006 | Covered |
| TR-ai-003 | ai-opponent | hand_type_score evaluation | ADR-0006, ADR-0011 | Covered |
| TR-ai-004 | ai-opponent | Sort strategies (RANDOM/DEFAULT/TACTICAL) | ADR-0006 | Covered |
| TR-ai-005 | ai-opponent | calculate_bust_probability | ADR-0006, ADR-0011 | Covered |
| TR-ai-006 | ai-opponent | Const lookup tables by opponent_number | ADR-0006 | Covered |
| TR-rm-001 | round-management | 8-phase round pipeline | ADR-0010 | Covered |
| TR-rm-002 | round-management | first_player alternation | ADR-0010 | Covered |
| TR-rm-003 | round-management | settlement_first_player determination | ADR-0010 | Covered |
| TR-rm-004 | round-management | Split sub-pipeline | ADR-0004, ADR-0010 | Covered |
| TR-rm-005 | round-management | Phase transition signals | ADR-0003, ADR-0010 | Covered |
| TR-rm-006 | round-management | Opponent transition flow | ADR-0010 | Covered |
| TR-mp-001 | match-progression | 5-state FSM | ADR-0010 | Covered |
| TR-mp-002 | match-progression | opponent_number ownership | ADR-0010 | Covered |
| TR-mp-003 | match-progression | Shop gating | ADR-0010 | Covered |
| TR-mp-004 | match-progression | Initialization sequence | ADR-0001, ADR-0010 | Covered |
| TR-mp-005 | match-progression | Auto-save triggers | ADR-0005 | Covered |
| TR-item-001 | item-system | 7 item types, 3 timing categories | ADR-0007 (purchase), ADR-0004 (effects) | Partial |
| TR-item-002 | item-system | Inventory management (max 5) | ADR-0007 (purchase), ADR-0005 (save) | Covered |
| TR-item-003 | item-system | Sort-phase-only usage restriction | ADR-0010 (SORT phase) | Partial |
| TR-item-004 | item-system | Cross-system calls (heal, damage, defense, etc.) | ADR-0004, ADR-0001 | Covered |
| TR-item-005 | item-system | Padlock card locking game logic | ADR-0008 (UI) | Partial |
| TR-ui-001 | table-ui | 5 permanent screen regions at 1920×1080 | ADR-0008 | Covered |
| TR-ui-002 | table-ui | CardView renders card attributes | ADR-0008 | Covered |
| TR-ui-003 | table-ui | Card spacing algorithm | ADR-0008 | Covered |
| TR-ui-004 | table-ui | Settlement animation from event queue | ADR-0003, ADR-0004, ADR-0008 | Covered |
| TR-ui-005 | table-ui | Phase-driven button enable/disable | ADR-0008 | Covered |
| TR-ui-006 | table-ui | Sort timer countdown | ADR-0008 | Covered |
| TR-ui-007 | table-ui | Drag-and-drop card sorting | ADR-0008 | Covered |
| TR-ui-008 | table-ui | Split-hand layout | ADR-0008 | Covered |
| TR-ui-009 | table-ui | Shop overlay | ADR-0008 | Covered |
| TR-ui-010 | table-ui | Dual-focus (mouse + gamepad) | ADR-0008 | Covered |
| TR-ui-011 | table-ui | AI card flip animation | ADR-0008 | Covered |
| TR-ui-012 | table-ui | Chip counter rolling animation | ADR-0008 | Covered |
| TR-ui-013 | table-ui | HP bar color thresholds | ADR-0008 | Covered |
| TR-ui-014 | table-ui | Draw calls <100 via texture atlas | ADR-0008 | Covered |
| TR-ui-015 | table-ui | Item bar in SORT phase | ADR-0008 (general) | Partial |
| TR-ui-016 | table-ui | Side pool UI | ADR-0009 | Covered |
| TR-ui-017 | table-ui | Accessibility features | ADR-0008 (dual-focus) | Partial |

## Known Gaps (all Partial — no gaps)

| TR-ID | Why Partial | Recommended Action |
|-------|-------------|-------------------|
| TR-sort-001 | No dedicated sorting ADR | Low risk — algorithm is simple stable sort; covered by GDD |
| TR-sort-002 | Position assignment is implementation detail | Low risk — covered by pipeline contract in ADR-0004 |
| TR-sort-005 | Padlock locking logic not ADR-covered | Optional ADR-0012 (Item System) would resolve |
| TR-item-001 | No ItemInstance class ADR | Optional ADR-0012 (Item System) would resolve |
| TR-item-003 | Sort-phase timing restriction not ADR-covered | Optional ADR-0012 (Item System) would resolve |
| TR-item-005 | Padlock game logic not ADR-covered | Optional ADR-0012 (Item System) would resolve |
| TR-ui-015 | Item bar UI not spec'd | Optional UX spec would resolve |
| TR-ui-017 | Accessibility implementation not ADR-covered | accessibility-requirements.md created; implementation ADR optional |

## Superseded Requirements

| TR-ID | Reason | Replacement |
|-------|--------|-------------|
| TR-chip-005 | second_player_bonus deleted per design override | SETTLEMENT_TIE_COMP=20 in ADR-0010 |

## History

| Date | Coverage | Notes |
|------|----------|-------|
| 2026-04-26 | 105/113 (92%) | Initial traceability index from Architecture Review #2 |
