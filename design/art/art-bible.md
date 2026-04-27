# Art Bible — 《决胜21点》

> **Status**: Sections 1–4 (Visual Identity Core)
> **Last Updated**: 2026-04-26

---

## 1. Visual Identity Statement

**One-Line Visual Rule:**

> Every pixel must earn its place on the felt — if it does not clarify a game state or deepen the casino-fantasy atmosphere, it does not belong.

The visual anchor is a card table. Not a battlefield, not a fantasy landscape — a table surface where information is the primary visual commodity. Backgrounds behind the play area should be subdued (like felt), not illustrative. Ornamentation belongs on the cards themselves and in the UI chrome, not in the play space.

The dual mandate ("clarify game state" AND "deepen casino-fantasy atmosphere") prevents sterile minimalism. The casino/wizard-workshop atmosphere is not optional — it is the reason the player chose this game over a plain Blackjack app. But atmosphere serves clarity, never the reverse.

### Supporting Principles

#### Principle 1: Layered Legibility

Every visual layer on a card (suit, rank, stamp, quality, position) must be independently readable in under 200ms, even when all layers are present simultaneously on a card at 120x168px.

**Design test:** "When a card carries all five information layers at once, the player can still identify suit and rank first, stamp second, and quality third — without any layer obscuring another."

**Pillar served:** Strategic Depth

**Implications:**
- Card layout uses a fixed spatial grammar: rank+suit in top-left corner, stamp icon in bottom-left, quality as a border treatment, quality level as a small badge near the stamp, position number in a separate tag below the card
- Color is never the sole differentiator between stamps — each stamp has a unique shape silhouette readable at 16x16px
- Quality borders use width and luminance to encode tier: thin/matte for metals, thick/glowing for gems

#### Principle 2: Escalating Presence

Visual density and atmospheric intensity increase as the player progresses through opponents 1 through 8, so the game *looks* harder before the player even reads the numbers.

**Design test:** "When the player enters a match against opponent 8, the visual environment should communicate greater stakes than opponent 1 — through background intensity, opponent portrait prominence, UI chrome detail, and card effect visual weight — without reducing readability."

**Pillar served:** Roguelike Progression

**Implications:**
- Background shifts across 8 opponents: warm and simple for opponent 1, progressively richer and more complex
- Color temperature shift: warm amber → cool deep blue/purple across the arc
- Border ornamentation density and ambient particle intensity escalate
- AI opponent portraits reflect the arc: 1-3 casual/friendly, 4-6 competent/businesslike, 7-8 imposing
- Card effect animations gain visual weight at higher stakes

#### Principle 3: Material Honesty

Visual treatments for card enhancement systems (stamps, qualities) must physically resemble what they represent — metal borders look metallic, gem borders look crystalline, stamp icons look like tools stamped into the card surface.

**Design test:** "When the player sees a card with Ruby quality and a Sword stamp, it should look like a physical object that has had a gem set into its border and a sword symbol pressed into its surface — not two overlapping UI icons on a rectangle."

**Pillar served:** Risk/Reward

**Implications:**
- Metal quality borders: opaque, solid, with subtle brushed-metal or hammered texture. No glow. Copper warm/earthy, silver cool/clean, gold warm/luminous, diamond brilliant/icy-white
- Gem quality borders: translucent facets with internal shimmer (2-3 second animated highlight loop). Ruby deep red glow, Sapphire soft blue pulse, Emerald green light catch, Obsidian dark glassy sheen with sharp highlights
- Stamp icons: rendered as embossed/debossed into the card surface with slight shadow/highlight suggesting physical depth
- Destruction animation: gem border cracks along facets, shards separate and fall away, card beneath revealed slightly duller. Stamp remains undamaged

---

## 2. Mood & Atmosphere

### Guiding Metaphor

A card table, lit in the dark. The world recedes to the surface between you and your opponent. The magic is subtle — it lives in the details (the shimmer of a card effect, the glint of a gem border), not in grand spectacle (no floating runes, no spell circles in the felt). The tone is **premium casino meets wizard's workshop**: a private high-roller room that happens to belong to someone who collects enchanted playing cards.

### Lighting Framework

All lighting in a scene should be understood as coming from three sources:

1. **Table Light** — Warm, focused overhead, casting a conical pool on the table surface. This is the primary illumination. Color temperature: 2700-3200K (incandescent/tungsten). Amber in early game, neutralizing toward late game.
2. **Ambient Light** — Soft glow around the cone's edge, providing minimum readability in the dark background. Always 2 stops below Table Light. Color temperature shifts with opponent progression (warm → cool).
3. **Effect Light** — Brief, localized flashes from card abilities, gem shimmer, and resolution effects. These are transient peak-brightness moments, not sustained. They mark game events, not illuminate scenes.

This three-layer model ensures the table is always the stage, the background is always a backdrop, and the effects are always punctuation.

### 9 Game States

#### 2.1 Main Menu

| Property | Value |
|----------|-------|
| **Primary Emotion** | Warm anticipation — "Welcome somewhere unusual" |
| **Lighting Character** | Single warm focused overhead (2850K), soft vignette. Table surface partially visible in shadow. Cards fanned at an angle catching edge light. |
| **Atmospheric Adjectives** | Intimate, alluring, restrained, suggestive, cozy |
| **Energy Level** | Low-warm — a slow dial turning on, not a switch clicking |
| **Signature Visual Element** | A single, slightly tilted card showing the game title/logo at an elegant angle. Card back visible with subtle metallic sheen hint. Deep shadows around. No particles, no animated effects — just surface, light, and one card. |

#### 2.2 Card Table (Pre-Round) — Side Pool Betting & Intel

| Property | Value |
|----------|-------|
| **Primary Emotion** | Contemplative assessment — weighing options, sizing up the opponent |
| **Lighting Character** | Table Light at 3000K, full cone illuminating table surface. Even lighting, no high-contrast shadows. Calm, readable, functional. |
| **Atmospheric Adjectives** | Contemplative, quiet, attentive, measured, ready |
| **Energy Level** | Low-steady — a held-breath moment before decisions begin |
| **Signature Visual Element** | Side-pool chips neatly placed in designated bet areas — small, solid stacks with clear, tangible presence. Opponent info panel softly lit, readable but not dominant. |

**Opponent Arc Shift:**
- **Opponents 1–3 (Early):** Ambient light warm amber (3200K background). Simple background — plain felt, minimal border ornament. Casual card-table feel.
- **Opponents 4–6 (Mid):** Ambient shifts to neutral/slightly cool (4200K background). Border ornament more refined. Felt texture subtly richer. Atmosphere transitions from casual to focused.
- **Opponents 7–8 (Late):** Ambient light cool, deep blue-indigo (5500K+ background). Border ornament complex, metallic. Table surface darker, denser. Opponent panel casts a faint cold rim-light.

#### 2.3 Card Table (Active Play) — Dealing & Actions

| Property | Value |
|----------|-------|
| **Primary Emotion** | Tight calculation — every decision carries weight |
| **Lighting Character** | Table Light full (3050K), wide cone. Newly dealt cards emit slightly more light — a subtle brightness lift making them pop as they land. Action buttons have a warm accent glow. Contrast subtly increases (1/3 stop) as player's hand approaches 21. |
| **Atmospheric Adjectives** | Taut, focused, deliberate, electric, calculating |
| **Energy Level** | Medium-high — active decision-making loop, not chaotic |
| **Signature Visual Element** | Card-landing animation: card slides from deck, brief glow (effect light flash ~0.3s), settles onto table. Player HP bar a warm, steady glowing indicator. |

**Opponent Arc Shift:**
- **Opponents 1–3:** Card landings gentle. Background quiet. Practice-round energy.
- **Opponents 4–6:** Card landings have subtle weight (heavier animation, slightly brighter effect flash). Background brightness fluctuates faintly. Opponent's visible cards slightly more elaborate in design.
- **Opponents 7–8:** Card landings crisp and sharp. Effect flashes sharper, slightly cooler. Background illuminated by faint ambient pulses on each action. HP bar feels critical — tick marks and percentage more prominent. Table edges darken.

#### 2.4 Card Table (Sort Phase) — 30-Second Timer

| Property | Value |
|----------|-------|
| **Primary Emotion** | Methodical urgency — precise arrangement under time pressure |
| **Lighting Character** | Table Light narrows, more focused (3100K), emphasizing the central card area over periphery. Table edges recede into shadow. Timer itself pulses soft warm glow, shifting to assertive orange in final 10 seconds, then red at 5 seconds. |
| **Atmospheric Adjectives** | Methodical, urgent, concentrated, time-warped, analytical |
| **Energy Level** | Medium — focused attention at varying urgency |
| **Signature Visual Element** | Connection arrows or position numbers between cards showing resolution order. Player's own hand cards slightly elevated (2-3px vertical lift) to signal "draggable." Clear countdown timer display. |

**Opponent Arc Shift:**
- **Opponents 1–3:** Timer present but generous. Sorting feels like learning a tool.
- **Opponents 4–6:** Timer equally felt. Table lighting forms a tighter cone. Background darker.
- **Opponents 7–8:** Timer viscerally felt — larger/brighter countdown digits. Tight reading-cone lighting. Cards elevated and position markers emphasized. Background nearly absent.

#### 2.5 Card Table (Resolution) — Cards Resolve One by One

| Property | Value |
|----------|-------|
| **Primary Emotion** | Payoff satisfaction — watching your arrangement play out |
| **Lighting Character** | Table Light dims to ambient (2950K) as base. Each resolving card casts its own brief Effect Light as the primary source. Space darkens between cards, "blinking" with each new resolution. Highest overall contrast of all table states. |
| **Atmospheric Adjectives** | Dramatic, satisfying, pulsing, narrative, crescendo-building |
| **Energy Level** | High and wavelike — each card resolution is a local peak, brief troughs between. Energy accumulates toward the final card. |
| **Signature Visual Element** | Resolution sequence: card activates (slides forward or slight scale-up), its suit effect flashes (Hearts heal = soft red glow, Diamonds damage = sharp amber flash, Spades defend = cool metallic glint, Clubs earn chips = warm gold "coin" flash), effect values briefly displayed above card, then card settles back. Final card in sequence has a slightly larger effect flash. |

**Opponent Arc Shift:**
- **Opponents 1–3:** Effect flashes soft, brief (~0.4s). Rhythmic, readable, pleasant.
- **Opponents 4–6:** Effect flashes brighter, slightly longer (~0.5s). Gem-quality cards get extra shimmer layer. Darks between deeper. Suit effects more visually weighty.
- **Opponents 7–8:** Effect flashes bright and sharp (~0.6s). Gem-quality cards produce visible glints. Background nearly black between resolutions. HP bar changes accompanied by subtle screen-edge color flash (red edge for HP loss, green for heal). Suit effects carry distinct weight.

#### 2.6 Shop — Between-Round Deckbuilding

| Property | Value |
|----------|-------|
| **Primary Emotion** | The intersection of opportunity and scarcity — "What can I afford, and what must I give up?" |
| **Lighting Character** | Table Light at minimum (2700K, low intensity), replaced by shop lighting: warmer (2750K), wider, diffuse — like a wall sconce or overhead lamp with warm glass shade. Items evenly illuminated. No dramatic shadows. |
| **Atmospheric Adjectives** | Paused, deliberate, frugal, reflective, planning |
| **Energy Level** | Medium-low — intentional deceleration from combat. Focus shifts, not drops. |
| **Signature Visual Element** | Items individually lit as if in a display case — clean, clear, no visual interference. Chip balance prominent in warm numeric display. Cards for sale show investment return subtly. Background static — the shop is a place for attention, not atmosphere. |

**Opponent Arc Shift:**
- **After Opponents 1–3:** Bright and warm. Shopping feels relaxed, pleasant. Warm neutral background.
- **After Opponents 4–6:** Slightly dimmer. Choices weigh heavier. Background neutral-warm.
- **After Opponent 7:** Darkest shop (still readable — never below 3 stops from Table Light). Final resupply stop. Coldest ambient tone (4300K) but items themselves still warm-lit. Serious but not oppressive.

#### 2.7 Victory Screen — Opponent Defeated

| Property | Value |
|----------|-------|
| **Primary Emotion** | Earned relief and achievement — a moment to breathe, not to celebrate wildly |
| **Lighting Character** | Table Light brightens (3200K), slightly warmer and more luminous. Warm bloom, not bright burst. Moderate contrast. Opponent's area now dimmed, focus shifts to player's rewards. |
| **Atmospheric Adjectives** | Relieved, warm, earned, satisfied, fleeting |
| **Energy Level** | Medium — calm crescendo. Victory is milestone, not finale. |
| **Signature Visual Element** | Reward display in clean, warm typography — feels like a confirmation slip, not a slot machine payout. Opponent portrait fades or shrinks on exit. Brief moment (~1.5s) where the table itself seems to exhale — softer, warmer — before transitioning to shop. |

**Opponent Arc Shift:**
- **Defeating Opponents 1–3:** Warm recognition, not dramatic triumph. Cozy lighting.
- **Defeating Opponents 4–6:** Lighting bloom brighter (~3300K). Opponent portrait more imposing on exit. "I conquered this" weight.
- **Defeating Opponent 7:** Victory feels like survival. Light has hard-earned warmth — tired but one fight remains. Reward display prominent. Feels like halftime before a final.

#### 2.8 Defeat Screen — Player Death, Run Over

| Property | Value |
|----------|-------|
| **Primary Emotion** | Contemplative disappointment — "Close. I'll do better next time." |
| **Lighting Character** | Table Light at minimum (2400K, very low intensity). Warm amber fading to near-shadow. Cards readable but light has withdrawn. Reduced contrast — flat, quiet. No harsh shadows, no dramatic darkness. Light gently leaving. |
| **Atmospheric Adjectives** | Still, gentle, reflective, wistful, inviting |
| **Energy Level** | Very low — stillness. The least active moment on screen. |
| **Signature Visual Element** | Cards lying still on table, light receding. Simple game-over text in warm but desaturated serif font. Small progress summary (opponents defeated, rounds reached). "Retry" option clearly visible, highlighted with warm glow — the door is open, not closed. No red flashes, no dramatic fade-to-black. |

#### 2.9 Final Victory — All 8 Opponents Defeated

| Property | Value |
|----------|-------|
| **Primary Emotion** | Genuine completion and satisfaction — "I conquered the room" |
| **Lighting Character** | Table Light at its warmest and brightest (3300K, full intensity). Light fills the scene — no vignette, no dark corners. Ambient light matches Table Light (the only time both sources merge). Effect light moments gentle and broad: cards briefly glow warm. Room feels bathed in soft golden-hour light. |
| **Atmospheric Adjectives** | Resplendent, warm, triumphant, complete, monumental |
| **Energy Level** | Medium-high — confident crescendo. Radiant, not explosive. |
| **Signature Visual Element** | Full deck displayed fanned or arranged with all enhancements visible — metal borders, gem shimmer, embossed stamps. A card collection on display. Background at its richest detail. Summary display with final stats. Atmosphere: "You belong at this table." |

### Opponent Arc Summary

**Color Temperature Gradient (Ambient/Background):**

```
Opponent 1:  3200K (warm amber)
Opponent 2:  3400K
Opponent 3:  3600K
Opponent 4:  4000K (neutral)
Opponent 5:  4400K
Opponent 6:  4800K (cool neutral)
Opponent 7:  5200K (cool blue)
Opponent 8:  5800K+ (deep blue-indigo)
```

The gradient from 3200K to 5800K is continuous — no perceptible jumps at any single opponent transition.

**Complexity Axis (Background + Ornament):**
- Opponents 1–3: Simple, geometric, understated background. Minimal border ornament. Smooth felt.
- Opponents 4–6: Moderate complexity. Subtle patterns in felt. Border present but restrained. Texture density increases.
- Opponents 7–8: Maximum complexity. Rich felt texture. Elaborate metallic/gem-tone border. Background has depth layers. Maximum texture density.

### Atmosphere Constraints

1. **No particle systems as atmosphere.** Particles only for card effects. No floating dust, sparks, or magical nebulae in backgrounds.
2. **No fantasy architecture.** The environment is a card table. No gothic arches, floating crystals, or enchanted pillars. Luxury through material quality, not architectural narrative.
3. **No spiked or jagged visual elements.** Even in defeat, the visual language stays rounded and soft. Defeat is gentle, victory is warm.
4. **Effect Light never sustains beyond 1 second.** All magic is transient. Sustained glow only from quality borders (gem shimmer), which is a material property.
5. **Background is always at least 2 stops below Table Light during active play.** The stage is the table. Everything else is theater.

---

## 3. Shape Language

### Guiding Philosophy

Shapes in this game have two jobs: **direct the eye** and **communicate identity**. Every visual element — from card corners to button edges — speaks using shape grammar. The grammar: round = safety and restoration, sharp/convergent = damage and offense, horizontal/stable = defense, stacked/massive = economy.

### 3.1 Card Geometry

**Card Proportions:** 1:1.4 ratio (120x168px nominal). Standard poker card proportions.
**Corner Radius:** 8px — rounded enough to feel friendly, tight enough to feel precise.

**Quality Hierarchy via Border Treatment (Material Honesty):**

| Quality | Border Width | Visual Treatment | Shape Message |
|---------|-------------|------------------|---------------|
| Copper | 2px | Solid, warm copper tone, subtle brushed horizontal texture | Slim, plain, functional |
| Silver | 3px | Solid, cool silver tone, clean smooth surface | Stepping up. "Coin" grade |
| Gold | 4px | Solid, warm gold tone, soft inner luminosity | Heavy, precious, warm. Draws the eye first |
| Diamond | 5px | Solid, icy-white, bright angular highlights (not glow) | Thickest, most brilliant. Brightest object on the table |

**Gem Quality — Faceted Border Treatment:**

| Quality | Border Width | Visual Treatment | Shape Message |
|---------|-------------|------------------|---------------|
| Ruby | 4px | Translucent facets, deep red glow, 2-3s shimmer cycle | Glowing internal weight |
| Sapphire | 4px | Translucent facets, soft blue pulse, 2-3s shimmer cycle | Gentle rhythm, liquid feel |
| Emerald | 4px | Translucent facets, green light catch, 2-3s shimmer cycle | Bright flash, catches light |
| Obsidian | 4px | Translucent dark glass, sharp highlight edges, 2-3s shimmer cycle | Dark but sharp, sharpened glass |

Gem borders use slightly angled diagonal cuts simulating faceted gem planes (2-3 visible facets). Shimmer animation travels along facet edges. Gems are geometrically distinct from metals: metals are opaque and flat, gems are translucent and deep.

**Quality Level Indicator (3 tiers):**
- Tier III (rough): small irregular polygon (suggests uncut stone)
- Tier II (finer): pentagon shape (partially cut)
- Tier I (finest): perfect circle (fully polished)

**Card Face Spatial Grammar:**
```
┌─────────────────┐
│ A  ♠             │  ← Top-left: card value (large) + suit symbol (medium)
│                  │
│                  │
│                  │
│          [stamp] │  ← Bottom-right: stamp icon (16x16px)
│    [qual]   [lv] │  ← Bottom-left: quality icon + level badge
└─────────────────┘
```

### 3.2 Suit Symbol Shape Language

The four suits use shape to reinforce their gameplay identity:

| Suit | Gameplay Function | Dominant Shape | Shape Rationale |
|------|------------------|---------------|----------------|
| Hearts | Heal | Rounded dome, symmetrical | Round, complete, enclosing. Associated with warmth, safety, restoration. No sharp edges. |
| Diamonds | Damage | Elongated rhombus | Sharp top and bottom vertices. Points upward for aggression, downward for penetration. |
| Spades | Defend | Pointed top, wide base | Transitions from sharp apex to rounded, massive base. Point faces outward, rounded mass faces the holder. |
| Clubs | Economy | Three overlapping circles | Three rounded masses with stem. Shape suggests accumulation, gathering, stacking. |

**Emotional Communication:**
- Hearts (round): "Safety. You are enclosed. Breathe." — healing as tension release
- Diamonds (rhombus): "Something sharp is coming." — damage as pressure
- Spades (point-base): "I am behind the spike." — defense as strategic positioning
- Clubs (overlapping): "More and more." — accumulation, compound growth

### 3.3 Stamp Icon Shape Grammar

All 7 stamps must have unique, recognizable silhouettes at 16x16px:

| Stamp | Icon Concept | Silhouette Description | Unique Shape Signature |
|-------|-------------|----------------------|----------------------|
| Sword | Crossed blade | Vertical line crossed by shorter horizontal, triangular tip at bottom | Apex cross |
| Shield | Kite shield | Rounded top tapering to point at bottom, slight horizontal divide | Rounded-top triangle |
| Heart | Heart shape | Standard heart silhouette — two rounded lobes meeting at downward point | Dual-lobe teardrop |
| Coin | Circle with cross | Solid circle with vertical + horizontal line forming cross pattern inside | Solid circle with interior lines |
| Hammer | Hammer head + handle | Rectangular head (wider) attached to thin vertical handle, head slightly off-center | Asymmetric T |
| Running Shoe | Right-pointing arrow | Wedge shape pointing right, tail flared, two small "legs" at bottom | Horizontal wedge |
| Turtle | Shell + legs | Large circular shell atop four short stubby legs, head protruding right | Circle with protruding legs |

Each stamp has at least 2 unique classification features. No two stamps share the same signature.

**Stamp Material Treatment (Material Honesty):** All stamps rendered as embossed into the card surface — slight inner shadow (depth), subtle highlight on raised edges, no glow, no drop shadow.

### 3.4 UI Shape Grammar

UI draws from the table's visual language — "table metalwork," not a separate visual system.

**Buttons:**
- Primary (Hit, Stand, Confirm): Rounded rectangle (10px radius), solid warm fill, subtle inner glow
- Secondary (Skip, Cancel): Same shape, outline only, reduced contrast
- Danger (Double Down): Same shape, amber border, pulsing subtle glow
- Disabled: All buttons gray out (30% opacity), no glow

**Panels:**
- Info panels (HP, Defense): Rounded top (8px), flat bottom (anchors to screen edge)
- Central info bar: Full-width rectangle, thin divider, no rounding
- Modals (Insurance dialog): Rounded rectangle (12px), warm dark background, 1px gold border
- Tooltips: Sharp bottom pointer, rounded top, warm dark background

**Progress Bars:**
- HP bar: Horizontal capsule (fully rounded ends), gradient fill. At <25% HP, bar physically widens +2px as a shape-level warning
- Sort timer: Linear bar, rounded ends, countdown erodes from right to left
- Opponent progress (3/8): Eight horizontal capsule segments, completed segments glow

### 3.5 Opponent Portrait Shape

**Base Frame:** Rounded rectangle (12px radius) with subtle arched crest at top.

**Escalation across 8 opponents:**

| Opponent | Frame Treatment | Ornamentation | Visual Message |
|----------|----------------|---------------|---------------|
| 1-2 | Simple, thin (2px), warm amber wood | None | Casual. Practice rounds |
| 3 | Medium (3px), slightly deeper wood | Subtle diamond motif at top | Getting into it |
| 4-5 | Medium (3px), neutral to cool metal | Geometric trim along inner edge | Professionalism begins |
| 6 | Thick (4px), cool metal, subtle inner sheen | Fine linear pattern along crest | Experienced |
| 7 | Thick (4px), deep blue-indigo metal, glowing edges | Complex nested geometric pattern | Powerful |
| 8 | Thickest (5px), deep blue-indigo metal, pulsing edge glow | Most intricate geometric pattern, multiple layers | Final boss. Master of this table |

Shape stays constant. Material escalates (wood → metal → glowing metal). Decoration density increases. Color temperature shifts follow the atmosphere system's 3200K→5800K gradient.

### 3.6 Hero Shapes vs Supporting Shapes

**Tier 1 (always attract):** Cards, HP bars, active action buttons (solid fills draw eye first)
**Tier 2 (scan-attract):** Central info bar, stamp icons, quality borders
**Tier 3 (background):** Opponent portrait, opponent hand (face-down), inactive buttons, table surface

Shape hierarchy works through: size contrast (cards dominate), fill vs outline (solid = actionable, outline = informational), and shape complexity (stamps and quality facets as interest points on simple card rectangles).

---

## 4. Color System

### 4.1 Primary Palette (7 Colors)

| Role | Name | Hex | What It Means in This World |
|------|------|-----|---------------------------|
| **Table Surface** | Casino Felt | `#1A472A` | The ground truth. Every scene sits on this. Premium card table. Never for text or interactive elements. |
| **Warm Light** | Amber Glow | `#D4A855` | The default light. Table light, shop warmth, victory, reward. Primary interactive elements, chip displays, gold borders. |
| **Pure Text** | Felt Ivory | `#F0E6D3` | All readable text, card face backgrounds, numeric values. Slightly warm white — "printed on the card" or "lit by the overhead lamp." |
| **Danger/Harm** | Crimson Edge | `#C4392D` | Damage taken, HP loss, bust, gem destruction. Reserved strictly for negative events. Never decorative. Low frequency preserves impact. |
| **Heal/Safety** | Soft Rose | `#D47D8C` | Healing, HP gain, restoration. Warm and muted, not alarming. Communicates recovery, not threat. |
| **Defense/Structure** | Steel Slate | `#7A8B99` | Defense points, armor, shield stamp, structural UI elements. Cool, stable, unyielding. |
| **Economy/Chips** | Mint Copper | `#C49A6C` | Chip earnings, coin stamp, shop prices, economic information. Tangible currency, not illumination. |

### 4.2 Semantic Color Usage

| Color | Meaning | Appears When | Never Appears |
|-------|---------|-------------|---------------|
| Crimson Edge | Harm, loss, destruction | HP loss flash, bust text, gem destruction | On buttons, as suit color, decorative |
| Soft Rose | Healing, recovery | HP gain flash, heal resolution, heart stamp | For damage or danger |
| Amber Glow | Opportunity, warmth | Action buttons, chip balance, rewards, gold borders | For negative events or defense |
| Steel Slate | Stability, armor | Defense bar, shield stamp, UI chrome, disabled states | For excitement, damage, chips |
| Mint Copper | Currency, economy | Chip values, shop prices, coin stamp | For combat effects or HP |
| Casino Felt | The world itself | Table surface, scene backgrounds | For text, interactive elements, effects |
| Felt Ivory | Information, readability | All text, card backgrounds, numeric readouts | As accent or effects |

**Cross-color rules:** No more than 3 semantic colors visible simultaneously in any information cluster. Crimson Edge and Soft Rose never appear adjacent without separation.

### 4.3 Suit Colors (Colorblind-Safe)

| Suit | Color Name | Hex | Distinguishing Feature Beyond Color |
|------|-----------|-----|-------------------------------------|
| **Hearts** | Hearth Red | `#E05565` | Round dome shape; warm temperature |
| **Diamonds** | Sunstone | `#E8A832` | Elongated rhombus shape; golden warmth |
| **Spades** | Deep Lapis | `#2D5FA0` | Pointed top + wide base; cool temperature |
| **Clubs** | Jade Moss | `#3A9E6E` | Three overlapping circles; earthy green |

All four suits maintain perceptual separation across protanopia, deuteranopia, and tritanopia through distinct luminance and hue axes, supplemented by unique shape silhouettes (Section 3.2) and pattern fills (Section 4.9).

### 4.4 Quality Color System

**Metal Qualities — Opaque, Progressive Luminance:**

| Quality | Hex | Border | Visual Message |
|---------|-----|--------|---------------|
| **Copper** | `#B87333` | 2px solid, brushed texture | Entry level — warm, earthy |
| **Silver** | `#B8C0C8` | 3px solid, clean surface | Step up — cool, clean |
| **Gold** | `#D4A855` | 4px solid, soft inner luminosity | Premium — warm, luminous (same as Amber Glow) |
| **Diamond** | `#D6ECF0` | 5px solid, angular highlights | Peak — brilliant, icy, brightest on table |

**Gem Qualities — Translucent, Suit-Aligned:**

| Quality | Hex | Border | Suit Alignment |
|---------|-----|--------|---------------|
| **Ruby** | `#9B1B30` | 4px translucent facets, red glow, shimmer | Diamonds suit (damage) |
| **Sapphire** | `#3A6EA5` | 4px translucent facets, blue pulse, shimmer | Hearts suit (healing) |
| **Emerald** | `#2E8B57` | 4px translucent facets, green light catch, shimmer | Clubs suit (chips) |
| **Obsidian** | `#2C2C3A` | 4px translucent dark glass, sharp highlights, shimmer | Spades suit (defense) |

Each gem's color echoes its locked suit's color but darker and deeper — "the gem IS the suit, distilled."

**Quality Level Badges:** III = rough brown `#8A6B4A`, II = refined gray `#A0A0B0`, I = polished ivory `#F0E6D3`

### 4.5 HP Bar Colors

| HP Range | Color | Hex | Visual Behavior |
|----------|-------|-----|----------------|
| **> 50%** | Life Green | `#4CAF50` | Steady, no pulse |
| **25-50%** | Caution Amber | `#E8A832` | Soft pulse at 0.5Hz |
| **< 25%** | Critical Red | `#C4392D` | Faster pulse at 1.2Hz, bar widens +2px |

Three accessibility channels: (1) color, (2) pulse speed, (3) width change. Numeric HP value always displayed.

### 4.6 UI Color System

| Layer | Background | Border | Text |
|-------|-----------|--------|------|
| **Base** (scene) | `#1A472A` (Casino Felt) | None | N/A |
| **Panel** (HP, Defense) | `#162015` (Shadow Felt) | 1px `#3A5A3A` | `#F0E6D3` (Felt Ivory) |
| **Modal** (dialogs) | `#1C2218` (Deep Felt) | 1px `#D4A855` (Amber Glow) | `#F0E6D3` (Felt Ivory) |
| **Elevated** (cards, buttons) | `#F0E6D3` (Felt Ivory) | varies | `#1A472A` (Casino Felt) |

**Interactive Elements:** Primary buttons = Amber Glow fill. Secondary = outline only. Danger (Double Down) = amber outline with pulse. Disabled = 30% contrast.

**Text Hierarchy:** Primary = Felt Ivory. Accent = Amber Glow bold. Muted = Steel Slate. Warning = Crimson Edge. System = Faded Felt.

### 4.7 Opponent Arc Color Temperature

| Opponent | Kelvin | Hex | Character |
|----------|--------|-----|-----------|
| 1 | 3200K | `#3D2E1A` | Cozy candlelight. Practice table |
| 2 | 3400K | `#382E1D` | Slightly less warm. Still inviting |
| 3 | 3600K | `#332E21` | Transition. Warmth fading |
| 4 | 4000K | `#2A2E2F` | First cool touch. "Practice is over" |
| 5 | 4400K | `#262E35` | Cool creeps in. Businesslike |
| 6 | 4800K | `#222E3C` | Distinctly cool. Steel edge |
| 7 | 5200K | `#1E2C40` | Deep cold. Imposing |
| 8 | 5800K | `#1A2440` | Indigo depths. Final boss |

These are background ambient colors only. Table surface (`#1A472A`) remains constant. Adjacent opponents differ by 2-4 RGB units — no perceptible jumps.

### 4.8 Shop vs. Table Color Separation

| Property | Card Table | Shop |
|----------|-----------|------|
| **Background** | `#1A472A` (Casino Felt, green) | `#2A2218` (Walnut, warm brown) |
| **Ambient tint** | Shifts with opponent arc | Fixed warm `#3D2E1A` (always 3200K) |
| **Lighting** | Table light cone, dramatic | Even, diffuse, "display shelf" |
| **Chip display** | Secondary position | Primary position (top center, larger) |
| **Shadow depth** | Deep vignette | Minimal shadow |

Same 7 primary palette. Shop removes the green and emphasizes warm browns. "You left the table, but you're still in the same room."

### 4.9 Colorblind Safety

**Suit Pattern Fills (secondary identifier beyond color and shape):**

| Suit | Pattern |
|------|---------|
| Hearts | Solid fill, no pattern |
| Diamonds | 3 thin horizontal lines across the rhombus |
| Spades | Vertical center line from apex to base |
| Clubs | One small dot in each lobe center |

**Colorblind Modes:** Three selectable modes (Standard, Protanopia Safe, Deuteranopia Safe, Tritanopia Safe). All modes boost pattern fill contrast from 10% to 25%. No palette changes needed for protanopia or deuteranopia — shape + luminance + patterns sufficient. Tritanopia mode adds thin Felt Ivory outlines to Hearts and Clubs.

**Critical pairs with backup:**

| Pair | Backup Method |
|------|--------------|
| Hearts vs Diamond | Shape (dome vs rhombus) + pattern (solid vs horizontal lines) |
| HP Green vs Yellow vs Red | Pulse speed (none/0.5Hz/1.2Hz) + width + numeric display |
| Copper vs Gold | Border width (2px vs 4px) + luminance difference |

### Typography

**Principle**: Text in Decisive 21 must feel like it belongs on a casino scoreboard — precise, legible, and confident. Two font families serve distinct roles:

| Role | Style | Weight | Usage |
|------|-------|--------|-------|
| **Numeric data** | Clean geometric sans-serif | Bold | HP values, chip counts, point totals, timer, card rank numbers |
| **Flavor text** | Elegant serif or slab-serif | Regular/Italic | Card stamp descriptions, opponent names, phase labels, shop item names |
| **System UI** | Same sans-serif as numeric | Regular | Button labels, settings, tooltips, debug info |

**Font selection criteria**:
- Sans-serif: Monospace-friendly figures (tabular nums) for alignment of HP/chip values. Must be legible at 14px on 1080p. Prefer fonts with a slight geometric character (e.g., Inter, IBM Plex Sans, Noto Sans).
- Serif: Must carry a "premium casino" tone without being ornate. Readable at 14px. Avoid display/decorative serifs. Prefer slab serifs or transitional serifs (e.g., Lora, IBM Plex Serif, Noto Serif).

**Size hierarchy** (at 1080p):

| Context | Min Size | Target Size | Weight |
|---------|----------|-------------|--------|
| Card rank (120×168 card) | 16px | 20px | Bold |
| Card stamp/quality icon label | 12px | 14px | Regular |
| HP / chip / point display | 18px | 22px | Bold |
| Phase indicator | 16px | 18px | Bold |
| Timer countdown | 24px | 32px | Bold (red flash last 5s) |
| Opponent name | 16px | 18px | Regular |
| Button labels | 14px | 16px | Bold |
| Flavor / lore text | 14px | 16px | Regular |
| Settings / debug | 12px | 14px | Regular |

**Scaling**: All sizes scale with UI scale factor (75%–150%). At minimum supported resolution (1280x720), all text meets 14px minimum.

---

## 5. Character Design Direction

[Out of scope — not authored in this session]

---

## 6. Environment Design Language

[Out of scope — not authored in this session]

---

## 7. UI/HUD Visual Direction

[Out of scope — not authored in this session]

---

## 8. Asset Standards

[Out of scope — not authored in this session]

---

## 9. Reference Direction

[Out of scope — not authored in this session]
