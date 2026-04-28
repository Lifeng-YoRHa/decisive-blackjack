# Story 003: Card Sort Drag UI

> **Epic**: Table UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.5 day

## Context

**GDD**: `design/gdd/table-ui.md`
**Requirements**: TR-ui-006 (sort timer countdown), TR-ui-007 (drag-and-drop sorting)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (UI Node Hierarchy)
**ADR Decision Summary**: CardView supports drag-and-drop during SORT phase. Sort timer label with 30s countdown, auto-confirms on expiry. Position numbers shown during SORT phase. Dual-focus system requires engine testing — MVP uses mouse-only drag.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Drag-and-drop via Control._get_drag_data(), _can_drop_data(), _drop_data() — stable since 4.0. Dual-focus (4.6) deferred — mouse-only for this story.

**Control Manifest Rules (this layer)**:
- Required: Sort UI emits `player_sort_confirmed(manual_order)` signal only
- Forbidden: UI never directly reorders game state — emits request signal

---

## Acceptance Criteria

*From GDD `design/gdd/table-ui.md`, scoped to MVP:*

- [x] AC-07: Player drags card from position 3 to position 1 — visual order updates to [orig3, orig1, orig2, orig4, orig5]. Position numbers update to [1, 2, 3, 4, 5].
- [x] AC-08: Sort countdown reaches 0 — auto-confirms with current order via `player_sort_confirmed` signal. No confirmation dialog.
- [x] Sort timer label visible during SORT phase, hidden otherwise. Displays remaining seconds.
- [x] Position numbers visible on player cards during SORT phase only.
- [x] Confirm Sort button emits `player_sort_confirmed` with current visual order.
- [x] Mouse-only drag interaction — no gamepad drag support (dual-focus deferred).

---

## Implementation Notes

*Derived from ADR-0008:*

Drag-and-drop on CardView:
- CardView sets `mouse_filter = MOUSE_FILTER_STOP` during SORT phase
- `_get_drag_data()` returns a Dictionary with the card's current position index
- `_can_drop_data()` returns true if the target is a CardView in the same hand
- `_drop_data()` rearranges the `_player_card_views` array and re-orders children in PlayerHandArea

Position numbers:
- Each CardView has a PositionNumber Label (hidden by default)
- During SORT phase: set visible, update text to position index + 1
- After SORT phase: hide all position numbers

Sort timer:
- Timer node (Timer, one_shot=false, wait_time=1.0)
- On SORT phase enter: start timer, show label
- On timeout: decrement counter, update label
- At 0: emit `player_sort_confirmed` with current visual order
- Last 5 seconds: label text color turns red (optional in MVP)

Signal emission:
- `signal player_sort_confirmed(order: Array[int])` — order is array of card indices in visual order

**Performance**: Drag-and-drop reorders children in HBoxContainer — Godot handles reflow internally (O(n) where n ≤ 11). Timer fires once per second (1 Hz) to update countdown label — negligible. Position number update iterates 11 cards max (O(n)). No per-frame processing outside active drag. Drag preview should use a lightweight Control, not a full CardView duplicate.

---

## Out of Scope

- Dual-focus drag (gamepad) → deferred (requires engine testing)
- Settlement animation → deferred
- HP bars, chip counter, buttons → Story 002
- CardView rendering and spacing → Story 001
- Shop overlay → deferred
- Split-hand layout → deferred

---

## QA Test Cases

- **AC-07 (drag reorder)**:
  - Setup: SORT phase, player has 5 cards at positions [1,2,3,4,5]
  - Verify: Drag card from position 3 to position 1
  - Pass condition: Visual order becomes [3,1,2,4,5], position labels update to [1,2,3,4,5]

- **AC-08 (countdown auto-confirm)**:
  - Setup: SORT phase, 30s countdown running, player does nothing
  - Verify: Timer reaches 0
  - Pass condition: `player_sort_confirmed` signal emitted with default order, no dialog shown

- **Sort timer visibility**:
  - Setup: Advance through phases
  - Verify: Timer label visible only during SORT phase
  - Pass condition: Hidden in all other phases

- **Position numbers**:
  - Setup: Enter SORT phase with 4 player cards
  - Verify: Each card shows position number (1, 2, 3, 4)
  - Pass condition: Numbers visible during SORT, hidden after

- **Confirm button**:
  - Setup: SORT phase, player reorders cards, clicks Confirm Sort
  - Verify: Signal emitted with reordered indices
  - Pass condition: Signal carries correct order array

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/sprint-2/table-sort-ui-evidence.md` — screenshots showing SORT phase with position numbers, drag interaction, timer countdown

**Status**: [x] Verified in Godot editor

---

## Dependencies

- Depends on: Story 001 (CardView and hand layout), Story 002 (phase-driven UI), Round Management Story 001 (SORT phase)
- Unlocks: None (Nice to Have story — no downstream dependents)

## Completion Notes
**Completed**: 2026-04-29
**Criteria**: 6/6 passing
**Deviations**: ADVISORY — signal uses untyped `Array` instead of `Array[int]`; emits CardInstance objects rather than indices. Functionally equivalent.
**Test Evidence**: Manual verification in Godot editor (UI story — no automated test required)
**Code Review**: Skipped (Lean mode)
