# Story 002: Game State Display and Phase Controls

> **Epic**: Table UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.5 day

## Context

**GDD**: `design/gdd/table-ui.md`
**Requirements**: TR-ui-005 (phase-driven buttons), TR-ui-012 (chip display MVP), TR-ui-013 (HP bar MVP)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal Architecture), ADR-0008 (UI Node Hierarchy)
**ADR Decision Summary**: UI signal contract: request signals from UI (player_hit_requested, player_stand_requested), state signals from game logic. Phase-driven button states via match on RoundPhase. HP bar uses ProgressBar. Chip counter uses Label with direct value update (no Tween in MVP).

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Button.disabled, ProgressBar.value, Label.text stable since 4.0. No post-cutoff APIs needed for this story.

**Control Manifest Rules (this layer)**:
- Required: UI connects game logic signals; emits request signals; never calls game logic methods directly
- Forbidden: No direct mutation of game state from UI

---

## Acceptance Criteria

*From GDD `design/gdd/table-ui.md`, scoped to MVP:*

- [ ] AC-04 (MVP): HP bars — player and AI HP bars fill proportionally (hp/max_hp). Single color fill (green). Numeric label shows "hp/max_hp" (e.g., "75/100").
- [ ] AC-05 (MVP): Hit/Stand buttons enabled in HIT_STAND phase; all buttons disabled in DEAL, RESOLUTION, DEATH_CHECK phases. MVP: only Hit and Stand buttons visible (DoubleDown, Split, Insurance hidden).
- [ ] AC-12 (MVP): Chip counter shows current balance as integer text. Direct display (no rolling animation).
- [ ] AC-14: Phase indicator updates on phase_changed signal — displays current phase name in central info bar.
- [ ] AC-16: Opponent progress display — shows "opponent_number/total_opponents" in central info bar.
- [ ] AC-19: Hit button click emits `player_hit_requested` signal; Stand button click emits `player_stand_requested` signal. UI does not call any game logic methods directly.
- [ ] Point total label updates when player hand changes (signal-driven).
- [ ] Defense label displays current defense value (signal-driven).
- [ ] First player flag shows which side goes first (signal-driven from first_player).

---

## Implementation Notes

*Derived from ADR-0003 and ADR-0008:*

Signal connections (UI observes game state):
- `round_manager.phase_changed` → `_on_phase_changed(old, new)` → update phase indicator, button states
- `combat.hp_changed` → update HP bar ProgressBar.value and Label
- `combat.defense_changed` → update defense Label
- `chips.chips_changed` → update chip counter Label
- Point total from round manager or point calculation → update point total Label

Signal emissions (UI requests player actions):
- `signal player_hit_requested`
- `signal player_stand_requested`

Phase-driven button states (ADR-0008):
```gdscript
func _on_phase_changed(old_phase: RoundPhase, new_phase: RoundPhase) -> void:
    match new_phase:
        RoundPhase.HIT_STAND:
            _show_buttons(["hit", "stand"])
        RoundPhase.DEAL, RoundPhase.RESOLUTION, RoundPhase.DEATH_CHECK, RoundPhase.SORT:
            _show_buttons([])
```

MVP simplifications: Only Hit and Stand buttons are visible. DoubleDown, Split, Insurance, SortConfirm buttons exist in scene tree but are hidden. HP bar uses single green StyleBox (no color threshold logic). Chip counter is a Label with `.text = str(balance)` on signal.

HP bar: `ProgressBar.value = hp`, `ProgressBar.max_value = max_hp`. Label: `"%d/%d" % [hp, max_hp]`.

**Performance**: No per-frame processing — all updates are signal-driven (event-based). HP bar ProgressBar.value set on hp_changed signal (O(1)). Chip counter Label.text set on chips_changed signal (O(1)). Button state change is a match + visibility toggle (O(1)). No Tween animations in MVP. Target: signal handlers complete within 1ms total per state change.

---

## Out of Scope

- Settlement animation playback → deferred (Vertical Slice)
- Drag-and-drop sorting → Story 003
- HP bar color thresholds (green/yellow/red) → deferred
- Chip counter rolling animation (Tween) → deferred
- DoubleDown, Split, Insurance buttons → deferred
- Shop overlay → deferred
- Sort timer countdown → Story 003
- Card rendering and spacing → Story 001

---

## QA Test Cases

- **AC-04 (HP bars)**:
  - Setup: Player HP=75/100, AI HP=200/300
  - Verify: Player bar fills 75%, AI bar fills ~66.7%. Both show numeric labels.
  - Pass condition: Bars proportional to hp/max_hp, labels match

- **AC-05 (phase-driven buttons)**:
  - Setup: Advance through phases DEAL → HIT_STAND → RESOLUTION → DEATH_CHECK
  - Verify: Buttons disabled in DEAL, enabled in HIT_STAND, disabled in RESOLUTION/DEATH_CHECK
  - Pass condition: Only Hit+Stand visible in HIT_STAND, no buttons visible in other phases

- **AC-12 (chip counter)**:
  - Setup: Start with 100 chips, gain 65 from clubs resolution
  - Verify: Chip counter shows 165 after signal
  - Pass condition: Label text updates immediately (no animation)

- **AC-14 (phase indicator)**:
  - Setup: Phase transitions from DEAL to HIT_STAND
  - Verify: Phase label text changes to "HIT_STAND"
  - Pass condition: Label updates on each phase_changed signal

- **AC-16 (opponent progress)**:
  - Setup: opponent_number=1
  - Verify: Central info shows "1/8"
  - Pass condition: Updates when opponent changes

- **AC-19 (signal emission)**:
  - Setup: HIT_STAND phase, click Hit button
  - Verify: `player_hit_requested` signal emitted, game logic receives it
  - Pass condition: Signal connected and received; no direct method call on game logic

- **Point total update**:
  - Setup: Player draws a card, point total changes from 12 to 19
  - Verify: Point total label shows 19 after signal
  - Pass condition: Label updates on hand change signal

- **Defense label**:
  - Setup: Defense goes from 0 to 9 after spades settlement
  - Verify: Defense label shows 9
  - Pass condition: Updates on defense_changed signal

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/sprint-2/table-state-controls-evidence.md` — screenshots showing HP bars, chip counter, phase indicator, button states across different phases

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (TableUI scene structure and CardView), Combat State Stories 001+002 (hp_changed, defense_changed signals), Chip Economy Story 001 (chips_changed signal), Round Management Stories 001+002 (phase_changed, round_result signals)
- Unlocks: Story 003 (Card Sort Drag UI)
