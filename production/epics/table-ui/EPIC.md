# Epic: Table UI

> **Layer**: Presentation
> **GDD**: design/gdd/table-ui.md
> **Architecture Module**: TableUI — all UI nodes, animations, input handling, pure consumer of game state
> **Status**: Ready
> **Stories**: 3 stories (see table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Table Layout, CardView, and Hand Display | UI | Ready | ADR-0008 |
| 002 | Game State Display and Phase Controls | UI | Ready | ADR-0003, ADR-0008 |
| 003 | Card Sort Drag UI | UI | Ready | ADR-0008 |

## Overview

Implements the minimal table UI for 决胜21点: card rendering (face up/down), HP bars for both player and AI, chip counter display, point total display, Hit/Stand buttons with phase-driven enable/disable, and a phase indicator. 1920×1080 layout with 5 permanent screen regions (opponent info, AI hand, central info, player hand, action bar). Sprint 2 MVP is mouse-only — gamepad dual-focus deferred. The UI is a pure consumer: it reads state via signals and emits request signals, never calling game logic directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal Architecture | UI signal contract: request signals from UI, state signals from game logic; no direct method calls | LOW |
| ADR-0008: UI Node Hierarchy | Table screen scene tree; card node lifecycle; animation layer; dual-focus system (4.6) | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ui-001 | 5 permanent screen regions at 1920×1080 | ADR-0008 ✅ |
| TR-ui-002 | CardView renders suit, rank, stamp icon, quality border — MVP: suit + rank only | ADR-0008 ✅ |
| TR-ui-003 | Card spacing algorithm for 1-11 cards | ADR-0008 ✅ |
| TR-ui-004 | Settlement animation from pre-computed event queue — MVP: deferred | ADR-0003 ✅ ADR-0008 ✅ |
| TR-ui-005 | Phase-driven button enable/disable | ADR-0008 ✅ |
| TR-ui-006 | Sort timer countdown — MVP: auto-sort, no timer | ADR-0008 ✅ |
| TR-ui-007 | Drag-and-drop card sorting — MVP: auto-sort, deferred to 2-9 | ADR-0008 ✅ |
| TR-ui-008 | Split-hand layout — MVP: skipped | ADR-0008 ✅ |
| TR-ui-009 | Shop overlay — MVP: skipped | ADR-0008 ✅ |
| TR-ui-010 | Dual-focus (mouse/gamepad) — MVP: mouse-only, deferred | ADR-0008 ✅ |
| TR-ui-011 | AI card flip animation — MVP: face-up/down toggle | ADR-0008 ✅ |
| TR-ui-012 | Chip counter rolling animation — MVP: direct display, no tween | ADR-0008 ✅ |
| TR-ui-013 | HP bar color thresholds — MVP: single color fill | ADR-0008 ✅ |
| TR-ui-014 | Draw calls under 100 — MVP: not optimized | ADR-0008 ✅ |
| TR-ui-015 | Item bar rendering — Alpha: deferred | ❌ Deferred |
| TR-ui-016 | Side pool UI — Alpha: deferred | ADR-0009 ✅ (deferred) |
| TR-ui-017 | Accessibility features — Alpha: deferred | ❌ Deferred |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/table-ui.md` (MVP scope) are verified
- Manual evidence docs with screenshots in `production/qa/evidence/sprint-2/ui-2-6-table-screenshots/`
- UI never calls game logic directly — request signals only
- Layout renders correctly at 1920×1080

## Next Step

Run `/story-readiness production/epics/table-ui/story-001-table-layout-cardview.md` to validate before implementation.
