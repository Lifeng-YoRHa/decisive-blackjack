# Accessibility Requirements: 《决胜21点》

> **Status**: Committed
> **Last Updated**: 2026-04-26
> **Accessibility Tier Target**: Standard
> **Platform(s)**: PC (Steam / Epic)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA
> - Game Accessibility Guidelines (basic + intermediate categories)
> - Xbox Accessibility Guidelines (reference only — not targeting Xbox at launch)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`

---

## Accessibility Tier Definition

**Target Tier**: Standard

**Rationale**: 《决胜21点》is a turn-based card game with no real-time motor demands. The turn-based structure eliminates the most severe motor barriers common in action games. However, the game is heavily visual — card suits are color-coded, quality tiers use colored borders, and the sort phase presents high cognitive load (6 simultaneous systems). Standard tier addresses colorblind support for the 4-suit system, scalable UI for text-heavy card information, and input flexibility for mouse vs gamepad. This is an indie PC title; Comprehensive tier (screen reader integration, mono audio) is beyond current scope but should be evaluated for a post-launch update. The primary barriers are visual (suit color, quality border, HP bar thresholds) and cognitive (sort-phase multi-system tracking).

**Features explicitly in scope (beyond tier baseline)**:
- Dual encoding for all color signals (suit icons + color, quality icon + border style) — elevated because the entire game is visual card information
- Sort timer adjustment — elevated because cognitive load is the game's primary accessibility barrier
- Gamepad support as secondary input — elevated because turn-based card games are ideal for controller play

**Features explicitly out of scope**:
- Screen reader for in-game card state (Comprehensive) — Godot 4.6 AccessKit covers menu navigation but extending to dynamic game state requires custom work
- Mono audio (Comprehensive) — minimal audio design in a card game reduces impact
- Full subtitle customization (Comprehensive) — no voice acting; all text is UI-based

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Notes |
|---------|-------------|-------|--------|-------|
| Minimum text size — menu UI | Standard | All menus, shop, settings | Not Started | 24px minimum at 1080p. Card stats (rank, effect_value, chip_value) must be legible at card size (~120x168px). |
| Minimum text size — HUD | Standard | HP bars, chip counter, timer, phase indicator | Not Started | 18px minimum for critical info. Phase name and timer visible at all times. |
| Text contrast — UI text | Standard | All UI text on all backgrounds | Not Started | Minimum 4.5:1 ratio (WCAG AA). Card text on card backgrounds is the hardest case — test with contrast checker. |
| Colorblind mode — all 3 types | Standard | Suit colors, quality borders, HP bar thresholds | Not Started | 4 suits (Spades/Hearts/Diamonds/Clubs) are color-coded. Each suit must have a distinct icon/pattern that works without color. Quality borders (metal/gem tiers) must use pattern or icon differentiation. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | Suits, quality tiers, HP thresholds, stamp types, hand type indicators — all must have non-color backups. |
| UI scaling | Standard | All UI elements | Not Started | Range: 75%–150%. Card size may need to scale with UI to maintain text legibility. |
| Screen flash / strobe | Basic | Settlement animations, gem destruction VFX | Not Started | No rapid flash sequences by design. Gem destruction animation must be audited for flash rate. |
| Motion reduction mode | Standard | Card flip animations, chip counter tween, HP bar flash | Not Started | Toggle to replace: card flip → instant swap, chip tween → instant update, HP flash → steady color change. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | Non-Color Backup | Status |
|----------|-------------|-----------------|--------|
| Card suits | ♠=black, ♥=red, ♦=red, ♣=black | Suit symbol (♠♥♦♣) always visible on card | Covered by design |
| Quality border | Metal=grey/silver/gold/blue, Gem=red/blue/green/purple | Quality icon (metal/gem symbol) + purity stars (I/II/III) | Not Started |
| HP bar thresholds | Green>50%, Yellow 25-50%, Red<25% | Numeric HP value always visible; red flashing has pulse animation independent of color | Not Started |
| Stamp icons | SWORD=red, SHIELD=blue, etc. | Unique icon per stamp type (sword, shield, heart, coin, hammer, shoes, turtle) | Covered by design |
| Hand type indicator | PAIR=purple, FLUSH=blue, etc. | Text label ("PAIR", "FLUSH") always displayed alongside color | Not Started |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Notes |
|---------|-------------|-------|--------|-------|
| Full input remapping | Standard | Keyboard/mouse and gamepad | Not Started | Turn-based game — all inputs are discrete (hit, stand, sort, confirm). No simultaneous input requirements. |
| Input method switching | Standard | Mouse + keyboard + gamepad | Not Started | UI prompts must update dynamically when input method changes (per ADR-0008 dual-focus). |
| Sort timer adjustment | Standard | Sort phase (default 30s) | Not Started | Range: 15s–60s, or toggle to unlimited. Default 30s. Critical for cognitive accessibility — high load moment. |
| Drag-and-drop alternatives | Standard | Card sorting phase | Not Started | Keyboard: select card with arrow keys, press Enter to pick up, arrow to target position, Enter to place. Gamepad: same with D-pad and A button. |
| Hold-to-press alternatives | Standard | Any hold inputs | Not Started | No hold inputs currently designed. If added, must offer toggle alternative. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Notes |
|---------|-------------|-------|--------|-------|
| Sort phase cognitive load warning | Standard | Sort phase | Not Started | 6 systems active simultaneously (card drag, stamp awareness, item usage, hand type display, HP monitoring, timer). Consider: tutorial that introduces systems one at a time across first 3 opponents. |
| Tutorial persistence | Standard | All mechanics | Not Started | First opponent introduces basic hit/stand. Opponent 2 introduces stamps. Opponent 3 introduces quality. Shop after opponent 1. Help section accessible from pause menu. |
| Pause anywhere | Basic | All gameplay states | Not Started | Turn-based — pausing is natural between phases. Timer pauses during pause menu. |
| Sort timer visibility | Standard | Sort phase | Not Started | Always visible countdown. Last 5s red flash (with non-color backup: pulse animation). Auto-confirm on expiry = safe default (draw order). |
| Hand type preview | Standard | Sort phase | Not Started | Display detected hand type and per-card multiplier preview during sorting. Reduces mental calculation load. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Notes |
|---------|-------------|-------|--------|-------|
| Subtitles/captions | N/A | No voice acting | N/A | Card game — all information is visual/text. No spoken dialogue. |
| Independent volume controls | Basic | Music / SFX / UI audio | Not Started | 3 independent sliders. Default 80%. |
| Visual equivalents for audio cues | Standard | Settlement SFX, gem destroy, card flip | Not Started | Every SFX that signals a game event must have a visual equivalent already on screen (card flip = visible swap, gem destroy = border shatter animation). |

---

## Per-Feature Accessibility Matrix

| System | Visual | Motor | Cognitive | Auditory | Status |
|--------|--------|-------|-----------|----------|--------|
| Card Data Model | Suit colors need dual encoding | N/A — turn-based | N/A — data layer | N/A | Not Started |
| Point Calculation | N/A — internal | N/A | N/A | N/A | N/A — pure function |
| Hand Type Detection | Hand type colors need labels | N/A | Multiplier preview reduces mental load | N/A | Not Started |
| Stamp System | Stamp colors → icons (already designed) | N/A | N/A | N/A | Partial |
| Card Quality | Quality border colors need patterns/icons | N/A | N/A | N/A | Not Started |
| Combat System | HP bar color thresholds need numeric backup | N/A — no real-time input | Track HP + defense simultaneously | N/A | Not Started |
| Resolution Engine | Settlement animation needs motion reduction option | N/A | Per-card results displayed visually | Settlement SFX needs visual backup | Not Started |
| Card Sorting | N/A | Drag-and-drop needs keyboard alternative | 6 systems active — highest load moment; timer adjustable | Timer expiry audio needs visual flash | Not Started |
| Side Pool | Bet tier buttons need clear labels | N/A | Payout odds should be visible before betting | N/A | Not Started |
| Shop | Quality/stamp icons need color-independent identification | N/A | Pricing information clearly displayed | N/A | Not Started |
| AI Opponent | N/A | N/A | N/A | N/A | N/A — non-visual system |
| Chip Economy | Chip counter tween needs motion reduction option | N/A | N/A | N/A | Not Started |
| Round Management | Phase indicator always visible | N/A | Phase name + progress indicator | N/A | Not Started |
| Match Progression | Opponent number clearly displayed | N/A | N/A | N/A | Not Started |
| Table UI | All of above aggregated | All of above aggregated | All of above aggregated | All of above aggregated | Not Started |
| Item System | Item icons need color-independent identification | Item use during sort = click + target; keyboard alternative needed | Item effects displayed clearly | N/A | Not Started |

---

## Accessibility Test Plan

| Feature | Test Method | Pass Criteria | Status |
|---------|------------|--------------|--------|
| Colorblind modes | Coblis simulator on all card and UI screenshots | All 4 suits distinguishable in all 3 modes; quality tiers distinguishable | Not Started |
| Text contrast | Contrast analyzer on card text, HUD, menu text | ≥ 4.5:1 for all body text; ≥ 3:1 for large text | Not Started |
| Keyboard-only playthrough | Complete full game using only keyboard | All phases completable without mouse | Not Started |
| Gamepad-only playthrough | Complete full game using only gamepad | All phases completable; UI prompts show gamepad icons | Not Started |
| Sort timer adjustment | Set timer to 60s and unlimited; verify both work | Timer respects setting; auto-confirm works at expiry | Not Started |
| UI scaling | Set to 75% and 150%; play full round at each | No layout break; all text legible; cards clickable at 75% | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Mitigation |
|---------|--------------|-----------------|------------|
| Screen reader for game state | Comprehensive | Godot 4.6 AccessKit covers menus; extending to dynamic card state requires custom implementation | All game state available as visible UI text; pause menu shows full summary |
| Mono audio | Comprehensive | Minimal spatial audio in card game; low impact | Evaluate post-launch |
| Full subtitle customization | Comprehensive | No voice acting; all text is UI-rendered and scales with UI scaling | Two preset styles (default + high-readability) as partial mitigation |

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Does Godot 4.6 AccessKit support dynamic accessibility node updates for HUD elements? | ux-designer | Check engine-reference/godot/ docs |
| Sort timer unlimited mode — does this break game balance for AI pacing? | game-designer | Evaluate during playtesting |
