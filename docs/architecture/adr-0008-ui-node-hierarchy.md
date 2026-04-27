# ADR-0008: UI Node Hierarchy

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | UI (Control nodes, Tween, scene composition) |
| **Knowledge Risk** | HIGH — Godot 4.6 dual-focus (mouse/gamepad focus now separate); MEDIUM — AccessKit (4.5) |
| **References Consulted** | VERSION.md, deprecated-apis.md, breaking-changes.md |
| **Post-Cutoff APIs Used** | Dual-focus system (4.6) — mouse and gamepad focus are independent |
| **Verification Required** | Test dual-focus behavior during SORT phase with both mouse and gamepad connected |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (TableUI as Control child of GameManager), ADR-0003 (all signal contracts, settlement event queue) |
| **Enables** | All UI implementation stories, accessibility stories |
| **Blocks** | Stories involving UI rendering, card animations, shop overlay, settlement visualization |
| **Ordering Note** | Should be Accepted before UI implementation. Depends on ADR-0003 signal names being finalized. |

## Context

### Problem Statement
TableUI is the most complex visual system: 5 screen regions, dynamic card nodes, phase-driven button states, drag-and-drop sorting, settlement animation queue, and a shop overlay. How is the scene tree structured?

### Constraints
- Single 1920x1080 screen, min 1280x720 with responsive card sizing
- Card nodes created/destroyed per round (up to 22 cards on screen)
- Settlement animation plays pre-computed event queue (ADR-0003) with Tween delays
- Phase transitions drive button enable/disable states
- Godot 4.6 dual-focus: mouse hover and gamepad focus are independent
- UI is pure consumer — reads state via signals, emits request signals only
- Draw calls must stay under 100

### Requirements
- Must support 5 permanent screen regions (opponent info, AI hand, central bar, player hand, action bar)
- Must render up to 22 card nodes simultaneously with texture atlas
- Must support drag-and-drop card sorting with 30s countdown
- Must play settlement animation from pre-computed event queue
- Must overlay shop UI on top of table
- Must handle split-hand layout (two side-by-side hand areas)
- Must support keyboard, gamepad, and mouse input simultaneously

## Decision

### Multi-Scene Composition

TableUI is the root Control node. CardView and ShopOverlay are separate .tscn scenes instanced into it.

```
TableUI.tscn (Control — full-screen)
├── OpponentInfoBar (HBoxContainer)
│   ├── OpponentName (Label)
│   ├── OpponentHPBar (ProgressBar + Label "75/100")
│   └── OpponentDefense (Label)
├── AIHandArea (HBoxContainer — center-aligned)
│   └── [CardView instances — face-down, created dynamically]
├── CentralInfoBar (HBoxContainer)
│   ├── PhaseIndicator (Label)
│   ├── OpponentCounter (Label "3/8")
│   ├── RoundCounter (Label)
│   ├── ChipCounter (Label + Tween)
│   └── FirstPlayerFlag (Label)
├── PlayerHandArea (HBoxContainer — center-aligned)
│   └── [CardView instances — face-up, created dynamically]
├── ActionBar (HBoxContainer)
│   ├── HPBar (ProgressBar + Label)
│   ├── DefenseLabel (Label)
│   ├── PointTotal (Label)
│   └── ButtonContainer (HBoxContainer)
│       ├── HitButton (Button)
│       ├── StandButton (Button)
│       ├── DoubleDownButton (Button)
│       ├── SplitButton (Button)
│       ├── InsuranceChipButton (Button)
│       ├── InsuranceHPButton (Button)
│       └── SortConfirmButton (Button)
├── ShopOverlay (ShopOverlay.tscn instance — hidden by default)
└── SortTimer (Label — visible during SORT phase only)
```

### CardView Scene Structure

```
CardView.tscn (Control — 120x168px)
├── CardBackground (ColorRect or NinePatchRect — suit color)
├── RankLabel (Label — top-left)
├── SuitIcon (TextureRect — top-right)
├── StampIcon (TextureRect — bottom-left, hidden when null)
├── QualityBorder (NinePatchRect — card border, hidden when null)
├── QualityIcon (TextureRect + LevelLabel — bottom-right, hidden when null)
├── PositionNumber (Label — top-center, visible during SORT phase)
└── CardBack (ColorRect — shown for AI face-down, hides all other children)
```

### Card Node Lifecycle

```gdscript
var _card_pool: Array[CardView] = []
var _player_card_views: Array[CardView] = []
var _ai_card_views: Array[CardView] = []

func _on_cards_dealt(player_cards: Array[CardInstance], ai_cards: Array[CardInstance]) -> void:
    _clear_cards()
    for card in player_cards:
        var view := _get_card_view()
        view.setup(card, face_up=true)
        _player_card_views.append(view)
        $PlayerHandArea.add_child(view)
    for card in ai_cards:
        var view := _get_card_view()
        view.setup(card, face_up=(card == ai_cards[0]))  # First card face-up
        _ai_card_views.append(view)
        $AIHandArea.add_child(view)
    _update_card_spacing()

func _get_card_view() -> CardView:
    if _card_pool.size() > 0:
        return _card_pool.pop_back()
    return preload("res://ui/CardView.tscn").instantiate()

func _clear_cards() -> void:
    for view in _player_card_views:
        $PlayerHandArea.remove_child(view)
        _card_pool.append(view)
    for view in _ai_card_views:
        $AIHandArea.remove_child(view)
        _card_pool.append(view)
    _player_card_views.clear()
    _ai_card_views.clear()
```

### Card Spacing

```gdscript
func _update_card_spacing() -> void:
    _apply_spacing($PlayerHandArea, _player_card_views)
    _apply_spacing($AIHandArea, _ai_card_views)

func _apply_spacing(container: HBoxContainer, cards: Array[CardView]) -> void:
    var count := cards.size()
    if count == 0:
        return
    var container_width := container.size.x
    var card_width := CARD_WIDTH
    var spacing: int
    if count <= 3:
        spacing = (container_width - count * card_width) / (count + 1)
    elif count <= 7:
        spacing = 80
    else:
        spacing = (container_width - card_width) / (count - 1)
    container.add_theme_constant_override("separation", spacing)
```

### Settlement Animation Playback

```gdscript
var _settlement_tween: Tween

func _on_settlement_step_completed(events: Array[SettlementEvent]) -> void:
    if _settlement_tween and _settlement_tween.is_valid():
        _settlement_tween.kill()
    _settlement_tween = create_tween()
    for event in events:
        _settlement_tween.tween_callback(_animate_event.bind(event))
        _settlement_tween.tween_interval(ANIM_SETTLE_DELAY / 1000.0)
    _settlement_tween.finished.connect(_on_settlement_animation_done)

func _animate_event(event: SettlementEvent) -> void:
    match event.step:
        StepKind.BASE_VALUE:
            _show_floating_text(event.card, str(event.value), Color.GREEN if event.target == "player" else Color.RED)
        StepKind.STAMP_EFFECT:
            _show_stamp_animation(event.card, event.value)
        StepKind.QUALITY_EFFECT:
            _show_quality_animation(event.card, event.value)
        StepKind.MULTIPLIER_APPLIED:
            _show_multiplier_text(event.card, event.metadata.get("multiplier", 1.0))
        StepKind.GEM_DESTROY:
            _animate_gem_destroy(event.card)
        StepKind.CHIP_GAINED:
            _animate_chip_gain(event.value)
        StepKind.HEAL_APPLIED:
            _show_floating_text(event.card, "+%d" % event.value, Color.GREEN)
        StepKind.DEFENSE_APPLIED:
            _show_floating_text(event.card, "+%d" % event.value, Color.BLUE)

func _on_settlement_animation_done() -> void:
    _settlement_tween = null
```

### Phase-Driven Button States

```gdscript
func _on_phase_changed(new_phase: RoundPhase, old_phase: RoundPhase) -> void:
    match new_phase:
        RoundPhase.INSURANCE:
            _show_buttons(["insurance_chip", "insurance_hp"])
        RoundPhase.SPLIT_CHECK:
            _show_buttons(["split"])
        RoundPhase.HIT_STAND:
            _show_buttons(["hit", "stand"])
            _update_doubledown_availability()
        RoundPhase.SORT:
            _show_buttons(["sort_confirm"])
            _start_sort_timer()
        RoundPhase.RESOLUTION, RoundPhase.DEATH_CHECK, RoundPhase.DEAL:
            _show_buttons([])

func _show_buttons(visible_ids: Array[String]) -> void:
    for child in $ActionBar/ButtonContainer.get_children():
        child.visible = child.name.to_snake_case() in visible_ids
        child.disabled = not child.visible
```

### Godot 4.6 Dual-Focus Handling

Godot 4.6 introduces "Click != Focus": mouse clicks give a control hidden focus
(no focus ring), while keyboard/gamepad shows visible focus (focus ring rendered).
The `hover` and `focus` visuals are independent and can be active on different
cards simultaneously.

Key 4.6 APIs:
- `grab_focus(hide_focus: bool = false)` — optional param to suppress visual
- `has_focus(ignore_hidden_focus: bool = false) -> bool` — ignore mouse-gained focus
- `gui/common/show_focus_state_on_pointer_event` project setting (default 1)

CardView is a bare Control (not a Button), so it needs custom `_draw()` rather
than theme StyleBox overrides. Mouse hover uses `mouse_entered`/`mouse_exited`
signals; keyboard/gamepad focus uses `focus_entered`/`focus_exited` signals.

```gdscript
# --- In CardView.gd ---
var _is_mouse_hovered: bool = false
var _is_kb_focus_visible: bool = false
var _last_input_was_mouse: bool = false

@export var gamepad_focus_color: Color = Color.YELLOW
@export var mouse_hover_color: Color = Color.WHITE

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    focus_entered.connect(_on_focus_entered)
    focus_exited.connect(_on_focus_exited)

func _input(event: InputEvent) -> void:
    if event is InputEventMouse:
        _last_input_was_mouse = true
    elif event is InputEventKey or event is InputEventJoypadButton:
        _last_input_was_mouse = false

func _on_mouse_entered() -> void:
    _is_mouse_hovered = true
    queue_draw()

func _on_mouse_exited() -> void:
    _is_mouse_hovered = false
    queue_draw()

func _on_focus_entered() -> void:
    _is_kb_focus_visible = not _last_input_was_mouse
    queue_draw()

func _on_focus_exited() -> void:
    _is_kb_focus_visible = false
    queue_draw()

func _draw() -> void:
    if _is_mouse_hovered:
        _draw_hover_glow(mouse_hover_color)
    if _is_kb_focus_visible:
        _draw_focus_border(gamepad_focus_color)

func _draw_hover_glow(color: Color) -> void:
    var glow_width: float = 3.0
    var inner_rect := Rect2(Vector2.ZERO, size).grow(-glow_width)
    draw_rect(inner_rect, Color(color.r, color.g, color.b, 0.3), false, glow_width)

func _draw_focus_border(color: Color) -> void:
    var border_width: float = 2.0
    var border_rect := Rect2(Vector2.ZERO, size).grow(border_width)
    draw_rect(border_rect, color, false, border_width)
```

```gdscript
# --- In TableUI.gd ---
func _setup_dual_focus() -> void:
    # Configure player cards for dual-focus (SORT phase interaction)
    for card_view in _player_card_views:
        card_view.focus_mode = Control.FOCUS_ALL
        card_view.mouse_filter = Control.MOUSE_FILTER_STOP
        card_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    # AI cards don't need player focus interaction
    for card_view in _ai_card_views:
        card_view.focus_mode = Control.FOCUS_NONE
        card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

**Engine testing required** (prototype validation):
1. Mouse hover Card A + gamepad focus Card B simultaneously — confirm both
   visuals render independently
2. `_last_input_was_mouse` tracking — confirm no race condition when mouse click
   is immediately followed by keyboard input before `focus_entered` fires
3. Drag-and-drop during SORT — confirm releasing drag doesn't change
   keyboard/gamepad focus

**Fallback** (if engine testing reveals issues):
Always show gamepad focus ring when `has_focus()` returns true, accepting that
mouse clicks will also show the yellow border (pre-4.6 behavior). Functional
but less polished.

**Note**: The dual-focus behavior requires engine testing during prototype phase. The GDD defines two separate visual styles (gamepad_focus_color = yellow, mouse_hover_color = white glow). The exact API for managing both simultaneously will be validated against Godot 4.6.2.

### Shop Overlay

ShopOverlay.tscn is a separate scene, hidden by default, shown when match enters SHOP state:

```gdscript
func _on_shop_entered() -> void:
    $ShopOverlay.show()
    $ShopOverlay.setup(shop_items, chips.get_balance())

func _on_shop_exited() -> void:
    $ShopOverlay.hide()
```

### Split-Hand Layout

```gdscript
func _on_split_activated(active_hand: int) -> void:
    $PlayerHandArea/HBoxSplitLeft.visible = true
    $PlayerHandArea/HBoxSplitRight.visible = true
    $PlayerHandArea/HBoxSingle.visible = false
    # Move cards to appropriate split container
```

## Alternatives Considered

### Alternative 1: Single Monolithic TableUI.tscn
- **Description**: All UI nodes (cards, shop, buttons, overlays) defined in one .tscn file.
- **Pros**: No scene loading overhead; all nodes visible in editor; single file to edit
- **Cons**: 500+ node scene is unwieldy in editor; card nodes must be dynamic anyway; shop overlay clutters the main view; merge conflicts when multiple developers edit UI
- **Rejection Reason**: CardView and ShopOverlay have distinct lifecycles and concerns. CardView is instantiated per-card (up to 22 times). ShopOverlay is shown/hidden per opponent. Separating them keeps the scene tree manageable and allows independent editing.

### Alternative 2: Programmatic Node Creation (no .tscn)
- **Description**: All nodes created in code via `add_child()`. No scene files.
- **Pros**: Maximum flexibility; no editor coupling; easier to parameterize
- **Cons**: No visual editing; no editor preview; all layout must be specified in code; harder for non-programmers to modify; longer development time
- **Rejection Reason**: Godot's strength is scene-based UI editing. Layout, anchors, and styling are much faster to iterate in the editor than in code. CardView benefits from visual setup (texture rects, labels, anchors). Use .tscn for structure, code for dynamic behavior.

## Consequences

### Positive
- Multi-scene: CardView and ShopOverlay are independently editable and testable
- Card pooling: avoids node creation/destruction overhead per round
- Tween-based animation: smooth, frame-rate independent, cancellable
- Responsive layout: HBoxContainer + spacing formula adapts to hand size
- Phase-driven buttons: single function handles all state transitions

### Negative
- 3 scene files to maintain (TableUI, CardView, ShopOverlay)
- Card pool requires manual lifecycle management
- Dual-focus requires engine testing (HIGH risk from VERSION.md)

### Risks
- **Risk**: Dual-focus input source detection (`_last_input_was_mouse`) may miss edge cases
  **Mitigation**: Requires prototype testing. Fallback: always show focus ring when `has_focus()` returns true (pre-4.6 behavior).
- **Risk**: Card pool grows if cards are created faster than recycled
  **Mitigation**: Pool is bounded by max hand size (11 per side = 22 total). Clear on round reset.
- **Risk**: Settlement animation blocks input for 22-44 seconds in worst case
  **Mitigation**: UI ignores all input during RESOLUTION phase. Consider adding "skip animation" button in future iteration.
- **Risk**: Texture atlas size grows with 8 quality borders + 7 stamp icons + 4 suit symbols
  **Mitigation**: All icons are small (32x32 or 48x48). Total atlas: ~4KB. Well within GPU budget.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| table-ui.md | 5 permanent screen regions | TableUI root with 5 HBox/VBox regions |
| table-ui.md | Card rendering with stamp/quality/position | CardView.tscn with conditional child nodes |
| table-ui.md | Card spacing algorithm (3 cases) | _apply_spacing with count-based formula |
| table-ui.md | Settlement animation from event queue | Tween playback of SettlementEvent array |
| table-ui.md | AI card flip (scale X → swap → scale X) | Separate flip Tween per AI CardView |
| table-ui.md | Chip counter 0.5s rolling animation | Tween on Label.text from old to new value |
| table-ui.md | HP bar color thresholds (green/yellow/red) | ProgressBar with color change via StyleBox |
| table-ui.md | Phase-driven button enable/disable | _on_phase_changed with match on RoundPhase |
| table-ui.md | Sort timer countdown (30s, red flash last 5s) | Timer node + Label update, color change at 5s |
| table-ui.md | Drag-and-drop during SORT | Input handling on CardView during SORT phase |
| table-ui.md | Split-hand side-by-side layout | Two HBoxSplit containers, toggle visibility |
| table-ui.md | Shop overlay | ShopOverlay.tscn instance, show/hide |
| table-ui.md | Dual-focus mouse/gamepad (4.6) | Separate visual styles, requires engine testing |
| card-sorting-system.md | Sort timer auto-confirm on expiry | Timer timeout → emit player_sort_confirmed |
| shop-system.md | Shop layout (fixed/random panels) | ShopOverlay.tscn with left/right HBox regions |

## Performance Implications
- **CPU**: Settlement animation = N Tween callbacks, lightweight. Phase transition = single match. Negligible.
- **Memory**: Card pool: 22 CardView instances × ~2KB = ~44KB. Always cached.
- **Draw Calls**: Texture atlas for cards. 22 cards + UI chrome ≈ <50 draw calls (within 100 budget).
- **Load Time**: 3 scene instances + card pool setup ≈ <50ms.

## Migration Plan
First implementation — no migration needed.

## Validation Criteria
- All 5 screen regions render correctly at 1920x1080 and 1280x720
- Card spacing formula produces correct layout for 1-11 cards
- CardView shows stamp icon, quality border, and position number when applicable
- AI cards render face-down until settlement flip
- Settlement animation plays all StepKind events with correct delays
- Phase transitions enable/disable correct button sets
- Shop overlay shows/hides without affecting table state
- Card pool reuses CardView instances across rounds (no unbounded growth)
- Chip counter animates smoothly on balance change
- HP bar color changes at 50% and 25% thresholds
