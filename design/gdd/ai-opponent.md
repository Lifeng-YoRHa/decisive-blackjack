# AI 对手系统 (AI Opponent System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: 策略深度 — AI 对手行为、决策逻辑、难度缩放

## Overview

AI 对手系统是《决胜21点》的 AI 行为控制层。它管理三个核心职责：AI 牌组生成（每个对手开始时创建 52 张带随机印记和卡质的卡牌实例）、AI 决策循环（要牌/停牌、特殊玩法选择、牌型选择、卡牌排序策略）、以及 AI 难度缩放（通过 HP 曲线、印记/卡质概率、决策策略的参数化调整）。系统消费点数计算引擎的 `simulate_hit` 函数评估爆牌风险，消费牌型检测系统的 `ai_hand_type_score` 公式评估牌型选择，实现卡牌排序系统的 `tiebreak_function` 接口提供上下文感知排序，并遵循特殊玩法系统的启发式规则（双倍下注在点数 {10,11}、可分牌时总是分牌、对手明牌为 A 时总是买保险）。AI 对手系统不驱动游戏流程——它仅提供决策输出，由回合管理系统在适当时机调用。在数据层面，AI 系统是一个策略函数集合：给定当前游戏状态（手牌、HP、防御、对手明牌、牌堆剩余），产出确定的行动指令（HIT / STAND / DOUBLE_DOWN / SPLIT / BUY_INSURANCE）和排序偏好。

## Player Fantasy

**读牌与破码 — 从未知到掌控**

核心时刻：对手 3 的明牌是方片 7，暗牌不可见。你站在 16 点——要还是不要？你回忆前几轮的交手：这个对手总是在 16 点要牌，总是买保险，从不手软。你算过——它要牌后爆牌的概率超过 60%。你选择停牌。AI 翻开暗牌：方片 9，总计 16。它要牌——抽出方片 5——21。你的心脏停跳一秒。但下一轮，你记住了：这个对手在 16 点必打，那你就把防御排到它能打出伤害的位置。你不再是在和一个未知对手赌博——你是在破解一个有规律的庄家。

AI 对手系统的玩家幻想是**从不确定性到掌控感的转变**。每轮对战，AI 的暗牌和决策构成不确定性——你不知道它手里有什么，不知道它会要牌还是停牌，不知道它的卡牌如何排序。这正是经典 21 点的紧张感来源。但跨轮次对战后，规律浮现：这个对手总是在 16 点要牌，那个对手总在 10 点双倍下注，Boss (opponent 8) 耐心地停牌在 17，用 300 HP 的血池碾压你。一旦你读出规律，游戏从"我在赌"变为"我在计算"。AI 不再是不可预测的黑箱——它是一本你可以翻阅的说明书，前提是你活过足够多的回合。

## Detailed Design

### Core Rules

**1. 系统性质**

AI 对手系统是一个确定性的策略函数集合。给定相同的游戏状态（手牌、牌堆、HP、防御、对手明牌），始终产出相同的决策输出。系统不持有跨回合的可变状态——每次决策调用都是无副作用的纯计算。系统不驱动游戏流程，由回合管理系统在适当时机调用。

**2. AI 信息模型**

AI 与玩家拥有相同的可见性模型：
- AI 可见：自身的完整手牌 + 对手（玩家）的第一张牌（明牌）
- AI 不可见：对手的暗牌、对手的牌型检测结果、对手的排序结果
- AI 使用完美算牌：追踪牌堆中所有已发出的卡牌，精确知道剩余牌堆的分布（52 张牌中已发出哪些 rank 和 suit）

**3. AI 牌组生成**

每个新对手开始时，AI 牌组重新生成（52 张 `CardInstance(owner=AI)`）。

牌组生成步骤：
1. 创建 52 个实例（每种 suit+rank 恰好一张），所有 `quality_level=III`
2. 分配印记（加权随机）：
   - 按 `ai_stamp_prob_table[opponent_number]` 概率决定每张牌是否有印记
   - 有印记的牌按权重分配：SWORD 25%, SHIELD 20%, HEART 15%, HAMMER 10% (硬上限 3), COIN 10%, RUNNING_SHOES 10%, TURTLE 10%
   - 约束：总印记数 ≤ `ai_max_stamps`(30)，HAMMER ≤ `ai_max_hammers`(3)
3. 分配卡质（加权随机）：
   - 按 `ai_quality_prob_table[opponent_number]` 概率决定每张牌是否有卡质
   - AI 牌组**仅生成宝石质**，不生成金属质。每个卡质槽位均为战斗有效
   - 宝石分布：RUBY 30% (→方片), SAPPHIRE 25% (→红桃), OBSIDIAN 25% (→黑桃), EMERALD 20% (→草花)
   - 宝石遵守花色限制：`is_valid_assignment(suit, quality)` 校验
   - 约束：有卡质的牌数 ≤ `ai_max_qualities`(30)
   - 后期对手卡质等级提升（见难度缩放表）

**4. AI 要牌/停牌决策**

AI 使用分层决策逻辑，策略质量随对手序号提升。

所有对手共用的硬规则：
- 爆牌时强制停牌（`is_bust=true` → STAND）
- 已停牌后不再决策

决策层次（按 `ai_decision_tier` 查表）：

| 等级 | 对手 | 策略 | 逻辑 |
|-------|------|------|------|
| BASIC | 1-3 | 固定阈值 | `point_total ≤ ai_hit_threshold → HIT, else STAND` |
| SMART | 4-6 | 风险评估 | 使用 `simulate_hit` + 牌堆分布计算爆牌概率，与阈值比较 |
| OPTIMAL | 7-8 | 概率优化 | 同 SMART，但阈值更紧 + 考虑 HP 危急度调整 |

**BASIC 层（对手 1-3）**：

```
IF point_total ≤ ai_hit_threshold[opponent]:
    → HIT
ELSE:
    → STAND
```

| 对手 | ai_hit_threshold |
|------|-----------------|
| 1    | 14 (积极要牌，易爆牌) |
| 2    | 15 |
| 3    | 16 |

**SMART 层（对手 4-6）**：

```
bust_prob = calculate_bust_probability(current_point_result, remaining_deck)
IF bust_prob < ai_bust_tolerance[opponent]:
    → HIT
ELSE:
    → STAND
```

`calculate_bust_probability` 算法：
1. 枚举剩余牌堆中每种可能抽到的牌的 rank
2. 对每种牌调用 `simulate_hit(current, card)` 计算 `is_bust`
3. 爆牌概率 = 爆牌情况数 / 总可能情况数（按剩余牌数加权）

| 对手 | ai_bust_tolerance |
|------|------------------|
| 4    | 0.50 (50% 爆牌概率以下才要牌) |
| 5    | 0.40 |
| 6    | 0.35 |

**OPTIMAL 层（对手 7-8）**：

在 SMART 基础上增加 HP 危急度调整：

```
bust_prob = calculate_bust_probability(...)
desperation = 1.0 - (ai_hp / ai_max_hp)

effective_tolerance = ai_bust_tolerance[opponent] + (desperation × desperation_bonus)

IF bust_prob < effective_tolerance:
    → HIT
ELSE:
    → STAND
```

`desperation_bonus` 使 AI 在 HP 低时更愿意冒险要牌。`effective_tolerance` 最大值为 0.90（AI 永远不会在爆牌概率 >90% 时要牌）。

| 对手 | ai_bust_tolerance | desperation_bonus |
|------|------------------|-------------------|
| 7    | 0.30 | 0.15 |
| 8    | 0.25 | 0.20 |

**5. AI 特殊玩法决策**

| 决策 | AI 行为 | 规则 |
|------|---------|------|
| 双倍下注 | `point_total ∈ {10, 11}` 时触发 | DD-2 |
| 分牌 | 起始两张牌 rank 相同时**总是分牌** | 用户决策 |
| 保险 | 对手（玩家）明牌为 A 时**总是买保险**，支付 6 HP | INS-6 |

分牌后的子手牌各自独立使用上述要牌/停牌逻辑（决策层不变）。

**6. AI 牌型选择**

AI 使用牌型检测系统的 `ai_hand_type_score` 公式评估所有匹配牌型，选择分数最高的：

```
scores = [ai_hand_type_score(option) for option in hand_type_result.matches]
selected = argmax(scores)
```

当多个牌型得分相同时，使用确定性排序优先选择：`TWENTY_ONE > FLUSH > TRIPLE_SEVEN > THREE_KIND > PAIR > BLACKJACK_TYPE`（`SPADE_BLACKJACK` = ∞ 始终选中）。

分牌后的手牌仍遵循 SP-5 压制规则（不触发 `BLACKJACK_TYPE` 和 `SPADE_BLACKJACK`）。

**7. AI 卡牌排序策略**

AI 实现卡牌排序系统的 `tiebreak_function` 接口。策略按 `ai_sort_strategy` 查表：

| 对手 | 策略 | 行为 |
|------|------|------|
| 1-3 | `RANDOM` | tiebreak 按原始顺序（发牌顺序）——不优化 |
| 4-5 | `DEFAULT` | 按 effect_value DESC, rank DESC, suit ASC（排序系统默认） |
| 6-8 | `TACTICAL` | 上下文感知排序：黑桃/SHIELD 优先（建防御），方片/SWORD 其次（输出），红桃/HEART 根据 HP 决定位置 |

**TACTICAL 排序详细规则**：
```
1. 按 stamp_sort_key 执行 Pass 2（跑鞋/乌龟位置不变）
2. 在同一 stamp_sort_key 组内：
   a. 按 suit 优先级：SPADES > HEARTS(if hp < 0.5×max_hp) > DIAMONDS > HEARTS(otherwise) > CLUBS
   b. 同 suit 按 effect_value DESC
   c. 同 effect_value 按 rank DESC, suit ASC
```

**8. AI 难度缩放**

所有缩放参数通过 8 位查找表控制：

**牌组质量缩放**：

| 对手 | stamp_prob | quality_prob | quality_level 分布 |
|------|-----------|-------------|-------------------|
| 1 | 0.30 | 0.20 | 100% III |
| 2 | 0.35 | 0.25 | 100% III |
| 3 | 0.40 | 0.30 | 100% III |
| 4 | 0.45 | 0.35 | 70% III / 30% II |
| 5 | 0.50 | 0.40 | 50% III / 50% II |
| 6 | 0.55 | 0.45 | 30% III / 70% II |
| 7 | 0.60 | 0.50 | 50% II / 50% I |
| 8 | 0.65 | 0.55 | 30% II / 70% I |

**决策质量缩放**：

| 对手 | decision_tier | hit_threshold / bust_tolerance | sort_strategy |
|------|--------------|-------------------------------|---------------|
| 1 | BASIC | 14 | RANDOM |
| 2 | BASIC | 15 | RANDOM |
| 3 | BASIC | 16 | RANDOM |
| 4 | SMART | 0.50 | DEFAULT |
| 5 | SMART | 0.40 | DEFAULT |
| 6 | SMART | 0.35 | TACTICAL |
| 7 | OPTIMAL | 0.30 + desperation(0.15) | TACTICAL |
| 8 | OPTIMAL | 0.25 + desperation(0.20) | TACTICAL |

### States and Transitions

AI 对手系统自身不持有状态机——它是被回合管理系统调用的策略层。以下状态图描述 AI 在一个对手生命周期内的调用时机：

```
[对手开始]
    │
    ▼
[AI 牌组生成] ←── 52 卡牌 + 印记/卡质分配
    │
    ▼
[AI HP 初始化] ←── lookup(ai_hp_table, opponent_number)
    │
    ▼
[回合循环] ──────────────────────────────────────┐
    │                                            │
    ▼                                            │
[发牌完成]                                       │
    │                                            │
    ▼                                            │
[保险决策] ←── 玩家明牌=Ace? → 总是购买(6HP)     │
    │                                            │
    ▼                                            │
[分牌检查] ←── 起始两张rank相同? → 总是分牌       │
    │                                            │
    ▼                                            │
[要牌/停牌循环] ───────────┐                      │
    │                      │                      │
    ▼                      │ HIT → 继续循环       │
[AI决策: HIT/STAND/DD] ────┘                      │
    │ STAND / DD(抽1张后自动停牌)                  │
    ▼                                            │
[牌型选择] ←── argmax(ai_hand_type_score)         │
    │                                            │
    ▼                                            │
[卡牌排序] ←── tiebreak_function(strategy)        │
    │                                            │
    ▼                                            │
[结算] ←── 由结算引擎执行，AI为被动数据提供者      │
    │                                            │
    ▼                                            │
[生死判定] ─── CONTINUE → 回合循环 ──────────────┘
    │ PLAYER_WIN → [下一对手]
    │ PLAYER_LOSE → [游戏结束]
```

**分牌子流程**（分牌触发时）：

```
[分牌触发]
    │
    ▼
[手牌A: 补1张牌] → [要牌/停牌循环] → [牌型选择] → [排序]
    │
    ▼
[手牌A结算] ←── 共享combat_state
    │
    ├─ 玩家HP=0 → [死亡判定，手牌B不结算]
    │
    ▼
[手牌B: 补1张牌] → [要牌/停牌循环] → [牌型选择] → [排序]
    │
    ▼
[手牌B结算] ←── 共享combat_state（防御从手牌A累积）
    │
    ▼
[防御清零] → [生死判定]
```

### Interactions with Other Systems

| 系统 | 方向 | 数据流 | 触发时机 |
|------|------|--------|---------|
| 卡牌数据模型 (#1) | 双向 | 入：读取 CardInstance 属性；出：生成时写入随机 `stamp`, `quality` | 牌组生成 |
| 点数计算引擎 (#2) | 入 | 调用 `simulate_hit` 计算爆牌概率；读取 `PointResult` | 要牌/停牌决策 |
| 牌型检测系统 (#3) | 入 | 读取 `HandTypeResult.matches`，调用 `ai_hand_type_score` 评估 | 牌型选择 |
| 卡牌排序系统 (#6a) | 出 | 提供 `tiebreak_function` 实现 | 排序阶段 |
| 特殊玩法系统 (#8) | 出 | 提供分牌/双倍下注/保险决策输出；消费 AI 保险支付(6HP) | 特殊玩法窗口 |
| 战斗状态系统 (#7) | 入 | 读取 `ai_hp`, `ai_max_hp` 计算危急度 | OPTIMAL 层决策 |
| 筹码经济系统 (#10) | 无 | AI 无筹码，chip_output 对 AI 为空操作 | — |
| 回合管理 (#13) | 双向 | 入：回合管理调用 AI 决策函数；出：AI 返回行动指令 | 每个决策点 |
| 结算引擎 (#6) | 间接 | AI 提供 sorted_hand 和 per_card_multiplier 作为管道输入 | 排序完成后 |
| 牌桌 UI (#15) | 出 | AI 决策事件（要牌/停牌/分牌/DD）用于动画表现 | 决策后 |

## Formulas

### 1. AI 爆牌概率计算 (calculate_bust_probability)

The `calculate_bust_probability` formula is defined as:

```
bust_prob = COUNT(busting_cards) / COUNT(remaining_cards)

busting_cards = { card in remaining_deck | simulate_hit(current, card).is_bust == true }
remaining_deck = full_deck - dealt_cards - current_hand
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| current | — | PointResult | — | 当前手牌点数结果 |
| remaining_deck | D_r | Array[CardPrototype] | 0 ~ 52 | 牌堆中剩余的卡牌原型 |
| busting_cards | N_b | int | 0 ~ \|D_r\| | 导致爆牌的剩余牌数 |
| bust_prob | P_b | float | 0.0 ~ 1.0 | 爆牌概率 |

**Output Range:** [0.0, 1.0]
**Example:** 当前 total=18, soft=0，剩余牌堆含 [2,3,5,7,10,K] → simulate_hit 结果: 20,21,23,25,28,28 → busting={7,10,K} → bust_prob = 3/6 = 0.50

### 2. AI 要牌/停牌决策 (ai_hit_stand_decision)

**BASIC tier:** `action = HIT IF point_total ≤ threshold ELSE STAND`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| point_total | int | 2 ~ 31 | 当前手牌总点数 |
| threshold | int | 14 ~ 16 | 查表 ai_hit_threshold |

**SMART/OPTIMAL tier:** `action = HIT IF bust_prob < effective_tolerance ELSE STAND`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| bust_prob | float | 0.0 ~ 1.0 | 来自 calculate_bust_probability |
| effective_tolerance | float | 0.10 ~ 0.90 | ai_bust_tolerance + desperation × desperation_bonus |

### 3. AI 牌型选择 (ai_hand_type_selection)

```
FOR each option in matches:
    score = ai_hand_type_score(option)  // 定义于牌型检测系统 GDD
selected = option_with_max_score
ties → 按固定优先级: TWENTY_ONE > FLUSH > TRIPLE_SEVEN > THREE_KIND > PAIR > BLACKJACK_TYPE
SPADE_BLACKJACK → score = ∞, 始终选中
```

### 4. AI 牌组生成概率 (ai_deck_generation)

`stamp_count ~ Binomial(52, ai_stamp_prob_table[opponent])`, capped at `ai_max_stamps`(30)

`quality_count ~ Binomial(52, ai_quality_prob_table[opponent])`, capped at `ai_max_qualities`(30)

宝石类型分类分布: `P(RUBY)=0.30, P(SAPPHIRE)=0.25, P(OBSIDIAN)=0.25, P(EMERALD)=0.20`, 受花色限制约束。

印记类型分类分布: `P(SWORD)=0.25, P(SHIELD)=0.20, P(HEART)=0.15, P(HAMMER)=0.10, P(COIN)=0.10, P(RUNNING_SHOES)=0.10, P(TURTLE)=0.10`, HAMMER 硬上限 3。

## Edge Cases

- **如果 AI 在 BASIC 层（对手 1-3）打出 soft 14-16**：按阈值正常 HIT。例如对手 1 阈值 14，soft 14（如 [A, 3]）→ HIT。这可能导致软手变硬后爆牌。这是有意设计——早期对手过度激进是难度调节的一部分。

- **如果 AI 分牌后两手牌都爆牌**：两手牌独立爆牌自伤，共享同一个 HP 池。总自伤 = hand_A_bust_damage + hand_B_bust_damage。按 SP-9，手牌 A 爆牌自伤若导致 AI HP 降至 0，手牌 B 不结算。

- **如果 AI 完美算牌发现剩余牌堆为空**：不应发生（52 张牌足够 21 点），但作为安全网：强制 STAND。此情况仅在牌堆管理异常时出现。

- **如果 AI 分牌后一手是 soft hand**：子手牌独立使用决策逻辑。`simulate_hit` 正确处理软→硬降级，SMART/OPTIMAL 层使用 `calculate_bust_probability` 自然处理此情况。BASIC 层不感知软/硬差异——阈值判定基于 point_total，不考虑 soft_ace_count。

- **如果多个牌型得分完全相同且优先级序列无差异**：理论上不可能——优先级序列保证终止。如果两个 PAIR 得分相同（不同 rank），选第一个检测到的（确定性，按 rank 枚举顺序）。

- **如果 AI 牌组生成时 HAMMER 数量超过上限**：先生成再检查。超限时移除最后添加的 HAMMER 并重新随机分配其他印记类型。重复直到满足约束。

- **如果 AI 牌组生成时宝石花色限制导致无法分配**：跳过该卡牌的品质分配（该牌保持 quality=null）。不会违反 30 上限。

- **如果 OPTIMAL 层的 effective_tolerance 超过 0.90**：钳制到 0.90。AI 永远不会在爆牌概率 >90% 时要牌——即使 HP 极低。

- **如果 AI 购买保险（6 HP）后 HP 降至极低**：AI 总是购买保险，即使 HP=7（支付后剩 1）。这是 AI 的固定策略，不考虑自身 HP。保险后 AI HP=1 仍要继续对战——这是 AI 的弱点（可被玩家利用）。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 点数计算引擎 (#2) | 硬 | 调用 `simulate_hit`、读取 `PointResult` | 已完成 |
| 牌型检测系统 (#3) | 硬 | 读取 `HandTypeResult.matches`、消费 `ai_hand_type_score` | 已完成 |
| 特殊玩法系统 (#8) | 硬 | 消费 AI 启发式规则（DD/Split/Insurance）；消费保险支付(6HP) | 已完成 |
| 战斗状态系统 (#7) | 硬 | 读取 `ai_hp`, `ai_max_hp`（OPTIMAL 层危急度计算） | 已完成 |
| 卡牌数据模型 (#1) | 硬 | 生成时写入随机 `stamp`, `quality`；读取 `suit`, `rank`, `effect_value` | 已完成 |
| 卡牌排序系统 (#6a) | 硬 | 提供 `tiebreak_function` 接口实现 | 已完成 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 回合管理 (#13) | 硬 | 调用 AI 决策函数获取行动指令 | 未设计 |
| 结算引擎 (#6) | 间接 | AI 提供 sorted_hand + per_card_multiplier 作为管道输入 | 已完成 |
| 牌桌 UI (#15) | 软 | AI 决策事件用于动画表现 | 未设计 |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Affects |
|------|------|---------|------------|---------|
| `ai_stamp_prob_table` | float[8] | [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65] | 每项 0.0-1.0 | AI 每张牌获得印记的概率。整体调高增加 AI 战术复杂度 |
| `ai_quality_prob_table` | float[8] | [0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55] | 每项 0.0-1.0 | AI 每张牌获得卡质的概率。整体调高增加 AI 战斗输出 |
| `ai_max_stamps` | int | 30 | 0-52 | AI 牌组总印记上限（由卡牌数据模型拥有，本系统消费） |
| `ai_max_qualities` | int | 30 | 0-52 | AI 牌组卡质上限（由卡牌数据模型拥有，本系统消费） |
| `ai_max_hammers` | int | 3 | 0-52 | AI 牌组重锤印记硬上限（由卡牌数据模型拥有，本系统消费） |
| `ai_hit_threshold` | int[3] | [14, 15, 16] | 每项 2-20 | BASIC 层要牌阈值。调低使早期对手更激进（易爆牌=更简单） |
| `ai_bust_tolerance` | float[5] | [0.50, 0.40, 0.35, 0.30, 0.25] | 每项 0.0-1.0 | SMART/OPTIMAL 层爆牌容忍度。调低使 AI 更保守 |
| `desperation_bonus` | float[2] | [0.15, 0.20] | 0.0-0.50 | OPTIMAL 层危急度加成。调高使 AI 在低 HP 时更激进 |
| `ai_doubledown_points` | Set[int] | {10, 11} | {2-20} | AI 双倍下注点数集合（由特殊玩法系统拥有，本系统消费） |
| `ai_always_buy_insurance` | bool | true | — | AI 是否总是买保险（由特殊玩法系统拥有，本系统消费） |
| `ai_sort_strategy` | enum[8] | [R,R,R,D,D,T,T,T] | RANDOM/DEFAULT/TACTICAL | 每个对手的排序策略 |
| `ai_quality_level_table` | float[8][2] | [[1.0,0.0],[1.0,0.0],[1.0,0.0],[0.7,0.3],[0.5,0.5],[0.3,0.7],[0.5,0.5],[0.3,0.7]] | 每项 0.0-1.0 | 每个对手的 [III,II] 或 [II,I] 概率分布。对手 1-3: 100% III; 4-6: III→II 过渡; 7-8: II→I 过渡 |

**Knob interactions:**
- `ai_bust_tolerance` 与 `desperation_bonus` 叠加：低容忍度 + 高危急度加成使 AI 在 HP 低时变激进，在高 HP 时保持保守
- `ai_stamp_prob_table` 和 `ai_quality_prob_table` 的增量一致（每级 +0.05），保持印记和卡质密度的平衡
- `ai_sort_strategy` 不影响决策质量，只影响卡牌执行顺序——TACTICAL 排序使 AI 的防御先于攻击，模拟有经验的玩家

## Visual/Audio Requirements

待牌桌 UI 系统设计时补充。关键反馈时刻：
- AI 要牌/停牌的决策动画
- AI 分牌时的双手牌展示
- AI 买保险时的 HP 扣减效果

## UI Requirements

待牌桌 UI 系统设计时补充。关键交互元素：
- AI 对手状态面板（HP、明牌）
- AI 决策提示（"AI 选择要牌"等通知）

## Acceptance Criteria

### Deck Generation

**AC-01: AI deck generates only gem qualities**
GIVEN AI deck generated for any opponent
WHEN checking all instances where quality is not null
THEN quality ∈ {RUBY, SAPPHIRE, EMERALD, OBSIDIAN}, no COPPER/SILVER/GOLD/DIAMOND

**AC-02: AI deck stamp constraints**
GIVEN AI deck generated
WHEN checking stamp=HAMMER count and stamp!=null count
THEN HAMMER ≤ 3, total stamps ≤ 30

**AC-03: AI deck quality constraints**
GIVEN AI deck generated
WHEN checking quality!=null count
THEN ≤ 30, and all gems respect suit restriction `is_valid_assignment(suit, quality)`

**AC-04: AI deck difficulty scaling**
GIVEN opponent_number=1
WHEN generating AI deck
THEN stamp_prob=0.30, quality_prob=0.20, quality_level all III

GIVEN opponent_number=8
WHEN generating AI deck
THEN stamp_prob=0.65, quality_prob=0.55, quality_level 30% II / 70% I

### Hit/Stand Decisions

**AC-05: BASIC tier — fixed threshold**
GIVEN opponent_number=1, ai_hit_threshold=14, AI hand point_total=14
WHEN AI evaluates hit/stand
THEN decision=HIT

GIVEN opponent_number=1, AI hand point_total=17
WHEN AI evaluates hit/stand
THEN decision=STAND

**AC-06: SMART tier — bust probability**
GIVEN opponent_number=4, ai_bust_tolerance=0.50, bust_prob=0.40
WHEN AI evaluates hit/stand
THEN decision=HIT (0.40 < 0.50)

GIVEN opponent_number=5, ai_bust_tolerance=0.40, bust_prob=0.45
WHEN AI evaluates hit/stand
THEN decision=STAND (0.45 ≥ 0.40)

**AC-07: OPTIMAL tier — desperation adjustment**
GIVEN opponent_number=8, ai_bust_tolerance=0.25, desperation_bonus=0.20, ai_hp=30/300 (desperation=0.90), bust_prob=0.35
WHEN AI evaluates hit/stand
THEN effective_tolerance=0.25+0.90×0.20=0.43, 0.35 < 0.43 → decision=HIT

**AC-08: OPTIMAL tier — tolerance ceiling**
GIVEN effective_tolerance calculates to 0.95
WHEN AI evaluates hit/stand
THEN clamped to 0.90

**AC-09: Bust forces stand**
GIVEN AI hand is_bust=true
WHEN AI evaluates hit/stand
THEN decision=STAND (regardless of decision tier)

### Special Play Decisions

**AC-10: AI double down**
GIVEN AI hand exactly 2 cards and not split, point_total=10
WHEN AI evaluates special plays
THEN triggers double down

GIVEN AI hand point_total=14
WHEN AI evaluates special plays
THEN does not trigger double down

**AC-11: AI split**
GIVEN AI starting two cards have same rank (e.g., [K♥, K♠])
WHEN split check
THEN triggers split

**AC-12: AI insurance**
GIVEN player visible card=Ace
WHEN AI evaluates insurance
THEN buys insurance, pays 6 HP

GIVEN player visible card=K
WHEN AI evaluates insurance
THEN does not buy insurance

### Hand Type Selection

**AC-13: AI selects highest-scoring hand type**
GIVEN AI hand detects FLUSH(×3, score=90) and TWENTY_ONE(×2, score=60)
WHEN AI selects hand type
THEN selects FLUSH by score (90 > 60)

**AC-14: AI selects SPADE_BLACKJACK**
GIVEN AI hand detects SPADE_BLACKJACK (score=∞) and TWENTY_ONE(×2)
WHEN AI selects hand type
THEN selects SPADE_BLACKJACK

### Card Sorting

**AC-15: RANDOM strategy**
GIVEN opponent_number=1, sort_strategy=RANDOM
WHEN AI sorts cards
THEN tiebreak by draw order, no optimization

**AC-16: TACTICAL strategy**
GIVEN opponent_number=7, sort_strategy=TACTICAL, AI HP < 50% max_hp
WHEN AI sorts within default stamp group
THEN priority: SPADES > HEARTS > DIAMONDS > CLUBS

### Determinism

**AC-17: Same inputs produce same decision**
GIVEN AI hand [7♦, K♥], point_total=17, opponent_number=2
WHEN AI decision is called N times (N≥3)
THEN each call returns STAND, no global/static state modified

## Open Questions

1. **AI 分牌是否需要加入 HP 条件？** — 当前设计 AI 总是分牌，但后期对手分牌造成 33%+ 伤害增幅可能过强。Playtest 后若 AI 分牌胜率超过 65%，考虑加入 HP 阈值条件（如 HP > 50% 时才分牌）。负责人：game designer + balance，目标：首次 playtest 后。

2. **卡牌数据模型的 `ai_stamp_probability` / `ai_quality_probability` 是否应被本 GDD 的查找表取代？** — card-data-model 定义了固定值 0.50/0.40，本 GDD 引入了按对手缩放的查找表。两个调参点存在冲突。建议标记旧旋钮为 deprecated，由本 GDD 的 `ai_stamp_prob_table` / `ai_quality_prob_table` 接管。负责人：game designer，目标：consistency-check 时处理。

3. **AI 在 HP=7 时购买保险（支付 6 HP 后剩 1 HP）是否合理？** — 这是 AI 的固定策略盲区，玩家可以利用（故意展示 Ace 诱使 AI 买保险，使其 HP 降至极低）。这可能是有趣的策略深度，也可能是不公平的 exploit。负责人：game designer，目标：playtest 验证。

4. **AI 牌型选择是否需要更智能的策略？** — 当前使用纯分数评估（argmax ai_hand_type_score），不考虑对手状态。例如，FLUSH(×5) 可能比 TWENTY_ONE(×2) 分数更高，但 TWENTY_ONE 的 ×2 作用范围是全部卡牌。后期对手是否应使用上下文感知选择？负责人：AI programmer，目标：Alpha 阶段。

5. **`calculate_bust_probability` 的性能影响？** — 枚举剩余牌堆（最坏 52 张牌）对每张调用 `simulate_hit`，SMART/OPTIMAL 层每次决策最多 52 次 O(1) 计算。总计约 52×5 字段读取 ≈ 260 次算术运算。在 16.6ms 帧预算内应无问题，但需实测确认。负责人：performance analyst，目标：prototype 阶段。
