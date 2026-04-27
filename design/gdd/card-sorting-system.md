# 卡牌排序系统 (Card Sorting System)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core — settlement order and player agency over resolution sequence

## Overview

卡牌排序系统是《决胜21点》结算前的手牌编排机制。它决定了双方手牌的结算顺序——每张牌在第几个结算位执行效果。排序由两层组成：玩家手动拖拽排列手牌的先后顺序，然后印记系统自动将跑鞋卡牌推至最前、乌龟卡牌推至最后（稳定排序保持手动子顺序）。最终排序结果映射为结算位编号（pos 1, pos 2, ...），由结算引擎按交替模式消费（先手方 pos1 → 后手方 pos1 → 先手方 pos2 → ...）。

在数据层面，排序系统消费 CardInstance 的 `stamp` 字段计算 `stamp_sort_key`（已在印记系统中定义：RUNNING_SHOES=0, 默认=1, TURTLE=2），对每方手牌独立执行稳定排序，输出有序的 CardInstance 列表。在体验层面，排序是玩家对结算结果的唯一主动控制手段——把黑桃防御牌排在前面以吃掉对手的第一张伤害，把重锤牌对准对手的关键位置，或者让跑鞋携带的方片抢先出手。排序的结果决定了"同一手牌能打出多少价值"，是构筑决策从理论到现实的最后一道关卡。

## Player Fantasy

**赌桌操盘手 — 运气到此为止，接下来由我决定**

核心时刻：要牌结束，你摊开手牌。抽牌阶段已经过去——要了多少张、出了什么花色、爆牌还是安全，这些是命运给你的牌。但排序阶段是命运交出指挥权的瞬间。你拖动卡牌，黑桃防御推到第一位，重锤对准对手可能的关键卡，跑鞋自动跳到前排。你确认排序。

这就是整局游戏中你唯一 100% 掌控的时刻。之前的每一轮决策（要不要牌、是否双倍下注、买哪个印记）都在为这一刻做准备。排序不是额外的 UI 操作——它是所有构筑决策的验证仪式。当你看到结算按你排的顺序一步步展开时，你不是在看运气——你是在看自己的判断力。

这个幻想服务了游戏的 Roguelike 构筑核心：印记选择决定了排序的"素材"（哪些牌有跑鞋、乌龟），而排序操作决定了这些素材的价值能否被最大化。一张跑鞋 + 方片 Q 的卡牌，排在第一位是抢先输出 12 伤害，排在最后是错过所有防御机会后被对手清空。同样的牌，不同的排序，截然不同的结局。

## Detailed Design

### Core Rules

**1. 排序阶段入口条件**

排序阶段在以下条件全部满足时激活：
- 双方均完成要牌/停牌/双倍下注操作
- 分牌情况下，每手牌独立触发排序阶段
- 单张手牌（如果存在）直接跳过排序，位置固定为 pos 1
- 空手牌（不应发生）产生空列表，无结算位

**2. 默认顺序**

排序阶段的初始顺序为**发牌顺序**（draw order）——卡牌被发出的先后顺序。玩家未进行任何手动排序时，此顺序即为手动排序结果。

**3. 手动排序（Pass 1）**

玩家通过拖拽操作自由重排手牌。每次拖拽更新卡牌的 `manual_order` 索引。排序阶段内支持无限次拖拽和撤销。手动排序阶段结束时，玩家按"确认排序"按钮锁定手动顺序。

- 如果玩家不执行任何拖拽操作并直接确认，`manual_order` = 发牌顺序
- 如果玩家在计时器结束前未确认，当前 `manual_order` 视为最终顺序（等同于自动确认）
- **卡牌锁定（密码锁）**：道具系统可在 Pass 1 期间调用 `set_card_locked(card_instance, true)` 将对手的卡牌标记为锁定。被锁定的卡牌在 Pass 1 期间不可被移动（不参与 AI tiebreak 重排），保持当前位置。锁定在 Pass 1 结束时（玩家确认排序后）自动解除：`set_card_locked(card_instance, false)`。锁定是排序阶段的瞬态，不持久化到 CardInstance 的永久字段。每个排序阶段开始时所有卡牌的锁定状态重置为 `false`。

**4. 印记自动排序（Pass 2）**

玩家确认手动顺序后，系统对手牌执行稳定排序（stable sort），排序键为 `stamp_sort_key`：

```
sorted_hand = stable_sort_by(hand, key=stamp_sort_key, tiebreak=manual_order)
```

| stamp_sort_key | 印记 | 行为 |
|----------------|------|------|
| 0 | RUNNING_SHOES | 推至最前组 |
| 1 | SWORD/SHIELD/HEART/COIN/HAMMER/null | 默认中间组 |
| 2 | TURTLE | 推至最后组 |

稳定排序保证：同一 `stamp_sort_key` 组内的卡牌保持 `manual_order` 中的相对顺序。印记排序**不覆盖**组内手动顺序——它只决定组之间的前后关系。

**示例**：
玩家手动排序后：[红桃J, 方片7+跑鞋, 黑桃K, 草花Q+乌龟, 方片2+跑鞋]
Pass 2 稳定排序后：[方片7+跑鞋(0), 方片2+跑鞋(0), 红桃J(1), 黑桃K(1), 草花Q+乌龟(2)]
→ 跑鞋组中方片7在方片2之前（保持手动子顺序）

**5. 结算位分配**

排序完成后，每张卡牌分配一个 1-based 结算位编号：

```
sorted_hand[0] → pos 1
sorted_hand[1] → pos 2
...
sorted_hand[n-1] → pos n
```

结算位编号在确认后冻结，任何系统（包括爆牌检测）不可重排。爆牌检测可**无效化**卡牌但不改变位置。

**6. AI 排序**

AI 使用相同的排序框架：
- Pass 2（stamp_sort_key 稳定排序）与玩家相同
- Pass 1（手动排序）替换为 AI 系统提供的**上下文感知排序策略**
- Pass 1 中被锁定的卡牌（`locked == true`）不参与 AI tiebreak 重排，保持在当前位置。tiebreak 仅对未锁定的卡牌执行

排序系统暴露一个 `tiebreak_function` 接口，AI 系统负责实现。接口契约：

```
func tiebreak(cards: Array[CardInstance]) -> Array[CardInstance]
```

输入：同一 `stamp_sort_key` 组内的无序卡牌列表。输出：有序卡牌列表。函数必须确定性（相同输入始终产生相同输出）。

AI 系统可基于游戏状态（HP、防御值、对手明牌等）实现上下文策略。具体策略定义在 AI 对手系统 GDD 中，不属于本系统范围。

默认 AI tiebreak（当 AI 系统未提供自定义策略时）：按 `effect_value` 降序排列，相同 `effect_value` 按 `rank` 降序，再相同按 `suit` 枚举升序。

**7. 交替结算模式**

排序系统为每方手牌独立产出有序列表。交替结算模式由结算引擎负责：

```
先手方 pos 1 → 后手方 pos 1 → 先手方 pos 2 → 后手方 pos 2 → ...
```

先手/后手由回合管理系统决定，不属于本系统。当一方手牌数少于另一方时，较长一方的多余位置在交替中无对手卡牌。

**8. 分牌排序**

分牌后每手牌独立排序：
- 排序系统被调用两次，每次接收一个独立手牌
- 每手牌独立执行 Pass 1 + Pass 2
- 两手牌的交替结算交错方式由结算引擎决定

**9. 排序结果不可变性**

确认排序 + 自动排序完成后，结算位列表冻结。后续任何阶段（爆牌检测、重锤扫描、摧毁检查）可以**标记卡牌状态**但不可**改变位置**。

### States and Transitions

```
[发牌完成, 双方停牌]
       │
       ▼
[排序阶段激活] ←── 初始顺序 = 发牌顺序，所有卡牌 locked=false
       │
       ├── 玩家: 拖拽重排（可无限次撤销）
       │         显示预期结算位编号
       │         跑鞋/乌龟卡牌显示方向箭头
       │
       ▼
[玩家确认排序] ── manual_order 锁定，解除所有密码锁（locked → false）
       │
       ▼
[印记自动排序] ── stable_sort_by(stamp_sort_key, manual_order)（锁定已解除，所有卡牌可自由参与）
       │
       ▼
[最终排序展示] ── 显示 pos 1, 2, 3... 编号
       │
       ▼
[结算开始] ── 位置冻结，交由结算引擎
```

单张手牌路径：`[发牌完成] → [跳过排序] → [pos 1] → [结算]`

### Interactions with Other Systems

| 系统 | 方向 | 数据流 | 触发时机 |
|------|------|--------|---------|
| 卡牌数据模型 (#1) | 入 | 读取 CardInstance（suit, rank, stamp, quality） | 排序阶段开始时 |
| 印记系统 (#4) | 入 | 读取 `stamp` 字段计算 `stamp_sort_key` | Pass 2 自动排序 |
| 结算引擎 (#6) | 出 | 有序 CardInstance 列表 + 结算位编号 | 排序确认后 |
| 结算引擎 (#6) | 出 | 为重锤扫描提供结算位映射 | 排序确认后 |
| 回合管理 (#13) | 入 | 排序阶段激活信号；先手/后手信息 | 双方停牌后 |
| AI 对手系统 (#12) | 出 | `tiebreak_function` 接口 | AI 排序时 |
| 牌桌 UI (#15) | 出 | 手牌顺序变更事件、结算位编号 | 排序全流程 |
| 牌桌 UI (#15) | 入 | 拖拽操作事件、确认按钮信号 | 玩家交互 |
| 道具系统 (#16) | 入 | `set_card_locked(card_instance, bool)` — 锁定/解除对手卡牌的移动约束（Pass 1 瞬态） | 排序阶段（道具使用 / 确认排序时） |
| 道具系统 (#16) | 出 | 密码锁：Pass 1 期间锁定对手卡牌位置，确认后解除，Pass 2 正常执行 | 排序阶段 |

## Formulas

### 1. 结算顺序合成 (compose_settlement_order)

The `compose_settlement_order` formula is defined as:

```
compose_settlement_order = stable_sort(hand, primary=stamp_sort_key ASC, secondary=manual_order ASC)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| hand | H | Array[CardInstance] | 1 ~ 11 | 输入手牌 |
| manual_order | m_i | int | 0 ~ \|H\|-1 | Pass 1 中每张牌的位置索引（0-based） |
| stamp_sort_key | k_i | int | {0, 1, 2} | 印记排序优先级（定义于印记系统 GDD） |

**Output Range**: 长度与输入相同，无增删。稳定排序保证相同 `k_i` 的卡牌保持 `m_i` 相对顺序。
**Example**: 手牌（手动排序后）：[红桃J(k=1,m=0), 方片7+跑鞋(k=0,m=1), 黑桃K(k=1,m=2), 草花Q+乌龟(k=2,m=3), 方片2+跑鞋(k=0,m=4)]
→ 稳定排序后：[方片7+跑鞋(0,1), 方片2+跑鞋(0,4), 红桃J(1,0), 黑桃K(1,2), 草花Q+乌龟(2,3)]

### 2. 结算位分配 (assign_positions)

```
assign_positions = [(card, i+1) for i, card in enumerate(sorted_hand)]
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| sorted_hand | H | Array[CardInstance] | 1 ~ 11 | compose_settlement_order 的输出 |
| position | p_i | int | 1 ~ \|H\| | 1-based 结算位编号 |

**Output Range**: pos 1 到 |H|。单张手牌固定 pos=1。空手牌产生空列表。
**Example**: sorted_hand = [D7+SHOES, D2+SHOES, HJ, SK, CQ+TURTLE] → [(D7+SHOES,1), (D2+SHOES,2), (HJ,3), (SK,4), (CQ+TURTLE,5)]

### 3. AI 默认排序策略 (ai_default_tiebreak)

```
ai_default_tiebreak = sort(cards, by=[effect_value DESC, rank DESC, suit ASC])
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| cards | C | Array[CardInstance] | 1 ~ 11 | 同一 stamp_sort_key 组内的待排序卡牌 |
| effect_value | ev | int | 2 ~ 15 | 来自 effect_value_lookup（卡牌数据模型） |
| rank | r | int | 1 ~ 13 | A=1, 2-10=面值, J=11, Q=12, K=13 |
| suit | s | enum | {HEARTS, DIAMONDS, SPADES, CLUBS} | HEARTS < DIAMONDS < SPADES < CLUBS |

**Output Range**: 长度与输入相同。完全确定性，无随机。
**Example**: 三张默认组卡牌：红桃A(ev=15), 黑桃K(ev=13), 方片Q(ev=12) → [红桃A, 黑桃K, 方片Q]

**注**: `stamp_sort_key` 已在印记系统 GDD 中定义并注册于实体注册表——本 GDD 引用而非重定义。

## Edge Cases

- **如果手牌中所有卡牌的 stamp_sort_key 相同**（如全部无印记）：稳定排序结果等于手动排序。Pass 2 为 no-op，不改变任何位置。系统不需要特殊处理——稳定排序自然退化。

- **如果 2 张手牌中 1 张有跑鞋但玩家手动将其排在第 2 位**：Pass 2 将跑鞋卡牌移至 pos 1，无视玩家的手动放置。跑鞋的"最先结算"承诺是绝对的，手动排序仅在跑鞋组内生效。UI 应在 Pass 1 阶段标注跑鞋卡牌将被自动前移。

- **如果玩家手牌 5 张而 AI 手牌 2 张**（非对称手牌）：每方独立排序。交替结算中，AI 方 pos 3-5 为空。玩家的 pos 3-5 卡牌无对手卡牌地结算。重锤在这些多余位置无目标，效果浪费但卡牌自身花色效果正常执行。

- **如果 AI 默认 tiebreak 收到相同 effect_value + rank 的卡牌**（如红桃J和方片J）：第三级 tiebreak suit 枚举顺序（HEARTS < DIAMONDS < SPADES < CLUBS）保证完全确定性。由于卡牌唯一键约束 `(owner, suit, rank)`，同一手牌内不可能出现完全相同的两张牌——tiebreak 一定能终止。

- **如果分牌后一手有跑鞋另一手有乌龟**：每手牌独立执行 Pass 1 + Pass 2。两手牌的排序结果完全独立，无跨手牌交互。交错方式由结算引擎决定。

- **如果排序计时器结束前玩家未执行任何拖拽**：自动确认，manual_order = 发牌顺序（Core Rule 2 默认值）。Pass 2 正常执行。无错误、无惩罚、无重新提示。这是新玩家的常见路径，系统优雅退化。

- **如果跑鞋将重锤推至非预期位置**（核心策略张力）：玩家手动将重锤牌放在第 1 位，意图对准对手 pos 1。但另一张跑鞋牌在 Pass 2 中被推到最前，重锤移至 pos 2。重锤现在对准对手 pos 2 而非 pos 1。玩家必须在 Pass 1 阶段就考虑 Pass 2 的影响。UI 的排序后预览让玩家在确认前看到重锤的实际落点。

- **如果在排序完成后有卡牌被添加到手牌**（阶段边界违规）：排序系统不重新排序——结果已冻结。排序系统的前置条件是调用方提供冻结的手牌（不再有卡牌加入）。阶段边界由回合管理系统守护。违反此前置条件是上游系统的 bug，不是排序系统的失败。

- **如果空手牌被传入 compose_settlement_order**：稳定排序空数组返回空数组。结算位分配返回空列表。无卡牌结算，无错误。结算引擎收到空列表后跳过该方的结算轮次。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 CardInstance（suit, rank, stamp, quality） | 已完成 |
| 印记系统 (#4) | 硬 | 读取 `stamp` 字段计算 `stamp_sort_key`；引用 `stamp_sort_key` 公式 | 已完成 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 结算引擎 (#6) | 硬 | 消费有序 CardInstance 列表 + 1-based 结算位编号；为重锤扫描提供结算位映射 | 已完成 |
| AI 对手系统 (#12) | 软 | 提供 `tiebreak_function` 接口实现（上下文感知排序策略） | 已设计 |
| 牌桌 UI (#15) | 软 | 消费手牌顺序变更事件、结算位编号用于渲染 | 未设计 |
| 回合管理 (#13) | 软 | 提供排序阶段激活信号、先手/后手信息 | 未设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档是否列出本系统 | 状态 |
|------|-----------|---------------------|------|
| 卡牌数据模型 | 上游 | ✓ 下游（排序系统读取 stamp） | 一致 |
| 印记系统 | 上游 | ✓ 下游（排序系统消费 sort_key） | 一致 |
| 结算引擎 | 下游 | ✓ 已完成（消费排序列表+位号） | 一致 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `sort_timer_seconds` | float | 30.0 | 5.0 ~ 120.0 | 排序阶段计时器。调高给玩家更多思考时间，调低增加节奏压力。低于 10s 对新手不友好 |
| `ui_hand_display_limit` | int | 11 | 5 ~ 15 | UI 布局支持的最大手牌展示数量。排序逻辑无上限，但 UI 需要为这个数量设计卡牌间距。理论最大无爆牌手牌为 11 张 |
| `ai_tiebreak_strategy` | enum | `DEFAULT` | `DEFAULT`, `CONTEXT_AWARE` | AI 在同一 stamp_sort_key 组内的排序策略。DEFAULT=effect_value DESC；CONTEXT_AWARE=AI 系统提供自定义策略。实际策略实现属于 AI 对手系统 |

**注**: `stamp_sort_key` 的值（0/1/2）和各印记的排序行为定义在印记系统 GDD 中，不属于本系统的调参点。跑鞋/乌龟是否影响排序是印记系统的设计决策，排序系统只是执行者。

## Acceptance Criteria

### 核心排序规则

**AC-01: 稳定排序保持手动子顺序**
GIVEN 手牌 [红桃J, 方片7+跑鞋, 黑桃K, 草花Q+乌龟, 方片2+跑鞋]（按此手动顺序）
WHEN 执行 compose_settlement_order
THEN 结果 [方片7+跑鞋(1), 方片2+跑鞋(2), 红桃J(3), 黑桃K(4), 草花Q+乌龟(5)]。跑鞋组保持手动子顺序（方片7在方片2前），默认组保持手动子顺序（红桃J在黑桃K前）。

**AC-02: 默认顺序等于发牌顺序**
GIVEN 排序阶段激活，玩家未执行任何拖拽操作，直接按确认
WHEN 排序完成
THEN 排序结果等于发牌顺序（卡牌按被发出的先后顺序排列）。如果手牌中有跑鞋/乌龟卡牌，印记自动排序仍基于发牌顺序执行。

**AC-03: 结算位 1-based 编号**
GIVEN 排序完成的手牌 [D7+SHOES, D2+SHOES, HJ, SK, CQ+TURTLE]
WHEN 执行 assign_positions
THEN pos 编号从 1 开始（非 0）：D7+SHOES=1, D2+SHOES=2, HJ=3, SK=4, CQ+TURTLE=5。最后一张牌 pos=手牌数量。

**AC-04: 单张手牌跳过排序**
GIVEN 手牌仅 1 张卡牌
WHEN 排序阶段评估入口条件
THEN 跳过排序阶段，该卡牌直接分配 pos=1。无排序 UI 显示。

### 跑鞋与乌龟

**AC-05: 跑鞋无视手动位置推至最前**
GIVEN 2 张手牌 [方片5, 方片9+跑鞋]（玩家手动排序，跑鞋在后）
WHEN 执行 compose_settlement_order
THEN 结果 [方片9+跑鞋(1), 方片5(2)]。跑鞋无视手动位置推至最前。

**AC-06: 乌龟无视手动位置推至最后**
GIVEN 手牌 [草花Q+乌龟, 红桃J, 黑桃K]（手动排序，乌龟在首位）
WHEN 执行 compose_settlement_order
THEN 结果 [红桃J(1), 黑桃K(2), 草花Q+乌龟(3)]。乌龟无视手动位置推至最后。

**AC-07: 跑鞋将重锤推至非预期位置**
GIVEN 手牌 [黑桃K+重锤, 方片7+跑鞋, 红桃J]（手动排序，重锤在首位）
WHEN 执行 compose_settlement_order
THEN 结果 [方片7+跑鞋(1), 黑桃K+重锤(2), 红桃J(3)]。重锤因跑鞋前移从 pos 1 变为 pos 2。

**AC-08: 全手牌相同 stamp_sort_key**
GIVEN 手牌 4 张全部无印记（stamp_sort_key 均为 1）
WHEN 执行 compose_settlement_order
THEN 结果等于手动排序顺序。Pass 2 不改变任何位置。

### AI 排序

**AC-09: AI 默认 tiebreak — effect_value 降序**
GIVEN AI 默认组内有 [红桃A(ev=15), 黑桃K(ev=13), 方片Q(ev=12)]
WHEN 执行 ai_default_tiebreak
THEN 结果 [红桃A, 黑桃K, 方片Q]（effect_value 降序）。

**AC-10: AI tiebreak — rank 降序（第二级）**
GIVEN AI 默认组内有 [红桃K(ev=13), 黑桃J(ev=13)]
WHEN 执行 ai_default_tiebreak
THEN 红桃K 排在黑桃J 之前（effect_value 相同时，rank DESC: K(13) > J(11)）。

**AC-11: AI tiebreak — suit 升序（第三级）**
GIVEN AI 默认组内有 [红桃J(ev=11), 方片J(ev=11)]
WHEN 执行 ai_default_tiebreak
THEN 红桃J 排在方片J 之前（effect_value 和 rank 均相同时，suit ASC: HEARTS < DIAMONDS）。结果完全确定性。

### 特殊场景

**AC-12: 非对称手牌**
GIVEN 玩家手牌 5 张，AI 手牌 2 张
WHEN 每方独立执行排序
THEN 玩家排序输出 5 张卡牌（pos 1-5），AI 排序输出 2 张卡牌（pos 1-2）。两手牌独立排序完成，无错误。

**AC-13: 分牌独立排序**
GIVEN 分牌后 Hand A = [黑桃9+跑鞋, 方片3]，Hand B = [草花7+乌龟, 红桃K]
WHEN 每手牌独立执行排序
THEN Hand A: [黑桃9+跑鞋(1), 方片3(2)]；Hand B: [红桃K(1), 草花7+乌龟(2)]。排序结果互不影响。

**AC-14: 排序结果不可变性**
GIVEN 排序已确认，结算位 [1,2,3,4,5] 已分配
WHEN 后续阶段（爆牌检测、重锤扫描）执行
THEN 结算位编号不变，不被任何后续阶段重新分配。

**AC-15: 计时器超时自动确认**
GIVEN 排序计时器到期，玩家未拖拽也未手动确认
WHEN 系统处理超时
THEN 排序结果等于发牌顺序经印记自动排序后的结果。无错误状态，直接进入结算。

**AC-16: 排序完成后手牌被添加卡牌**
GIVEN 排序已完成并确认，结算位 [1,2,3] 已分配
WHEN 上游系统尝试向手牌添加新卡牌
THEN 排序系统返回冻结的原始结果，不重新排序，不崩溃。新增卡牌不出现在结算位列表中。

**AC-17: 空手牌**
GIVEN 空手牌 [] 被传入 compose_settlement_order
WHEN 执行排序
THEN 返回空列表，assign_positions 返回空列表。无崩溃。

## Visual/Audio Requirements

排序系统的视觉需求已在印记系统 GDD 的 Visual/Audio Requirements 中覆盖：跑鞋/乌龟方向箭头、结算位编号标识、排序后预览。本系统不引入额外的视觉/音频需求。

## UI Requirements

排序系统的主要 UI 交互为拖拽排序 + 确认按钮，属于牌桌 UI 系统的范围。

> **📌 UX Flag — 卡牌排序系统**: This system has UI requirements (drag-and-drop sorting, confirm button, sort timer display, post-sort preview). In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the sort phase interaction **before** writing epics.

## Open Questions

- [ ] 排序计时器默认 30 秒是否合适？需要玩家测试验证——新手可能需要更多时间理解跑鞋/乌龟的影响，老玩家可能觉得 30 秒太长（负责人：playtest，目标：Alpha 阶段前）
- [ ] 玩家是否应该在结算前看到对手的排序结果？当前设计中对手手牌（除第一张外）不可见——排序结果是否同样隐藏？如果隐藏，玩家无法精确瞄准重锤位置（负责人：game design，目标：结算引擎设计时）
- [ ] AI 上下文感知排序策略的具体实现属于 AI 对手系统 GDD——当该 GDD 设计时，需确认 `tiebreak_function` 接口契约是否满足 AI 的需求（负责人：AI system design）
