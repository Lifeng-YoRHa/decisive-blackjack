# Story 001: Table Layout, CardView, and Hand Display

> **Epic**: Table UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: N/A — manifest not yet created
> **Estimate**: ~0.5 day

## Context

**GDD**: `design/gdd/table-ui.md`
**Requirements**: TR-ui-001 (5 screen regions), TR-ui-002 (CardView rendering), TR-ui-003 (card spacing), TR-ui-011 (AI card flip)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (UI Node Hierarchy)
**ADR Decision Summary**: TableUI is a Control root with 5 HBoxContainer regions. CardView is a separate .tscn scene (120×168px) with CardBackground, RankLabel, SuitIcon, and CardBack. Card node pooling for lifecycle management. Card spacing algorithm: 3 tiers based on hand count.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Godot 4.6 dual-focus system (mouse/gamepad focus independent) — MVP uses mouse-only, dual-focus deferred. No post-cutoff APIs needed for this story.

**Control Manifest Rules (this layer)**:
- Required: UI reads state via signals, emits request signals only
- Forbidden: UI never calls game logic methods directly — request signals only

---

## Acceptance Criteria

*From GDD `design/gdd/table-ui.md`, scoped to MVP:*

- [ ] AC-01: Screen layout — 5 permanent regions visible at 1920×1080: opponent info bar (top), AI hand area (upper), central info bar (middle), player hand area (lower), player info + action bar (bottom). Each region contains at least one child node.
- [ ] AC-02 (MVP): CardView renders suit symbol + rank text — e.g., ♠A shows spade icon + "A"; ♥K shows heart icon + "K"; ♦7 shows diamond icon + "7". Stamp icons and quality borders NOT rendered (hidden).
- [ ] AC-03: AI face-up/down — first AI card shows suit+rank; remaining AI cards show card back (solid color or simple pattern). Player cards always face-up.
- [ ] AC-09: Card spacing — 2 cards: evenly distributed, no overlap; 5 cards: moderate overlap (~80px offset); 11 cards: tight overlap (~55px offset), all cards at least partially visible.
- [ ] CardView.tscn is a separate scene file at `res://ui/CardView.tscn`
- [ ] TableUI.tscn scene tree matches ADR-0008 structure (5 regions as HBoxContainer/VBoxContainer)
- [ ] Card node pooling: cards reuse CardView instances across rounds, no unbounded growth

---

## Implementation Notes

*Derived from ADR-0008:*

Scene tree structure (ADR-0008 Decision):
```
TableUI.tscn (Control — full-screen)
├── OpponentInfoBar (HBoxContainer)
│   ├── OpponentName (Label)
│   ├── OpponentHPBar (ProgressBar + Label)
│   └── OpponentDefense (Label)
├── AIHandArea (HBoxContainer — center-aligned)
│   └── [CardView instances — dynamic]
├── CentralInfoBar (HBoxContainer)
│   ├── PhaseIndicator (Label)
│   ├── OpponentCounter (Label)
│   ├── RoundCounter (Label)
│   ├── ChipCounter (Label)
│   └── FirstPlayerFlag (Label)
├── PlayerHandArea (HBoxContainer — center-aligned)
│   └── [CardView instances — dynamic]
├── ActionBar (HBoxContainer)
│   ├── HPBar (ProgressBar + Label)
│   ├── DefenseLabel (Label)
│   ├── PointTotal (Label)
│   └── ButtonContainer (HBoxContainer)
└── SortTimer (Label — hidden by default)
```

CardView.tscn (120×168px):
```
CardView.tscn (Control)
├── CardBackground (ColorRect — suit color)
├── RankLabel (Label — top-left)
├── SuitIcon (TextureRect — top-right)
├── StampIcon (TextureRect — hidden in MVP)
├── QualityBorder (NinePatchRect — hidden in MVP)
├── QualityIcon (TextureRect — hidden in MVP)
├── PositionNumber (Label — hidden in MVP)
└── CardBack (ColorRect — shown for AI face-down)
```

Card lifecycle: `_on_cards_dealt` creates CardView instances from pool, calls `setup(card, face_up)`. `_clear_cards` returns instances to pool. Pool bounded by max 22 cards.

Card spacing formula from GDD:
```
IF hand_count <= 3: spacing = (container_width - count × card_width) / (count + 1)
ELIF hand_count <= 7: spacing = 80
ELSE: spacing = (container_width - card_width) / (count - 1)
```

MVP simplifications: StampIcon, QualityBorder, QualityIcon, PositionNumber nodes exist but are hidden (visible=false). CardBack is a simple ColorRect — no texture needed. SuitIcon can use Label with unicode suit characters (♠♥♦♣) instead of textures for MVP.

**Performance**: MVP does not enforce the 100-draw-call budget. Each CardView is ~8 Control nodes; with 22 cards that's ~176 nodes on screen. Card pool avoids instantiate()/queue_free() per round. Spacing calculation is O(1) per hand area (3-branch conditional). Target: stable 60fps at 1920×1080 with all regions rendered. Draw call optimization deferred to Vertical Slice (TR-ui-014).

---

## Out of Scope

- HP bar color thresholds (green/yellow/red) → Story 002
- Chip counter animation → Story 002
- Hit/Stand buttons and phase-driven controls → Story 002
- Settlement animation playback → deferred (Vertical Slice)
- Drag-and-drop sorting → Story 003
- Shop overlay → deferred
- Split-hand layout → deferred
- Dual-focus (mouse/gamepad) → deferred
- AI card flip Tween animation → deferred (MVP: instant toggle)
- Draw call optimization (texture atlas) → deferred

---

## QA Test Cases

- **AC-01 (screen layout)**:
  - Setup: Launch game, enter first round
  - Verify: All 5 regions present with correct vertical ordering (opponent info → AI hand → central info → player hand → action bar)
  - Pass condition: Each region has ≥1 child node, no overlap between regions at 1920×1080

- **AC-02 (CardView suit+rank)**:
  - Setup: Deal cards to player including ♠A, ♥K, ♦7, ♣3
  - Verify: Each card shows correct suit symbol and rank text
  - Pass condition: Rank label visible, suit icon visible, no stamp/quality elements shown

- **AC-03 (AI face-up/down)**:
  - Setup: AI has 3 cards, first card ♦Q, others hidden
  - Verify: First card shows ♦Q with rank+symbol; remaining cards show card back
  - Pass condition: Exactly 1 AI card face-up, rest face-down

- **AC-09 (card spacing)**:
  - Setup: Test with 2, 5, and 11 player cards
  - Verify: 2 cards evenly spaced, 5 cards at ~80px offset, 11 cards at ~55px offset
  - Pass condition: All cards at least partially visible in each case

- **Card pooling**:
  - Setup: Complete 2 rounds, observe card instance count
  - Verify: No new CardView instances created on round 2 (pool reused)
  - Pass condition: Instance count stays bounded at initial allocation

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/sprint-2/table-layout-cardview-evidence.md` — screenshots at 1920×1080 showing all 5 regions, card rendering, and spacing for 2/5/11 cards

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Sprint 1 (CardDataModel for suit/rank), Round Management Story 001 (phase_changed signal, cards_dealt data)
- Unlocks: Story 002 (game state display and controls)
