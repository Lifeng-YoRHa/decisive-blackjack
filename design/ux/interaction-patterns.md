# UX Interaction Pattern Library — 《决胜21点》(Decisive 21)

> **Status**: Approved
> **Last Updated**: 2026-04-26

## Overview

This document defines the reusable interaction patterns that form the UX vocabulary of Decisive 21. Every player-facing interaction in the game should be expressible as an instance of one of these patterns. Consistency of patterns reduces cognitive load: once a player learns how one card behaves, they know how all cards behave.

Each pattern is defined with its trigger conditions, feedback channels, state machine, and accessibility accommodations. Implementation should reference ADR-0008 for node hierarchy and Godot 4.6 dual-focus specifics.

---

## 1. Pattern Catalog

### PATTERN-01: Card Hover Inspection

**Description**: Hover (mouse) or focus (keyboard/gamepad) a card to preview details. Used whenever cards are visible: player hand, AI hand (face-up only), shop cards, deck viewer. Must feel instant and weightless.

**Trigger**: Mouse `mouse_entered` / Keyboard Tab / Gamepad D-pad or left stick

**Feedback**:
- Visual: Card lifts 20px. Suit-colored inner glow (white 30% alpha). Gamepad focus renders yellow border 2px. Mouse hover and gamepad focus are independent visual layers.
- Audio: Soft tactile "tick" on focus change.
- Haptic: Subtle vibration on gamepad focus change (0.05s, low intensity).

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Default | Card at rest, no glow | Unselected, no focus |
| Hover (mouse) | Lift 20px, white inner glow 3px | Only one card hovered at a time |
| Focus (KB/GP) | Lift 20px, yellow border 2px | Independent of hover |
| Disabled | Dimmed (alpha 0.5), no lift | Resolution phase, AI face-down |
| Inspected | Detail tooltip appears beside card | Click or Enter opens full detail |

**Accessibility**: Full Tab navigation with visible focus ring. Click-to-inspect alternative. Screen reader announces card rank, suit, stamp, quality on focus via AccessKit.

### PATTERN-02: Phase Action Button

**Description**: Context-sensitive action button enabling/disabling based on current round phase. Used for Hit, Stand, Double Down, Split, Insurance, Sort Confirm.

**Trigger**: Mouse click / Enter or Space / Gamepad A-button

**Feedback**: Amber Glow fill (#D4A855) enabled, darkened 50% when disabled. 10px rounded corners. Hover: brighten + 1.05x scale. Active: 0.95x scale + darken.

**States**: Hidden → Disabled → Default (enabled) → Hover → Active → Just-used (brief green flash 0.2s)

**Accessibility**: Tab navigation between visible enabled buttons. Disabled buttons are focusable with "unavailable" screen reader announcement. Button text minimum 16px. Key binding hint below label.

### PATTERN-03: Timed Phase Overlay

**Description**: Countdown timer for Sort Phase (30s default, adjustable 15-60s or unlimited). Creates productive urgency without panic. Timeout auto-confirms gracefully.

**Trigger**: `phase_changed(SORT)` signal

**Feedback**: Timer label top-right, 32px. White (>10s) → yellow (5-10s) → red pulse (<5s). Subtle tick each second <10s, accelerating <5s.

**States**: Active (>10s) → Warning (5-10s) → Critical (<5s, pulse) → Paused → Completed (auto-confirm) → Unlimited (no countdown, manual confirm)

**Accessibility**: Timer adjustable in settings (15/20/30/45/60s/unlimited). Audio cues provide redundant urgency info. Unlimited mode removes all timer pressure.

### PATTERN-04: Drag-and-Drop Reorder

**Description**: Reorder items by dragging. Used for Sort Phase card reordering. Most complex motor interaction — must offer click-to-swap alternative.

**Trigger**: Click+hold (mouse) / Enter to select + arrows to move (keyboard) / A to select + D-pad (gamepad)

**Feedback**: Dragged card follows cursor at 1.1x scale with drop shadow. Original position shows ghost outline. Other cards animate to make room (0.15s). Position numbers update in real-time.

**States**: Idle → Selected (click mode, amber border) → Dragging → Dropping (snap 0.15s) → Locked (unresponsive)

**Accessibility**: Click-to-swap alternative (click A, click destination). Full keyboard flow (Enter/Arrows/Enter). Full undo (Ctrl+Z) within sort phase. Drag deadzone adjustable (0-20px).

### PATTERN-05: Chip Placement / Side Pool Bet

**Description**: Place chips into betting zone before dealing. "Select amount, then confirm" flow prevents accidental bets.

**Trigger**: Click bet zone / Tab+Enter / Gamepad D-pad+A

**Feedback**: Bet zone highlights on hover. Amount selector (10/20/50 tokens). Chip stack grows in zone. Invalid bet: denomination shakes and dims.

**States**: Closed → Selector Open → Amount Selected → Bet Placed (locked) → Skipped

**Accessibility**: Full keyboard flow without mouse. Two-click confirmation prevents accidents. Denominations show number labels.

### PATTERN-06: Shop Transaction

**Description**: Multi-step purchase flow: browse → select target → confirm. Atomic transaction model with clear price/balance feedback at every step.

**Trigger**: Click shop item / Tab+Enter / Gamepad D-pad+A

**Feedback**: Item highlights on selection. Target selection: deck grid appears, valid targets glow. Chip balance prominent at top. Confirm shows deduction preview. Success: gold flash 0.3s. Failure: item shakes, price flashes red.

**States**: Browse → Item Selected → Target Selected → Confirming → Failed → Sold

**Accessibility**: Full keyboard navigation. Each step is discrete with clear undo (Escape/B backs out without penalty). Screen reader announces item name, price, affordability.

### PATTERN-07: Floating Status Notification

**Description**: Transient text/numbers for state changes without interrupting gameplay. Damage, healing, defense, chip gains, stamp effects, quality destruction.

**Trigger**: Automatic from settlement event queue and state change signals.

**Feedback**: Text floats upward 40px over 0.8s, fading. Scale 1.2x → 1.0x. Damage=red "-", Healing=green "+", Defense=blue "+shield", Chips=gold "+", Stamp=orange+icon, Destroyed=purple "DESTROYED".

**Accessibility**: Each type has unique icon prefix AND text label, not only color. Reduced motion: text appears at position for 1.0s without floating. Font minimum 18px bold with 2px dark outline. Combat log (L key) shows last 5s of notifications.

### PATTERN-08: Screen Transition

**Description**: Animated transitions between screens. Card table is "home base" — all transitions depart from or return to it.

**Trigger**: Automatic from game state changes.

**Feedback**: Cross-fade with slide. Forward (Table→Shop, Table→Victory) slides right. Backward slides left. 0.4s ease-in-out.

**States**: Stable → Transitioning out (input blocked) → Transitioning in (input blocked) → Stable (new screen)

**Accessibility**: Reduced motion: simple cross-fade 0.3s, no slide. Loading text if >0.2s load time.

---

## 2. Input Mapping

### Keyboard / Mouse (Primary)

| Action | Binding | Context |
|--------|---------|---------|
| Navigate cards | Tab / Shift+Tab | Card Table, Shop |
| Navigate buttons | Tab / Shift+Tab | Action bar, Shop |
| Activate/Confirm | Enter or Space | All screens |
| Cancel/Back | Escape | All screens |
| Hit | H | HIT_STAND phase |
| Stand | S | HIT_STAND phase |
| Double Down | D | HIT_STAND phase |
| Split | P | SPLIT_CHECK phase |
| Insurance (chip) | I | INSURANCE phase |
| Insurance (HP) | J | INSURANCE phase |
| Skip/Decline | N | INSURANCE/SPLIT |
| Sort confirm | Enter | SORT phase |
| Select card (click mode) | Enter | SORT phase |
| Move selected card | Left/Right Arrow | SORT phase |
| Undo sort | Ctrl+Z | SORT phase |
| Inspect card detail | F or Right-click | All card views |
| Toggle combat log | L | Card Table |
| Pause/Settings | Escape | Card Table |
| Shop: Confirm purchase | Enter | Shop |
| Shop: Sell card | Delete or X | Shop deck viewer |
| Shop: Refresh | R | Shop |
| Deck viewer | V | Shop, Card Table |

### Gamepad (Secondary)

| Action | Binding | Context |
|--------|---------|---------|
| Navigate focus | D-pad / Left Stick | All screens |
| Activate/Confirm | A (South) | All screens |
| Cancel/Back | B (East) | All screens |
| Inspect card detail | Y (North) | Card views |
| Switch hand areas | LB / RB | Split hands |
| Sort: Select/Confirm | A / Start | SORT phase |
| Sort: Move position | D-pad Left/Right | SORT phase |
| Sort: Undo | Select (Back) | SORT phase |
| Toggle combat log | Select (Back) | Card Table (non-sort) |
| Pause | Start | Card Table (non-sort) |
| Shop: Switch panel | LB / RB | Shop |
| Shop: Refresh | Y (North) | Shop |
| Deck viewer | X (West) | Shop, Card Table |

All bindings remappable via Settings > Controls using Godot `InputMap`. Persisted to save file.

---

## 3. Feedback Levels

### Micro (Immediate, Single Element) — 0 to 0.3s

| Event | Visual | Audio | Haptic |
|-------|--------|-------|--------|
| Button hover | Brighten, 1.05x scale | — | — |
| Button press | Darken, 0.95x scale | Soft click | 0.1s pulse |
| Card hover | Lift 20px, inner glow | Soft tick | 0.05s pulse |
| Card pick up | 1.1x scale, shadow | card_lift.wav | 0.1s pulse |
| Card drop | Snap to slot | card_place.wav | 0.1s pulse |
| Disabled button press | Shake 5px | button_disabled.wav | — |

### Meso (Multi-Element, Animated) — 0.3s to 1.5s

| Event | Visual | Audio | Haptic |
|-------|--------|-------|--------|
| Card dealt | Slide from deck, 0.4s | card_deal.wav | 0.1s/card |
| AI card flip | Scale X 1→0→1, 0.4s | card_flip.wav | — |
| HP changed | Bar fill animates + floating number | hit/heal.wav | Damage: 0.2s / Heal: 0.1s |
| Chip balance changed | Counter rolls, 0.5s | coin.wav | 0.15s double-tap |
| Sort timer tick (<5s) | Text pulses red, 1.1x | timer_tick.wav | 0.05s pulse |
| Stamp effect triggers | Icon glows, floating text | stamp_[type].wav | 0.15s pulse |
| Quality destroyed | Border shatters, 0.5s | quality_destroy.wav | 0.3s strong |
| Card bust | Shake + red flash | bust.wav | 0.3s strong |

### Macro (Screen-Level, Emotional) — 1.0s to 3.0s

| Event | Visual | Audio | Haptic |
|-------|--------|-------|--------|
| Round victory | Opponent HP drains, gold "+CHIPS", 1.5s delay to shop | victory_fanfare.wav | 0.5s escalating |
| Round defeat | Player HP drains, screen dims 50%, defeat text | defeat_drum.wav | 0.5s sustained |
| Black Jack (instant win) | Both cards slam, golden burst, HP empties | black_jack_slam.wav | 0.5s strong |
| Game victory | Screen brightens, warm glow, "VICTORY" + stats | game_victory.wav | 0.5s escalating |
| Game over | Dim overlay, defeat text, stats, "Try Again" after 1s | game_over.wav | — |

---

## 4. Animation Timing

### Card Animations

| Animation | Duration | Easing |
|-----------|----------|--------|
| Card deal | 0.4s | ease_out(Cubic), staggered 100ms |
| Card hover lift/lower | 0.1s / 0.08s | ease_out(Quad) |
| Card flip (AI reveal) | 0.4s | ease_in_out(Sine) |
| Card drag follow | 0.0s (immediate) | Linear |
| Card snap to slot | 0.15s | ease_out(Back, overshoot=1.2) |
| Card spacing adjust | 0.15s | ease_out(Quad) |
| Card bust shake | 0.3s | ease_out(Elastic), 10px x3 |
| Quality border shatter | 0.5s | ease_in(Expo) |
| Stamp glow pulse | 0.3s | ease_in_out(Sine) |

### UI Panel Animations

| Animation | Duration | Easing |
|-----------|----------|--------|
| Button hover/press | 0.1s / 0.05s | ease_out(Quad) / Linear |
| Phase button swap | 0.3s | ease_out(Quad) |
| Shop overlay appear/disappear | 0.4s / 0.3s | ease_out/in(Cubic) |
| Detail panel open/close | 0.2s / 0.15s | ease_out(Back) / ease_in(Quad) |
| Combat log toggle | 0.2s | ease_out(Quad) |
| Modal appear/dismiss | 0.25s / 0.15s | ease_out(Back) / ease_in(Quad) |

### Data Display Animations

| Animation | Duration | Easing |
|-----------|----------|--------|
| HP bar fill change | 0.3s | ease_out(Quad) |
| HP bar color transition | 0.2s | ease_out(Quad) |
| Chip counter roll | 0.5s | ease_out(Quad) |
| Floating notification | 0.8s | ease_out(Quad) rise, ease_in(Sine) fade |
| Defense label change | 0.2s | ease_out(Quad) |

### Screen Transitions

| Transition | Duration |
|------------|----------|
| Main Menu → Card Table | 0.5s |
| Card Table → Shop | 0.4s |
| Shop → Card Table | 0.4s |
| Card Table → Victory | 0.5s |
| Card Table → Defeat | 0.5s |

All transitions: ease_in_out(Cubic). Forward slides right, backward slides left.

### Timing Principles

1. Responsiveness first — hover (0.1s) and press (0.05s) must feel instant
2. Progressive disclosure — micro (0.05-0.15s), meso (0.2-0.5s), macro (0.5-1.5s)
3. Consistent easing — ease_out for arrivals, ease_in for departures, ease_in_out for transitions, Back overshoot for snaps
4. No stacking delay — stagger but cap total duration
5. Reduced motion override — durations halved, no overshoot, no floating movement, cross-fades replace slides

---

## Cross-Reference

| Pattern | Used On | ADR Reference |
|---------|---------|---------------|
| PATTERN-01 Card Hover | Card Table (all phases), Shop, Deck viewer | ADR-0008 |
| PATTERN-02 Phase Action Button | Card Table (action bar) | ADR-0008 |
| PATTERN-03 Timed Phase | Card Table (Sort phase) | ADR-0008 |
| PATTERN-04 Drag-and-Drop | Card Table (Sort phase) | ADR-0008 |
| PATTERN-05 Chip Placement | Card Table (pre-deal) | — |
| PATTERN-06 Shop Transaction | Shop overlay | ADR-0008 |
| PATTERN-07 Floating Notification | Card Table (Resolution) | ADR-0008 |
| PATTERN-08 Screen Transition | All screens | — |
