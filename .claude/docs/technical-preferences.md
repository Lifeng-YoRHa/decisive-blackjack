# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Rendering**: Forward+
- **Physics**: Jolt Physics (default in 4.6+)

## Input & Platform

- **Target Platforms**: PC (Steam / Epic)
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: Card game UI — mouse-driven interactions, gamepad as optional secondary input.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: <100
- **Memory Ceiling**: 256MB

## Testing

- **Framework**: GdUnit4
- **Minimum Coverage**: 80%
- **Required Tests**: Balance formulas, card resolution engine, shop system, special hand detection

## Forbidden Patterns

- No cross-module state mutation — each module solely owns its state; call the owner's API
- No Core → Feature imports — dependencies point downward only (Foundation ← Core ← Feature ← Game Flow ← Presentation)
- No Autoload singletons — GameManager composition root pattern (ADR-0001)
- No `get_node()` or `get_parent()` in subsystems — dependency injection via `initialize()` methods
- No hardcoded gameplay values — all tuning knobs in data-driven config
- No `yield()` — use `await` for coroutines (deprecated since Godot 4.0)
- No string-based `connect()` — use typed signal connections (deprecated since Godot 4.0)
- No untyped `Array` / `Dictionary` — use `Array[Type]` and typed variables

## Allowed Libraries / Addons

- **GdUnit4** — test framework for GDScript unit and integration tests

## Architecture Decisions Log

- ADR-0001: Scene/Node Architecture — Accepted
- ADR-0002: Card Data Model — Accepted
- ADR-0003: Signal Architecture — Accepted
- ADR-0004: Resolution Pipeline — Accepted
- ADR-0005: Save/Load Strategy — Accepted
- ADR-0006: AI Strategy Pattern — Accepted
- ADR-0007: Shop Weighted Random — Accepted
- ADR-0008: UI Node Hierarchy — Accepted
- ADR-0009: Side Pool System — Accepted
- ADR-0010: Chip Economy & Round Management — Accepted
- ADR-0011: Point Calculation & Hand Type — Accepted

## Engine Specialists

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
