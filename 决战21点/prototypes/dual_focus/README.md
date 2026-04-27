# Dual-Focus Prototype Validation

## Purpose

Validate Godot 4.6 dual-focus behavior (ADR-0008, HIGH knowledge risk).
Mouse hover and gamepad/keyboard focus are independent visual states.

## Setup

1. In Godot editor, create a new scene: `Control` root node
2. Attach script: `res://prototypes/dual_focus/dual_focus_test.gd`
3. Set as main scene → Play (F5)

## Test Checklist

| # | Action | Expected | Pass/Fail |
|---|--------|----------|-----------|
| 1 | Mouse hover over Card A | White glow border + "HOVER" label on Card A | |
| 2 | Move mouse away from Card A | Glow disappears, "HOVER" label gone | |
| 3 | Press Tab to keyboard-focus Card A | Yellow border + "FOCUS" label on Card A | |
| 4 | Press Tab again | Yellow border moves to Card B | |
| 5 | Mouse hover Card A + Tab-focus Card B | **Both** render: white glow on A, yellow border on B | |
| 6 | Click Card C with mouse | White glow only, NO yellow border | |
| 7 | Click Card C, immediately press Tab | Yellow border appears on next card (no stale state) | |
| 8 | Gamepad D-pad to focus Card D | Yellow border on Card D, mouse hover on previous card | |

## Pass Criteria

- Tests 5 and 6 are the critical ones for dual-focus validation
- Test 5: **Both visuals must coexist on different cards** — this is the 4.6 behavior
- Test 6: **Mouse click must NOT show yellow border** — hidden focus only

## If Tests Fail (Fallback)

If mouse clicks also show the yellow focus border (pre-4.6 behavior):
- The `grab_focus()` `hide_focus` parameter may not work as documented
- Fallback: always show focus ring when `has_focus()` returns true
- Accept less polished but functional behavior
- Document the deviation in ADR-0008

## Result

- [ ] PASS — Dual-focus works as documented in ADR-0008
- [ ] PARTIAL — Works with minor deviations (document below)
- [ ] FAIL — Requires fallback approach

**Notes:**
