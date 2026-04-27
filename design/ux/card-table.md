# UX Screen Spec: Card Table (Main Gameplay)

> **Status**: Draft
> **Last Updated**: 2026-04-26
> **Resolution**: 1920x1080 (min 1280x720)
> **Linked ADRs**: ADR-0008 (UI Node Hierarchy), ADR-0001 (Scene Architecture)
> **Linked GDDs**: table-ui.md, card-sorting-system.md, combat-system.md, chip-economy.md
> **Linked Patterns**: PATTERN-01 (Card Hover Inspection), PATTERN-02 (Phase Action Button)

---

## Overview

The card table is the primary gameplay screen where all rounds are played. It displays the opponent's hand, the player's hand, combat state, chip balance, and phase-driven action buttons. Five permanent regions are always visible; overlay elements appear contextually.

---

## Screen Layout (1920x1080)

```
┌──────────────────────────── 1920px ────────────────────────────┐
│                    OPPONENT INFO BAR (60px)                     │
│   [Opponent 3/8]   ████████████░░░ 180/260 HP    🛡 15         │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    AI HAND AREA (200px)                         │
│              ▓▓  ▓▓  ▓▓  ▓▓  ▓▓  ▓▓  ▓▓                       │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                   CENTRAL INFO BAR (40px)                       │
│   [HIT_STAND]  Opponent 3/8  Round 4  💰 340  ⚡ Player first  │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│                  PLAYER HAND AREA (220px)                       │
│              🂡  🂱  🃁  🃑  🂢  🂲  🃂  🃒                       │
│              1   2   3   4   5   6   7   8                      │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│                PLAYER INFO + ACTION BAR (80px)                  │
│  ████████░░ 85/100 HP  🛡 5  Pt: 18  [Hit][Stand][Double Down] │
└────────────────────────────────────────────────────────────────┘
```

### Region Specifications

| Region | Height | V-Separation | Contents | Layout |
|--------|--------|-------------|----------|--------|
| Opponent Info Bar | 60px | 8px bottom margin | Name, HP bar, defense | HBoxContainer, center-aligned |
| AI Hand Area | 200px | 4px bottom margin | Face-down/face-up cards | HBoxContainer, center-aligned |
| Central Info Bar | 40px | 4px bottom margin | Phase, counters, chip, first-player | HBoxContainer, center-aligned |
| Player Hand Area | 220px | 4px bottom margin | Player cards, position numbers | HBoxContainer, center-aligned |
| Player Info + Action Bar | 80px | 0 | HP, defense, points, buttons | HBoxContainer, spread |

**Total fixed UI**: ~620px. Remaining ~460px distributed as flexible padding between regions via VBoxContainer.

**Side margins**: 160px each side (card hand container width ≈ 1600px).

---

## Card Dimensions

| Property | Value | Range |
|----------|-------|-------|
| Card width | 120px | 80–160px |
| Card height | 168px | 112–224px |
| Aspect ratio | ~1.4:1 | Locked |
| Hover lift | 20px | 10–40px |

**Card spacing** (per hand container, ~1600px wide):

| Card count | Spacing |
|-----------|---------|
| 1–3 | Evenly distributed: `(1600 - count × 120) / (count + 1)` |
| 4–7 | Fixed 80px separation |
| 8–11 | Overlapping fan: `(1600 - 120) / (count - 1)` |

---

## Region Details

### Opponent Info Bar

| Element | Size | Position | Notes |
|---------|------|----------|-------|
| Opponent label | Auto | Left | "Opponent 3/8" format |
| HP bar | 300×20px | Center | Progress bar, color thresholds: >50% green, 25–50% yellow, <25% red flash |
| HP text | Auto | Beside bar | "180/260" format, min 18px |
| Defense icon + value | Auto | Right | Blue text, hidden when 0 |

### AI Hand Area

- Cards face-down by default (dark card-back texture)
- Cards flip face-up during RESOLUTION phase (0.4s flip, 200ms stagger)
- Face-up AI cards: `focus_mode = FOCUS_NONE`, `mouse_filter = IGNORE`
- Face-down AI cards: card-back ColorRect hides all card children
- Sort position numbers hidden (AI sorting is automatic)

### Central Info Bar

| Element | Format | Visibility |
|---------|--------|-----------|
| Phase indicator | Uppercase label, e.g. "HIT_STAND" | Always, center |
| Opponent counter | "Opponent 3/8" | Always |
| Round counter | "Round 4" | Always |
| Chip counter | "💰 340" (animated tween, 0.5s) | Always |
| First-player flag | "⚡ Player first" or "⚡ AI first" | Per-round |
| Sort timer | "⏱ 25" (red flash last 5s) | SORT phase only |
| Settlement step | Text description | RESOLUTION phase only |

### Player Hand Area

- Cards always face-up, interactive during HIT_STAND and SORT phases
- Position numbers visible during SORT phase (1-based, displayed above each card)
- Drag-and-drop reordering during SORT phase
- Split layout: two sub-containers (~800px each), active hand highlighted, inactive dimmed (alpha 0.5)

### Player Info + Action Bar

| Element | Position | Notes |
|---------|----------|-------|
| HP bar (player) | Left group | Same style as opponent, max 100 default |
| HP text | Beside bar | "85/100" |
| Defense value | Left of buttons | Blue, "🛡 5" |
| Point total | Left of buttons | "Pt: 18", updates on hit/stand |
| Action buttons | Right group | Phase-driven enable/disable, amber glow enabled state |

---

## Phase-Driven States

| Phase | Buttons Active | Card Interaction | Timer |
|-------|---------------|-----------------|-------|
| DEAL | None | Locked (deal animation) | — |
| INSURANCE | [Buy Insurance (30💰)] [Buy Insurance (6❤)] [Skip] | Locked | — |
| SPLIT | [Confirm Split] [Skip] | Locked | — |
| HIT_STAND | [Hit] [Stand] [Double Down*] | Click cards or buttons | — |
| SORT | [Confirm Sort] | Drag-to-reorder | 30s countdown |
| RESOLUTION | None | Locked (settlement animation) | — |
| DEATH_CHECK | None | Locked | — |

\* Double Down: enabled only when hand_count == 2 and no active split.

---

## Overlay Screens

| Overlay | Trigger | Layout |
|---------|---------|--------|
| Shop | Between opponents (match-progression) | Full-screen overlay, ADR-0008 specifies shop overlay |
| Side Pool Bet | SIDE_POOL phase (Vertical Slice) | Modal dialog over central area |
| Item Bar | SORT phase (when player has items) | Horizontal bar above player hand, max 5 slots |

---

## Animation Timings

| Animation | Duration | Range |
|-----------|----------|-------|
| Card flip | 0.4s | 0.2–1.0s |
| AI card stagger | 200ms between cards | — |
| Settlement step delay | 500ms between events | 200–2000ms |
| Chip counter tween | 0.5s (ease_out) | 0.1–2.0s |
| HP bar flash | 0.3s | — |
| Phase transition | max 300ms (non-blocking) | — |
| Quality destroy | 0.5s (shrink + fade) | — |
| Hover lift | instant | — |

---

## Accessibility Notes

- All interactive elements Tab-navigable (dual-focus: PATTERN-01)
- Sort timer adjustable (15s–60s or unlimited) per accessibility-requirements.md
- HP thresholds use shape + color (not color alone): green filled, yellow striped, red flashing
- Card info available via keyboard inspect (Enter on focused card)
- Min font: 14px general, 18px critical (HP, points, timer)
- Motion reduction mode: replaces animations with instant state changes

---

## Responsive Behavior (1280x720)

- Cards scale to ~90px width
- Hand containers reduce to ~1060px width
- Side margins reduce to 110px
- Spacing algorithm recalculates with new container width
- All text meets minimum 14px at 720p
