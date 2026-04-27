# 《决胜21点》 — 主架构文档

## Document Status
- Version: 1
- Last Updated: 2026-04-26
- Engine: Godot 4.6.2
- GDDs Covered: 16 system GDDs (all approved)
- ADRs Referenced: 11/12 (ADR-0001..0011 all Accepted; see Required ADRs section)
- Technical Director Sign-Off: 2026-04-26 — APPROVED WITH CONDITIONS
- Lead Programmer Feasibility: skipped (lean mode)

## Engine Knowledge Gap Summary

| Risk | Domain | Impact |
|------|--------|--------|
| HIGH | UI dual-focus (4.6) | table-ui sort interaction |
| HIGH | AccessKit (4.5) | accessibility support |
| HIGH | @abstract (4.5) | class hierarchy design |
| MEDIUM | FileAccess return types (4.4) | save/load serialization |
| LOW | All other domains | 2D card game, minimal exposure |

No physics engine needed. Jolt changes irrelevant. Rendering changes minimal (2D only).

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│  表现层 (PRESENTATION)                                          │
│  牌桌 UI (#15) — 渲染、动画、输入、无障碍                      │
├─────────────────────────────────────────────────────────────────┤
│  游戏流程层 (GAME FLOW)                                         │
│  对局进度 (#14) — 对局状态机、对手转换                         │
│  回合管理 (#13) — 阶段控制器、回合编排                         │
├─────────────────────────────────────────────────────────────────┤
│  功能层 (FEATURE)                                               │
│  特殊玩法 (#8) — 保险、分牌、双倍下注                          │
│  筹码经济 (#10) — 余额追踪、交易记录                           │
│  边池系统 (#9) — 赌博小游戏                                    │
│  商店系统 (#11) — 购买、出售、提纯                             │
│  AI 对手 (#12) — 决策引擎、牌组生成器                          │
│  道具系统 (#16) — 消耗品道具                                   │
├─────────────────────────────────────────────────────────────────┤
│  核心层 (CORE)                                                  │
│  结算引擎 (#6) — 6阶段确定性结算管道                           │
│  点数计算 (#2) — 纯函数，无状态                                │
│  牌型检测 (#3) — 纯函数，无状态                                │
│  印记系统 (#4) — 印记查找 + 排序键                             │
│  卡质系统 (#5) — 卡质加成双轨计算                              │
│  卡牌排序 (#6a) — 稳定排序算法                                 │
│  战斗状态 (#7) — 生命值/防御值状态追踪                         │
├─────────────────────────────────────────────────────────────────┤
│  基础层 (FOUNDATION)                                            │
│  卡牌数据模型 (#1) — CardPrototype、CardInstance、枚举          │
│  查找表 — effect_value、chip_value、价格、加成                  │
│  信号/事件基础设施 — 跨系统通信                                 │
│  存档/读档序列化 — 未来实现                                    │
├─────────────────────────────────────────────────────────────────┤
│  平台层 (PLATFORM)                                              │
│  Godot 4.6.2 — SceneTree、节点、信号、Tween、Resource          │
└─────────────────────────────────────────────────────────────────┘
```

## Module Ownership

### 基础层 (Foundation)

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 卡牌数据模型 (#1) | CardPrototype[52], CardInstance[104], enums, lookup tables | CardPrototype.get(), CardInstance fields (read), is_valid_assignment(), all lookup tables | Nothing |
| 信号/事件 | Signal definitions | Typed signals for cross-system communication | Nothing |
| 存档/读档 | Save data schema | save() / load() | All persistent state |

### 核心层 (Core)

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 点数计算 (#2) | Nothing (stateless) | calculate_points(), simulate_hit() | CardInstance |
| 牌型检测 (#3) | Nothing (stateless) | detect_hand_types() | CardInstance, PointResult |
| 印记系统 (#4) | stamp_bonus_lookup | get_stamp_bonus(), get_sort_key() | CardInstance.stamp |
| 卡质系统 (#5) | quality_bonus_resolve | get_quality_bonus(), get_chip_output(), get_combat_effect() | CardInstance, StampSystem |
| 卡牌排序 (#6a) | Nothing (stateless) | compose_settlement_order(), assign_positions() | CardInstance, locked state |
| 战斗状态 (#7) | Combatant structs (hp, defense, pending_defense) | apply_damage(), apply_heal(), add_defense(), queue_defense(), apply_bust_damage(), reset_defense(), get_round_result() | opponent_number (#14) |
| 结算引擎 (#6) | Nothing (stateless pipeline) | run_pipeline() -> RoundResult | All Core + ChipEconomy |

### 功能层 (Feature)

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 特殊玩法 (#8) | doubledown/insurance/split flags | check_conditions(), execute_*() | CombatState, ChipEconomy, CardDataModel |
| 筹码经济 (#10) | balance [0,999], transaction_log | add_chips(), spend_chips(), can_afford() | Nothing |
| 边池系统 (#9) | Nothing (per-round stateless) | resolve_sp7(), resolve_cw() | ChipEconomy |
| 商店系统 (#11) | shop FSM, random inventory | enter/exit_shop(), buy/sell/refine/refresh() | ChipEconomy, CardDataModel, CombatState, ItemSystem |
| AI 对手 (#12) | difficulty config, deck gen | make_decision(), select_hand_type(), generate_deck() | PointCalc, HandTypeDetection |
| 道具系统 (#16) | inventory Array[ItemInstance] (max 5) | purchase_item(), use_item(), get_inventory() | CombatState, ChipEconomy, CardDataModel |

### 游戏流程层 (Game Flow)

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 回合管理 (#13) | phase state, round_counter, first_player, decks | start_round(), advance_phase(), round_result signal | All Feature + Core |
| 对局进度 (#14) | match FSM, opponent_number, total_opponents | get_opponent_number(), get_match_state(), on_round_result() | RoundManagement, ChipEconomy, ShopSystem |

### 表现层 (Presentation)

| Module | Owns | Exposes | Consumes |
|--------|------|---------|----------|
| 牌桌 UI (#15) | All UI nodes, animations, timer | Nothing (pure consumer) | All game state via signals |

### Ownership Rules

1. No module writes to another module's owned state — calls the owner's API
2. Core modules never call Feature or Game Flow APIs (dependency: down only)
3. ChipEconomy sole authority on chip balance — no direct mutation
4. CombatState sole authority on HP/defense — resolution engine calls API
5. CardDataModel sole authority on card attributes — shop calls mutation APIs

## Data Flow

### 1. 结算管道 (Settlement Pipeline)

```
回合管理.start_settlement()
 ├─ PointCalc.calculate_points() × 2 (player + AI)
 ├─ determine settlement_first_player (compare point_totals)
 ├─ HandType.detect() × 2 → player selects → multipliers
 ├─ Sorting.compose_order() × 2
 ├─ CombatState: FIFO execute pending_defense
 └─ ResolutionEngine.run_pipeline()
     ├─ Phase 0a-0c: insurance/SPADE_BLACKJACK/HAMMER
     ├─ Phase 1: doubledown base value ×2
     ├─ Phase 2: bust → CombatState.apply_bust_damage()
     ├─ Phase 3-5 per card (交替):
     │   ├─ stamp effect → CombatState API
     │   ├─ suit+quality effect → CombatState API + ChipEconomy.add_chips()
     │   └─ emit settlement_event (UI animation)
     ├─ Phase 6: gem destroy → CardDataModel mutation
     ├─ Phase 7a: CombatState.reset_defense()
     └─ Phase 7b: CombatState.get_round_result()
```

Synchronous. ChipEconomy.add_chips() per card. CombatState per effect.

### 2. 回合阶段 (Round Phase Flow)

```
DEAL → SIDE_POOL → INSURANCE → SPLIT_CHECK → HIT_STAND → SORT → RESOLUTION → DEATH_CHECK
  │        │            │           │            │          │         │            │
  │    ChipEcon.    SpecialPlays  SpecialPlays   AI:      ItemSys.  Pipeline    MatchProg.
  │   spend/add     check/exec   check/exec   decide()   use_item()            on_result()
  Deck.draw(2)
  UI: show face-up cards                     Player: UI input
```

### 3. 商店购买 (Shop Purchase)

```
can_afford(price) → spend_chips(price) → mutate card/item/heal → revision++
Atomicity: spend before mutate. No rollback needed (chips committed).
```

### 4. 存档/读档 (Save/Load)

```
Save: match_state + opponent_number + player_hp + chip_balance
      + player_deck[52] + item_inventory + round_counter + first_player
Load: validate 104 instances → restore → regenerate AI deck
NOT saved: AI deck, AI HP, transaction log, UI state
```

## API Boundaries

### CardDataModel (Foundation)

```gdscript
class_name CardPrototype  # Immutable. 52 instances.
var suit: Suit; var rank: Rank
var bj_values: Array[int]; var effect_value: int; var chip_value: int

class_name CardInstance   # Mutable. 104 instances.
var prototype: CardPrototype; var owner: Owner
var stamp: Stamp; var quality: Quality; var quality_level: QualityLevel
var revision: int; signal attribute_changed(card)
func destroy_quality() -> void
static func is_valid_assignment(suit, quality) -> bool
```

### CombatState (Core)

```gdscript
class_name CombatState extends Node
signal hp_changed(target, new_hp, max_hp)
signal defense_changed(target, new_defense)
signal round_result_determined(result)
func apply_damage(target, amount) -> void
func apply_heal(target, amount) -> int  # returns overflow
func add_defense(target, amount) -> void
func queue_defense(target, amount) -> void
func apply_bust_damage(target, amount) -> void  # bypasses defense
func reset_defense() -> void
func get_round_result() -> RoundResult
```

### ChipEconomy (Feature)

```gdscript
class_name ChipEconomy extends Node
signal chips_changed(new_balance: int, delta: int, source: String)
func add_chips(amount: int, source: String) -> int
func spend_chips(amount: int, purpose: String) -> bool
func can_afford(amount: int) -> bool
func get_balance() -> int
```

### ResolutionEngine (Core)

```gdscript
class_name ResolutionEngine
signal settlement_step_completed(events: Array[SettlementEvent])
func run_pipeline(input: PipelineInput) -> RoundResult:
```

### RoundManagement (Game Flow)

```gdscript
class_name RoundManager extends Node
signal phase_changed(new_phase: RoundPhase, old_phase: RoundPhase)
signal round_result(result, opponent, round, player_hp, ai_hp)
func start_round() -> void; func advance_phase() -> void
```

### UI Signal Contract

```gdscript
# UI reads state via queries. Emits request signals only.
signal sort_confirmed(sorted_order)
signal hit_requested(); signal stand_requested()
signal doubledown_requested()
signal insurance_accepted(payment)
signal split_accepted()
signal item_used(item_type, target)
signal shop_purchase_requested(item)
```

## ADR Audit

11/12 required ADRs exist (ADR-0001 through ADR-0011 all Accepted). 1 deferred:
ADR-0012 (Performance Budget Validation).

## Required ADRs

### Must Have Before Coding (Foundation & Core)

| # | ADR Title | Key Decision | Covers TRs |
|---|-----------|-------------|------------|
| 1 | Scene/Node Architecture | Autoloads vs scene-tree; how singletons are accessed | CDM-001..012, TUI-001..014 |
| 2 | Card Data Model Implementation | CardPrototype/CardInstance as Resource vs RefCounted; 104-instance lifecycle | CDM-001..012 |
| 3 | Event/Signal Architecture | Direct node signals vs EventBus; resolution events to UI | RES-013, TUI-008..009, all cross-system |
| 4 | Resolution Pipeline Design | Single function vs phased object; animation timing | RES-001..020 |
| 5 | Save/Load Strategy | JSON vs Resource; persist vs regenerate; validation | CDM-010, MP-007, ITEM-001, CHIP-008..009 |

### Should Have Before System Is Built

| # | ADR Title | Key Decision | Covers TRs |
|---|-----------|-------------|------------|
| 6 | AI Strategy Pattern | Strategy interface; deck gen timing; difficulty scaling | AI-001..011 |
| 7 | Shop Weighted Random | Weighted selection; inventory gen; atomic tx | SHOP-001..018 |
| 8 | UI Node Hierarchy | Table screen scene tree; card node lifecycle; animation layer | TUI-001..014 |
| 9 | Side Pool System | Two side bets (SP7, CW) with const lookup tables; ChipEconomy integration | TR-spool-001..004, TR-ui-016 |
| 10 | Chip Economy & Round Management | Typed ChipSource/ChipPurpose enums; RoundPhase FSM; MatchState FSM; ownership boundary | TR-chip-001..007, TR-rm-001..006, TR-mp-001..005 |
| 11 | Point Calculation & Hand Type Detection | Static pure-function classes; RefCounted output structs; HandType enum; tuning knob delivery | TR-pce-001..004, TR-htd-001..004 |

### Can Defer to Implementation

| # | ADR Title | Covers TRs |
|---|-----------|------------|
| 9 | RNG & Deterministic Replay | RES-008, AI-005 |
| 10 | Accessibility Implementation | TUI-012 |
| 11 | Localization Strategy | TUI-013 |
| 12 | Performance Budget Validation | TUI-002, TUI-014 |

## Architecture Principles

1. **Data ownership is absolute** — each module solely owns its state. No cross-module state mutation.
2. **Dependencies point downward** — Core never imports Feature. Feature never imports Game Flow.
3. **Pure functions for computation** — PointCalc, HandTypeDetection, side pool: zero side effects.
4. **Spend before mutate** — chip transactions commit before card mutations. No rollback needed.
5. **UI is a pure consumer** — UI reads state via queries and emits request signals. Never calls game logic directly.
6. **Deterministic pipelines** — resolution engine and AI decisions use seeded RNG for replay.

## Open Questions

1. **Scene architecture**: Should CombatState, ChipEconomy, CardDataModel be Autoload singletons or scene-tree nodes managed by RoundManager? (ADR #1)
2. **Card instance type**: Resource (serializable, Inspector-friendly) vs RefCounted (lightweight, no .tres overhead)? (ADR #2)
3. **Resolution animation**: Should the pipeline emit events and yield for animation, or should UI observe a completed result? (ADR #4)
4. **Save format**: JSON (human-readable, diffable) vs Godot Resource (binary, typed)? (ADR #5)
5. **FLUSH snowball mitigation**: GDD W11 flags this for playtest. Architecture should allow easy retuning of metal_chip_bonus exemption from hand_type_multiplier without breaking the pipeline.
6. **Sort timer UX**: 30s may be too short with item usage. Architecture should make timer duration data-driven (tuning knob).
